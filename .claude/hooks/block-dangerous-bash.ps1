# PreToolUse(Bash|PowerShell): 取り返しのつかないコマンドを止める。block-dangerous-bash.sh の PowerShell 版。
# Bash ツールと PowerShell ツールの両方の命令を見る。終了コード 2 で止め、stderr の文が Claude に伝わる。
# Windows PowerShell 5.1 と PowerShell 7 の両方で動く書き方にしている(?? や三項演算子を使わない)。
[Console]::InputEncoding  = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
try { $in = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$in.tool_input.command
if (-not $cmd) { exit 0 }

function Block([string]$why) {
  [Console]::Error.WriteLine("hook で禁止: $why。必要なら手順を書いて人に実行を依頼してください。(コマンド: $cmd)")
  exit 2
}

# SAP Commerce: 初期化は全テーブルを消す
if ($cmd -cmatch '\bant\b.*\binitialize\b') { Block 'ant initialize(全テーブルを削除する)' }
# 削除と履歴の書き換え
if ($cmd -cmatch '\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r') { Block 'rm -rf' }
# PowerShell の再帰削除(Remove-Item と別名 rm / del / ri / rd。-Recurse と -Force は省略形も)と、cmd の rd /s
if ($cmd -match '(^|[^a-z-])(remove-item|ri|rm|rmdir|rd|del|erase)\s(.*\s)?-r(e|ec|ecu|ecur|ecurs|ecurse)?(\s|$)' -and
    $cmd -match '\s-f(o|or|orc|orce)?(\s|$)') { Block '再帰と強制つきの削除(rm -r -f / Remove-Item -Recurse -Force)' }
if ($cmd -match '(^|[^a-z-])(rd|rmdir)\s+/s\b') { Block 'rd /s' }
if ($cmd -cmatch '\bgit\s+push\b.*(--force|-f\b)') { Block 'git push --force' }
if ($cmd -cmatch '\bgit\s+reset\s+--hard') { Block 'git reset --hard' }
if ($cmd -match '\b(drop|truncate)\s+table\b') { Block 'DROP / TRUNCATE TABLE' }
# 公開・配布
if ($cmd -cmatch '\b(npm|yarn|pnpm)\s+publish\b') { Block 'パッケージの公開' }
# 鍵の持ち出しと、取ってきたスクリプトの実行
if ($cmd -match '\b(cat|less|head|tail|cp|scp|type|more|gc|get-content|copy|copy-item|cpi)\s+[^|;]*\.env(\s|$|\.|["''])') { Block '.env の読み出し' }
if ($cmd -cmatch '(curl|wget)\b[^|]*\|\s*(ba|z)?sh\b') { Block 'ダウンロードしたスクリプトをそのまま実行' }
if ($cmd -match '\b(iwr|irm|invoke-webrequest|invoke-restmethod|curl|wget)\b[^|]*\|\s*(iex|invoke-expression)\b') { Block 'ダウンロードしたスクリプトをそのまま実行(| iex)' }
if ($cmd -match '\b(iex|invoke-expression)\b.*\b(iwr|irm|invoke-webrequest|invoke-restmethod|downloadstring)\b') { Block 'ダウンロードしたスクリプトをそのまま実行(iex)' }
exit 0
