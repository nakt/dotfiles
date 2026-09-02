# Decision Records (ADR)

このディレクトリは設計・ロジック判断の決定記録を管理します。
技術選定だけでなく、処理フロー・アルゴリズム・データモデル・API 設計、検証や実験から得た方針の「決定とその理由」を記録します。

## 一覧

| No. | タイトル | Status | サマリ |
|-----|---------|--------|--------|
| [0001](./0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 決定記録を運用する |

## 運用

- append-only。本文は既存の記述を書き換えず、末尾への追記は `## Deprecation` に限る。フロントマターは状態を表す機械可読値なので append-only の対象外
- 決定が無効になったときは後継方針の有無で分ける。代わりの方針があるなら新規 ADR を起票して旧 ADR を `Superseded`、代替がない (対象機能の廃止、前提の消滅) なら旧 ADR を `Deprecated` にする
- `Superseded` にする場合は、旧 ADR のフロントマター `status` を `Superseded` に変更し、`superseded_by` に新 ADR 番号を設定する
- `Deprecated` にする場合は、旧 ADR のフロントマター `status` を `Deprecated` に変更し、`deprecated_date` にやめた日付を設定し、本文末尾に `## Deprecation` を追記する
- `## Deprecation` は見出し直下に 1 段落でやめた理由を書き、後継方針がないことを明記する。日付は本文に書かず `deprecated_date` のみで表す
- status の遷移は `Accepted` からの一方向のみで、`Superseded` / `Deprecated` からの逆行と横移動はしない。Deprecated 化の後に後継方針が出てきた場合は新規 ADR を起票し、旧 ADR は `Deprecated` のまま残す
- 起票は record-adr スキルが行う。重要な設計・ロジック判断が下された場面では自動で起票が提案され、明示したいときは `/record-adr [タイトル]` で呼び出す
- 検証・実験の一時ファイルは `.workspace/` (使い捨て)、確定した決定と根拠はここ
