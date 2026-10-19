#!/bin/bash
# 文字起こし(cs-office-transcribe の transcribe.py)のテスト。期待する Markdown と 1 文字ずつ比べる。
# 期待値は PowerShell 版(run.ps1)と共通。使い方: bash tests/transcribe/run.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$ROOT/.claude/skills/cs-office-transcribe/scripts/transcribe.py"
D="$ROOT/tests/transcribe"
PY=$(command -v python3 || command -v python)
pass=0; fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
ng() { fail=$((fail+1)); echo "NG   $1"; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

same() { # same <説明> <期待ファイル> <引数...>
  local label=$1 want=$2; shift 2
  if "$PY" "$T" "$@" > "$tmp/out.md" 2>"$tmp/err" && cmp -s "$tmp/out.md" "$D/expected/$want"; then ok "$label"
  else ng "$label"; diff "$D/expected/$want" "$tmp/out.md" | head -20; cat "$tmp/err"; fi
}
same "PowerPoint: 表示順、タイトル、段落の深さ、表、グループ、画像の説明、ノート、非表示、グラフ、SmartArt" sample.pptx.md "$D/fixtures/sample.pptx"
same "Excel: 共有文字列、ふりがなを除く、セル内の文字、日付、真偽、式の計算結果、結合、非表示、空のシート" sample.xlsx.md "$D/fixtures/sample.xlsx"
same "Excel: 行の上限(--max-rows 3)" sample.xlsx.max3.md --max-rows 3 "$D/fixtures/sample.xlsx"

"$PY" "$T" -o "$tmp/out" "$D/fixtures/sample.pptx" 2>/dev/null && cmp -s "$tmp/out/sample.pptx.md" "$D/expected/sample.pptx.md" && ok "-o でフォルダに書き出す" || ng "-o でフォルダに書き出す"
"$PY" "$T" "$D/fixtures/old.ppt" >/dev/null 2>&1; [ $? = 1 ] && ok "古い形式(.ppt)は 1 で終わる" || ng "古い形式(.ppt)は 1 で終わる"
"$PY" "$T" "$D/fixtures/broken.xlsx" >/dev/null 2>&1; [ $? = 1 ] && ok "zip でないファイルは 1 で終わる" || ng "zip でないファイルは 1 で終わる"

echo "合計: ok $pass / NG $fail"
[ "$fail" = 0 ]
