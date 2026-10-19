---
name: cs-perf-budget
description: Composable Storefront の性能予算(バンドルサイズ、Core Web Vitals の目標)を定義し、計測して超過を見つける手順。性能改善や予算設定を頼まれたときに使う。
allowed-tools: Read, Grep, Glob, Edit, Bash(yarn build *), Bash(npx ng build *), Bash(npx lighthouse *), Bash(npx source-map-explorer *)
---

# 性能予算と計測

## 1. 予算を決める(例。案件の数値に置き換える)
| 指標 | 目標 | 計測 |
|---|---|---|
| LCP | 2.5 秒以内(モバイル、商品詳細) | Lighthouse / 実ユーザー計測 |
| INP | 200 ms 以内 | 実ユーザー計測 |
| CLS | 0.1 以内 | Lighthouse |
| 初期 JS | 案件で決めた KB 以内 | ビルドの出力、source-map-explorer |
| SSR TTFB | 案件で決めた ms 以内 | curl の計測、SSR ログ |

## 2. 予算をコードに入れる
- `angular.json` の `budgets` に初期バンドルの上限を設定し、超えたら CI が失敗するようにする

## 3. 計測
- 同じページ、同じ端末条件、同じネットワーク条件で 3 回以上計測して中央値を使う
- 変更前後を同じ表に並べる

## 4. よくある原因と対処
- 初期バンドルに不要な機能ライブラリ → 遅延読み込み
- ヒーロー画像が大きい、サイズ未指定 → 形式とサイズの最適化、幅高さ指定
- SSR で同じ OCC を複数回呼ぶ → 呼び出しの共有、Transfer State
- サードパーティのスクリプトがブロッキング → 非同期化、読み込み順の見直し

## 5. 報告
- 予算表、計測表(前後)、変更内容、残課題

参考: https://learn-sap-commerce.vercel.app/learn/composable-storefront/07-ssr-pwa-performance
