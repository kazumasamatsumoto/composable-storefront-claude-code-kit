---
name: cs-occ-extension
description: SAP Commerce 側で OCC API を足す・変える手順(yocc から自分の OCC 拡張を作る、WsDTO と fieldSetLevelMapping、Controller と @Secured、@RequestMappingOverride、エラー応答、Spock テスト)。「OCC に項目を足して」「新しい OCC 端点を作って」「標準の端点の動きを変えて」と頼まれたときに使う。
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(ant *)
---

# OCC API の追加と変更(Commerce 側)

## 0. 手法を決める
| 頼まれたこと | 手法 |
|---|---|
| 既存の応答(商品、カートなど)に 1 項目足したい | A: Data と WsDTO に項目、Populator、fieldSetLevelMapping |
| 新しい資源を出したい | B: 自分の OCC 拡張に Controller を足す |
| 標準の端点の動きを変えたい | C: @RequestMappingOverride か Bean の差し替え |
| 応答から項目を外したい | D: Populator を外す(configurablePopulatorModification) |
| エラー、キャッシュ、端点の停止 | E: 例外とステータスのプロパティ、ehcache、API の無効化 |
| システム間の連携(画面からではない) | OCC ではなく Integration API を検討する |
- チェック: 手法と理由を 3 行で書いた

## 1. 自分の OCC 拡張を用意する
- 無ければ yocc テンプレートから作る(名前は occ で終わる。commercewebservices に依存する)
- localextensions.xml に追加し、ビルドログに拡張名が出ることを確かめる
- チェック: commercewebservices のソースに差分が無い

## 2. 項目を足す(手法 A)
- 業務の型に項目が要るなら、先に cs-type-and-impex
- beans.xml で Data(例: ProductData)と WsDTO(例: ProductWsDTO)の両方に項目を足す。同じ名前なら DataMapper が自動で写す
- Populator を書き、modifyPopulatorList で既存の Converter に足す。Populator を直接呼ばない
- fieldSetLevelMapping で BASIC / DEFAULT / FULL のどこに出すかを決める
- チェック: `fields=` で指定したときだけ、またはレベルどおりに項目が出る

## 3. 新しい端点を作る(手法 B)
- Controller は自分の OCC 拡張の Web 側に置き、xyzocc-web-spring.xml の component-scan で読ませる
- URL は /{baseSiteId}/... の慣習に沿い、利用者の資源は /users/{userId}/... の下
- @Secured で認可を決める。@Operation の operationId は拡張内で一意にする
- Controller は Facade を呼び、Data を WsDTO に写して返すだけ
- チェック: Swagger UI(/occ/v2/swagger-ui.html)に出る。Model を返していない

## 4. 既存の端点を変える(手法 C・D)
- @RequestMappingOverride は元と同じマッピングで書く。違うと上書きされず Ambiguous handler methods になる。競合するときは priorityProperty で優先順位を付ける
- Bean の差し替えは同じ名前の Bean を自分の拡張の Spring 設定で定義する
- チェック: 上書きした端点、差し替えた Bean、外した Populator を一覧にした

## 5. エラー
- 入力の誤りは WebserviceValidationException、業務の例外は自前の例外クラスにし、ステータスコードはプロパティで決める(既定は 400)
- 独自の JSON を組み立てない。標準の errors 配列の形で返す
- チェック: 400 / 401 / 403 / 404 の応答が標準の形

## 6. 確かめる
- ant clean all → ローカルで更新 → トークンを取って curl で叩く
- yocctests から xyzocctests を作り、Spock でテストを書く
- チェック: テストが通る。fields を変えて応答が変わる

## 7. 引き渡す
- 変えた端点と項目、fields のレベル、認可を一覧にし、cs-occ-liaison に OpenAPI の更新を伝える(ストアフロントの型、MSW モック、契約テストの更新のため)
- 新しいストアフロントのドメインがあるなら、本番 CORS(corsfilter.commercewebservices.*)の変更手順を運用手順に足す。本番で * にしない
