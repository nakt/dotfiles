---
name: gpt5-prompting
description: >-
  GPT-5/GPT-5.1/GPT-5.2 向けプロンプト設計の支援スキル。
  references/guide.md をリファレンスとして参照し、レビュー・ドラフティング・アドバイスを行う。
  GPT-5系モデル向けプロンプトの新規作成、既存プロンプトの最適化・移行、
  reasoning_effort や verbosity パラメータの設定検討、
  エージェント的ワークフローの積極性調整、
  プロンプトが期待通りに動かない場合の原因特定に使用する。
---

回答時に references/guide.md のどの原則に基づくかを章タイトルで引用する（例: guide.md「指示遵守の注意点」）。

## モード判定

リクエスト内容に応じて柔軟に判断する。境界ケースや複合リクエストは適宜組み合わせる。

- **Review**: 既存プロンプトを提示された場合
- **Draft**: 新規プロンプト作成の依頼
- **Advise**: パラメータや手法についての質問

## Review

既存プロンプトの評価と改善提案を行う。

出力形式:

1. 評価サマリー
2. チェック項目ごとの判定（OK / 要改善 / 該当なし）- Review Checklist を使用
3. 改善提案（具体的な修正案 + guide.md の該当原則を引用）
4. 改善後のプロンプト全文

## Draft

新規プロンプトを設計・作成する。

出力形式:

1. 設計判断の説明（guide.md の原則に基づく根拠）
2. プロンプト全文
3. 推奨パラメータ設定（reasoning_effort, verbosity）

## Advise

パラメータや手法についての質問に回答する。

出力形式:

1. 質問への回答（guide.md の該当セクションを章タイトルで引用）

## Review Checklist

| チェック項目 | 参照 | 確認内容 |
|---|---|---|
| 矛盾した指示の有無 | guide.md「指示遵守の注意点」 | 相反する指示が含まれていないか |
| 成功基準の明示 | guide.md「まとめ」 | DoDが明確に定義されているか |
| 出力フォーマット指定 | guide.md「まとめ」 | 出力形式が曖昧でないか |
| 積極性制御 | guide.md「エージェント積極性の制御」 | タスクに適した探索深度が設定されているか |
| reasoning_effort | guide.md「reasoning_effort パラメータ」 | タスク複雑度に見合った設定か |
| verbosity | guide.md「verbosity パラメータ」 | 出力の冗長性が適切か |
| ツール呼び出し前説明 | guide.md「Tool Preamble」 | UX向けプリアンブルが考慮されているか |
| 自己検証指示 | guide.md「minimal reasoning モード」 | 反省・検証ステップが含まれているか |
| Markdown指示 | guide.md「Markdownフォーマット」 | フォーマット要件が明示されているか |
| 永続性指示 | guide.md「エージェント積極性の制御」 | 長時間タスクでの継続性が確保されているか |
| メタプロンプティング | guide.md「メタプロンプティング」 | GPT-5自身にプロンプト改善を問う手法が活用できるか |

## Quick Reference

### reasoning_effort

| minimal | low | medium | high |
|---|---|---|---|
| 低レイテンシ優先 | 簡単なタスク | デフォルト | 複雑なマルチステップ |

### 積極性制御

- **下げる**: `reasoning_effort` を低く設定、探索の停止条件を明示、ツール呼び出し回数の上限設定
- **上げる**: `reasoning_effort` を `high` に設定、永続性指示を追加

### プロンプト構成の骨格

```text
成功基準（DoD） → 思考の指針 → 出力フォーマット → 制約
```

## References

- 詳細なベストプラクティスは [references/guide.md](references/guide.md) を参照
- [GPT-5 prompting guide | OpenAI Cookbook](https://cookbook.openai.com/examples/gpt-5/gpt-5_prompting_guide)
- [GPT-5.1 Prompting Guide | OpenAI Cookbook](https://cookbook.openai.com/examples/gpt-5/gpt-5-1_prompting_guide)
- [GPT-5.2 Prompting Guide | OpenAI Cookbook](https://cookbook.openai.com/examples/gpt-5/gpt-5-2_prompting_guide)
