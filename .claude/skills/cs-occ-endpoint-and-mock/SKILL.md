---
name: cs-occ-endpoint-and-mock
description: Composable Storefront に新しい OCC 呼び出しを追加し、同時に MSW のモックを用意する手順。「この API を画面で使いたい」「バックエンド無しで画面を作りたい」と頼まれたときに使う。
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(npx ng test *), Bash(yarn test *)
---

# OCC 端点の追加と MSW モック

## 1. 端点を確かめる
- OCC の URL の形は `https://<host>/occ/v2/<baseSiteId>/...`。まず実 OCC か API 定義で応答の形を確認する
- 必要な項目だけを `fields` に列挙する。`FULL` にしない
- 認証が要るか(匿名で取れるか、ログイン後だけか)を確認する

## 2. 設定に端点を足す
- `backend.occ.endpoints` の設定に、名前付きで URL のパターンを追加する(例: `myEndpoint: 'users/$' + '{userId}/my-resource'`)
- チェック: 既存の端点名と衝突していない

## 3. Adapter → Connector → Facade
- Adapter: `OccEndpointsService` で URL を組み、HTTP を呼ぶ。応答を Normalizer で画面用の型に変換する
- Connector: Adapter を束ねる薄い層
- Facade: Query(読む)/ Command(書く)で公開し、コンポーネントはここだけを見る
- チェック: コンポーネントに `HttpClient` が無い

## 4. MSW モックを同時に作る
- 実 OCC の応答を 1 件保存し、そのままモックデータにする(都合のよい形に直さない)
- ハンドラは URL のパターンと `fields` を無視せず、代表的な正常系と 1 つの異常系(404 か 400)を返す
- チェック: モックで画面が動く。実 OCC に切り替えても同じ画面になる

## 5. 契約テスト
- 応答の形(必須項目と型)を検証するテストを 1 件書く。OCC 側が変わったら最初に落ちる
