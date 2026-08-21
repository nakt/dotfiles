---
status: Accepted
date: YYYY-MM-DD
supersedes: ""
superseded_by: ""
deprecated_date: ""
---

# 0001: Record architecture decisions

## Context

検証・実験が多い開発スタイルで、「なぜこのロジック・処理フローにしたか」を後から参照できる場所がなかった。docs/arch は現状の記述、.workspace は揮発する作業メモであり、確定した決定とその根拠を残す層が欠けていた。

## Decision

技術選定に限らず、処理フロー変更・アルゴリズム選択・データモデル・API 設計、検証や実験から得た方針も含めて、決定とその理由を docs/adr に記録する。

## Rationale

決定の経緯と却下案を残すことで、同じ検討の蒸し返しを防ぎ、数ヶ月後の自分が判断の前提を辿れるようにする。実験ベースの開発では「なぜ」が最も失われやすい。

## Consequences

- ADR は append-only とし、本文は既存の記述を書き換えず、末尾への追記は Deprecation 節に限る。フロントマターは状態を表す機械可読値なので対象外とする
- 方針変更時は新規 ADR を起票し、旧 ADR の status を Superseded に変更して superseded_by を更新する
- 後継方針を持たない無効化では旧 ADR の status を Deprecated に変更し、deprecated_date を設定して、やめた理由を Deprecation 節に残す
- Accepted な ADR の集合が現在有効な方針であり、Superseded / Deprecated は履歴として残る
