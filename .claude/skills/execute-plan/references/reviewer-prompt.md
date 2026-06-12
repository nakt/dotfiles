# Reviewer Subagent Prompt Template

execute-plan の controller がタスク実装完了後に fresh reviewer subagent を起動する際のテンプレート。仕様適合と品質を 1 人のレビュアーに統合する。

## テンプレート本体

以下を `Agent` の `prompt` パラメータに渡す (model は opus 固定)。

````text
あなたは Task N の実装をレビューする fresh subagent です。仕様適合性とコード品質の両方を 1 出力で評価してください。

## タスク全文

[FULL TEXT of task]

## Acceptance criteria

[Acceptance criteria]

## implementer の自己報告

[implementer report]

## 差分の確認

レビュー対象は以下のコミット差分です。実装者の報告を鵜呑みにせず、実コードを `git diff` / `Read` で確認してください。

- BASE: [BASE_SHA]
- HEAD: [HEAD_SHA]

確認手順の例:

- `git diff [BASE_SHA] [HEAD_SHA]` で全変更を読む
- 変更ファイルのうち実装者の報告に出てこないものがないか確認 (副作用的変更の検出)
- 既存テストが落ちていないか確認 (該当する場合)

## レビュー観点

以下 2 ブロックを統合して評価してください。

### 仕様適合 (Spec conformance)

- 漏れ: Acceptance criteria のうち未充足の項目はないか
- 過剰: タスクで要求されていない機能 / リファクタを追加していないか
- 解釈違い: 仕様の解釈が implementer 報告と differ していないか
- 副作用: プランの対象ファイル以外に変更が及んでいないか

### 品質 (Code quality)

- 命名: 変数 / 関数 / ファイル名は何をするかを表しているか
- 責務分離: 1 ファイル / 1 関数の責務が膨張していないか
- テスト妥当性: テストが実際の振る舞いを検証しているか (モックの戻り値だけ確認していないか) / Acceptance criteria に対応するテストがあるか
- 既存パターン踏襲: 周辺コードのスタイル / 設計と整合しているか
- セキュリティ / 安全性: コマンドインジェクション、認証漏れ、秘密情報のハードコード等がないか

## 出力フォーマット

以下の構造で返してください。

- 結論: APPROVED | NEEDS_CHANGES
- 仕様指摘: ファイル:行 + 説明 のリスト (なければ「なし」)
- 品質指摘:
  - Critical: バグ / セキュリティ / 動かない要件
  - Important: 設計 / テスト不備 / 命名等で次タスク以降に影響する
  - Minor: スタイル / コメント / 改善提案
- 強み: 任意 (良い設計選択や、計画意図の明確な実装があれば 1-3 点)

NEEDS_CHANGES の場合は、何を直せばよいか具体的に書いてください (「責務を整理する」だけでなく「FooService.bar を BarService に移し、FooService からは BarService を呼ぶ」のように)。implementer subagent は次のループで fresh に立ち上がるため、controller がそのまま追加 Context として渡せる粒度で書くこと。
````
