# GitHub Copilot の hooks の橋渡し(PowerShell 版、.github/hooks/copilot-adapter.ps1)のテスト。tests/copilot/run.sh の PowerShell 版。
# tests/hooks/cases.json の全ケースを、Copilot が渡す形(ファイルの場所は path で渡す、と仮定した形)に直して橋渡しに通す。
# 使い方: powershell -NoProfile -ExecutionPolicy Bypass -File tests\copilot\run.ps1   (PowerShell 7 なら pwsh -File ...)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$adapter = Join-Path $root '.github/hooks/copilot-adapter.ps1'
$fix = Join-Path $root 'tests/hooks/fixtures'
$exe = (Get-Process -Id $PID).Path
$cases = [IO.File]::ReadAllText((Join-Path $root 'tests/hooks/cases.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$pass = 0; $fail = 0

function Invoke-Adapter([string]$event, [string]$hook, [string]$json) {
  $si = New-Object System.Diagnostics.ProcessStartInfo
  $si.FileName = $exe
  $si.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $adapter + '" ' + $event + ' ' + $hook
  $si.UseShellExecute = $false
  $si.RedirectStandardInput = $true; $si.RedirectStandardOutput = $true; $si.RedirectStandardError = $true
  $si.StandardOutputEncoding = [Text.Encoding]::UTF8; $si.StandardErrorEncoding = [Text.Encoding]::UTF8
  $proc = [Diagnostics.Process]::Start($si)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
  $proc.StandardInput.Close()
  $errTask = $proc.StandardError.ReadToEndAsync()
  $out = $proc.StandardOutput.ReadToEnd()
  $proc.WaitForExit()
  $o = $null; try { if ($out.Trim()) { $o = $out | ConvertFrom-Json } } catch { }
  return @{ code = $proc.ExitCode; out = $o; err = $errTask.Result }
}

foreach ($c in $cases) {
  if ($c.hook -eq 'session-context') { continue }
  $in = $c.input
  if ($in.tool_input.file_path) {
    $in.tool_input | Add-Member -NotePropertyName path -NotePropertyValue $in.tool_input.file_path -Force
    $in.tool_input.PSObject.Properties.Remove('file_path')
  }
  $json = ($in | ConvertTo-Json -Compress -Depth 5)
  $json = $json.Replace('{ROOT}', $root.Replace('\', '\\')).Replace('{F}', $fix.Replace('\', '\\'))
  if ($c.hook -eq 'check-after-edit') {
    $r = Invoke-Adapter 'PostToolUse' $c.hook $json
    $hasCtx = $r.out -and $r.out.additionalContext
    $good = ($r.code -eq 0) -and ((($c.expect -eq 2) -and $hasCtx) -or (($c.expect -eq 0) -and -not $hasCtx))
  } else {
    $r = Invoke-Adapter 'PreToolUse' $c.hook $json
    $good = ($r.code -eq $c.expect) -and (($c.expect -eq 0) -or ($r.out -and $r.out.permissionDecision -eq 'deny'))
  }
  if ($good) { $pass++; [Console]::Out.WriteLine(('ok   {0,-24} {1}' -f $c.hook, $c.label)) }
  else {
    $fail++; [Console]::Out.WriteLine(('NG   {0,-24} {1}(期待 {2}、実際 {3})' -f $c.hook, $c.label, $c.expect, $r.code))
    if ($r.err) { [Console]::Out.WriteLine('     stderr: ' + $r.err.Trim()) }
  }
}

$r = Invoke-Adapter 'SessionStart' 'session-context' '{}'
if ($r.out -and $r.out.additionalContext) { $pass++; [Console]::Out.WriteLine('ok   SessionStart: additionalContext を返す') } else { $fail++; [Console]::Out.WriteLine('NG   SessionStart: additionalContext が無い') }

[Console]::Out.WriteLine("合計: ok $pass / NG $fail  ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion))")
if ($fail -ne 0) { exit 1 }
exit 0
