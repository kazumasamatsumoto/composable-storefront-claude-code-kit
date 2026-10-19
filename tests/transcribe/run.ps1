# 文字起こし(cs-office-transcribe の transcribe.ps1)のテスト。期待する Markdown と 1 文字ずつ比べる。
# 期待値は Python 版(run.sh)と共通なので、2 つの版が同じ結果を出すことも確かめられる。
# 使い方: powershell -NoProfile -ExecutionPolicy Bypass -File tests\transcribe\run.ps1   (PowerShell 7 なら pwsh -File ...)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$t = Join-Path $root '.claude/skills/cs-office-transcribe/scripts/transcribe.ps1'
$d = Join-Path $root 'tests/transcribe'
$exe = (Get-Process -Id $PID).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('transcribe-' + [guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $tmp)
$pass = 0; $fail = 0

function Run([string[]]$argv) {
  # 標準出力をバイト列のまま受け取る(PowerShell のパイプで文字コードを変えない)
  $si = New-Object System.Diagnostics.ProcessStartInfo
  $si.FileName = $exe
  $si.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $t + '" ' + (($argv | ForEach-Object { '"' + $_ + '"' }) -join ' ')
  $si.UseShellExecute = $false; $si.RedirectStandardOutput = $true; $si.RedirectStandardError = $true
  $p = [Diagnostics.Process]::Start($si)
  $errTask = $p.StandardError.ReadToEndAsync()
  $ms = New-Object IO.MemoryStream; $p.StandardOutput.BaseStream.CopyTo($ms); $p.WaitForExit()
  return @{ code = $p.ExitCode; out = $ms.ToArray(); err = $errTask.Result }
}
function Same-Bytes([byte[]]$a, [byte[]]$b) {
  if ($a.Length -ne $b.Length) { return $false }
  for ($i = 0; $i -lt $a.Length; $i++) { if ($a[$i] -ne $b[$i]) { return $false } }
  return $true
}
function Check([string]$label, [bool]$cond, [string]$detail) {
  if ($cond) { $script:pass++; [Console]::Out.WriteLine("ok   $label") }
  else { $script:fail++; [Console]::Out.WriteLine("NG   $label"); if ($detail) { [Console]::Out.WriteLine("     $detail") } }
}
function Same([string]$label, [string]$want, [string[]]$argv) {
  $r = Run $argv
  $exp = [IO.File]::ReadAllBytes((Join-Path $d "expected/$want"))
  $ok = $r.code -eq 0 -and (Same-Bytes $r.out $exp)
  $detail = ''
  if (-not $ok) {
    $got = [Text.Encoding]::UTF8.GetString($r.out) -split "`n"; $w = [Text.Encoding]::UTF8.GetString($exp) -split "`n"
    for ($i = 0; $i -lt [math]::Max($got.Count, $w.Count); $i++) { if ($got[$i] -ne $w[$i]) { $detail = "$($i + 1) 行目: 期待 [$($w[$i])] / 実際 [$($got[$i])] $($r.err)"; break } }
  }
  Check $label $ok $detail
}

Same 'PowerPoint: 表示順、タイトル、段落の深さ、表、グループ、画像の説明、ノート、非表示、グラフ、SmartArt' 'sample.pptx.md' @((Join-Path $d 'fixtures/sample.pptx'))
Same 'Excel: 共有文字列、ふりがなを除く、セル内の文字、日付、真偽、式の計算結果、結合、非表示、空のシート' 'sample.xlsx.md' @((Join-Path $d 'fixtures/sample.xlsx'))
Same 'Excel: 行の上限(-MaxRows 3)' 'sample.xlsx.max3.md' @((Join-Path $d 'fixtures/sample.xlsx'), '-MaxRows', '3')

$r = Run @((Join-Path $d 'fixtures/sample.pptx'), '-OutDir', (Join-Path $tmp 'out'))
$f = Join-Path $tmp 'out/sample.pptx.md'
Check '-OutDir でフォルダに書き出す' ($r.code -eq 0 -and (Test-Path $f) -and (Same-Bytes ([IO.File]::ReadAllBytes($f)) ([IO.File]::ReadAllBytes((Join-Path $d 'expected/sample.pptx.md'))))) ''
Check '古い形式(.ppt)は 1 で終わる' ((Run @((Join-Path $d 'fixtures/old.ppt'))).code -eq 1) ''
Check 'zip でないファイルは 1 で終わる' ((Run @((Join-Path $d 'fixtures/broken.xlsx'))).code -eq 1) ''

Remove-Item -Recurse -Force $tmp
[Console]::Out.WriteLine("合計: ok $pass / NG $fail  ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion))")
if ($fail -ne 0) { exit 1 }
exit 0
