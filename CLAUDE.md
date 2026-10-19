# CLAUDE.md

このリポジトリは、SAP Commerce Cloud の Composable Storefront(Spartacus / Angular)案件で使う
Claude Code のエージェント・スキル・hooks のサンプルです。`playground/` は練習用の断片で、ビルドはできません。

## この案件の前提(決定済み。変えるときは人が決める)
- SSR あり(manifest の `ssr.enabled: true`、`yarn build:ssr`)。すべての画面はサーバーでも描かれる。
- フロントは Angular(Composable Storefront の標準構成)。バックエンドは SAP Commerce(Spring)の標準構成。ストアフロントは OCC だけを呼ぶ。
- BFF、Next.js などの別フロント、別の Spring Boot サービスは置かない。

## ルール(本番の案件でも同じ)
- 標準ライブラリのソースをコピーして改変しない。差し替えは cmsComponents、追加は Outlet。
- コンポーネントから直接 HTTP を呼ばない。Facade(Query / Command)経由。
- OCC の fields は必要な項目だけ。FULL を既定にしない。
- 画面文言は翻訳キー(playground/storefront/src/assets/i18n)。ハードコードしない。
- window / document / localStorage を直接触らない(WindowRef か isPlatformBrowser)。サーバーで取った OCC はブラウザで取り直さない(Transfer State)。
- OCC の URL はハードコードしない(CCv2 では OCC_BACKEND_BASE_URL_VALUE の置換)。
- SAP Commerce 側は自社の拡張(hybris/bin/custom)だけを変える。typecode は 10001 以上。ImpEx のヘッダには unique=true。
- 本番の操作(デプロイ、ロールバック、設定変更、initialize)は提案までにとどめ、人が実行する。
- push、プルリクエスト、コミットは人がする。

## コマンド
- hooks のテスト: bash tests/hooks/run.sh(PowerShell 版は powershell -NoProfile -ExecutionPolicy Bypass -File tests\hooks\run.ps1)。.sh と .ps1 は同じ規則に保ち、ケースは tests/hooks/cases.json に足す
- 定義の検査: bash tests/validate-kit.sh
- 文字起こしのテスト: bash tests/transcribe/run.sh(PowerShell 版は tests\transcribe\run.ps1)。transcribe.py と transcribe.ps1 は同じ出力に保つ
- (実案件の例)開発: yarn start / テスト: yarn test / SSR ビルド: yarn build:ssr / E2E: yarn e2e

## 仕組みで止めていること(.claude/hooks)
- ant initialize、rm -rf、git push --force、git reset --hard、DROP TABLE、パッケージの公開は hook で止まる。止まったら手順を書いて人に依頼する。
- .env と鍵は、Read と、よくある読み出しコマンド(cat、Get-Content など)を hook で止める。すべての読み方を防げるわけではないので、本物の秘密は作業用のリポジトリに置かない。node_modules、dist、hybris/bin(custom 以外)への書き込みは止まる。
- 編集後に OCC の URL の直書き、fields=FULL、コンポーネントの HttpClient、window / document の直接利用(SSR)、typecode、ImpEx の unique=true を検査する。

## 担当の分け方(.claude/agents)
- フロントエンド(ストアフロント側の実装): cs-frontend / 設計: cs-architect / 運用: cs-operator / 信頼性: cs-sre
- 監査: cs-auditor / 要望の整理: cs-pdm / テスト: cs-qa / 性能: cs-performance
- 更新: cs-upgrader / 文言と CMS: cs-content-i18n / OCC の契約: cs-occ-liaison
- バックエンド(SAP Commerce 側の OCC 拡張、型、ImpEx): cs-backend
- 文書(引き継ぎ、設計書、手順書、API 仕様、説明資料、PowerPoint / Excel の文字起こしと要約): cs-docs
