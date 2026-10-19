#!/bin/bash
# PreToolUse(Bash): 取り返しのつかないコマンドを止める。終了コード 2 で止め、stderr の文が Claude に伝わる。
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

block() { echo "hook で禁止: $1。必要なら手順を書いて人に実行を依頼してください。(コマンド: $cmd)" >&2; exit 2; }

# SAP Commerce: 初期化は全テーブルを消す
printf '%s' "$cmd" | grep -Eq '\bant\b.*\binitialize\b' && block "ant initialize(全テーブルを削除する)"
# 削除と履歴の書き換え
printf '%s' "$cmd" | grep -Eq '\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r' && block "rm -rf"
printf '%s' "$cmd" | grep -Eq '\bgit\s+push\b.*(--force|-f\b)' && block "git push --force"
printf '%s' "$cmd" | grep -Eq '\bgit\s+reset\s+--hard' && block "git reset --hard"
printf '%s' "$cmd" | grep -Eiq '\b(drop|truncate)\s+table\b' && block "DROP / TRUNCATE TABLE"
# 公開・配布
printf '%s' "$cmd" | grep -Eq '\b(npm|yarn|pnpm)\s+publish\b' && block "パッケージの公開"
# 鍵の持ち出しと、取ってきたスクリプトの実行
printf '%s' "$cmd" | grep -Eq '(cat|less|head|tail|cp|scp)\s+[^|;]*\.env(\s|$|\.)' && block ".env の読み出し"
printf '%s' "$cmd" | grep -Eq '(curl|wget)\b[^|]*\|\s*(ba|z)?sh\b' && block "ダウンロードしたスクリプトをそのまま実行"
exit 0
