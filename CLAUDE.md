# CLAUDE.md

このリポジトリは、SAP Commerce Cloud の Composable Storefront(Spartacus / Angular)案件で使う
Claude Code のエージェント・スキル・hooks のサンプルです。`playground/` は練習用の断片で、ビルドはできません。

## ルール(本番の案件でも同じ)
- 標準ライブラリのソースをコピーして改変しない。差し替えは cmsComponents、追加は Outlet。
- コンポーネントから直接 HTTP を呼ばない。Facade(Query / Command)経由。
- OCC の fields は必要な項目だけ。FULL を既定にしない。
- 画面文言は翻訳キー(playground/storefront/src/assets/i18n)。ハードコードしない。
- OCC の URL はハードコードしない(CCv2 では OCC_BACKEND_BASE_URL_VALUE の置換)。
- SAP Commerce 側は自社の拡張(hybris/bin/custom)だけを変える。typecode は 10001 以上。ImpEx のヘッダには unique=true。
- 本番の操作(デプロイ、ロールバック、設定変更、initialize)は提案までにとどめ、人が実行する。
- push、プルリクエスト、コミットは人がする。

## コマンド
- hooks のテスト: bash tests/hooks/run.sh
- 定義の検査: bash tests/validate-kit.sh
- (実案件の例)開発: yarn start / テスト: yarn test / SSR ビルド: yarn build:ssr / E2E: yarn e2e

## 仕組みで止めていること(.claude/hooks)
- ant initialize、rm -rf、git push --force、git reset --hard、DROP TABLE、パッケージの公開は hook で止まる。止まったら手順を書いて人に依頼する。
- .env と鍵は読めない。node_modules、dist、hybris/bin(custom 以外)への書き込みは止まる。
- 編集後に OCC の URL の直書き、fields=FULL、コンポーネントの HttpClient、typecode、ImpEx の unique=true を検査する。

## 担当の分け方(.claude/agents)
- 実装: cs-developer / 設計: cs-architect / 運用: cs-operator / 信頼性: cs-sre
- 監査: cs-auditor / 要望の整理: cs-pdm / テスト: cs-qa / 性能: cs-performance
- 更新: cs-upgrader / 文言と CMS: cs-content-i18n / OCC の契約: cs-occ-liaison
- バックエンド(SAP Commerce 側の OCC 拡張、型、ImpEx): cs-backend
