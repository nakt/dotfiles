---
name: fable5-prompting
description: Claude Fable 5 / Mythos 5 向けプロンプト設計の支援スキル。references/ 内のガイド（common.md / fable-5.md / parameters.md）をリファレンスとして参照し、レビュー・ドラフティング・アドバイスを行う。Claude Fable 5 / Mythos 5 向けプロンプトの新規作成、既存プロンプト（他モデル・GPT 系含む）からの移行・最適化、effort/adaptive thinking/max_tokens 等のパラメータ設定検討、長時間 autonomous run のスキャフォールディング設計、サブエージェント委譲・メモリシステム・send-to-user ツールの設計、refusal/fallback 対応、reasoning_extraction を避けるプロンプト監査、プロンプトが期待通りに動かない場合の原因特定に使用する。
allowed-tools: Read
---

# Claude Fable 5 / Mythos 5 プロンプティングガイド

回答時に references/ のどのファイル・どの章に基づくかをファイル名と章タイトルで引用する（例: `fable-5.md「進捗報告を根拠づける」`、`parameters.md「effort パラメータ」`）。

対象は Claude Fable 5（`claude-fable-5`）と Claude Mythos 5（`claude-mythos-5`）。両者はプロンプティング・パラメータ推奨が同一なので、特記しない限りまとめて扱う。

## モード判定

リクエスト内容に応じて柔軟に判断する。境界ケースや複合リクエストは適宜組み合わせる。

- Review: 既存プロンプトを提示された場合
- Draft: 新規プロンプト作成の依頼
- Advise: パラメータや手法についての質問

## リファレンスの読み分け

`common.md` は常に併読する。加えてリクエストの焦点で以下を Read する。判断がつかなければ3ファイルすべてを Read する。

| リクエストの焦点 / シグナル | Read するファイル |
|---|---|
| 長時間 autonomous run / サブエージェント / メモリ / 進捗報告 / 早期停止 / 境界設定 / send-to-user | fable-5.md |
| Opus 4.8 や GPT 系からの Fable 5 移行 / スキルのリファクタ / prescriptive すぎる指示 | fable-5.md（+ common.md） |
| effort / xhigh / max_tokens / thinking の深さ | parameters.md |
| adaptive thinking / thinking.display / omitted / summarized / thinking ブロックの往復 | parameters.md |
| `stop_reason: refusal` / cyber / bio / frontier_llm / reasoning_extraction / fallback | parameters.md |
| clear-and-direct / 例 / XML タグ / ロール / 長 context / prefill 移行 / hallucination | common.md |

Fable 5 固有の最重要ポイント（判断に迷ったら優先的に確認）:

1. Fable 5 は指示遵守が強く、挙動を1つずつ列挙するより短い指示1本で steer する方が良い。従来モデル向けの prescriptive なプロンプトは過度で、品質を下げうる（`fable-5.md「推奨スキャフォールディング変更」`）
2. thinking は常時オンの adaptive のみ。`budget_tokens` は 400 エラー。内部推論を応答テキストで再現させる指示は `reasoning_extraction` refusal を誘発する（`parameters.md「adaptive thinking」`）
3. effort が主要コントロールで既定は `high`（`parameters.md「effort パラメータ」`）

## Review

既存プロンプトの評価と改善提案を行う。

出力形式:

1. 対象モデル（Fable 5 / Mythos 5）と、他モデル向けからの移行なら移行元
2. 評価サマリー
3. チェック項目ごとの判定（OK / 要改善 / 該当なし）- Review Checklist を使用
4. 改善提案（具体的な修正案 + 該当ファイル名と原則を引用）
5. 改善後のプロンプト全文

## Draft

新規プロンプトを設計・作成する。

出力形式:

1. 対象モデルと設計方針
2. 設計判断の説明（該当ファイルの原則に基づく根拠）
3. プロンプト全文
4. 推奨パラメータ設定（effort, max_tokens, thinking.display, 必要なら fallback 構成）

## Advise

パラメータや手法についての質問に回答する。

出力形式:

1. 質問への回答（該当ファイル名と章タイトルを引用）

## Review Checklist

| チェック項目 | 参照 | 確認内容 |
|---|---|---|
| 過度な prescriptive さ | fable-5.md「推奨スキャフォールディング変更」 | 挙動を1つずつ列挙して steer していないか。短い指示に集約できないか |
| reasoning_extraction 誘発 | fable-5.md「推奨スキャフォールディング変更」 / parameters.md「Refusal と Fallback」 | 内部推論を応答テキストで echo / transcribe / explain させる指示がないか |
| outcome-first / 簡潔さ | fable-5.md「強い指示遵守」 | 結論を先頭に置く指示があるか。冗長化を抑えているか |
| 進捗報告の根拠づけ | fable-5.md「進捗報告を根拠づける」 | 長時間 run で claim をツール結果に照らして監査させているか |
| 境界の明示 | fable-5.md「境界を明示する」 | 要求外の行動を禁じ、system 状態変更コマンドの前に根拠確認をさせているか |
| checkpoint / 早期停止 | fable-5.md「強い指示遵守」 / 「まれな早期停止」 | 本当に必要なときだけ止める指示か。ターン終了前に未実行の約束を検査させているか |
| effort 設定 | parameters.md「effort パラメータ」 | タスク複雑度に見合うか。既定 high から始め、routine は下げているか |
| max_tokens | parameters.md「effort パラメータ」 / 「コスト制御」 | high/xhigh で thinking + response の総出力に足る大きさを確保しているか |
| thinking 制御 | parameters.md「adaptive thinking」 | budget_tokens を使っていないか。display の要否を意識しているか |
| overthinking 抑制 | common.md「overthinking の抑制」 / fable-5.md「effort レベルを使い分ける」 | 高 effort での要求外の整理・リファクタ・探索を抑えているか |
| サブエージェント委譲 | fable-5.md「並列サブエージェント」 / common.md「サブエージェント orchestration」 | 委譲の適否と非同期通信を指示しているか。過剰 spawn を抑えているか |
| メモリシステム | fable-5.md「メモリシステムを構築する」 | 教訓の記録・参照先を与えているか |
| 理由の提供 | fable-5.md「依頼だけでなく理由を伝える」 | why / 誰のため / 何を可能にするかを伝えているか |
| 可読性 | fable-5.md「ユーザーとのコミュニケーションの可読性」 | 長い agentic 会話で最終サマリーを re-grounding として書かせているか |
| send-to-user | fable-5.md「send-to-user ツールを作る」 | verbatim content が要る UX でツール定義 + elicitation 指示があるか |
| 自己検証 | fable-5.md「推奨スキャフォールディング変更」 / common.md「thinking / interleaved thinking の活用」 | fresh-context の別 verifier サブエージェントで検証させているか |
| fallback 構成 | parameters.md「Refusal と Fallback」 | cyber/bio 等に触れうるなら Opus 4.8 への fallback を各 request path に設定しているか |
| 明確さ / 具体性 | common.md「明確かつ直接的に」 | 望む出力・制約が具体的か。過剰な語調で overtrigger させていないか |
| ツール使用の明示 | common.md「ツール使用の明示」 | 行動させたいのに「提案して」になっていないか。CRITICAL 等の過剰語調がないか |
| 過剰エンジニアリング | common.md「過剰エンジニアリング」 / fable-5.md「effort レベルを使い分ける」 | 要求外のファイル・抽象・防御コードを抑えているか |

## Quick Reference

### effort 早見（Fable 5 / Mythos 5）

| レベル | 使いどころ |
|---|---|
| `low` | 単純タスク、サブエージェント。速度・低コスト優先 |
| `medium` | routine work の step down |
| `high`（既定） | 大半のタスクの出発点 |
| `xhigh` | 最も能力が要るワークロード、30分超の長時間 agentic |
| `max` | トークン無制約で絶対最大能力 |

運用方針: 既定 `high` から始め、routine は `medium` / `low` に下げる。Fable 5 の低 effort は従来モデルの `xhigh` を上回ることが多い。完了するが遅すぎる / より対話的にしたいなら下げる。`high` / `xhigh` では `max_tokens`（thinking + response の総出力上限）を大きく取る。詳細は `parameters.md「effort パラメータ」`。

### thinking の要点

- 常時オンの adaptive thinking のみ。`disabled` 不可、`budget_tokens` は 400 エラー
- `thinking.display` の既定は `"omitted"`（thinking フィールドが空）。サマリーが欲しければ `"summarized"` を明示
- raw chain of thought は返らない。可視化は `thinking` ブロックを読む（応答テキストで推論を求めない）
- 同一モデル継続時は thinking ブロックを受け取ったまま返す。モデル切替時は除去する
- 詳細は `parameters.md「adaptive thinking」`

### refusal category と対処

| category | 対処 |
|---|---|
| `cyber` / `bio` / `frontier_llm` | Opus 4.8 等へ fallback（server-side / SDK middleware / 手動 retry） |
| `reasoning_extraction` | 応答テキストで推論を求める指示を除去し、adaptive thinking の構造化ブロックを使う |

詳細は `parameters.md「Refusal と Fallback」`。

### 積極性・冗長性の制御

- 抑える: effort を下げる、要求外の整理・リファクタを禁じる指示、checkpoint を「本当に必要なときだけ」に限定
- 上げる: effort を `high` / `xhigh` に、autonomous 用の system reminder（許可を求めず reversible な行動は進める）
- 簡潔化: outcome-first 指示1本で足りる。個別挙動の列挙は不要

### 移行時の勘所（Opus 4.8 / GPT 系 → Fable 5）

- prescriptive すぎる指示・過剰な語調を削る（品質を下げうる）
- 内部推論を応答に書かせる指示を監査・除去（`reasoning_extraction` 対策）
- `budget_tokens` を effort + `max_tokens` に置換
- ターンが長くなる前提で timeout / streaming / 進捗インジケータを調整、非同期確認の構成を検討
- 難易度レンジの上限のタスクで試す

## References

- 共通原則: [references/common.md](references/common.md)
- Fable 5 / Mythos 5 固有: [references/fable-5.md](references/fable-5.md)
- API パラメータ（effort / adaptive thinking / refusal・fallback）: [references/parameters.md](references/parameters.md)
- 公式: [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Effort](https://platform.claude.com/docs/en/build-with-claude/effort)
- [Adaptive thinking](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking)
- [Refusals and fallback](https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback)
