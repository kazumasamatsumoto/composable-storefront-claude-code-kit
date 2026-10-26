---
name: cs-type-and-impex
description: SAP Commerce で items.xml に型や属性を足し、ビルドと更新で DB に反映し、ImpEx でデータを入れる手順。「新しい項目を DB に持たせたい」「マスタデータを投入したい」と頼まれたときに使う。
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(ant *)
---

# 型の追加と ImpEx

## 1. items.xml に書く
- 自分の拡張の items.xml に書く。標準の拡張の items.xml は変えない
- 新しい型には deployment(専用のテーブル名と typecode)を付ける。付けないと GenericItem と同じテーブルに入る
- typecode は 0〜10000 が SAP の予約。案件の番号帯(例: 20000 番台)から重複しない番号を選ぶ
- 既存の型への属性追加は、その型を自分の items.xml で拡張して書く
- チェック: typecode が案件内で重複していない

## 2. ビルドと更新
- ant clean all でコンパイルし、Model クラスが生成されることを確かめる
- ローカルは ant updatesystem か HAC の Update で DB に反映する。初期化(initialize)は全テーブルを消すので、共有環境・本番では使わない
- 更新は列やテーブルを削除しない。消したい属性は手順を別に書き、人の判断に回す
- チェック: FlexibleSearch で新しい型がエラーにならない

## 3. ImpEx でデータを入れる
- 1 件を特定する列に unique=true を付けてから INSERT_UPDATE で書く。付けないと 2 回目に重複エラー
- 無いと動かないデータは resources/impex の essentialdata*.impex、サンプルや CMS は projectdata*.impex に置く
- 運用中の投入は履歴が残る経路(CronJob か Backoffice)を使う。HAC の ImpEx Import は開発用
- チェック: 同じ ImpEx を 2 回流しても件数が変わらない

## 4. 本番への反映
- 本番の更新は Cloud Portal のデプロイ時の設定で行う。手順と「どのデータを流すか」を書き、実行は人に依頼する
- チェック: 本番で initialize を選ぶ手順になっていない
