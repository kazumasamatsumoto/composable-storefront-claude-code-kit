# hooks(PowerShell 版)のテスト。Claude Code が hook に渡すのと同じ形の JSON を標準入力に入れ、終了コードを確かめる。
# 0 = 通す、2 = 止める(PreToolUse)/ 直させる(PostToolUse)。ケースは cases.json(bash 版の run.sh と共通)。
# 使い方: powershell -NoProfile -ExecutionPolicy Bypass -File tests\hooks\run.ps1   (PowerShell 7 なら pwsh -File ...)
# 今動いている PowerShell(5.1 か 7)で各 hook を起動する。
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$hooks = Join-Path $root '.claude/hooks'
$fix = Join-Path $root 'tests/hooks/fixtures'
$env:CLAUDE_PROJECT_DIR = $root
$exe = (Get-Process -Id $PID).Path
$cases = [IO.File]::ReadAllText((Join-Path $root 'tests/hooks/cases.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$pass = 0; $fail = 0

foreach ($c in $cases) {
  $json = ($c.input | ConvertTo-Json -Compress -Depth 5)
  # {ROOT} と {F} を実際のパスに(JSON の文字列の中なので \ は \\ にする)
  $json = $json.Replace('{ROOT}', $root.Replace('\', '\\')).Replace('{F}', $fix.Replace('\', '\\'))
  $script = Join-Path $hooks ($c.hook + '.ps1')
  # Claude Code と同じく、標準入力に UTF-8 のバイト列を書いて閉じる(PowerShell のパイプの文字コード変換を通さない)
  $si = New-Object System.Diagnostics.ProcessStartInfo
  $si.FileName = $exe
  $si.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
  $si.UseShellExecute = $false
  $si.RedirectStandardInput = $true; $si.RedirectStandardOutput = $true; $si.RedirectStandardError = $true
  $si.StandardErrorEncoding = [Text.Encoding]::UTF8
  $proc = [Diagnostics.Process]::Start($si)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
  $proc.StandardInput.Close()
  $errTask = $proc.StandardError.ReadToEndAsync()
  $null = $proc.StandardOutput.ReadToEnd()
  $proc.WaitForExit()
  $got = $proc.ExitCode
  if ($got -eq $c.expect) { $pass++; [Console]::Out.WriteLine(('ok   {0,-24} {1}' -f $c.hook, $c.label)) }
  else {
    $fail++; [Console]::Out.WriteLine(('NG   {0,-24} {1}(期待 {2}、実際 {3})' -f $c.hook, $c.label, $c.expect, $got))
    if ($errTask.Result) { [Console]::Out.WriteLine('     stderr: ' + $errTask.Result.Trim()) }
  }
}

[Console]::Out.WriteLine("合計: ok $pass / NG $fail  ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion))")
if ($fail -ne 0) { exit 1 }
exit 0
