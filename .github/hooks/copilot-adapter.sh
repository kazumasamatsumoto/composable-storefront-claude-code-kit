#!/bin/bash
# GitHub Copilot の hooks から、.claude/hooks の同じスクリプトを呼ぶための橋渡し(bash 版)。
# cs-hooks.json はイベント名を PascalCase(PreToolUse など)で書くので、Copilot は Claude Code と同じ形の入力
# (tool_name は Bash / Read / Edit / Write、tool_input)を渡す(公式 GitHub Copilot hooks reference)。
# ここでは結果の返し方だけを Copilot の形に直す。止める・通すの規則は .claude/hooks にだけ書く。
# 使い方: copilot-adapter.sh <SessionStart|PreToolUse|PostToolUse> <.claude/hooks のスクリプト名(拡張子なし)>
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export CLAUDE_PROJECT_DIR="$ROOT"
event="${1:-}"; hook="${2:-}"
script="$ROOT/.claude/hooks/$hook.sh"
[ -f "$script" ] || { echo "copilot-adapter: $script がありません" >&2; exit 2; }
input=$(cat)
has_jq=0; command -v jq >/dev/null 2>&1 && has_jq=1
# Copilot の道具がファイルの場所を path で渡したときに備えて、file_path が無ければ path を写す(推論。Claude の形なら何もしない)
if [ "$has_jq" = 1 ]; then
  input=$(printf '%s' "$input" | jq -c 'if (.tool_input | type) == "object" and .tool_input.file_path == null and .tool_input.path != null then .tool_input.file_path = .tool_input.path else . end' 2>/dev/null || printf '%s' "$input")
fi

case "$event" in
  SessionStart)
    # Claude Code は標準出力の文をそのまま文脈に入れるが、Copilot は {"additionalContext": "..."} を読む
    text=$(printf '%s' "$input" | bash "$script" 2>/dev/null)
    if [ "$has_jq" = 1 ]; then jq -n --arg c "$text" '{additionalContext: $c}'; fi
    exit 0
    ;;
  PreToolUse)
    # 終了コード 2 は、Copilot でも道具の呼び出しを止める。理由は permissionDecisionReason で渡す
    msg=$(printf '%s' "$input" | bash "$script" 2>&1 >/dev/null); code=$?
    [ "$code" = 0 ] && exit 0
    if [ "$has_jq" = 1 ]; then jq -n --arg r "$msg" '{permissionDecision: "deny", permissionDecisionReason: $r}'; else echo "$msg" >&2; fi
    exit 2
    ;;
  PostToolUse)
    # Copilot の PostToolUse は、終了コード 2 を人への警告として扱う。AI に直させるには additionalContext で返す
    msg=$(printf '%s' "$input" | bash "$script" 2>&1 >/dev/null); code=$?
    if [ "$code" = 2 ] && [ "$has_jq" = 1 ]; then jq -n --arg c "$msg 直してから次に進んでください。" '{additionalContext: $c}'; fi
    [ "$code" = 2 ] && [ "$has_jq" = 0 ] && echo "$msg" >&2
    exit 0
    ;;
  *)
    echo "copilot-adapter: 知らないイベント $event" >&2
    exit 2
    ;;
esac
