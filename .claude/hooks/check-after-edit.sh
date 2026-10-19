#!/bin/bash
# PostToolUse(Edit|Write): 編集したファイルを、案件のルールで検査する。
# ツールはもう実行済み。問題があれば終了コード 2 で stderr を Claude に見せ、直させる。
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
path=${path//\\//}  # Windows(Git Bash)の C:\a\b を C:/a/b にそろえる
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

problems=()
case "$path" in
  *.ts|*.html)
    # ストアフロント: OCC の URL を直書きしない、FULL を既定にしない、文言を直書きしない(目安)
    grep -nE 'https?://[^"'"'"' ]*/occ/v2' "$path" >/dev/null && problems+=("OCC の URL を直書きしている。設定(backend.occ.baseUrl、CCv2 では OCC_BACKEND_BASE_URL_VALUE)から取る")
    grep -nE 'fields=FULL' "$path" >/dev/null && problems+=("fields=FULL を使っている。必要な項目だけを列挙する")
    case "$path" in
      *.component.ts) grep -nE '\bHttpClient\b' "$path" >/dev/null && problems+=("コンポーネントで HttpClient を使っている。Facade(Query / Command)経由にする") ;;
    esac
    # SSR: サーバー(Node)には window / document が無い。WindowRef か isPlatformBrowser で分けていないファイルで直接触っていたら止める
    case "$path" in
      *.spec.ts|*server.ts) ;;
      *.ts)
        if grep -nE '(^|[^.A-Za-z0-9_$])(window|document|localStorage|sessionStorage|navigator)\.' "$path" >/dev/null \
           && ! grep -qE 'WindowRef|isPlatformBrowser|isPlatformServer' "$path"; then
          problems+=("window / document / localStorage / navigator を直接触っている。SSR で落ちるので WindowRef(@spartacus/core)か isPlatformBrowser で分ける")
        fi ;;
    esac
    # リンタ(プロジェクトに eslint があるときだけ)
    if [ -x "${CLAUDE_PROJECT_DIR:-.}/node_modules/.bin/eslint" ]; then
      out=$("${CLAUDE_PROJECT_DIR:-.}/node_modules/.bin/eslint" --no-warn-ignored "$path" 2>&1) || problems+=("eslint のエラー:\n$out")
    fi
    ;;
  *items.xml)
    # SAP Commerce: typecode は 10000 以下が SAP の予約
    while read -r tc; do
      [ -n "$tc" ] && [ "$tc" -le 10000 ] && problems+=("typecode=$tc は SAP の予約範囲(0〜10000)。案件の番号帯から選ぶ")
    done < <(grep -oE 'typecode="[0-9]+"' "$path" | grep -oE '[0-9]+')
    ;;
  *.impex)
    # INSERT_UPDATE / UPDATE / REMOVE のヘッダに unique=true が無い
    while IFS= read -r line; do
      printf '%s' "$line" | grep -q 'unique=true' || problems+=("unique=true の無いヘッダ: $line")
    done < <(grep -E '^(INSERT_UPDATE|UPDATE|REMOVE)\s' "$path")
    ;;
esac

if [ ${#problems[@]} -gt 0 ]; then
  echo "編集後の検査で問題が見つかりました($path):" >&2
  for p in "${problems[@]}"; do printf -- '- %b\n' "$p" >&2; done
  exit 2
fi
exit 0
