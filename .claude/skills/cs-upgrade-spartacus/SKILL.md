---
name: cs-upgrade-spartacus
description: Composable Storefront(Spartacus)を次の版に上げる手順。リリースノートの確認、影響表、ng update と schematics、回帰テスト、報告まで。バージョンアップを頼まれたときに使う。
allowed-tools: Read, Grep, Glob, Edit, Bash(git *), Bash(npx ng update *), Bash(npx ng generate *), Bash(yarn install *), Bash(yarn build *), Bash(yarn test *)
---

# Spartacus のバージョンアップ

## 1. 準備
- 現在の版(package.json の `@spartacus/*`)と目標の版を書く
- 間の版のリリースノートから、破壊的変更・非推奨・削除された API を一覧化する
- Node.js の対応版を確認し、ローカルと manifest の `nodeVersion` を合わせる

## 2. 影響表
- 自プロジェクトが触っている箇所を Grep: 差し替えた `cmsComponents`、Outlet、継承した標準クラス、非公開 API(`@spartacus/*/src/` 直下の import など)
- 各箇所に「影響あり / なし / 要確認」を付ける

## 3. 実施(専用ブランチ)
- `ng update` で `@spartacus/schematics` と関連パッケージを一段上げる
- schematics の移行出力(TODO コメントや警告)をすべて保存し、1 つずつ対応する
- 複数のメジャー版をまたぐときは、一段ずつ

## 4. 検証
- ビルド(SSR 含む)→ ユニット → E2E(主要フロー)
- 壊れた箇所を影響表と突き合わせ、非公開 API 依存は公開 API へ寄せる

## 5. 報告
- 変更点、手で直した箇所、残課題、切り戻し手順(ブランチと lock ファイル)
- 本番反映は cs-ccv2-release の手順へ

参考: https://learn-sap-commerce.vercel.app/learn/composable-storefront/09-upgrade-and-operations
