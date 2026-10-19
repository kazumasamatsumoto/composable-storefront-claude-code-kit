---
name: cs-review-checklist
description: Composable Storefront の差分レビューで必ず見る観点の一覧。cs-auditor などのエージェントが事前読み込みする参照用。人が直接呼ぶことは想定しない。
user-invocable: false
---

# Composable Storefront レビュー観点

番号を指摘の根拠として使う。

## A. 拡張の作法
- A1 標準ライブラリのソースをコピーして改変していない
- A2 差し替えは `cmsComponents`、追加は Outlet で行っている
- A3 非公開 API(ライブラリ内部のパス)に依存していない
- A4 コンポーネントから直接 HTTP を呼んでいない(Facade 経由)

## B. OCC と性能
- B1 `fields=FULL` を既定にしていない
- B2 一覧で項目ごとに OCC を呼ぶ(N+1)構造が無い
- B3 SSR で `window` / `document` を直接触っていない
- B4 初期バンドルに不要な機能ライブラリが入っていない

## C. セキュリティ
- C1 CORS に本番 `*` が無い(OCC 側の設定)
- C2 `innerHTML` / `bypassSecurityTrust*` の使用に理由がある
- C3 機密情報を localStorage に長期保存していない
- C4 リポジトリに秘密情報が無い

## D. 文言とアクセシビリティ
- D1 画面文言は翻訳キー
- D2 aria 属性、ラベル、フォーカス順が標準から後退していない
- D3 色だけで情報を伝えていない

## E. テストと範囲
- E1 変更にユニットテストがある(ある / 無いとき)
- E2 主要フローに影響する変更なら E2E が更新されている
- E3 計画の範囲外のファイルを変更していない

## F. 運用
- F1 manifest.json の変更に理由とリリース手順がある
- F2 OCC の URL をハードコードしていない(`OCC_BACKEND_BASE_URL_VALUE`)
- F3 CMS で変えられるものをコードに埋めていない

参考: https://learn-sap-commerce.vercel.app/learn/ai-driven-development/06-reviewing-ai-generated-deliverables
