---
name: cs-ccv2-release
description: Composable Storefront を SAP Commerce Cloud(CCv2 / Cloud Portal)にリリースする手順書を作り、実施を支援する。manifest.json の確認、ビルド、デプロイ、事後確認、切り戻しを含む。リリース作業や手順書作成を頼まれたときに使う。本番の操作は人が行う。
allowed-tools: Read, Grep, Glob, Write, Bash(git log *), Bash(git diff *)
---

# CCv2 への js-storefront リリース

## 0. 事前確認(すべて YES になるまで進まない)
- [ ] `js-storefront/<app>/manifest.json` の `applications[].path`、`ssr.enabled`、`nodeVersion`、`enabledRepositories`(`spartacus-6`)が意図どおり
- [ ] OCC の URL は `OCC_BACKEND_BASE_URL_VALUE` の置換で注入し、ハードコードしていない
- [ ] `dist` をコミットしていない(あるとビルドが飛ばされる)
- [ ] 対象コミットのタグとリリースノートがある
- [ ] CMS コンテンツ(SmartEdit)の公開タイミングを担当と合わせた
- [ ] 切り戻し先のビルド(前回成功したビルドのコード)を控えた

## 1. ビルド(Cloud Portal)
- 対象ブランチ / タグでビルドを作成。ビルドログで `yarn build`(SSR なら `yarn build:ssr`)が実行されたことを確認
- 失敗したら Node.js 版と依存の lock ファイルを疑う

## 2. デプロイ(Cloud Portal、人が実行)
- 先に検証環境へ。デプロイ方式(更新の有無)を手順書に明記
- 本番は業務時間外か、トラフィックの少ない時間帯

## 3. 事後確認
- トップ、商品一覧、商品詳細、カート、ログインの 5 画面を開く
- SSR 対象ページは `curl` で HTML に内容が入っているか確認
- エラー率と応答時間を 15 分観察

## 4. 切り戻し
- 判断基準(エラー率、主要フローの失敗)を数値で先に決める
- 前回成功ビルドを再デプロイする手順を書く。CMS コンテンツを戻す必要があるかも書く
