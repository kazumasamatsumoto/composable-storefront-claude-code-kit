# PreToolUse(Read|Edit|Write): 読ませない・書かせないファイルを止める。protect-files.sh の PowerShell 版。
# パスの \ は / にそろえてから比べる。-like は大文字と小文字を区別しない(Windows のパスと同じ)。
[Console]::InputEncoding  = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$raw = [Console]::In.ReadToEnd(); if ($env:HOOK_DEBUG) { [Console]::Error.WriteLine('raw=[' + $raw + '] len=' + $raw.Length) }
try { $in = $raw | ConvertFrom-Json } catch { if ($env:HOOK_DEBUG) { [Console]::Error.WriteLine('json error: ' + $_) }; exit 0 }
$tool = [string]$in.tool_name
$path = [string]$in.tool_input.file_path
if (-not $path) { exit 0 }
$p = $path -replace '\\', '/'

function Block([string]$why) {
  [Console]::Error.WriteLine("hook で禁止: $why($path)")
  exit 2
}

# 秘密(読むのも禁止)
foreach ($pat in '*.env', '*.env.*', '*/secrets/*', '*.pem', '*.key', '*/local.properties.secret*') {
  if ($p -like $pat) { Block '秘密を含むファイル' }
}
if ($tool -eq 'Read') { exit 0 }

# ここから下は書き込みだけを止める
if ($p -like '*/node_modules/*') { Block 'node_modules の中(標準ライブラリはコピーや改変をせず、cmsComponents と Outlet で差し替える)' }
if ($p -like '*/dist/*') { Block 'ビルド成果物 dist' }
if ($p -like '*/hybris/bin/custom/*') { exit 0 }  # 自社の拡張(core-customize/hybris/bin/custom)は書いてよい
if ($p -like '*/hybris/bin/*') { Block 'SAP Commerce の標準の拡張(hybris/bin の custom 以外)。自社の拡張(hybris/bin/custom)で上書きする' }
if ($p -like '*/platform/project.properties') { Block 'platform の project.properties。local.properties か manifest で上書きする' }
exit 0
