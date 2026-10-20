#!/bin/bash
# cs-cost のスクリプトに作り物の会話記録を読ませ、数と金額が合うかを確かめる。
# 使い方: bash tests/cost/run.sh   (node が必要)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/.claude/skills/cs-cost/scripts/cost.mjs"
W="$(mktemp -d)"   # 一時フォルダ。消すのは OS に任せる
command -v cygpath >/dev/null && W="$(cygpath -m "$W")"   # Windows の Git Bash では node に渡せる形にする
err=0
ng() { echo "NG  $1"; err=$((err+1)); }

# 作業フォルダ $W/demo-proj の会話記録を作る(フォルダ名は、node が解決したパスの英数字以外を - にしたもの)
PROJ="$W/demo-proj"
mkdir -p "$PROJ"
P="$W/config/projects/$(node -e 'console.log(require("path").resolve(process.argv[1]).replace(/[^A-Za-z0-9]/g,"-"))' "$PROJ")"
mkdir -p "$P/s1/subagents"
A='{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":1000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":1000000,"output_tokens":3000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":2000}}}}'
{
  echo '{"type":"user","message":{"content":"hi"}}'
  echo "$A"
  echo "$A"   # 同じ応答が 2 行に分かれていても 1 回と数える
  echo '{"type":"assistant","message":{"id":"m2","model":"claude-haiku-4-5-20251001","usage":{"input_tokens":1000000,"output_tokens":0}}}'
} > "$P/s1.jsonl"
echo '{"type":"assistant","message":{"id":"x1","model":"claude-sonnet-5-5","usage":{"input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1000000,"speed":"standard"}}}' > "$P/s1/subagents/agent-a1.jsonl"
echo '{"agentType":"cs-frontend"}' > "$P/s1/subagents/agent-a1.meta.json"
echo '{"type":"assistant","message":{"id":"y1","model":"claude-unknown-9","usage":{"input_tokens":5,"output_tokens":5}}}' > "$P/s1/subagents/agent-a2.jsonl"

run() { CLAUDE_CONFIG_DIR="$W/config" node "$S" --project-dir "$PROJ" --log "$W/log.csv" "$@"; }

# opus: 1000*4 + 2000*8 + 1e6*0.2 + 3000*20 = 280000 → $0.28 / haiku(日付付きの名前): 1e6*1 → $1 / sonnet: 1e6*10 → $10
j=$(run --session s1 --label "一回目" --json) || ng "実行に失敗"
got=$(node -e 'const j=JSON.parse(process.argv[1]);console.log(j.total.calls,j.total.input,j.total.output,j.total.usd.toFixed(2),j.unknownModels.join(" "))' "$j")
[ "$got" = "4 1001005 1003005 11.28 claude-unknown-9" ] || ng "累計が違う: $got"
node -e 'const j=JSON.parse(process.argv[1]);process.exit(j.rows.some(r=>r.who==="担当 cs-frontend(1 回)")?0:1)' "$j" || ng "担当の種類が表に出ない"

# 2 回目は、記録が増えていないので今回分は 0
j=$(run --session s1 --json) || ng "2 回目の実行に失敗"
[ "$(node -e 'console.log(JSON.parse(process.argv[1]).delta.usd.toFixed(2))' "$j")" = "0.00" ] || ng "前回からの差が 0 にならない"
[ "$(wc -l < "$W/log.csv" | tr -d ' ')" = "3" ] || ng "CSV が見出し + 2 行になっていない"
grep -q '"一回目"' "$W/log.csv" || ng "CSV に依頼の名前が無い"

# 会話 ID を省くと、いちばん新しい記録を使う。--no-log なら CSV は増えない
run --no-log > "$W/out.md" || ng "--session なしで失敗"
grep -q '会話 ID: s1' "$W/out.md" || ng "最新の会話を選べていない"
[ "$(wc -l < "$W/log.csv" | tr -d ' ')" = "3" ] || ng "--no-log なのに CSV が増えた"

[ "$err" = 0 ] && echo "cs-cost: すべて OK" || { echo "cs-cost: NG が $err 件"; exit 1; }
