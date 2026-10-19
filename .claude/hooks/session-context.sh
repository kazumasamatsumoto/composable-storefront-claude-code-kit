#!/bin/bash
# SessionStart: 会話の最初に、今いるリポジトリの種類と現在のブランチを Claude に伝える(標準出力が文脈に入る)。
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "不明")
kind="不明"
[ -f angular.json ] && kind="ストアフロント(Composable Storefront / Angular)。担当は cs-frontend ほか"
if [ -d core-customize ] || [ -d hybris ] || grep -q commerceSuiteVersion manifest.json 2>/dev/null || grep -q commerceSuiteVersion core-customize/manifest.json 2>/dev/null; then
  kind="SAP Commerce(core-customize)。担当は cs-backend"
fi
echo "リポジトリの種類: $kind"
echo "現在のブランチ: $branch"
echo "この案件の前提: SSR あり。フロントは Angular(Composable Storefront)、バックエンドは SAP Commerce(Spring)の標準構成。BFF や別フロントは置かない。"
echo "このプロジェクトの hooks: 危険なコマンド(ant initialize、rm -rf、git push --force など)と、秘密・標準ソース・dist への書き込みは hook で止まる。止まったら手順を書いて人に依頼する。"
exit 0
