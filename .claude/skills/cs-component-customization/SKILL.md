---
name: cs-component-customization
description: Composable Storefront で標準の CMS コンポーネントを自作に差し替える、または決まった場所(Outlet)に UI を足す手順とチェック。「このコンポーネントを変えて」「ここにバナーを足して」と頼まれたときに使う。
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(npx ng test *), Bash(yarn test *)
---

# CMS コンポーネントの差し替えと Outlet 追加

必ずこの順で進める。

## 0. どちらの型か決める
- 標準コンポーネントの見た目や振る舞いを変えたい → **差し替え**(`cmsComponents` の対応表)
- 既存の場所に新しい UI を足したい → **Outlet**(`cxOutletRef`)
- 文言や並び順だけ → コードではなく CMS(SmartEdit)。ここで止めて担当に相談する

## 1. 対象を特定する
- CMS コンポーネントの `typeCode`(例: ProductCarouselComponent)を確認する
- 標準実装の場所を Grep し、入力(`CmsComponentData`)と出力を読む
- チェック: 差し替え対象の typeCode が 1 つに定まっている

## 2. 差し替え(cmsComponents)
- 自作コンポーネントを作る(スタンドアロンでも可)。標準の `CmsComponentData` を同じように受け取る
- `provideConfig` で `cmsComponents` に `typeCode: { component: 自作コンポーネント }` を登録する
- 標準のロジックを再利用したいときは標準コンポーネントを継承するか、標準のサービスを注入する。**ソースをコピーしない**
- チェック: 画面で差し替わった。標準に戻すには設定を外すだけで戻る

## 3. Outlet
- 足したい場所の Outlet 名を確認する(標準のテンプレートにある `cxOutlet` 名、またはページテンプレートのスロット名)
- `ng-template` に `cxOutletRef` と位置(`cxOutletPos`: before / after / replace)を付けて配置する
- チェック: 位置が before / after / replace のどれかで意図どおり。replace のときは元の内容が要らないことを確認した

## 4. 仕上げ
- 文言は翻訳キー。aria 属性とキーボード操作を確認
- ユニットテスト: 入力データがあるとき / 無いときの 2 件
- 報告: 変更ファイル、設定の差分、CMS 側で必要な作業(新しい typeCode を使うなら ImpEx か SmartEdit)
