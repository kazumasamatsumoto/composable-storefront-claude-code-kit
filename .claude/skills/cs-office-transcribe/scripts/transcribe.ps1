# PowerPoint(.pptx / .pptm)と Excel(.xlsx / .xlsm)の文字を Markdown に書き出す。transcribe.py の PowerShell 版。
# Python の無い Windows 用。Windows PowerShell 5.1 と PowerShell 7 で動き、追加のインストールは要らない。
# マクロは実行しない(XML を読むだけ)。出力は transcribe.py と 1 文字も違わないようにしてある(tests/transcribe で比べる)。
#
# 使い方:
#   powershell -NoProfile -ExecutionPolicy Bypass -File transcribe.ps1 <ファイル> [<ファイル> ...]
#   powershell -NoProfile -ExecutionPolicy Bypass -File transcribe.ps1 <ファイル> ... -OutDir docs\transcripts
#   オプション: -MaxRows N(1 シートで書き出す行の上限。既定 2000)
# 終了コード: 0 = すべて書き出せた、1 = 読めないファイルがあった(理由は標準エラー)
param(
  [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Files,
  [string]$OutDir,
  [int]$MaxRows = 2000
)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $Utf8
$Inv = [Globalization.CultureInfo]::InvariantCulture

$NS_P = 'http://schemas.openxmlformats.org/presentationml/2006/main'
$NS_A = 'http://schemas.openxmlformats.org/drawingml/2006/main'
$NS_R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
$NS_S = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
$NS_REL = 'http://schemas.openxmlformats.org/package/2006/relationships'
$NS_DGM = 'http://schemas.openxmlformats.org/drawingml/2006/diagram'
$DateFmtIds = @(14..22) + @(27..36) + @(45, 46, 47) + @(50..58)

class TranscribeError : System.Exception { TranscribeError([string]$m) : base($m) { } }

function Read-Xml($zip, [string]$part) {
  $e = $zip.GetEntry($part)
  if ($null -eq $e) { return $null }
  $sr = New-Object System.IO.StreamReader($e.Open(), $Utf8)
  try { $doc = New-Object System.Xml.XmlDocument; $doc.PreserveWhitespace = $true; $doc.LoadXml($sr.ReadToEnd()); return $doc.DocumentElement }
  finally { $sr.Dispose() }
}

function Join-Part([string]$dir, [string]$target) {
  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($seg in (($dir + '/' + $target) -split '/')) {
    if ($seg -eq '' -or $seg -eq '.') { continue }
    if ($seg -eq '..') { if ($parts.Count -gt 0) { $parts.RemoveAt($parts.Count - 1) }; continue }
    $parts.Add($seg)
  }
  return ($parts -join '/')
}

# part の関係(.rels)を @{ Id = @(種類の末尾, 解決したパス) } で返す。外部リンクは除く。
function Get-Rels($zip, [string]$part) {
  $i = $part.LastIndexOf('/')
  $dir = if ($i -ge 0) { $part.Substring(0, $i) } else { '' }
  $name = $part.Substring($i + 1)
  $relsPath = if ($dir) { "$dir/_rels/$name.rels" } else { "_rels/$name.rels" }
  $root = Read-Xml $zip $relsPath
  $out = @{}
  if ($null -eq $root) { return $out }
  foreach ($rel in $root.ChildNodes) {
    if ($rel.LocalName -ne 'Relationship' -or $rel.NamespaceURI -ne $NS_REL) { continue }
    if ($rel.GetAttribute('TargetMode') -eq 'External') { continue }
    $target = $rel.GetAttribute('Target')
    $path = if ($target.StartsWith('/')) { $target.Substring(1) } else { Join-Part $dir $target }
    $type = $rel.GetAttribute('Type')
    $out[$rel.GetAttribute('Id')] = @($type.Substring($type.LastIndexOf('/') + 1), $path)
  }
  return $out
}

function Kids($el, [string]$ns, [string]$local) {
  $r = @()
  if ($null -eq $el) { return $r }
  foreach ($c in $el.ChildNodes) { if ($c.NodeType -eq 'Element' -and $c.LocalName -eq $local -and $c.NamespaceURI -eq $ns) { $r += $c } }
  return $r
}
function Kid($el, [string]$ns, [string]$local) { $k = @(Kids $el $ns $local); if ($k.Count) { return $k[0] }; return $null }
function Path-Kid($el, [string[]]$steps) {
  # steps: 'ns|local' の並び
  $cur = $el
  foreach ($s in $steps) { $n, $l = $s -split '\|'; $cur = Kid $cur $n $l; if ($null -eq $cur) { return $null } }
  return $cur
}
function Descendants($el, [string]$ns, [string]$local) {
  if ($null -eq $el) { return @() }
  return @($el.GetElementsByTagName($local, $ns))
}

function Cell-Text([string]$s) {
  return $s.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", '<br>').Replace('|', '\|')
}

# ---------------------------------------------------------------- PowerPoint

function Para-Text($p) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($el in $p.ChildNodes) {
    if ($el.NodeType -ne 'Element' -or $el.NamespaceURI -ne $NS_A) { continue }
    if ($el.LocalName -eq 'r' -or $el.LocalName -eq 'fld') {
      $t = Kid $el $NS_A 't'
      if ($null -ne $t -and $t.InnerText) { [void]$sb.Append($t.InnerText) }
    }
    elseif ($el.LocalName -eq 'br') { [void]$sb.Append('<br>') }
  }
  return $sb.ToString().Trim()
}

# (段落の文字, 段落の深さ) の並び。空の段落は除く。
function Get-Paragraphs($txBody) {
  $out = New-Object System.Collections.Generic.List[object]
  if ($null -eq $txBody) { return , $out }
  foreach ($p in (Kids $txBody $NS_A 'p')) {
    $text = Para-Text $p
    if (-not $text) { continue }
    $ppr = Kid $p $NS_A 'pPr'
    $lvl = 0
    if ($null -ne $ppr -and $ppr.HasAttribute('lvl')) { $lvl = [int]$ppr.GetAttribute('lvl') }
    $out.Add(@($text, $lvl))
  }
  return , $out
}
function Para-Texts($txBody) { $r = @(); foreach ($x in (Get-Paragraphs $txBody)) { $r += $x[0] }; return $r }

function Table-Lines($tbl) {
  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($tr in (Kids $tbl $NS_A 'tr')) {
    $cells = New-Object System.Collections.Generic.List[string]
    foreach ($tc in (Kids $tr $NS_A 'tc')) { $cells.Add((Cell-Text ((Para-Texts (Kid $tc $NS_A 'txBody')) -join '<br>'))) }
    $rows.Add($cells)
  }
  if ($rows.Count -eq 0) { return @() }
  $width = 0; foreach ($r in $rows) { if ($r.Count -gt $width) { $width = $r.Count } }
  foreach ($r in $rows) { while ($r.Count -lt $width) { $r.Add('') } }
  $lines = @(('| ' + ($rows[0] -join ' | ') + ' |'), ('|' + ('---|' * $width)))
  for ($i = 1; $i -lt $rows.Count; $i++) { $lines += '| ' + ($rows[$i] -join ' | ') + ' |' }
  return $lines
}

function SmartArt-Lines($zip, $frame, $slideRels) {
  $relIds = @(Descendants $frame $NS_DGM 'relIds')
  if ($relIds.Count -eq 0) { return @('- [SmartArt]') }
  $target = $slideRels[$relIds[0].GetAttribute('dm', $NS_R)]
  $data = if ($target) { Read-Xml $zip $target[1] } else { $null }
  $lines = @('- [SmartArt]')
  if ($null -ne $data) {
    foreach ($pt in (Descendants $data $NS_DGM 'pt')) {
      $type = if ($pt.HasAttribute('type')) { $pt.GetAttribute('type') } else { 'node' }
      if ($type -ne 'node') { continue }
      $texts = @(Para-Texts (Kid $pt $NS_DGM 't'))
      if ($texts.Count) { $lines += '  - ' + ($texts -join ' ') }
    }
  }
  return $lines
}

# 図形を文書の順にたどり、本文の行を返す。最初のタイトルは $state.title に入れる。
function Shape-Lines($zip, $tree, $slideRels, $state) {
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($el in $tree.ChildNodes) {
    if ($el.NodeType -ne 'Element' -or $el.NamespaceURI -ne $NS_P) { continue }
    switch ($el.LocalName) {
      'grpSp' { foreach ($l in (Shape-Lines $zip $el $slideRels $state)) { $lines.Add($l) } }
      'sp' {
        $ph = Path-Kid $el @("$NS_P|nvSpPr", "$NS_P|nvPr", "$NS_P|ph")
        $paras = Get-Paragraphs (Kid $el $NS_P 'txBody')
        $phType = if ($null -ne $ph) { $ph.GetAttribute('type') } else { '' }
        if (($phType -eq 'title' -or $phType -eq 'ctrTitle') -and $null -eq $state.title) {
          $state.title = (@($paras | ForEach-Object { $_[0] }) -join ' ')
          continue
        }
        foreach ($x in $paras) { $lines.Add(('  ' * $x[1]) + '- ' + $x[0]) }
      }
      'graphicFrame' {
        $gd = Path-Kid $el @("$NS_A|graphic", "$NS_A|graphicData")
        $uri = if ($null -ne $gd) { $gd.GetAttribute('uri') } else { '' }
        $tbl = if ($null -ne $gd) { Kid $gd $NS_A 'tbl' } else { $null }
        if ($null -ne $tbl) { $lines.Add(''); foreach ($l in (Table-Lines $tbl)) { $lines.Add($l) }; $lines.Add('') }
        elseif ($uri.EndsWith('/chart')) { $lines.Add('- [グラフ]') }
        elseif ($uri.EndsWith('/diagram')) { foreach ($l in (SmartArt-Lines $zip $el $slideRels)) { $lines.Add($l) } }
      }
      'pic' {
        $pr = Path-Kid $el @("$NS_P|nvPicPr", "$NS_P|cNvPr")
        $descr = if ($null -ne $pr) { $pr.GetAttribute('descr').Trim() } else { '' }
        if ($descr) { $lines.Add('- [画像: ' + (Cell-Text $descr) + ']') } else { $lines.Add('- [画像]') }
      }
    }
  }
  return , $lines
}

function Notes-Lines($zip, $slideRels) {
  foreach ($v in $slideRels.Values) {
    if ($v[0] -ne 'notesSlide') { continue }
    $notes = Read-Xml $zip $v[1]
    if ($null -eq $notes) { return @() }
    $out = @()
    foreach ($sp in (Descendants $notes $NS_P 'sp')) {
      $ph = Path-Kid $sp @("$NS_P|nvSpPr", "$NS_P|nvPr", "$NS_P|ph")
      if ($null -ne $ph -and $ph.GetAttribute('type') -eq 'body') { $out += @(Para-Texts (Kid $sp $NS_P 'txBody')) }
    }
    return $out
  }
  return @()
}

function Transcribe-Pptx($zip, [string]$name) {
  $pres = Read-Xml $zip 'ppt/presentation.xml'
  if ($null -eq $pres) { throw [TranscribeError]::new('ppt/presentation.xml が無い(PowerPoint のファイルではない)') }
  $presRels = Get-Rels $zip 'ppt/presentation.xml'
  $ids = @(Kids (Kid $pres $NS_P 'sldIdLst') $NS_P 'sldId')
  $body = New-Object System.Collections.Generic.List[string]
  $i = 0
  foreach ($sid in $ids) {
    $i++
    $part = $presRels[$sid.GetAttribute('id', $NS_R)][1]
    $sld = Read-Xml $zip $part
    $slideRels = Get-Rels $zip $part
    $state = @{ title = $null }
    $lines = Shape-Lines $zip (Path-Kid $sld @("$NS_P|cSld", "$NS_P|spTree")) $slideRels $state
    $head = "## スライド $i"
    if ($state.title) { $head += ': ' + $state.title }
    if ($sld.GetAttribute('show') -eq '0') { $head += '(非表示)' }
    $body.Add(''); $body.Add($head); $body.Add('')
    while ($lines.Count -and $lines[0] -eq '') { $lines.RemoveAt(0) }
    while ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    if ($lines.Count) { foreach ($l in $lines) { $body.Add($l) } } else { $body.Add('(文字なし)') }
    $notes = @(Notes-Lines $zip $slideRels)
    if ($notes.Count) {
      $body.Add(''); $body.Add('> ノート: ' + $notes[0])
      for ($k = 1; $k -lt $notes.Count; $k++) { $body.Add('> ' + $notes[$k]) }
    }
  }
  $head = @("# $name", '',
    "- 元の資料: $name(正本は元の資料。これは文字起こし)",
    "- 形式: PowerPoint、スライド $($ids.Count) 枚",
    '- 含まないもの: 画像やグラフの中の文字、図形の位置関係と色。必要なら元の資料を PDF にして見る')
  return $head + $body
}

# ---------------------------------------------------------------- Excel

# <si> / <is> の文字。ふりがな(rPh)は除く。
function Rich-Text($el) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($c in $el.ChildNodes) {
    if ($c.NodeType -ne 'Element' -or $c.NamespaceURI -ne $NS_S) { continue }
    if ($c.LocalName -eq 't') { [void]$sb.Append($c.InnerText) }
    elseif ($c.LocalName -eq 'r') { $t = Kid $c $NS_S 't'; if ($null -ne $t) { [void]$sb.Append($t.InnerText) } }
  }
  return $sb.ToString()
}

function Col-Number([string]$letters) { $n = 0; foreach ($ch in $letters.ToCharArray()) { $n = $n * 26 + ([int]$ch - 64) }; return $n }
function Col-Letters([int]$n) { $s = ''; while ($n -gt 0) { $rem = ($n - 1) % 26; $n = [int][math]::Floor(($n - 1) / 26); $s = [char](65 + $rem) + $s }; return $s }

function Is-DateCode([string]$code) {
  $c = [regex]::Replace($code, '"[^"]*"|\[[^\]]*\]|\\.|_.|\*.', '')
  $c = [regex]::Replace($c, '(?i)general', '')
  return [regex]::IsMatch($c, '[ymdhsYMDHS]')
}

function Serial-ToText([string]$value, [bool]$date1904) {
  $serial = [double]::Parse($value, $Inv)
  $days = [math]::Floor($serial)
  $secs = [math]::Round(($serial - $days) * 86400, [MidpointRounding]::ToEven)
  if ($secs -ge 86400) { $days += 1; $secs -= 86400 }
  $secs = [int]$secs
  if ($days -eq 0 -and $secs -gt 0 -and -not $date1904) {
    return '{0:00}:{1:00}:{2:00}' -f [int][math]::Floor($secs / 3600), [int][math]::Floor(($secs % 3600) / 60), ($secs % 60)
  }
  $base = if ($date1904) { New-Object DateTime 1904, 1, 1 } else { New-Object DateTime 1899, 12, 30 }
  $dt = $base.AddDays($days).AddSeconds($secs)
  if ($secs -eq 0) { return $dt.ToString('yyyy-MM-dd', $Inv) }
  return $dt.ToString('yyyy-MM-dd HH:mm:ss', $Inv)
}

function Transcribe-Xlsx($zip, [string]$name, [int]$maxRows) {
  $wb = Read-Xml $zip 'xl/workbook.xml'
  if ($null -eq $wb) { throw [TranscribeError]::new('xl/workbook.xml が無い(Excel のファイルではない)') }
  $wbRels = Get-Rels $zip 'xl/workbook.xml'
  $pr = Kid $wb $NS_S 'workbookPr'
  $date1904 = $null -ne $pr -and ($pr.GetAttribute('date1904') -eq '1' -or $pr.GetAttribute('date1904') -eq 'true')

  $shared = New-Object System.Collections.Generic.List[string]
  foreach ($v in $wbRels.Values) {
    if ($v[0] -eq 'sharedStrings') {
      $sst = Read-Xml $zip $v[1]
      if ($null -ne $sst) { foreach ($si in (Kids $sst $NS_S 'si')) { $shared.Add((Rich-Text $si)) } }
    }
  }
  $dateStyles = New-Object System.Collections.Generic.HashSet[int]
  foreach ($v in $wbRels.Values) {
    if ($v[0] -ne 'styles') { continue }
    $st = Read-Xml $zip $v[1]
    if ($null -eq $st) { continue }
    $codes = @{}
    foreach ($f in (Descendants $st $NS_S 'numFmt')) { $codes[[int]$f.GetAttribute('numFmtId')] = $f.GetAttribute('formatCode') }
    $xfs = Kid $st $NS_S 'cellXfs'
    $k = 0
    foreach ($xf in (Kids $xfs $NS_S 'xf')) {
      $fid = if ($xf.HasAttribute('numFmtId')) { [int]$xf.GetAttribute('numFmtId') } else { 0 }
      if ($DateFmtIds -contains $fid -or ($codes.ContainsKey($fid) -and (Is-DateCode $codes[$fid]))) { [void]$dateStyles.Add($k) }
      $k++
    }
  }

  $sheets = @(Kids (Kid $wb $NS_S 'sheets') $NS_S 'sheet')
  $body = New-Object System.Collections.Generic.List[string]
  $i = 0
  foreach ($sh in $sheets) {
    $i++
    $head = "## シート ${i}: " + $sh.GetAttribute('name')
    $state = $sh.GetAttribute('state')
    if ($state -eq 'hidden' -or $state -eq 'veryHidden') { $head += '(非表示)' }
    $body.Add(''); $body.Add($head); $body.Add('')
    $target = $wbRels[$sh.GetAttribute('id', $NS_R)]
    $ws = if ($target -and $target[0] -eq 'worksheet') { Read-Xml $zip $target[1] } else { $null }
    if ($null -eq $ws) { $body.Add('(表のシートではない。グラフのシートなど)'); continue }
    $cells = @{}
    $rowSet = New-Object System.Collections.Generic.SortedSet[int]
    $c1 = [int]::MaxValue; $c2 = 0
    $formulas = New-Object System.Collections.Generic.List[string]
    foreach ($row in (Descendants $ws $NS_S 'row')) {
      foreach ($c in (Kids $row $NS_S 'c')) {
        $m = [regex]::Match($c.GetAttribute('r'), '^([A-Z]+)(\d+)$')
        if (-not $m.Success) { continue }
        $col = Col-Number $m.Groups[1].Value; $rown = [int]$m.Groups[2].Value
        $t = if ($c.HasAttribute('t')) { $c.GetAttribute('t') } else { 'n' }
        $vEl = Kid $c $NS_S 'v'
        $raw = if ($null -ne $vEl) { $vEl.InnerText } else { '' }
        $sIdx = if ($c.HasAttribute('s')) { [int]$c.GetAttribute('s') } else { 0 }
        if ($t -eq 's' -and $raw -ne '') { $val = $shared[[int]$raw] }
        elseif ($t -eq 'inlineStr') { $is = Kid $c $NS_S 'is'; $val = if ($null -ne $is) { Rich-Text $is } else { '' } }
        elseif ($t -eq 'b') { $val = if ($raw -eq '1') { 'TRUE' } elseif ($raw -eq '0') { 'FALSE' } else { $raw } }
        elseif ($t -eq 'n' -and $raw -ne '' -and $dateStyles.Contains($sIdx)) { $val = Serial-ToText $raw $date1904 }
        else { $val = $raw }
        $f = Kid $c $NS_S 'f'
        if ($null -ne $f -and $f.InnerText) {
          $shown = if ($val -ne '') { $val } else { '(値なし)' }
          $formulas.Add('- ' + $m.Value + ': =' + $f.InnerText + ' → ' + $shown)
        }
        if ($val -ne '') {
          $cells["$rown,$col"] = $val; [void]$rowSet.Add($rown)
          if ($col -lt $c1) { $c1 = $col }; if ($col -gt $c2) { $c2 = $col }
        }
      }
    }
    if ($cells.Count -eq 0) { $body.Add('(空のシート)'); continue }
    $rows = @($rowSet)
    $body.Add('範囲: ' + (Col-Letters $c1) + $rows[0] + ':' + (Col-Letters $c2) + $rows[$rows.Count - 1] + '(値のある行だけを書く)')
    $body.Add('')
    $letters = @(); for ($c = $c1; $c -le $c2; $c++) { $letters += Col-Letters $c }
    $body.Add('| 行 | ' + ($letters -join ' | ') + ' |')
    $body.Add('|---|' + ('---|' * ($c2 - $c1 + 1)))
    $n = 0
    foreach ($r in $rows) {
      if ($n -ge $maxRows) { break }; $n++
      $vals = @(); for ($c = $c1; $c -le $c2; $c++) { $x = $cells["$r,$c"]; $vals += if ($null -ne $x) { Cell-Text $x } else { '' } }
      $body.Add("| $r | " + ($vals -join ' | ') + ' |')
    }
    if ($rows.Count -gt $maxRows) { $body.Add(''); $body.Add('(以下 ' + ($rows.Count - $maxRows) + ' 行は省略。上限は --max-rows(PowerShell 版は -MaxRows)で変えられる)') }
    $merges = @(); foreach ($mc in (Descendants $ws $NS_S 'mergeCell')) { $merges += $mc.GetAttribute('ref') }
    if ($merges.Count) { $body.Add(''); $body.Add('結合セル: ' + ($merges -join '、')) }
    if ($formulas.Count) { $body.Add(''); $body.Add('式(表には計算結果を書いた):'); foreach ($x in $formulas) { $body.Add($x) } }
  }
  $head = @("# $name", '',
    "- 元の資料: $name(正本は元の資料。これは文字起こし)",
    "- 形式: Excel、シート $($sheets.Count) 枚",
    '- 含まないもの: 書式と色、グラフ、画像、コメント、非表示の行と列の区別')
  return $head + $body
}

# ---------------------------------------------------------------- 入口

function Transcribe([string]$path, [int]$maxRows) {
  $name = [IO.Path]::GetFileName($path)
  $ext = [IO.Path]::GetExtension($name).ToLowerInvariant()
  if ($ext -eq '.ppt' -or $ext -eq '.xls') { throw [TranscribeError]::new("古い形式($ext)は読めない。PowerPoint / Excel で .pptx / .xlsx として保存し直す") }
  if (@('.pptx', '.pptm', '.xlsx', '.xlsm') -notcontains $ext) { throw [TranscribeError]::new("対応していない拡張子($ext)。.pptx と .xlsx だけ") }
  try { $zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $path).Path) }
  catch { throw [TranscribeError]::new('zip として開けない(パスワード付きか、壊れているか、古い形式): ' + $_.Exception.Message) }
  try {
    if ($ext.StartsWith('.ppt')) { $lines = Transcribe-Pptx $zip $name } else { $lines = Transcribe-Xlsx $zip $name $maxRows }
  }
  finally { $zip.Dispose() }
  return (($lines -join "`n") + "`n")
}

$status = 0
foreach ($f in $Files) {
  try { $md = Transcribe $f $MaxRows }
  catch [TranscribeError] { [Console]::Error.WriteLine("${f}: " + $_.Exception.Message); $status = 1; continue }
  if ($OutDir) {
    [void](New-Item -ItemType Directory -Force -Path $OutDir)
    $out = Join-Path $OutDir ([IO.Path]::GetFileName($f) + '.md')
    [IO.File]::WriteAllText($out, $md, $Utf8)
    [Console]::Error.WriteLine("書き出した: $out")
  }
  else {
    $stdout = [Console]::OpenStandardOutput(); $b = $Utf8.GetBytes($md); $stdout.Write($b, 0, $b.Length); $stdout.Flush()
  }
}
exit $status
