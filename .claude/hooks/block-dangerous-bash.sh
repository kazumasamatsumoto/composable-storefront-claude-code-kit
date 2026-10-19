#!/bin/bash
# PreToolUse(Bash|PowerShell): 取り返しのつかないコマンドを止める。Bash ツールと PowerShell ツールの両方の命令を見る。終了コード 2 で止め、stderr の文が Claude に伝わる。
# jq が無いと入力を読めず、何も守れないまま通ってしまうので、止めて知らせる(fail-closed)
command -v jq >/dev/null 2>&1 || { echo "hook に jq が必要です(macOS: brew install jq、Windows の Git Bash: winget install jqlang.jq)。入れるまでこの操作は止めます" >&2; exit 2; }
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

block() { echo "hook で禁止: $1。必要なら手順を書いて人に実行を依頼してください。(コマンド: $cmd)" >&2; exit 2; }

# SAP Commerce: 初期化は全テーブルを消す
printf '%s' "$cmd" | grep -Eq '\bant\b.*\binitialize\b' && block "ant initialize(全テーブルを削除する)"
# 削除と履歴の書き換え
printf '%s' "$cmd" | grep -Eq '\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r' && block "rm -rf"
# PowerShell の再帰削除(Remove-Item と別名 rm / del / ri / rd。-Recurse と -Force は省略形も)と、cmd の rd /s
if printf '%s' "$cmd" | grep -Eiq '(^|[^a-z-])(remove-item|ri|rm|rmdir|rd|del|erase)\s(.*\s)?-r(e|ec|ecu|ecur|ecurs|ecurse)?(\s|$)' \
   && printf '%s' "$cmd" | grep -Eiq '\s-f(o|or|orc|orce)?(\s|$)'; then block "再帰と強制つきの削除(rm -r -f / Remove-Item -Recurse -Force)"; fi
printf '%s' "$cmd" | grep -Eiq '(^|[^a-z-])(rd|rmdir)\s+/s\b' && block "rd /s"
printf '%s' "$cmd" | grep -Eq '\bgit\s+push\b.*(--force|-f\b)' && block "git push --force"
printf '%s' "$cmd" | grep -Eq '\bgit\s+reset\s+--hard' && block "git reset --hard"
printf '%s' "$cmd" | grep -Eiq '\b(drop|truncate)\s+table\b' && block "DROP / TRUNCATE TABLE"
# 公開・配布
printf '%s' "$cmd" | grep -Eq '\b(npm|yarn|pnpm)\s+publish\b' && block "パッケージの公開"
# 鍵の持ち出しと、取ってきたスクリプトの実行
printf '%s' "$cmd" | grep -Eiq '\b(cat|less|head|tail|cp|scp|type|more|gc|get-content|copy|copy-item|cpi)\s+[^|;]*\.env(\s|$|\.|["'"'"'])' && block ".env の読み出し"
printf '%s' "$cmd" | grep -Eq '(curl|wget)\b[^|]*\|\s*(ba|z)?sh\b' && block "ダウンロードしたスクリプトをそのまま実行"
printf '%s' "$cmd" | grep -Eiq '\b(iwr|irm|invoke-webrequest|invoke-restmethod|curl|wget)\b[^|]*\|\s*(iex|invoke-expression)\b' && block "ダウンロードしたスクリプトをそのまま実行(| iex)"
printf '%s' "$cmd" | grep -Eiq '\b(iex|invoke-expression)\b.*\b(iwr|irm|invoke-webrequest|invoke-restmethod|downloadstring)\b' && block "ダウンロードしたスクリプトをそのまま実行(iex)"
exit 0
