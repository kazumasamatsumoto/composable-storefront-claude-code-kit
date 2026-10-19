#!/usr/bin/env python3
"""PowerPoint(.pptx / .pptm)と Excel(.xlsx / .xlsm)の文字を Markdown に書き出す。

標準ライブラリだけで動く(追加のインストールは要らない)。マクロは実行しない(XML を読むだけ)。
同じ出力を出す PowerShell 版が transcribe.ps1(Python の無い Windows 用)。

使い方:
  python3 transcribe.py <ファイル> [<ファイル> ...]            # 標準出力へ
  python3 transcribe.py <ファイル> ... -o docs/transcripts     # <フォルダ>/<元の名前>.md へ
  オプション: --max-rows N(1 シートで書き出す行の上限。既定 2000)
終了コード: 0 = すべて書き出せた、1 = 読めないファイルがあった(理由は標準エラー)
"""
import argparse
import datetime
import math
import os
import posixpath
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

P = '{http://schemas.openxmlformats.org/presentationml/2006/main}'
A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
S = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
REL = '{http://schemas.openxmlformats.org/package/2006/relationships}'
DGM = '{http://schemas.openxmlformats.org/drawingml/2006/diagram}'

# 日付として扱う組み込みの表示形式(14〜22、45〜47 と、日本語などの 27〜36、50〜58)
DATE_FMT_IDS = set(range(14, 23)) | set(range(27, 37)) | {45, 46, 47} | set(range(50, 59))


class TranscribeError(Exception):
    pass


def read_xml(z, part):
    try:
        return ET.fromstring(z.read(part))
    except KeyError:
        return None


def rels_of(z, part):
    """part の関係(.rels)を {Id: (種類の末尾, 解決したパス)} で返す。外部リンクは除く。"""
    d, name = posixpath.split(part)
    root = read_xml(z, posixpath.join(d, '_rels', name + '.rels'))
    out = {}
    if root is None:
        return out
    for rel in root.findall(REL + 'Relationship'):
        if rel.get('TargetMode') == 'External':
            continue
        target = rel.get('Target', '')
        if target.startswith('/'):
            path = target[1:]
        else:
            path = posixpath.normpath(posixpath.join(d, target))
        out[rel.get('Id')] = (rel.get('Type', '').rsplit('/', 1)[-1], path)
    return out


def cell_text(s):
    """表のマスに入れる文字: 改行は <br>、| はエスケープ。"""
    return s.replace('\r\n', '\n').replace('\r', '\n').replace('\n', '<br>').replace('|', '\\|')


# ---------------------------------------------------------------- PowerPoint

def para_text(p):
    parts = []
    for el in p:
        if el.tag in (A + 'r', A + 'fld'):
            t = el.find(A + 't')
            if t is not None and t.text:
                parts.append(t.text)
        elif el.tag == A + 'br':
            parts.append('<br>')
    return ''.join(parts).strip()


def paragraphs(tx_body):
    """(段落の文字, 段落の深さ) の並び。空の段落は除く。"""
    out = []
    if tx_body is None:
        return out
    for p in tx_body.findall(A + 'p'):
        text = para_text(p)
        if not text:
            continue
        ppr = p.find(A + 'pPr')
        lvl = int(ppr.get('lvl', '0')) if ppr is not None else 0
        out.append((text, lvl))
    return out


def table_lines(tbl):
    rows = []
    for tr in tbl.findall(A + 'tr'):
        cells = []
        for tc in tr.findall(A + 'tc'):
            texts = [t for t, _ in paragraphs(tc.find(A + 'txBody'))]
            cells.append(cell_text('<br>'.join(texts)))
        rows.append(cells)
    if not rows:
        return []
    width = max(len(r) for r in rows)
    rows = [r + [''] * (width - len(r)) for r in rows]
    lines = ['| ' + ' | '.join(rows[0]) + ' |', '|' + '---|' * width]
    lines += ['| ' + ' | '.join(r) + ' |' for r in rows[1:]]
    return lines


def smartart_lines(z, frame, slide_rels):
    rel_ids = frame.find('.//' + DGM + 'relIds')
    if rel_ids is None:
        return ['- [SmartArt]']
    target = slide_rels.get(rel_ids.get(R + 'dm'))
    data = read_xml(z, target[1]) if target else None
    lines = ['- [SmartArt]']
    if data is not None:
        for pt in data.iter(DGM + 'pt'):
            if pt.get('type', 'node') != 'node':
                continue
            texts = [t for t, _ in paragraphs(pt.find(DGM + 't'))]
            if texts:
                lines.append('  - ' + ' '.join(texts))
    return lines


def shape_lines(z, tree, slide_rels, state):
    """図形を文書の順にたどり、本文の行を返す。最初のタイトルは state['title'] に入れる。"""
    lines = []
    for el in tree:
        tag = el.tag
        if tag == P + 'grpSp':
            lines += shape_lines(z, el, slide_rels, state)
        elif tag == P + 'sp':
            ph = el.find(P + 'nvSpPr/' + P + 'nvPr/' + P + 'ph')
            paras = paragraphs(el.find(P + 'txBody'))
            if ph is not None and ph.get('type') in ('title', 'ctrTitle') and state['title'] is None:
                state['title'] = ' '.join(t for t, _ in paras)
                continue
            lines += ['  ' * lvl + '- ' + t for t, lvl in paras]
        elif tag == P + 'graphicFrame':
            gd = el.find(A + 'graphic/' + A + 'graphicData')
            uri = gd.get('uri', '') if gd is not None else ''
            tbl = gd.find(A + 'tbl') if gd is not None else None
            if tbl is not None:
                lines += [''] + table_lines(tbl) + ['']
            elif uri.endswith('/chart'):
                lines.append('- [グラフ]')
            elif uri.endswith('/diagram'):
                lines += smartart_lines(z, el, slide_rels)
        elif tag == P + 'pic':
            pr = el.find(P + 'nvPicPr/' + P + 'cNvPr')
            descr = (pr.get('descr') or '').strip() if pr is not None else ''
            lines.append('- [画像: ' + cell_text(descr) + ']' if descr else '- [画像]')
    return lines


def notes_lines(z, slide_rels):
    for kind, path in slide_rels.values():
        if kind != 'notesSlide':
            continue
        notes = read_xml(z, path)
        if notes is None:
            return []
        out = []
        for sp in notes.iter(P + 'sp'):
            ph = sp.find(P + 'nvSpPr/' + P + 'nvPr/' + P + 'ph')
            if ph is not None and ph.get('type') == 'body':
                out += [t for t, _ in paragraphs(sp.find(P + 'txBody'))]
        return out
    return []


def transcribe_pptx(z, name):
    pres = read_xml(z, 'ppt/presentation.xml')
    if pres is None:
        raise TranscribeError('ppt/presentation.xml が無い(PowerPoint のファイルではない)')
    pres_rels = rels_of(z, 'ppt/presentation.xml')
    ids = pres.findall(P + 'sldIdLst/' + P + 'sldId')
    body = []
    for i, sid in enumerate(ids, 1):
        part = pres_rels[sid.get(R + 'id')][1]
        sld = read_xml(z, part)
        slide_rels = rels_of(z, part)
        state = {'title': None}
        lines = shape_lines(z, sld.find(P + 'cSld/' + P + 'spTree'), slide_rels, state)
        head = '## スライド %d' % i
        if state['title']:
            head += ': ' + state['title']
        if sld.get('show') == '0':
            head += '(非表示)'
        body += ['', head, '']
        while lines and lines[0] == '':
            lines.pop(0)
        while lines and lines[-1] == '':
            lines.pop()
        body += lines if lines else ['(文字なし)']
        notes = notes_lines(z, slide_rels)
        if notes:
            body += [''] + ['> ノート: ' + notes[0]] + ['> ' + n for n in notes[1:]]
    head = ['# ' + name, '',
            '- 元の資料: %s(正本は元の資料。これは文字起こし)' % name,
            '- 形式: PowerPoint、スライド %d 枚' % len(ids),
            '- 含まないもの: 画像やグラフの中の文字、図形の位置関係と色。必要なら元の資料を PDF にして見る']
    return head + body


# ---------------------------------------------------------------- Excel

def rich_text(el):
    """<si> / <is> の文字。ふりがな(rPh)は除く。"""
    parts = []
    for child in el:
        if child.tag == S + 't':
            parts.append(child.text or '')
        elif child.tag == S + 'r':
            t = child.find(S + 't')
            if t is not None:
                parts.append(t.text or '')
    return ''.join(parts)


def col_number(letters):
    n = 0
    for ch in letters:
        n = n * 26 + (ord(ch) - 64)
    return n


def col_letters(n):
    s = ''
    while n:
        n, rem = divmod(n - 1, 26)
        s = chr(65 + rem) + s
    return s


def is_date_code(code):
    c = re.sub(r'"[^"]*"|\[[^\]]*\]|\\.|_.|\*.', '', code)
    c = re.sub(r'(?i)general', '', c)
    return re.search(r'[ymdhsYMDHS]', c) is not None


def serial_to_text(value, date1904):
    serial = float(value)
    days = math.floor(serial)
    secs = round((serial - days) * 86400)
    if secs >= 86400:
        days += 1
        secs -= 86400
    if days == 0 and secs > 0 and not date1904:
        return '%02d:%02d:%02d' % (secs // 3600, secs % 3600 // 60, secs % 60)
    base = datetime.datetime(1904, 1, 1) if date1904 else datetime.datetime(1899, 12, 30)
    dt = base + datetime.timedelta(days=days, seconds=secs)
    return dt.strftime('%Y-%m-%d') if secs == 0 else dt.strftime('%Y-%m-%d %H:%M:%S')


def transcribe_xlsx(z, name, max_rows):
    wb = read_xml(z, 'xl/workbook.xml')
    if wb is None:
        raise TranscribeError('xl/workbook.xml が無い(Excel のファイルではない)')
    wb_rels = rels_of(z, 'xl/workbook.xml')
    pr = wb.find(S + 'workbookPr')
    date1904 = pr is not None and pr.get('date1904') in ('1', 'true')

    shared = []
    for kind, path in wb_rels.values():
        if kind == 'sharedStrings':
            sst = read_xml(z, path)
            if sst is not None:
                shared = [rich_text(si) for si in sst.findall(S + 'si')]
    date_styles = set()
    for kind, path in wb_rels.values():
        if kind == 'styles':
            st = read_xml(z, path)
            if st is None:
                continue
            codes = {int(f.get('numFmtId')): f.get('formatCode', '') for f in st.iter(S + 'numFmt')}
            xfs = st.find(S + 'cellXfs')
            for i, xf in enumerate(xfs.findall(S + 'xf') if xfs is not None else []):
                fid = int(xf.get('numFmtId', '0'))
                if fid in DATE_FMT_IDS or (fid in codes and is_date_code(codes[fid])):
                    date_styles.add(i)

    sheets = wb.findall(S + 'sheets/' + S + 'sheet')
    body = []
    for i, sh in enumerate(sheets, 1):
        head = '## シート %d: %s' % (i, sh.get('name'))
        if sh.get('state') in ('hidden', 'veryHidden'):
            head += '(非表示)'
        body += ['', head, '']
        target = wb_rels.get(sh.get(R + 'id'))
        ws = read_xml(z, target[1]) if target and target[0] == 'worksheet' else None
        if ws is None:
            body.append('(表のシートではない。グラフのシートなど)')
            continue
        cells = {}
        formulas = []
        for row in ws.iter(S + 'row'):
            for c in row.findall(S + 'c'):
                m = re.match(r'([A-Z]+)(\d+)$', c.get('r', ''))
                if not m:
                    continue
                col, rown = col_number(m.group(1)), int(m.group(2))
                t = c.get('t', 'n')
                v = c.find(S + 'v')
                raw = v.text if v is not None and v.text is not None else ''
                if t == 's' and raw != '':
                    val = shared[int(raw)]
                elif t == 'inlineStr':
                    is_ = c.find(S + 'is')
                    val = rich_text(is_) if is_ is not None else ''
                elif t == 'b':
                    val = 'TRUE' if raw == '1' else ('FALSE' if raw == '0' else raw)
                elif t == 'n' and raw != '' and int(c.get('s', '0')) in date_styles:
                    val = serial_to_text(raw, date1904)
                else:
                    val = raw
                f = c.find(S + 'f')
                if f is not None and f.text:
                    formulas.append('- %s: =%s → %s' % (m.group(0), f.text, val if val != '' else '(値なし)'))
                if val != '':
                    cells[(rown, col)] = val
        if not cells:
            body.append('(空のシート)')
            continue
        rows = sorted({r for r, _ in cells})
        cols = [c for _, c in cells]
        c1, c2 = min(cols), max(cols)
        body.append('範囲: %s%d:%s%d(値のある行だけを書く)' % (col_letters(c1), rows[0], col_letters(c2), rows[-1]))
        body.append('')
        body.append('| 行 | ' + ' | '.join(col_letters(c) for c in range(c1, c2 + 1)) + ' |')
        body.append('|---|' + '---|' * (c2 - c1 + 1))
        for r in rows[:max_rows]:
            body.append('| %d | ' % r + ' | '.join(cell_text(cells.get((r, c), '')) for c in range(c1, c2 + 1)) + ' |')
        if len(rows) > max_rows:
            body.append('')
            body.append('(以下 %d 行は省略。上限は --max-rows(PowerShell 版は -MaxRows)で変えられる)' % (len(rows) - max_rows))
        merges = [mc.get('ref') for mc in ws.iter(S + 'mergeCell')]
        if merges:
            body += ['', '結合セル: ' + '、'.join(merges)]
        if formulas:
            body += ['', '式(表には計算結果を書いた):'] + formulas
    head = ['# ' + name, '',
            '- 元の資料: %s(正本は元の資料。これは文字起こし)' % name,
            '- 形式: Excel、シート %d 枚' % len(sheets),
            '- 含まないもの: 書式と色、グラフ、画像、コメント、非表示の行と列の区別']
    return head + body


# ---------------------------------------------------------------- 入口

def transcribe(path, max_rows=2000):
    name = os.path.basename(path)
    ext = os.path.splitext(name)[1].lower()
    if ext in ('.ppt', '.xls'):
        raise TranscribeError('古い形式(%s)は読めない。PowerPoint / Excel で .pptx / .xlsx として保存し直す' % ext)
    if ext not in ('.pptx', '.pptm', '.xlsx', '.xlsm'):
        raise TranscribeError('対応していない拡張子(%s)。.pptx と .xlsx だけ' % ext)
    try:
        z = zipfile.ZipFile(path)
    except (zipfile.BadZipFile, OSError) as e:
        raise TranscribeError('zip として開けない(パスワード付きか、壊れているか、古い形式): %s' % e)
    with z:
        lines = transcribe_pptx(z, name) if ext.startswith('.ppt') else transcribe_xlsx(z, name, max_rows)
    return '\n'.join(lines) + '\n'


def main(argv=None):
    ap = argparse.ArgumentParser(description='PowerPoint と Excel の文字を Markdown に書き出す')
    ap.add_argument('files', nargs='+')
    ap.add_argument('-o', '--out-dir')
    ap.add_argument('--max-rows', type=int, default=2000)
    args = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    except AttributeError:
        pass
    status = 0
    for f in args.files:
        try:
            md = transcribe(f, args.max_rows)
        except TranscribeError as e:
            print('%s: %s' % (f, e), file=sys.stderr)
            status = 1
            continue
        if args.out_dir:
            os.makedirs(args.out_dir, exist_ok=True)
            out = os.path.join(args.out_dir, os.path.basename(f) + '.md')
            with open(out, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(md)
            print('書き出した: ' + out, file=sys.stderr)
        else:
            sys.stdout.write(md)
    return status


if __name__ == '__main__':
    sys.exit(main())
