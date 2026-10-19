# Composable Storefront × Claude Code: エージェント・スキル・hooks のサンプル

SAP Commerce Cloud の Composable Storefront(Spartacus / Angular)案件で、Claude Code に仕事を分担させるためのサンプルリポジトリです。

**前提の構成**: SSR あり。フロントは Angular(Composable Storefront の標準構成)、バックエンドは SAP Commerce(Spring)の標準構成で、ストアフロントは OCC だけを呼びます。BFF や Next.js などの別フロントは置きません。エージェント・スキル・hooks はこの前提で書いてあり、前提を変える案は出さずに人に上げます。

- **エージェント(.claude/agents)12 人**: フロントエンド、設計、運用、SRE、監査、PdM、テスト、性能、更新、文言と CMS、OCC の契約、SAP Commerce 側のバックエンド
- **スキル(.claude/skills)17 本**: コンポーネントの差し替え、OCC の追加とモック、SSR の確認、CCv2 のリリース、障害の切り分け、監査、性能予算、バージョンアップ、ストーリー、ADR、E2E、リリースノート、SLO、レビュー観点、Commerce 側の OCC 拡張、型の追加と ImpEx
- **hooks(.claude/hooks と .claude/settings.json)4 本**: 危険なコマンドを止める、秘密と標準ソースへの書き込みを止める、編集後に案件のルールで検査する、会話の最初にリポジトリの種類を伝える。**bash 版(.sh)と PowerShell 版(.ps1)の 2 組**があり、中身は同じです
- **playground/**: 手を動かして試すための断片(ストアフロントの部品 1 つ、SAP Commerce の items.xml と ImpEx)。**ビルドはできません**
- **tests/**: hooks のテスト(66 件。bash 版と PowerShell 版で同じケース)と、定義ファイルの検査。GitHub Actions が Linux と Windows で毎回動かします

解説: https://learn-sap-commerce.vercel.app/learn/ai-driven-development/13-composable-storefront-agents-and-skills-kit

## 必要なもの

- [Claude Code](https://code.claude.com/docs/en/overview)
- macOS / Linux / Windows(Git Bash あり): `bash` と `jq`(bash 版の hooks が使います。macOS なら `brew install jq`)
- Windows(Git Bash なし): Windows に最初から入っている PowerShell 5.1 だけで動きます(PowerShell 版の hooks)。jq は要りません

## 構成

```text
.
├── CLAUDE.md                     … Claude が毎回読むルール(このリポジトリ用)
├── .claude/
│   ├── agents/                   … 12 人の定義(name、description、tools、skills と本文)
│   ├── skills/<名前>/SKILL.md    … 17 本の手順書
│   ├── hooks/                    … 4 本 × 2 組(*.sh は bash 版、*.ps1 は PowerShell 版)
│   ├── settings.json             … どのイベントでどの hook を動かすか(bash 版を呼ぶ)
│   └── settings.powershell.json  … 同じ内容で PowerShell 版を呼ぶ(Windows で使うときに settings.json と置き換える)
├── playground/
│   ├── storefront/               … 送料無料バッジの部品(出発点)、翻訳ファイル、ダミーの .env
│   └── core-customize/hybris/bin/
│       ├── custom/xyzcore/       … 自社の拡張(書いてよい)
│       └── modules/              … 標準の拡張の見本(書くと hook が止める)
├── tests/
│   ├── hooks/cases.json          … hooks のテストのケース(両方の版で共通)
│   ├── hooks/run.sh              … bash 版に JSON を与えて、止める・通すを確かめる
│   ├── hooks/run.ps1             … PowerShell 版を同じケースで確かめる
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
bash tests/hooks/run.sh        # 合計: ok 66 / NG 0 と出る
claude                         # リポジトリの直下で起動する
```

Windows で Git Bash が無い場合は、PowerShell で次のようにします。

```powershell
git clone <このリポジトリの URL>
cd composable-storefront-claude-code-kit
Copy-Item .claude\settings.powershell.json .claude\settings.json   # hooks を PowerShell 版に切り替える
powershell -NoProfile -ExecutionPolicy Bypass -File tests\hooks\run.ps1   # 合計: ok 66 / NG 0 と出る
claude
```

切り替えは「足す」のではなく「置き換える」です。両方を登録すると、Git Bash の無い Windows では bash 版が動かず、公式ドキュメントによると、失敗した PreToolUse の hook がツールの呼び出しを止めることがあります。

起動したら、入っているものを確かめます。

| 打つもの | 見えるもの |
|---|---|
| `/agents` | 12 人のエージェント |
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

練習で変わったファイルは、終わったらあなたが `git restore playground` で元に戻します。

## 自分の案件に入れる

1. この `.claude/` をストアフロントのリポジトリの直下にコピーします。cs-backend と、その 2 本のスキル(`cs-occ-extension`、`cs-type-and-impex`)、hooks は、core-customize のリポジトリにも置きます。
2. すでに `.claude/settings.json` がある場合は、上書きせずに `hooks` の部分だけを足します。
3. `CLAUDE.md` のルールとコマンドを、案件の実際の名前(`yarn` か `npm` か、E2E の道具など)に直します。
4. 各スキルの数値(性能予算、SLO、リリースの環境名と切り戻しの基準)を案件の値に置き換えます。
5. Claude Code を起動し直します。`.claude/agents` などのフォルダが無い状態で始めたセッションには、新しいフォルダが読み込まれないためです。
6. hooks を変えたら `tests/hooks/cases.json` にケースを足し、`bash tests/hooks/run.sh` と `run.ps1` の両方で確かめます。.sh と .ps1 は同じ規則に保ちます。
7. Windows の開発者がいるなら、どちらの版を使うかを決めます。Git Bash があれば bash 版のままで動きます(Windows の `C:\a\b` 形式のパスにも対応済み)。Git Bash が無ければ `settings.powershell.json` を `settings.json` にします。

最初から全部入れる必要はありません。まず `cs-frontend` と 2 本のスキル(`cs-component-customization`、`cs-occ-endpoint-and-mock`)と hooks だけ入れて、呼ばれ方を確かめてから増やすのがおすすめです。

## 注意

- hooks は、あなたのマシンでシェルスクリプトとして動きます。入れる前に `.claude/hooks/` の中身を読んでください。
- PowerShell 版は `powershell.exe -NoProfile -ExecutionPolicy Bypass -File` で起動します(公式の例と同じ形)。実行ポリシーの変更はこのプロセスだけで、マシンの設定は変えません。.ps1 は BOM 付き UTF-8 で保存してあります。BOM を消すと Windows PowerShell 5.1 が日本語を読み違えます。
- Claude Code には Bash ツールとは別に PowerShell ツールがあります。命令を見る hook は、両方の版とも matcher を `Bash|PowerShell` にして、`Remove-Item -Recurse -Force` や `irm ... | iex` も止めます。
- hooks は「よくある事故」を止める網で、すべてを防ぐものではありません。本番の操作は人がやる前提です。
- 書かれている SAP Commerce と Composable Storefront の前提(CORS、manifest、OCC 拡張の作り方など)は、解説サイトの出典に基づきます。版が変わったら見直してください。
