# Decision Records (ADR)

このディレクトリは設計・ロジック判断の決定記録を管理します。技術選定だけでなく、処理フロー・アルゴリズム・データモデル・API 設計、検証や実験から得た方針の「決定とその理由」を記録します。

## 一覧

| No. | タイトル | Status | サマリ |
|-----|---------|--------|--------|
| [0001](./0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 決定記録を運用する |

## 運用

- append-only。一度書いた本文は書き換えない
- 方針変更時は新規 ADR を起票し、旧 ADR のフロントマター `status` を `Superseded`、`superseded_by` に新 ADR 番号を設定する
- 起票は `/record-adr [タイトル]` で行う
- 実験の生ログは `.workspace/knowledge/`、確定した決定と根拠はここ
