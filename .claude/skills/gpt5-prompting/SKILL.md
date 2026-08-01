---
name: gpt5-prompting
description: GPT-5/GPT-5.1/GPT-5.2/GPT-5.3 Codex/GPT-5.4/GPT-5.5 向けプロンプト設計の支援スキル（レビュー・ドラフティング・アドバイス）。新規作成、既存プロンプトの最適化・移行、reasoning_effort/verbosity/phase 等のパラメータ設定検討、エージェント的ワークフローの積極性調整、outcome-first 構造への移行、ツール多用フローでの phase 設計、プロンプトが期待通りに動かない場合の原因特定に使用する。
allowed-tools:
  - Read
---

# GPT-5 系プロンプティングガイド

回答時に references/ のどのファイル・どの章に基づくかをファイル名と章タイトルで引用する（例: `gpt-5-4.md「Verification Loop」`、`common.md「指示遵守の注意点」`）。

## モード判定

リクエスト内容に応じて柔軟に判断する。境界ケースや複合リクエストは適宜組み合わせる。

- Review: 既存プロンプトを提示された場合
- Draft: 新規プロンプト作成の依頼
- Advise: パラメータや手法についての質問

## 対象バージョンの特定

ユーザーが対象モデルを明示した場合は該当ファイルを優先して Read。明示がない場合は次のキーワード推定表で判断する。推定不能なら `common.md` + `gpt-5-5.md`（最新）を Read する。

| キーワード / シグナル | 推定バージョン | 根拠 |
|---|---|---|
| `apply_patch` / `update_plan` / Codex CLI 言及 | gpt-5-3-codex | Codex 専用ツール |
| `phase: "commentary"` / `phase: "final_answer"` | gpt-5-3-codex / gpt-5-4 / gpt-5-5 | 5.3 Codex で導入され以降のモデルに拡大。単独ではバージョンを絞れない |
| `output_contract` / `verification_loop` / `tool_persistence_rules` / `completeness_contract` / `empty_result_recovery` / `parallel_tool_calling` / `personality_and_writing_controls` | gpt-5-4 | 5.4 で標準化された XML タグ |
| outcome-first 構造 / Stop rules セクション / プレーン散文志向 / `# Personality` ヘッダ | gpt-5-5 | 5.5 推奨構造 |
| `xhigh` reasoning_effort | gpt-5-series / gpt-5-4 | 5.2 で導入（gpt-5-series.md）、5.4 で運用推奨を更新 |
| `none` reasoning_effort 言及 | gpt-5-series | 5.1 で導入（gpt-5-series.md）。5.4 / 5.5 でも推奨スタートなので単独では弱いシグナル |
| `<persistence>` / `<context_gathering>` / `<tool_preambles>` の独立タグ | gpt-5-series | 既存 GPT-5/5.1/5.2 の標準 |
| `<exploration>` / `<verification>`（Terminal-Bench スタイル） | gpt-5-series | 公式ベンチマーク準拠 |
| Markdown 不使用 / Cursor 事例言及 | gpt-5-series | GPT-5 系初期チューニング |

複数キーワード該当時の優先順位:

1. Codex 専用ツール言及（`apply_patch` 等）→ `gpt-5-3-codex.md` を最優先
2. `phase` パラメータ言及 → Codex 文脈なら `gpt-5-3-codex.md`、そうでなければ `gpt-5-4.md` と `gpt-5-5.md` を Read
3. それ以外は最新側を採用（5.5 → 5.4 → series の順）

`common.md` は常に併読する。

## Review

既存プロンプトの評価と改善提案を行う。

出力形式:

1. 対象バージョン（推定根拠を 1 行）
2. 評価サマリー
3. チェック項目ごとの判定（OK / 要改善 / 該当なし）- Review Checklist を使用
4. 改善提案（具体的な修正案 + 該当ファイル名と原則を引用）
5. 改善後のプロンプト全文

## Draft

新規プロンプトを設計・作成する。

出力形式:

1. 対象バージョンと選定理由
2. 設計判断の説明（該当ファイルの原則に基づく根拠）
3. プロンプト全文
4. 推奨パラメータ設定（reasoning_effort, verbosity, phase の使い分け）

## Advise

パラメータや手法についての質問に回答する。

出力形式:

1. 質問への回答（該当ファイル名と章タイトルを引用）

## Review Checklist

| チェック項目 | 参照 | 確認内容 |
|---|---|---|
| ロール指定の混入 | common.md「ロール指定とパーソナリティの区別」 | 専門性バイアスを誘導するロール指定が含まれていないか |
| 矛盾した指示の有無 | common.md「指示遵守の注意点」 | 相反する指示が含まれていないか |
| 成功基準の明示 | common.md「実務向けプロンプト構成テンプレート」 / gpt-5-5.md「Outcome-first prompts and stopping conditions」 | DoD が明確に定義されているか、outcome-first 構造になっているか |
| 出力フォーマット指定 | gpt-5-4.md「Output Contract」 / 「Structured Output Contract」 | 出力形式・順序・スキーマが厳密に定義されているか |
| 積極性制御 | gpt-5-series.md「エージェント積極性（Eagerness）の制御」 / gpt-5-4.md「Default Follow-Through Policy」 | タスクに適した探索深度・確認頻度が設定されているか |
| reasoning_effort | gpt-5-series.md「reasoning_effort パラメータ」 / gpt-5-4.md「Reasoning Effort 推奨」 | タスク複雑度に見合った設定か。none/low/medium から始める原則に沿うか |
| verbosity | gpt-5-series.md「verbosity パラメータ」 / gpt-5-4.md「Verbosity Controls」 | 出力の冗長性が適切か |
| ツール呼び出し前説明 | gpt-5-series.md「Tool Preamble」 / gpt-5-5.md「Improve time to first visible token with a preamble」 | UX 向けプリアンブルが考慮されているか |
| 自己検証指示 | gpt-5-4.md「Verification Loop」 / common.md「曖昧性・ハルシネーション対策」 | 反省・検証ステップが含まれているか |
| Markdown 指示 | common.md「Markdown フォーマット」 / gpt-5-5.md「Formatting」 | フォーマット要件が明示されているか、5.5 ではプレーン散文志向か |
| 永続性指示 | gpt-5-series.md「エージェント積極性（Eagerness）の制御」 / gpt-5-4.md「Autonomy & Persistence」 / gpt-5-3-codex.md「スタータープロンプトの構成ブロック」 | 長時間タスクでの継続性が確保されているか |
| スコープドリフト防止 | common.md「スコープドリフト防止」 | 要求外の機能追加やスタイリングを禁止しているか |
| メタプロンプティング | common.md「メタプロンプティング」 | GPT-5 自身にプロンプト改善を問う手法が活用できるか |
| Phase parameter | gpt-5-3-codex.md「Phase Parameter (Codex 固有)」 / gpt-5-4.md「Phase Parameter」 / gpt-5-5.md「Phase parameter」 | ツール多用フローで commentary / final_answer が適切に使い分けられているか。Codex では必須 |
| Empty Result Recovery | gpt-5-4.md「Empty Result Recovery」 | 空結果時のフォールバック戦略が指定されているか |
| Outcome-first 構造 | gpt-5-5.md「Outcome-first prompts and stopping conditions」 | プロセス指示よりゴール定義が優先されているか |
| Streaming Preamble | gpt-5-5.md「Improve time to first visible token with a preamble」 | 最初の可視トークンを早めるプリアンブル指示があるか |
| Retrieval Budget | gpt-5-5.md「Grounding, citations, and retrieval budgets」 | 検索の停止条件・追加検索の発動条件が明示されているか |
| Tool Persistence Rules | gpt-5-4.md「Tool Persistence Rules」 | ツール継続呼び出しの規則が定義されているか |
| Codex ツール規約 | gpt-5-3-codex.md「推奨ツール」 / 「Editing Constraints 要点」 | `apply_patch` / `shell` / 並列呼び出しを前提にしているか。ASCII 優先と git dirty 保護が指示されているか |
| Plan ツールの開閉 | gpt-5-3-codex.md「Plan ツール（update_plan）の開閉ルール」 | 計画を開く基準と、終了時に全アイテムを Done / Blocked / Cancelled へ確定させる指示があるか |
| Compaction | gpt-5-series.md「Compaction（コンテキスト拡張）」 / gpt-5-4.md「Compaction for Long Sessions」 / gpt-5-3-codex.md「Compaction サポート」 | 長時間セッションで圧縮の呼び時と、再開時のプロンプト同一性が考慮されているか |

## 参照索引

「知りたいこと」から入口を引くための索引。ファイル名と章タイトルの実体は Review Checklist の「参照」列が持つので、そこに載っている主題はチェック項目名で指す。索引にしか無い主題だけ章を直接書く。回答前に該当章を Read するのは共通。

| 知りたいこと | 入口 |
|---|---|
| reasoning_effort のレベル一覧とバージョン別デフォルト | Checklist「reasoning_effort」 |
| gpt-5.3-codex の reasoning_effort | gpt-5-4.md「Migration Path」（現行 effort の維持が推奨） |
| verbosity の制御 | Checklist「verbosity」。5.5 のプレーン散文志向は Checklist「Markdown 指示」 |
| phase の値・保持ルール・必須度 | Checklist「Phase parameter」 |
| 積極性と永続性の制御 | Checklist「積極性制御」「永続性指示」「Tool Persistence Rules」 |
| プロンプト構成の骨格 | Checklist「成功基準の明示」、加えて gpt-5-4.md「Suggested Prompt Structure」、gpt-5-5.md「Suggested prompt structure」 |
| ツール多用フロー向け XML ブロックの原文 | gpt-5-4.md「Output Contract」〜「BBox Extraction」の各章 |
| Codex 固有のツール・編集制約・計画管理 | Checklist「Codex ツール規約」「Plan ツールの開閉」 |
| 小型モデル（gpt-5.4-mini / nano） | gpt-5-4.md「Small Model Guidance（gpt-5.4-mini / nano）」 |
| 長時間セッションの Compaction | Checklist「Compaction」 |
| outcome-first 構造とプレーン散文 | Checklist「Outcome-first 構造」「Markdown 指示」、加えて gpt-5-5.md「Avoid unnecessary absolute rules」 |

## References

- 共通原則: [references/common.md](references/common.md)
- GPT-5 / 5.1 / 5.2: [references/gpt-5-series.md](references/gpt-5-series.md)
- GPT-5.3 Codex: [references/gpt-5-3-codex.md](references/gpt-5-3-codex.md)
- GPT-5.4: [references/gpt-5-4.md](references/gpt-5-4.md)
- GPT-5.5: [references/gpt-5-5.md](references/gpt-5-5.md)
- 公式: [Prompt Guidance | OpenAI Developers](https://developers.openai.com/api/docs/guides/prompt-guidance)
- [Using GPT-5.5 | OpenAI Developers](https://developers.openai.com/api/docs/guides/latest-model)
- [GPT-5 prompting guide | OpenAI Cookbook](https://developers.openai.com/cookbook/examples/gpt-5/gpt-5_prompting_guide)
- [GPT-5.1 Prompting Guide | OpenAI Cookbook](https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-1_prompting_guide)
- [GPT-5.2 Prompting Guide | OpenAI Cookbook](https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide)
- [Codex Prompting Guide | OpenAI Cookbook](https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide)
- [Prompt Personalities | OpenAI Cookbook](https://developers.openai.com/cookbook/examples/gpt-5/prompt_personalities)
