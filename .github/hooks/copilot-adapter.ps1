# GitHub Copilot の hooks から、.claude/hooks の同じスクリプト(PowerShell 版)を呼ぶための橋渡し。copilot-adapter.sh の PowerShell 版。
# cs-hooks.json はイベント名を PascalCase で書くので、Copilot は Claude Code と同じ形の入力を渡す(公式 GitHub Copilot hooks reference)。
# ここでは結果の返し方だけを Copilot の形に直す。止める・通すの規則は .claude/hooks にだけ書く。
# 使い方: powershell -NoProfile -ExecutionPolicy Bypass -File .github\hooks\copilot-adapter.ps1 <イベント> <スクリプト名>
param([string]$Event, [string]$Hook)
[Console]::InputEncoding  = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$env:CLAUDE_PROJECT_DIR = $root
$script = Join-Path $root ".claude\hooks\$Hook.ps1"
if (-not (Test-Path $script)) { [Console]::Error.WriteLine("copilot-adapter: $script がありません"); exit 2 }
$raw = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)

# Copilot の道具がファイルの場所を path で渡したときに備えて、file_path が無ければ path を写す(推論)
try {
  $in = $raw | ConvertFrom-Json
  if ($in -and $in.tool_input -and -not $in.tool_input.file_path -and $in.tool_input.path) {
    $in.tool_input | Add-Member -NotePropertyName file_path -NotePropertyValue $in.tool_input.path -Force
    $raw = $in | ConvertTo-Json -Depth 20 -Compress
  }
} catch { }

# 同じ PowerShell で .claude/hooks の .ps1 を別のプロセスとして動かし、標準入力に JSON を渡す
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = (Get-Process -Id $PID).Path
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding $false
$psi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding $false
$p = [System.Diagnostics.Process]::Start($psi)
$w = New-Object System.IO.StreamWriter($p.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding $false))
$w.Write($raw); $w.Close()
$errTask = $p.StandardError.ReadToEndAsync()  # 片方を待つ間にもう片方が詰まらないように、標準エラーは並行して読む
$out = $p.StandardOutput.ReadToEnd()
$p.WaitForExit()
$err = $errTask.Result.Trim()
$code = $p.ExitCode

switch ($Event) {
  'SessionStart' {
    # Copilot は {"additionalContext": "..."} を読む
    [Console]::Out.Write((@{ additionalContext = $out.Trim() } | ConvertTo-Json -Compress))
    exit 0
  }
  'PreToolUse' {
    if ($code -eq 0) { exit 0 }
    [Console]::Out.Write((@{ permissionDecision = 'deny'; permissionDecisionReason = $err } | ConvertTo-Json -Compress))
    exit 2
  }
  'PostToolUse' {
    if ($code -eq 2) { [Console]::Out.Write((@{ additionalContext = "$err 直してから次に進んでください。" } | ConvertTo-Json -Compress)) }
    exit 0
  }
  default { [Console]::Error.WriteLine("copilot-adapter: 知らないイベント $Event"); exit 2 }
}
