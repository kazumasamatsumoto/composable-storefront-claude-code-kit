---
name: cs-incident-triage
description: Composable Storefront の障害(画面が出ない、遅い、エラーが出る)を、ブラウザ / CDN / SSR / OCC / バックエンドのどの区間かに切り分ける手順。障害対応の最初の 15 分で使う。
allowed-tools: Read, Grep, Glob
---

# 障害の切り分け(最初の 15 分)

## 1. 事実を集める(推測しない)
- いつから、どの画面、どの利用者(全員 / ログイン済み / 特定の国)、再現手順
- 直前の変更(リリース、CMS 公開、バックエンドの変更、証明書の期限)

## 2. 区間を切る
| 症状 | 疑う区間 | 確認 |
|---|---|---|
| 真っ白、`app-root` が空 | SSR 失敗 → CSR フォールバック、または JS の読み込み失敗 | `curl` で HTML を見る。ブラウザのコンソール |
| 一部の情報だけ出ない | OCC の特定端点 | ネットワークタブで 4xx / 5xx の URL |
| ログイン・カートだけ失敗 | 認可サーバー(JWT)、CORS | 401 / 403 / CORS エラーの有無 |
| 全体が遅い | SSR Pod、OCC、CDN のキャッシュ落ち | TTFB、OCC の応答時間、キャッシュヒット率 |
| 特定の国・端末だけ | CDN、証明書、ブラウザ互換 | 該当環境で再現 |
| CMS の内容が古い / 消えた | カタログ同期、SmartEdit 公開 | CMS の公開状態 |

## 3. どこを見るか
- ストアフロント: ブラウザのコンソールとネットワーク。SSR のログ(Cloud Portal のログ検索)
- OCC: 応答コードと `errors` 本文。Commerce 側のログ
- 連携: Integration Suite が絡むなら、https://learn-sap-commerce.vercel.app/learn/cloud-integration/06-operations-monitoring-and-troubleshooting の 3 か所の切り分け

## 4. 一次対応の候補(人が判断して実行)
- 直前のリリースの切り戻し
- CDN キャッシュの削除(キャッシュ汚染のとき)
- SSR を一時的に無効化して CSR で凌ぐ(この案件の前提は SSR あり。SEO への影響を承知のうえで、戻す期限を決めて人が判断する)

## 5. 記録
- 時系列、影響範囲、検知までの時間、暫定対応、恒久対応の担当を残す(ポストモーテムの材料)
