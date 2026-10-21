# Composable Storefront × Claude Code: エージェント・スキル・hooks のサンプル

SAP Commerce Cloud の Composable Storefront(Spartacus / Angular)案件で、Claude Code に仕事を分担させるためのサンプルリポジトリです。

**前提の構成**: SSR あり。フロントは Angular(Composable Storefront の標準構成)、バックエンドは SAP Commerce(Spring)の標準構成で、ストアフロントは OCC だけを呼びます。BFF や Next.js などの別フロントは置きません。エージェント・スキル・hooks はこの前提で書いてあり、前提を変える案は出さずに人に上げます。

- **エージェント(.claude/agents)13 人**: フロントエンド、設計、運用、SRE、監査、PdM、テスト、性能、更新、文言と CMS、OCC の契約、SAP Commerce 側のバックエンド、ドキュメント
- **スキル(.claude/skills)20 本**: コンポーネントの差し替え、OCC の追加とモック、SSR の確認、CCv2 のリリース、障害の切り分け、監査、性能予算、バージョンアップ、ストーリー、ADR、E2E、リリースノート、SLO、レビュー観点、Commerce 側の OCC 拡張、型の追加と ImpEx、文書の書き方(型 5 種)、PowerPoint と Excel の文字起こし、コストの集計
- **コストの集計(cs-cost)**: 依頼を 1 件終えるたびに、本会話と担当(サブエージェント)が使ったトークン数と、API 料金に換算した金額を表にして報告に付け、`docs/cost-log.csv` に 1 行足します。CLAUDE.md と、Bash を持つ 10 人の担当の定義に「終わるときに実行する」と書いてあります
- **hooks(.claude/hooks と .claude/settings.json)4 本**: 危険なコマンドを止める、秘密と標準ソースへの書き込みを止める、編集後に案件のルールで検査する、会話の最初にリポジトリの種類を伝える。**bash 版(.sh)と PowerShell 版(.ps1)の 2 組**があり、中身は同じです
- **権限ルール(.claude/settings.json の permissions)**: 禁止(deny)、毎回確認(ask)、聞かずに許す(allow)の 3 つのリスト。hooks と違い Claude Code 自身が止めます。秘密のファイルを読むこと、標準ソースと node_modules・dist への書き込み、`ant initialize`、パッケージの公開を禁止し、`git push` / `git reset` / `git clean` と外へのダウンロードは毎回聞きます。git の閲覧、npm の build・test・lint、コストの集計スクリプトは聞かずに許します
- **GitHub Copilot 用(.github)**: 同じ 13 人を Copilot のカスタムエージェント(`.github/agents/*.agent.md`)に、CLAUDE.md を `.github/copilot-instructions.md` にしたもの。`tools/make-copilot.py` が .claude から作るので、直すのは .claude 側だけ。スキルは Copilot が `.claude/skills` をそのまま読む。hooks は `.github/hooks/cs-hooks.json` から同じ `.claude/hooks` のスクリプトを呼ぶ
- **playground/**: 手を動かして試すための断片(ストアフロントの部品 1 つ、SAP Commerce の items.xml と ImpEx)。**ビルドはできません**
- **tests/**: hooks のテスト(71 件。bash 版と PowerShell 版で同じケース)と、定義ファイルの検査。GitHub Actions が Linux と Windows で毎回動かします

解説: https://learn-sap-commerce.vercel.app/learn/ai-driven-development/13-composable-storefront-agents-and-skills-kit

## 必要なもの

- [Claude Code](https://code.claude.com/docs/en/overview)
- macOS / Linux / Windows(Git Bash あり): `bash` と `jq`(bash 版の hooks が使います。macOS なら `brew install jq`)
- Windows(Git Bash なし): Windows に最初から入っている PowerShell 5.1 だけで動きます(PowerShell 版の hooks)。jq は要りません
- コストの集計(cs-cost): `node`(標準ライブラリだけ。Angular の開発に使うものでよい)
- PowerPoint / Excel の文字起こし(cs-office-transcribe): `python3`(標準ライブラリだけ)。Python の無い Windows では PowerShell 版が同じ出力を出します

## 構成

```text
.
├── CLAUDE.md                     … Claude が毎回読むルール(このリポジトリ用)
├── .claude/
│   ├── agents/                   … 13 人の定義(name、description、tools、skills と本文)
│   ├── skills/<名前>/SKILL.md    … 20 本の手順書(cs-doc-writing は templates/、cs-office-transcribe と cs-cost は scripts/ も持つ)
│   ├── hooks/                    … 4 本 × 2 組(*.sh は bash 版、*.ps1 は PowerShell 版)
│   ├── settings.json             … 権限ルール(permissions)と、どのイベントでどの hook を動かすか(bash 版を呼ぶ)
│   └── settings.powershell.json  … 同じ権限ルールで、hooks は PowerShell 版を呼ぶ(Windows で使うときに settings.json と置き換える)
├── .github/
│   ├── agents/*.agent.md         … Copilot のカスタムエージェント 13 人(tools/make-copilot.py が .claude/agents から作る)
│   ├── copilot-instructions.md   … Copilot への指示(同じく CLAUDE.md から作る)
│   └── hooks/                    … cs-hooks.json と、.claude/hooks を呼ぶ橋渡し(copilot-adapter.sh / .ps1)
├── tools/make-copilot.py         … Copilot 用のファイルを作る(--check で古くないかを確かめる)
├── playground/
│   ├── storefront/               … 送料無料バッジの部品(出発点)、翻訳ファイル、ダミーの .env
│   └── core-customize/hybris/bin/
│       ├── custom/xyzcore/       … 自社の拡張(書いてよい)
│       └── modules/              … 標準の拡張の見本(書くと hook が止める)
├── tests/
│   ├── hooks/cases.json          … hooks のテストのケース(両方の版で共通)
│   ├── hooks/run.sh              … bash 版に JSON を与えて、止める・通すを確かめる
│   ├── hooks/run.ps1             … PowerShell 版を同じケースで確かめる
│   ├── transcribe/               … 文字起こしのテスト(見本の .pptx / .xlsx と、期待する Markdown)
│   ├── copilot/run.sh / run.ps1  … Copilot の橋渡しに hooks のケースを全部通す
│   ├── cost/run.sh               … コストの集計に作り物の会話記録を読ませ、数と金額を確かめる
│   └── validate-kit.sh           … name と description、skills の参照先、hooks の実行権限を確かめる
└── docs/
    ├── how-it-is-invoked.md      … エージェント・スキル・hooks はいつ、どう動くか
    └── walkthrough.md            … 課題 1 件を、プランモードからオートモードで進める操作手順
```

## 5 分で試す

```bash
git clone <このリポジトリの URL>
cd composable-storefront-claude-code-kit
bash tests/validate-kit.sh     # すべて OK と出る
bash tests/hooks/run.sh        # 合計: ok 71 / NG 0 と出る
claude                         # リポジトリの直下で起動する
```

Windows で Git Bash が無い場合は、PowerShell で次のようにします。

```powershell
git clone <このリポジトリの URL>
cd composable-storefront-claude-code-kit
Copy-Item .claude\settings.powershell.json .claude\settings.json   # hooks を PowerShell 版に切り替える
powershell -NoProfile -ExecutionPolicy Bypass -File tests\hooks\run.ps1   # 合計: ok 71 / NG 0 と出る
claude
```

切り替えは「足す」のではなく「置き換える」です。両方を登録すると、Git Bash の無い Windows では bash 版が動かず、公式ドキュメントによると、失敗した PreToolUse の hook がツールの呼び出しを止めることがあります。

起動したら、入っているものを確かめます。

| 打つもの | 見えるもの |
|---|---|
| `/agents` | 13 人のエージェント |
| `/hooks` | 4 本の hooks と、どの設定ファイルから来たか(読み取り専用) |
| `/` | スキルの一覧(`cs-review-checklist` は参照用なので出ません) |

## 練習

上から順にやると、エージェント・スキル・hooks の動き方が一通り分かります。

### 練習 1. hooks が止めるのを見る

```text
rm -rf playground/core-customize を実行して
```

```text
playground/storefront/.env の中身を見せて
```

どちらも hook が止め、理由が Claude に伝わります。Claude は「人に依頼する」形で返します。

### 練習 2. 編集した直後の検査を見る

```text
playground/storefront/src/app/free-shipping/free-shipping-badge.component.ts を、
HttpClient で https://api.example.com/occ/v2/electronics/products/1?fields=FULL から直接取る形に書き換えて
```

書いた直後に `check-after-edit.sh` が「HttpClient」「OCC の URL の直書き」「fields=FULL」を見つけ、Claude に直させます。

SSR の検査も試せます。

```text
playground/storefront/src/app/free-shipping/ に、最後に見た商品コードを localStorage に直接保存するサービスを作って
```

`localStorage` や `window` を直接触ると、サーバー(Node)で描くときに落ちるため、hook が「WindowRef か isPlatformBrowser で分ける」と差し戻します。

### 練習 3. スキルを自分で開く

```text
/cs-component-customization 送料無料バッジを商品詳細の価格の下に Outlet で出したい。計画だけ示して、ファイルは変えないで
```

メッセージの**先頭**に `/名前` を書くと、その手順書が必ず開きます。後ろの文は引数として渡ります。

### 練習 4. エージェントに頼む

```text
@agent-cs-auditor playground/storefront を cs-review-checklist の観点で監査し、重要度・場所・根拠・直し方の形で報告して。コードは変えないで
```

`@agent-名前` で頼むと、必ずそのエージェントが動きます。エージェントは本会話の履歴を持たない別の部屋で作業し、報告だけを返します。

### 練習 5. 課題 1 件を、プランモードからオートモードで進める

[docs/walkthrough.md](docs/walkthrough.md) の手順で進めます。`Shift+Tab` で `⏸ plan mode on` にし、課題と「担当の割り当てを計画に書いて」を渡し、計画を読んで直し、`Yes, and use auto mode` で承認します。

### 練習 6. バックエンドの担当で起動する

```bash
claude --agent cs-backend
```

```text
playground/core-customize の xyzcore-items.xml の XyzShippingRule に、送料無料の下限金額 minOrderValue(java.lang.Double)を足して。
ImpEx の出発点にも列を足して。ant は実行しないで
```

会話全体が cs-backend の定義(守ること、事前に読む 2 本のスキル)で動きます。わざと「typecode を 5000 に変えて」と頼むと、編集後の検査が止めます。

### 練習 7. Excel と PowerPoint の資料を文字起こしして、引き継ぎ資料にまとめる

見本の資料は `tests/transcribe/fixtures/` にあります(OCC API 一覧の Excel と、送料無料バッジの要件の PowerPoint)。

```text
cs-docs で、tests/transcribe/fixtures/sample.xlsx と sample.pptx を文字起こしして、
送料無料バッジの引き継ぎ資料を docs/handover/free-shipping.md に書いて
```

cs-docs が cs-office-transcribe で `docs/transcripts/` に Markdown を書き出し、cs-doc-writing の引き継ぎ資料の型でまとめます。できた文書で、次を確かめてください。

- 事実の文に(ソース)(推論)(未確認)などの印がある
- 資料から取った文に「(シート API一覧、D8)」「(スライド 2)」のような元の場所がある
- 非表示のスライドとシートを「使わない」「非表示」と区別している
- 最後に「会議で言える 3 文」がある

文字起こしだけを見たいときは、Claude を使わずに `python3 .claude/skills/cs-office-transcribe/scripts/transcribe.py tests/transcribe/fixtures/sample.xlsx` を打ちます。

練習で変わったファイルは、終わったらあなたが `git restore playground` で元に戻します。
練習 7 で作った `docs/` も、要らなければ消します。

## 自分の案件に入れる

1. この `.claude/` をストアフロントのリポジトリの直下にコピーします。cs-backend と、その 2 本のスキル(`cs-occ-extension`、`cs-type-and-impex`)、hooks は、core-customize のリポジトリにも置きます。
2. すでに `.claude/settings.json` がある場合は、上書きせずに `permissions` と `hooks` の部分を足します。`permissions` の `deny` / `ask` / `allow` は、今あるリストに項目を足します。
3. `CLAUDE.md` のルールとコマンドを、案件の実際の名前(`yarn` か `npm` か、E2E の道具など)に直します。
4. 各スキルの数値(性能予算、SLO、リリースの環境名と切り戻しの基準)を案件の値に置き換えます。
5. Claude Code を起動し直します。`.claude/agents` などのフォルダが無い状態で始めたセッションには、新しいフォルダが読み込まれないためです。
6. hooks を変えたら `tests/hooks/cases.json` にケースを足し、`bash tests/hooks/run.sh` と `run.ps1` の両方で確かめます。.sh と .ps1 は同じ規則に保ちます。
7. Windows の開発者がいるなら、どちらの版を使うかを決めます。Git Bash があれば bash 版のままで動きます(Windows の `C:\a\b` 形式のパスにも対応済み)。Git Bash が無ければ `settings.powershell.json` を `settings.json` にします。

### 権限ルールについて

- **効く順番**: deny → ask → allow の順に見て、最初に当たったもので決まります。allow で deny に穴は開けられません。設定ファイルが違っても同じで、どこかの deny に当たれば止まります(公式 Permissions)。
- **allow が効く時期**: allow は、そのフォルダを「信頼する」と答えるまで効きません。deny と ask は、狭めるだけなので最初から効きます(公式 Permissions)。
- **Read の deny の範囲**: 同じパスへの Edit と Write も止めます(公式 Permissions)。
- **限界**: 権限ルールもコマンドの文字列を見ているので、書き方を変えると一致しません。公式も「セキュリティの境界ではない」と書いています。守りの本体はサンドボックスです。
- **サンドボックスの入れ方**: リポジトリの設定ではなく、各自のユーザー設定(`~/.claude/settings.json`)に人が入れます。Mac・Linux・WSL2 で使えますが、Windows ネイティブでは使えません。
- **解説**: https://learn-sap-commerce.vercel.app/learn/ai-driven-development/14-permission-rules-and-sandbox
- **未確認**: Mac で Claude Code が PowerShell の道具を持たない場合に、`PowerShell(...)` のルールに起動時の警告が出るかどうかは確かめていません。警告が出ても、ルールが効かなくなるだけで害はありません(推論)。

### コストの集計について

- **数え方**: Claude Code が手元に残す会話の記録(`~/.claude/projects/` の下)を読み、応答ごとの使用量を足します。記録は読むだけで、書き換えません。担当の分も含みます。
- **今回の依頼の行**: `docs/cost-log.csv` の同じ会話の前回の行との差です。見積もりの実績にはこの行を使います。
- **金額**: `.claude/skills/cs-cost/rates.json` の単価(公式の料金表を 2026-10-20 に写したもの)で API 料金に換算しています。定額プランではこの金額は請求されませんが、使った量の目安になります。料金が変わったら rates.json を直します。
- **聞かれずに動く理由**: permissions の allow に、このスクリプトを起動するコマンドを 1 本だけ足してあります。
- **Bash を持たない担当**: cs-architect、cs-content-i18n、cs-pdm は自分では数えられないので、本会話が報告を受け取ったあとに数えます。

最初から全部入れる必要はありません。まず `cs-frontend` と 2 本のスキル(`cs-component-customization`、`cs-occ-endpoint-and-mock`)と hooks だけ入れて、呼ばれ方を確かめてから増やすのがおすすめです。

## GitHub Copilot で使う

このリポジトリには、同じ担当・手順書・hooks を GitHub Copilot で使うためのファイルも入っています(Copilot CLI、Copilot app、クラウドエージェント、VS Code のエージェントモード)。

| Claude Code | GitHub Copilot | どう作っているか |
|---|---|---|
| `.claude/agents/*.md`(13 人) | `.github/agents/*.agent.md` | `python3 tools/make-copilot.py` で作る。`skills:` の代わりに、本文の先頭に「最初に読む手順書」を書く |
| `CLAUDE.md` | `.github/copilot-instructions.md` | 同じスクリプトで作る。cs-cost の行は「報告に書くこと」に置き換える |
| `.claude/skills/` | そのまま | Copilot は `.claude/skills` を読む(公式 About agent skills) |
| `.claude/settings.json` の hooks | `.github/hooks/cs-hooks.json` | イベント名を `PreToolUse` などで書くと、Copilot は Claude Code と同じ形の入力を渡す(公式 hooks reference)。返し方だけを `copilot-adapter.sh` / `.ps1` で直す |
| `.claude/settings.json` の permissions | なし | Copilot には同じ形の設定ファイルが無い。止める本体は hooks。組織では企業管理設定(managed-settings.json)の permissions を使う |
| cs-cost | なし | Copilot の使用量は、組織の使用状況メトリクスと AI クレジットの請求で見る |

- **直す場所は .claude 側だけ**です。直したら `python3 tools/make-copilot.py` を動かし、できたファイルもコミットします。古いままだと `bash tests/validate-kit.sh` が NG を出します。
- **Copilot の hooks の違い**:
  - 道具を使う前の hook が時間切れになると、Copilot は止めずに通します(公式)。既定の 30 秒に収まるようにしてあります。
  - クラウドエージェントでは Linux の中で bash 版だけが動き、`jq` が要ります。入っているかは確かめていません(未確認)。
- **Copilot CLI は `.claude/settings.json` の hooks も読みます**(公式)。そのため CLI では同じ検査が 2 回動きますが、どちらも同じ規則なので結果は変わりません。CLAUDE_PROJECT_DIR が無くても動くように、`.claude/settings.json` のパスは `${CLAUDE_PROJECT_DIR:-.}` にしてあります。
- **Copilot がファイルの場所を渡す項目の名前**は確かめていません(未確認)。橋渡しは `file_path` が無ければ `path` を使います。
- 確かめ方: `bash tests/copilot/run.sh`(PowerShell 版は `tests\copilot\run.ps1`)。hooks のケース 71 件を Copilot の形に直して通します。

## 注意

- hooks は、あなたのマシンでシェルスクリプトとして動きます。入れる前に `.claude/hooks/` の中身を読んでください。
- PowerShell 版は `powershell.exe -NoProfile -ExecutionPolicy Bypass -File` で起動します(公式の例と同じ形)。実行ポリシーの変更はこのプロセスだけで、マシンの設定は変えません。.ps1 は BOM 付き UTF-8 で保存してあります。BOM を消すと Windows PowerShell 5.1 が日本語を読み違えます。
- Claude Code には Bash ツールとは別に PowerShell ツールがあります。命令を見る hook は、両方の版とも matcher を `Bash|PowerShell` にして、`Remove-Item -Recurse -Force` や `irm ... | iex` も止めます。
- hooks は「よくある事故」を止める網で、すべてを防ぐものではありません。本番の操作は人がやる前提です。
- 書かれている SAP Commerce と Composable Storefront の前提(CORS、manifest、OCC 拡張の作り方など)は、解説サイトの出典に基づきます。版が変わったら見直してください。
