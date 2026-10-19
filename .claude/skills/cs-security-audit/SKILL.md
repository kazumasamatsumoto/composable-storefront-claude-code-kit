---
name: cs-security-audit
description: Composable Storefront のセキュリティ設定と実装を監査する手順。CORS、CSP、認証トークンの扱い、XSS、依存パッケージの脆弱性、秘密情報の混入を調べるときに使う。
allowed-tools: Read, Grep, Glob, Bash(npm audit *), Bash(yarn audit *), Bash(git log *)
---

# セキュリティ監査

## 1. 通信と認証
- [ ] 認可サーバーは JWT。Authorization Code + PKCE を使い、トークンを URL に載せていない
- [ ] CORS の許可は OCC 側で設定し、本番に `*` が無い(公式: 本番で `*` は不可)
- [ ] 認証トークンや個人情報を localStorage に長期保存していない。保存するなら理由と期限がある
- [ ] HTTP(平文)への通信が無い

## 2. 出力とスクリプト
- [ ] `innerHTML` や `bypassSecurityTrust*` の使用箇所を Grep し、各箇所に理由と入力の信頼性の説明がある
- [ ] CMS から来る HTML(リッチテキスト)の挿入箇所でサニタイズが効いている
- [ ] CSP が設定され、`unsafe-inline` / `unsafe-eval` が無い、または理由が記録されている
- [ ] 外部スクリプト(タグマネージャ、計測)の読み込み元が一覧化されている

## 3. 秘密情報
- [ ] リポジトリに API キー、パスワード、証明書の秘密鍵が無い(`git log` の履歴も含めて Grep)
- [ ] 環境ごとの設定は環境変数か Cloud Portal の設定で注入している

## 4. 依存パッケージ
- `npm audit` / `yarn audit` を実行し、高以上を一覧化。修正版の有無と影響を書く
- ライセンスの一覧を出し、禁止ライセンスが無いか確認

## 5. 報告
- 重要度 / 場所 / 根拠(公式の記述か、一般的な基準か) / 直し方。未確認は未確認と書く
