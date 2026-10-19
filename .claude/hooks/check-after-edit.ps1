# PostToolUse(Edit|Write): 編集したファイルを、案件のルールで検査する。check-after-edit.sh の PowerShell 版。
# ツールはもう実行済み。問題があれば終了コード 2 で stderr を Claude に見せ、直させる。
[Console]::InputEncoding  = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
try { $in = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$path = [string]$in.tool_input.file_path
if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { exit 0 }
$p = $path -replace '\\', '/'
$text  = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$lines = $text -split "`r?`n"
$problems = New-Object System.Collections.Generic.List[string]

if ($p -like '*.ts' -or $p -like '*.html') {
  # ストアフロント: OCC の URL を直書きしない、FULL を既定にしない(目安)
  if ($text -cmatch 'https?://[^"'' ]*/occ/v2') { $problems.Add('OCC の URL を直書きしている。設定(backend.occ.baseUrl、CCv2 では OCC_BACKEND_BASE_URL_VALUE)から取る') }
  if ($text -cmatch 'fields=FULL') { $problems.Add('fields=FULL を使っている。必要な項目だけを列挙する') }
  if ($p -like '*.component.ts' -and $text -cmatch '\bHttpClient\b') { $problems.Add('コンポーネントで HttpClient を使っている。Facade(Query / Command)経由にする') }
  # SSR: サーバー(Node)には window / document が無い。WindowRef か isPlatformBrowser で分けていないファイルで直接触っていたら止める
  if ($p -like '*.ts' -and $p -notlike '*.spec.ts' -and $p -notlike '*server.ts') {
    $direct = $false
    foreach ($l in $lines) { if ($l -cmatch '(^|[^.A-Za-z0-9_$])(window|document|localStorage|sessionStorage|navigator)\.') { $direct = $true; break } }
    if ($direct -and $text -cnotmatch 'WindowRef|isPlatformBrowser|isPlatformServer') {
      $problems.Add('window / document / localStorage / navigator を直接触っている。SSR で落ちるので WindowRef(@spartacus/core)か isPlatformBrowser で分ける')
    }
  }
  # リンタ(プロジェクトに eslint があるときだけ。Windows では eslint.cmd)
  $root = $env:CLAUDE_PROJECT_DIR; if (-not $root) { $root = '.' }
  foreach ($name in 'eslint.cmd', 'eslint') {
    $eslint = Join-Path $root "node_modules/.bin/$name"
    if (Test-Path -LiteralPath $eslint -PathType Leaf) {
      $out = & $eslint --no-warn-ignored $path 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { $problems.Add("eslint のエラー:`n$out") }
      break
    }
  }
}
elseif ($p -like '*items.xml') {
  # SAP Commerce: typecode は 10000 以下が SAP の予約
  foreach ($m in [regex]::Matches($text, 'typecode="([0-9]+)"')) {
    $tc = [int]$m.Groups[1].Value
    if ($tc -le 10000) { $problems.Add("typecode=$tc は SAP の予約範囲(0〜10000)。案件の番号帯から選ぶ") }
  }
}
elseif ($p -like '*.impex') {
  # INSERT_UPDATE / UPDATE / REMOVE のヘッダに unique=true が無い
  foreach ($l in $lines) {
    if ($l -cmatch '^(INSERT_UPDATE|UPDATE|REMOVE)\s' -and $l -cnotmatch 'unique=true') { $problems.Add("unique=true の無いヘッダ: $l") }
  }
}

if ($problems.Count -gt 0) {
  [Console]::Error.WriteLine("編集後の検査で問題が見つかりました($path):")
  foreach ($x in $problems) { [Console]::Error.WriteLine("- $x") }
  exit 2
}
exit 0
