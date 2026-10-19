---
name: cs-ssr-check
description: Composable Storefront の SSR(サーバー側描画)をローカルで動かし、正しく HTML が返っているか、二重取得や SSR 失敗が無いかを確認する手順。SSR の不具合調査や性能確認のときに使う。
allowed-tools: Read, Grep, Glob, Bash(yarn build:ssr *), Bash(yarn serve:ssr *), Bash(npm run build:ssr *), Bash(npm run serve:ssr *)
---

# SSR の確認

## 1. ビルドして起動
- `yarn build:ssr` → `yarn serve:ssr`(プロジェクトのスクリプト名に合わせる)
- OCC の向き先が正しいか(環境変数か設定)を確認する

## 2. HTML を直接見る
- `curl -s http://localhost:4000/ | head -c 3000`(`serve:ssr` の既定は 4000。4200 は `ng serve` の CSR) のように、ブラウザを使わず HTML を見る
- チェック: 主要な内容(商品名、見出し)が HTML に入っている。空の `app-root` だけなら SSR が失敗して CSR に落ちている
- チェック: `<title>` と meta が入っている(SEO 対象ページ)

## 3. 二重取得を確認
- サーバー側で取ったデータがブラウザで再取得されていないか(Transfer State)。ネットワークタブで同じ OCC 呼び出しが 2 回出ていないか
- チェック: 初期表示に必要な OCC 呼び出しが最小限

## 4. SSR 固有の落とし穴
- `window` や `document` を直接触っていないか(SSR では存在しない)。Spartacus の `WindowRef`(`isBrowser()`、`nativeWindow`)か `isPlatformBrowser` で分岐する
- 時間のかかる呼び出しに SSR のタイムアウトが効いているか。失敗時は CSR にフォールバックする設定か
- ログイン後やカートなど利用者ごとのページを SSR でキャッシュしていないか

## 5. 報告
- 対象 URL、TTFB、HTML に主要内容が含まれるか、OCC 呼び出し回数、見つけた問題と直し方

CCv2 では manifest の `ssr.enabled` が true のときに `yarn build:ssr` が走る。詳しくは https://learn-sap-commerce.vercel.app/learn/composable-storefront/07-ssr-pwa-performance
