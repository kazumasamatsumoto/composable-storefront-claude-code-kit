#!/bin/bash
# PreToolUse(Read|Edit|Write): 読ませない・書かせないファイルを止める。
# jq が無いと入力を読めず、何も守れないまま通ってしまうので、止めて知らせる(fail-closed)
command -v jq >/dev/null 2>&1 || { echo "hook に jq が必要です(macOS: brew install jq、Windows の Git Bash: winget install jqlang.jq)。入れるまでこの操作は止めます" >&2; exit 2; }
input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
path=${path//\\//}  # Windows(Git Bash)の C:\a\b を C:/a/b にそろえる
[ -z "$path" ] && exit 0

shopt -s nocasematch  # Windows のパスは大文字と小文字を区別しない(Node_Modules、.ENV も止める)
block() { echo "hook で禁止: $1($path)" >&2; exit 2; }

# 秘密(読むのも禁止)
case "$path" in
  *.env|*.env.*|*/secrets/*|*.pem|*.key|*/local.properties.secret*) block "秘密を含むファイル" ;;
esac
[ "$tool" = "Read" ] && exit 0

# ここから下は書き込みだけを止める
case "$path" in
  */node_modules/*) block "node_modules の中(標準ライブラリはコピーや改変をせず、cmsComponents と Outlet で差し替える)" ;;
  */dist/*) block "ビルド成果物 dist" ;;
  */hybris/bin/custom/*) ;;  # 自社の拡張(core-customize/hybris/bin/custom)は書いてよい
  */hybris/bin/*) block "SAP Commerce の標準の拡張(hybris/bin の custom 以外)。自社の拡張(hybris/bin/custom)で上書きする" ;;
  */platform/project.properties) block "platform の project.properties。local.properties か manifest で上書きする" ;;
esac
exit 0
