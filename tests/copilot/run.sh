#!/bin/bash
# GitHub Copilot の hooks の橋渡し(.github/hooks/copilot-adapter.sh)のテスト。
# tests/hooks/cases.json の全ケースを、Copilot が渡す形(ファイルの場所は path で渡す、と仮定した形)に直して橋渡しに通し、
# 止める・通す・直させるが Claude Code のときと同じになるかを確かめる。
# 使い方: bash tests/copilot/run.sh   (jq が必要)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
A="$ROOT/.github/hooks/copilot-adapter.sh"
F="$ROOT/tests/hooks/fixtures"
C="$ROOT/tests/hooks/cases.json"
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
ng() { fail=$((fail+1)); printf 'NG   %s\n' "$1"; }

n=$(jq length "$C")
for ((i=0; i<n; i++)); do
  hook=$(jq -r ".[$i].hook" "$C"); want=$(jq -r ".[$i].expect" "$C"); label=$(jq -r ".[$i].label" "$C")
  [ "$hook" = "session-context" ] && continue
  json=$(jq -c --arg root "$ROOT" --arg f "$F" ".[$i].input | tojson | gsub(\"\\\\{ROOT\\\\}\"; \$root) | gsub(\"\\\\{F\\\\}\"; \$f) | fromjson
    | if .tool_input.file_path then .tool_input.path = .tool_input.file_path | del(.tool_input.file_path) else . end" "$C")
  if [ "$hook" = "check-after-edit" ]; then
    out=$(printf '%s' "$json" | bash "$A" PostToolUse "$hook" 2>/dev/null); got=$?
    ctx=$(printf '%s' "$out" | jq -r '.additionalContext // empty' 2>/dev/null)
    if [ "$got" = 0 ] && { { [ "$want" = 2 ] && [ -n "$ctx" ]; } || { [ "$want" = 0 ] && [ -z "$ctx" ]; }; }; then ok "$hook $label"; else ng "$hook $label(期待 ${want}、終了 ${got}、additionalContext ${ctx:+あり})"; fi
  else
    out=$(printf '%s' "$json" | bash "$A" PreToolUse "$hook" 2>/dev/null); got=$?
    reason=$(printf '%s' "$out" | jq -r 'select(.permissionDecision == "deny") | .permissionDecisionReason' 2>/dev/null)
    if [ "$got" = "$want" ] && { [ "$want" = 0 ] || [ -n "$reason" ]; }; then ok "$hook $label"; else ng "$hook $label(期待 ${want}、実際 ${got})"; fi
  fi
done

# 会話の始まり: 文を additionalContext の JSON にして返す
out=$(printf '{}' | bash "$A" SessionStart session-context)
[ -n "$(printf '%s' "$out" | jq -r '.additionalContext // empty')" ] && ok "SessionStart: additionalContext を返す" || ng "SessionStart: additionalContext が無い"
# 知らないイベントは止める
printf '{}' | bash "$A" Nope block-dangerous-bash >/dev/null 2>&1; [ $? = 2 ] && ok "知らないイベントは止める" || ng "知らないイベントで止まらない"

echo "合計: ok $pass / NG $fail"
[ "$fail" = 0 ]
