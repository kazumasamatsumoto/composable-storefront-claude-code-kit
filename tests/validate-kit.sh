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
  p=${cmd//\$\{CLAUDE_PROJECT_DIR:-.\}/$ROOT}
  p=${p//\$\{CLAUDE_PROJECT_DIR\}/$ROOT}
  p=${p//\"/}  # 空白のあるパスに備えた引用符を外す
  [ -f "$p" ] || { ng "settings.json の $cmd が無い"; continue; }
  [ -x "$p" ] || ng "$p に実行権限が無い(chmod +x)"
  bash -n "$p" || ng "$p に文法エラー"
done < <(jq -r '.hooks[][].hooks[].command' "$C/settings.json")
echo "hooks: $(jq '[.hooks[][].hooks[]] | length' "$C/settings.json") 本"

# --- hooks の PowerShell 版(settings.powershell.json。Windows で Git Bash が無いときに settings.json と置き換える)
P="$C/settings.powershell.json"
jq empty "$P" 2>/dev/null || ng "settings.powershell.json が JSON として読めない"
[ "$(jq -c '[.hooks | to_entries[] | .key as $e | .value[] | "\($e):\(.matcher // "")"]' "$C/settings.json")" = \
  "$(jq -c '[.hooks | to_entries[] | .key as $e | .value[] | "\($e):\(.matcher // "")"]' "$P")" ] || ng "settings.json と settings.powershell.json でイベントや matcher が違う"
while read -r f; do
  p=${f//\$\{CLAUDE_PROJECT_DIR\}/$ROOT}
  [ -f "$p" ] || { ng "settings.powershell.json の $f が無い"; continue; }
  [ "$(head -c 3 "$p" | od -An -tx1 | tr -d ' ')" = "efbbbf" ] || ng "$p が BOM 付き UTF-8 でない(Windows PowerShell 5.1 が日本語を読み違える)"
  [ -f "${p%.ps1}.sh" ] || ng "$p に対応する bash 版が無い"
  if command -v pwsh >/dev/null; then
    pwsh -NoProfile -Command "\$e=\$null; [void][System.Management.Automation.Language.Parser]::ParseFile('$p',[ref]\$null,[ref]\$e); if (\$e) { \$e | % { \$_.Message }; exit 1 }" || ng "$p に文法エラー"
  fi
done < <(jq -r '.hooks[][].hooks[] | .args[-1]' "$P")
echo "hooks(PowerShell 版): $(jq '[.hooks[][].hooks[]] | length' "$P") 本$(command -v pwsh >/dev/null || echo '(pwsh が無いので文法検査は省略)')"

# --- 権限ルール(settings.json と settings.powershell.json で同じにする)
[ "$(jq -c '.permissions' "$C/settings.json")" = "$(jq -c '.permissions' "$P")" ] || ng "settings.json と settings.powershell.json で permissions が違う"
jq -e '.permissions.deny | length > 0' "$C/settings.json" >/dev/null || ng "settings.json に permissions.deny が無い"
echo "権限ルール: deny $(jq '.permissions.deny | length' "$C/settings.json") / ask $(jq '.permissions.ask | length' "$C/settings.json") / allow $(jq '.permissions.allow | length' "$C/settings.json")"

# --- GitHub Copilot 用(.github。tools/make-copilot.py で .claude から作る)
python3 "$ROOT/tools/make-copilot.py" --check >/dev/null || ng ".github/agents か copilot-instructions.md が古い(python3 tools/make-copilot.py を動かす)"
n=0
for f in "$ROOT"/.github/agents/*.agent.md; do
  n=$((n+1))
  [ -n "$(fm "$f" description)" ] || ng "$f: description が無い(Copilot では必須)"
  for s in $(grep -o '\.claude/skills/[^/]*/SKILL.md' "$f"); do [ -f "$ROOT/$s" ] || ng "$f: $s が無い"; done
done
echo "Copilot のエージェント: $n 本"
H="$ROOT/.github/hooks/cs-hooks.json"
jq -e '.version == 1' "$H" >/dev/null 2>&1 || ng "cs-hooks.json が JSON として読めないか、version が 1 でない"
while read -r name; do
  [ -f "$C/hooks/$name.sh" ] && [ -f "$C/hooks/$name.ps1" ] || ng "cs-hooks.json が呼ぶ $name の .sh か .ps1 が無い"
done < <(jq -r '.hooks[][] | .bash | split(" ") | last' "$H")
[ "$(jq -c '[.hooks | to_entries[] | .key as $e | .value[] | "\($e):\(.bash | split(" ") | last)"]' "$H")" = \
  "$(jq -c '[.hooks | to_entries[] | .key as $e | .value[] | "\($e):\(.powershell | split(" ") | last)"]' "$H")" ] || ng "cs-hooks.json の bash と powershell で呼ぶものが違う"
[ "$(head -c 3 "$ROOT/.github/hooks/copilot-adapter.ps1" | od -An -tx1 | tr -d ' ')" = "efbbbf" ] || ng "copilot-adapter.ps1 が BOM 付き UTF-8 でない"
bash -n "$ROOT/.github/hooks/copilot-adapter.sh" || ng "copilot-adapter.sh に文法エラー"
echo "Copilot の hooks: $(jq '[.hooks[][]] | length' "$H") 本"

[ "$err" = 0 ] && echo "すべて OK" || { echo "NG が $err 件"; exit 1; }
