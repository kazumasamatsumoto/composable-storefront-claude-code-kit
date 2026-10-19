---
name: cs-office-transcribe
description: PowerPoint(.pptx)と Excel(.xlsx)の資料の文字を Markdown に書き出す(文字起こし)。要件定義書、画面項目定義、API 一覧、引き継ぎ資料などが Office ファイルで渡されたとき、中身を読む・要約する・文書にまとめる前に使う。
allowed-tools: Read, Grep, Glob, Write, Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/transcribe.py *)
---

# PowerPoint と Excel の文字起こし

Claude の Read は .pptx と .xlsx を読めない(中身は zip の中の XML)。このスキルの `scripts/` にある道具で、文字を Markdown に書き出してから読む。

## 1. 道具を選ぶ
- `python3` が動く(macOS、Linux、Python を入れた Windows): `python3 ${CLAUDE_SKILL_DIR}/scripts/transcribe.py <ファイル> -o docs/transcripts`
- Python が無い Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_SKILL_DIR}/scripts/transcribe.ps1 <ファイル> -OutDir docs\transcripts`
- どちらも追加のインストールは要らず、出力は 1 文字も違わない(tests/transcribe で確かめている)。マクロは実行しない。
- 何枚もあるときは、ファイルを並べて 1 回で渡す。

## 2. 書き出されるもの
- 置き場所: `docs/transcripts/<元のファイル名>.md`(例: `要件定義.pptx.md`)。先頭に「正本は元の資料」と書かれる。
- PowerPoint: スライドを**表示される順**に「## スライド N: タイトル」。本文は段落の深さを字下げした箇条書き。表は Markdown の表。グループの中の文字、画像の説明(代替テキスト)、SmartArt の文字、ノート(「> ノート:」)も出す。非表示のスライドには「(非表示)」と付く。グラフは「[グラフ]」の印だけ。
- Excel: シートごとに「## シート N: 名前」。表の左端は行番号、上端は列の文字(A、B…)なので、元のセルの位置が分かる。値のある行だけを書く。式は計算結果を表に入れ、式そのものは表の下に「D8: =SUM(D4:D6) → 3520.1」の形で並べる。日付は 2026-10-19 の形。結合セルとふりがなの扱いは下の「注意」。
- 1 シートの行が多いときは 2000 行で切り、省略した行数を書く(`--max-rows` / `-MaxRows` で変える)。

## 3. 読むときの注意
- **画像やグラフの中の文字は出ない。** スライドが画像ばかりなら(本文がほぼ「[画像]」だけ)、人に「PDF で書き出して渡してほしい」と頼む。Read は PDF を読める。
- Excel の結合セルは、左上のセルにだけ値がある。表の下の「結合セル: A1:D1」を見て、どこまでが 1 つの見出しかを読む。
- ふりがな(ルビ)は出さない。書式と色、コメント、非表示の行と列の区別も出ない。色で意味を持たせている表(赤字は削除、など)は、人に意味を確かめる。
- 古い形式(.ppt / .xls)と、パスワード付きのファイルは読めない(終了コード 1)。人に .pptx / .xlsx で保存し直してもらう。

## 4. 文字起こしの後
- 文字起こしは写し。内容を引用するときは「(元の資料: <名前>、スライド 3)」「(シート API一覧、D8)」のように元の場所を書く。
- 元の資料を書き換えない。直すべき点を見つけたら、一覧にして人に返す。
- 要約や文書にまとめるときは cs-doc-writing の型を使う。
- `docs/transcripts/` をコミットするかどうかは人が決める(元の資料に社外秘が含まれることがある)。

参考: Claude Code 公式 Skills(同梱のスクリプトは `${CLAUDE_SKILL_DIR}` で参照する)https://code.claude.com/docs/en/skills
