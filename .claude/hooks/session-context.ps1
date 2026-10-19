# SessionStart: 会話の最初に、今いるリポジトリの種類と現在のブランチを Claude に伝える(標準出力が文脈に入る)。session-context.sh の PowerShell 版。
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = $env:CLAUDE_PROJECT_DIR; if (-not $root) { $root = '.' }
try { Set-Location -LiteralPath $root } catch { exit 0 }
$branch = '不明'
try { $b = git rev-parse --abbrev-ref HEAD 2>$null; if ($LASTEXITCODE -eq 0 -and $b) { $branch = $b } } catch { }
$kind = '不明'
if (Test-Path angular.json) { $kind = 'ストアフロント(Composable Storefront / Angular)。担当は cs-frontend ほか' }
$manifest = $false
foreach ($m in 'manifest.json', 'core-customize/manifest.json') {
  if ((Test-Path $m) -and (Select-String -Path $m -Pattern 'commerceSuiteVersion' -Quiet)) { $manifest = $true }
}
if ((Test-Path core-customize) -or (Test-Path hybris) -or $manifest) { $kind = 'SAP Commerce(core-customize)。担当は cs-backend' }
[Console]::Out.WriteLine("リポジトリの種類: $kind")
[Console]::Out.WriteLine("現在のブランチ: $branch")
[Console]::Out.WriteLine('この案件の前提: SSR あり。フロントは Angular(Composable Storefront)、バックエンドは SAP Commerce(Spring)の標準構成。BFF や別フロントは置かない。')
[Console]::Out.WriteLine('このプロジェクトの hooks: 危険なコマンド(ant initialize、rm -rf、Remove-Item -Recurse -Force、git push --force など)と、秘密・標準ソース・dist への書き込みは hook で止まる。止まったら手順を書いて人に依頼する。')
exit 0
