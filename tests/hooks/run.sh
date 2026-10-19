#!/bin/bash
# hooks(bash 版)のテスト。Claude Code が hook に渡すのと同じ形の JSON を標準入力に入れ、終了コードを確かめる。
# 0 = 通す、2 = 止める(PreToolUse)/ 直させる(PostToolUse)。ケースは cases.json(PowerShell 版の run.ps1 と共通)。
# 使い方: bash tests/hooks/run.sh   (jq が必要)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/.claude/hooks"
F="$ROOT/tests/hooks/fixtures"
export CLAUDE_PROJECT_DIR="$ROOT"
pass=0; fail=0

C="$ROOT/tests/hooks/cases.json"
n=$(jq length "$C")
for ((i=0; i<n; i++)); do
  hook=$(jq -r ".[$i].hook" "$C"); want=$(jq -r ".[$i].expect" "$C"); label=$(jq -r ".[$i].label" "$C")
  json=$(jq -c --arg root "$ROOT" --arg f "$F" ".[$i].input | tojson | gsub(\"\\\\{ROOT\\\\}\"; \$root) | gsub(\"\\\\{F\\\\}\"; \$f) | fromjson" "$C")
  printf '%s' "$json" | "$H/$hook.sh" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then pass=$((pass+1)); printf 'ok   %-24s %s\n' "$hook" "$label"
  else fail=$((fail+1)); printf 'NG   %-24s %s(期待 %s、実際 %s)\n' "$hook" "$label" "$want" "$got"; fi
done

echo "合計: ok $pass / NG $fail"
[ "$fail" = 0 ]
