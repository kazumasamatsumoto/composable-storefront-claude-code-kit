#!/bin/bash
# エージェント・スキル・hooks の定義が Claude Code に読める形かを確かめる。
# 使い方: bash tests/validate-kit.sh   (jq が必要)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
C="$ROOT/.claude"
err=0
ng() { echo "NG  $1"; err=$((err+1)); }

# frontmatter(先頭の --- から次の --- まで)の 1 項目を取り出す
fm() { awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{ if (index($0,k": ")==1){sub(k": *","");print;exit} }' "$1"; }
# skills: の並び(1 行の "a, b" と、続く "  - a" の両方の書き方)
fm_list() { awk -v k="$2" 'NR==1{next} $0=="---"{exit} index($0,k":")==1{v=$0;sub(k": *","",v);gsub(/[\[\]]/,"",v);n=split(v,a,/, */);for(i=1;i<=n;i++)if(a[i]!="")print a[i];inl=1;next} inl&&/^ *- /{v=$0;sub(/^ *- */,"",v);print v;next} {inl=0}' "$1"; }

# --- エージェント
n=0
for f in "$C"/agents/*.md; do
  n=$((n+1)); base=$(basename "$f" .md)
  [ "$(head -1 "$f")" = "---" ] || ng "$f: 先頭が --- でない"
  name=$(fm "$f" name); desc=$(fm "$f" description)
  [ "$name" = "$base" ] || ng "$f: name($name)がファイル名($base)と違う"
  [ -n "$desc" ] || ng "$f: description が無い(Claude が委任先を選ぶ手がかり)"
  while read -r s; do
    [ -z "$s" ] && continue
    [ -f "$C/skills/$s/SKILL.md" ] || ng "$f: skills に書いた $s が .claude/skills に無い"
  done < <(fm_list "$f" skills)
done
echo "エージェント: $n 本"

# --- スキル
n=0
for d in "$C"/skills/*/; do
  n=$((n+1)); base=$(basename "$d"); f="$d/SKILL.md"
  [ -f "$f" ] || { ng "$d: SKILL.md が無い"; continue; }
  name=$(fm "$f" name); desc=$(fm "$f" description)
  [ "$name" = "$base" ] || ng "$f: name($name)がフォルダ名($base)と違う"
  [ -n "$desc" ] || ng "$f: description が無い(Claude が開くかどうかの手がかり)"
  lines=$(wc -l < "$f"); [ "$lines" -lt 500 ] || ng "$f: $lines 行(公式の目安は 500 行未満)"
done
echo "スキル: $n 本"

# --- hooks
jq empty "$C/settings.json" 2>/dev/null || ng "settings.json が JSON として読めない"
while read -r cmd; do
  p=${cmd//\$\{CLAUDE_PROJECT_DIR\}/$ROOT}
  [ -f "$p" ] || { ng "settings.json の $cmd が無い"; continue; }
  [ -x "$p" ] || ng "$p に実行権限が無い(chmod +x)"
  bash -n "$p" || ng "$p に文法エラー"
done < <(jq -r '.hooks[][].hooks[].command' "$C/settings.json")
echo "hooks: $(jq '[.hooks[][].hooks[]] | length' "$C/settings.json") 本"

[ "$err" = 0 ] && echo "すべて OK" || { echo "NG が $err 件"; exit 1; }
