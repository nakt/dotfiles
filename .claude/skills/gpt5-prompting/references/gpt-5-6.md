# GPT-5.6 プロンプティングガイド

GPT-5.6 は「プロンプトを足すより削る」方向をさらに徹底した世代で、リーンなプロンプト設計、明示的なプロンプトキャッシュ、ターンをまたぐ推論の再利用、Programmatic Tool Calling / Multi-agent といったツール実行系の拡張が中心になる。本ファイルは公式 [Model guidance](https://developers.openai.com/api/docs/guides/latest-model) をベースに、推奨プロンプトを原文で掲載する。

共通原則は [common.md](common.md)、Codex ハーネス規約は [codex.md](codex.md)、5.4 は [gpt-5-4.md](gpt-5-4.md)、5.5 は [gpt-5-5.md](gpt-5-5.md) を参照。

## 目次

- [GPT-5.6 プロンプティングガイド](#gpt-56-プロンプティングガイド)
  - [目次](#目次)
  - [1. New in GPT-5.6 vs GPT-5.5](#1-new-in-gpt-56-vs-gpt-55)
    - [新機能](#新機能)
    - [品質向上領域](#品質向上領域)
  - [2. モデル選択（sol / terra / luna）](#2-モデル選択sol--terra--luna)
  - [3. Reasoning Effort](#3-reasoning-effort)
  - [4. Migration Path](#4-migration-path)
  - [5. Lean Prompting](#5-lean-prompting)
  - [6. 繰り返し・矛盾ルールの害](#6-繰り返し矛盾ルールの害)
  - [7. Autonomy と承認境界](#7-autonomy-と承認境界)
  - [8. Verbosity と文体制御](#8-verbosity-と文体制御)
  - [9. Pro mode](#9-pro-mode)
  - [10. Programmatic Tool Calling](#10-programmatic-tool-calling)
    - [採用基準](#採用基準)
    - [避けるべき場合](#避けるべき場合)
    - [ルーティング指示の型](#ルーティング指示の型)
  - [11. Multi-agent \[beta\]](#11-multi-agent-beta)
  - [12. Prompt caching と Persisted reasoning](#12-prompt-caching-と-persisted-reasoning)
  - [13. Safeguards](#13-safeguards)
  - [14. Suggested prompt structure](#14-suggested-prompt-structure)

---

## 1. New in GPT-5.6 vs GPT-5.5

### 新機能

| 機能 | 内容 |
|---|---|
| Programmatic Tool Calling | JavaScript でツールを呼び、結果を受け渡し、中間出力を処理する（第 10 章） |
| Multi-agent [beta] | 1 つの GPT-5.6 インスタンスが複数サブエージェントを並列調整し、結果を統合する。Responses API のベータ（第 11 章） |
| Explicit prompt caching | 再利用するプロンプト接頭辞をどれキャッシュするか明示指定できる（第 12 章） |
| Persisted reasoning | ターンをまたいで推論アイテムを再利用する。`reasoning.context` で挙動を制御（第 4 章 / 第 12 章） |
| Max reasoning effort | 要求の高いタスク向けの最大推論努力 `max`（第 3 章） |
| Pro mode | 難タスクの信頼性を上げるためモデルの作業量を増やし、単一の最終回答を返す（第 9 章） |

Multi-agent の原文:

> a GPT-5.6 instance coordinate multiple subagents in parallel and synthesize their results
>
> reduce wall-clock time and improve performance for complex tasks

Pro mode の原文:

> more model work to improve reliability on difficult tasks and return a single final answer

### 品質向上領域

- トークン効率性: 同じ結果をより少ないトークンで出す方向の改善
- フロントエンド設計: "more polished websites and applications" を生成する
- インテント理解: 文脈からユーザーの目標を推測する精度が上がる
- 画像詳細度: `detail` に `original` または `auto` を指定すると元の寸法が保持される（`high` / `low` を含む従来値は [gpt-5-4.md](gpt-5-4.md)「Vision & Computer Use（detail パラメータ）」を参照）

## 2. モデル選択（sol / terra / luna）

| モデル | 位置づけ |
|---|---|
| `gpt-5.6-sol` | frontier capability。最も高い能力が必要なワークロード |
| `gpt-5.6-terra` | balances intelligence and cost。知能とコストの均衡 |
| `gpt-5.6-luna` | efficient, high-volume workloads。高スループット向け |

エイリアス `gpt-5.6` は `gpt-5.6-sol` にルーティングされる。エイリアスのまま運用すると常にフロンティア側に寄るため、コスト感度が高いワークロードでは `terra` / `luna` を明示的に指定する。

価格は変動するため本ファイルには記載しない。公式の料金ページを都度参照すること。

## 3. Reasoning Effort

GPT-5.6 の reasoning effort は 6 段階。

| レベル | 推奨用途 |
|---|---|
| `none` | レイテンシのベースライン |
| `low` | latency-sensitive workflows |
| `medium` | balanced starting point。まずここから始める |
| `high` | measurable quality gains が見込める場合 |
| `xhigh` | 同上。さらに重い推論が必要な場合 |
| `max` | reserved for the hardest quality-first workloads |

`max` は最難関かつ品質優先のワークフローに限定する。デフォルトでは使わず、eval で利得が確認できた場合のみ採用する。

## 4. Migration Path

移行手順:

1. 現在の推論設定をそのまま維持して GPT-5.6 に切り替える
2. その後、1 段階低い effort でテストし、eval が落ちないか確認する

GPT-5.5 までの「1 変更ずつ」原則（[gpt-5-4.md](gpt-5-4.md)「Migration Path」）はそのまま有効で、モデル切替と effort 変更を同時に行わない。

推論の持ち越しに関するパラメータ:

| パラメータ | 値 | 用途 |
|---|---|---|
| `reasoning.context` | `auto` / `all_turns` / `current_turn` | ターンをまたぐ推論アイテムの再利用範囲を制御する |
| `previous_response_id` | 直前レスポンスの ID | 前ターンの推論を再利用する |

`previous_response_id` で推論トレースを引き継ぐと、マルチターンの品質とキャッシュ効率の両方に効く。キャッシュ書き込みは uncached 入力レートの 1.25 倍で課金されるため、書き込み対象を絞る設計と併せて考える（第 12 章）。

## 5. Lean Prompting

GPT-5.6 のプロンプティングは「削る」ことが主要な最適化手段になる。公式は設定ごとに次の改善を報告している。

| 指標 | 変化 |
|---|---|
| eval スコア | 10〜15% 改善 |
| トークン | 41〜66% 削減 |
| コスト | 33〜67% 削減 |

段階的削除の手順（原文）:

> Start with a prompt and tool set that already works. Remove one group of instructions, examples, or tools at a time, then rerun the same evals.

要点:

- 動くプロンプトとツールセットを出発点にする（ゼロから短く書き直すのではない）
- 指示・例・ツールを 1 グループずつ削り、そのたびに同じ eval を回す
- 各命令は一度だけ記述する。同じ内容を別の言い方で再掲しない
- ツール説明は簡潔かつ正確に保つ

## 6. 繰り返し・矛盾ルールの害

同じ制約を繰り返すこと自体が挙動を悪化させる。

> Repeating instructions such as 'ask first,' 'do not mutate,' or 'wait for approval' can cause unnecessary approval requests

`ask first` / `do not mutate` / `wait for approval` のような指示を重ねて書くと、本来不要な承認要求が発生する。安全側に倒したつもりの重複が、エージェントを止める方向に効いてしまう。

> conflicting rules can create more instability than missing detail

矛盾したルールは、情報が不足している状態よりも大きな不安定を招く。プロンプトを削る過程で矛盾が残っていないか確認し、迷ったら記述を足すのではなく矛盾する側を消す。

## 7. Autonomy と承認境界

承認境界は、繰り返しではなく 1 つのコンパクトな方針として書く。公式の推奨文言:

```text
For requests to answer, explain, review, diagnose, or plan, inspect the
relevant materials and report the result. Do not implement changes unless
the request also asks for them. For requests to change, build, or fix, make
the requested in-scope local changes and run relevant non-destructive
validation without asking first. Require confirmation for external writes,
destructive actions, purchases, or a material expansion of scope.
```

要約:

- 回答 / 説明 / レビュー / 診断 / 計画の依頼では、関連資料を調べて結果を報告するだけにとどめ、依頼されていない変更は実装しない
- 変更 / 構築 / 修正の依頼では、範囲内のローカル変更と非破壊的な検証を、事前確認なしで実行する
- 外部書き込み、破壊的行動、購入、スコープの実質的拡大には確認を要求する

事前確認なしで進めてよい local actions の例:

- ファイルの読み取り
- ログの検査
- 範囲内のコード編集
- テストの実行

## 8. Verbosity と文体制御

`text.verbosity` は API パラメータで、デフォルトの詳細度（"default level of detail"）をプロンプトの文言とは独立に制御する。値は `low` / `medium` / `high`。

使い分けの原則:

- グローバルな詳細度は `text.verbosity` で設定する。プロンプト本文に「簡潔に」「詳しく」を書き足して制御しない
- プロンプト側の文言は、特定セクションだけ詳しくする / 短くするといった部分的な上書きに使う

短答が求められる場面の文言（原文）:

> Lead with the conclusion. Include the evidence needed to support it, any material caveat, and the next action. Omit secondary detail and repetition.

結論から書き、それを支える根拠・重要な留保・次のアクションだけを含め、二次的な詳細と繰り返しは省く。

文体定義（原文）:

> State the answer directly. If the user reports a problem, acknowledge the specific issue before giving the next step. Use reassurance only when it is relevant. Omit generic praise and unnecessary sign-offs.

答えを直接述べる。ユーザーが問題を報告している場合は、次の手順を示す前にその具体的な問題を認識していると示す。安心させる言葉は関連するときだけ使い、一般的な賞賛や不要な締めの挨拶は省く。

XML ブロック形式の記述例は [gpt-5-4.md](gpt-5-4.md)「Verbosity Controls」を参照。

## 9. Pro mode

Responses API で `reasoning.mode: "pro"` を指定する。

採用基準:

- 品質がレイテンシとトークン使用量より重要な場面（"quality matters more than latency and token usage"）
- 品質がアウトカムに実質的な影響を与え、かつタスクの難度が高い場合
- 具体例: 複雑な最適化、高価値なコード審査、明確な評価基準のある深い分析

Pro mode は reasoning effort とは独立した設定である。両方を同時に動かすと何が効いたか分からなくなるため、同じモデル・同じ effort のまま Pro mode の有無だけを比較するところから始める。

## 10. Programmatic Tool Calling

複数のツール結果、または大規模な中間出力から小規模な構造化結果を得る「bounded workflows」に使う。

### 採用基準

中間結果に対して次のような処理をかける段階に向く。

- 絞り込み（フィルタ）
- 結合
- ランキング
- 重複排除
- 集約
- 検証

### 避けるべき場合

- 1 回のツール呼び出しで十分な場合
- 中間出力が既に小さい場合
- 各結果が次の判定を変える場合（逐次的な意思決定が必要な場合）

> Multiple, parallel, or dependent calls alone do not justify

呼び出しが複数ある、並列である、依存関係があるという理由だけでは、このアプローチを正当化しない。判断基準はあくまで「大きな中間出力を小さな構造化結果に縮約する段階かどうか」にある。

### ルーティング指示の型

```text
Use Programmatic Tool Calling for [bounded stage] using only
[eligible tools]...Process and reduce the intermediate results, then
emit exactly [output schema]...
```

範囲を区切った段階と、そこで使ってよいツールを限定し、中間結果を処理・縮約したうえで出力スキーマを厳密に指定する形にする。

## 11. Multi-agent [beta]

> a GPT-5.6 instance coordinate multiple subagents in parallel and synthesize their results

1 つの GPT-5.6 インスタンスが複数のサブエージェントを並列に調整し、その結果を統合する。

> reduce wall-clock time and improve performance for complex tasks

複雑なタスクにおいて実時間を短縮し、性能を改善することが狙い。Responses API でベータ提供される。ベータのため、本番運用に組み込む前に挙動の安定性を eval で確認すること。

## 12. Prompt caching と Persisted reasoning

Explicit prompt caching では、再利用するプロンプト接頭辞のうちどれを OpenAI 側でキャッシュするかを明示指定できる。

> mark exactly which reusable prompt prefixes OpenAI caches

課金上の注意: キャッシュ書き込みは uncached 入力レートの 1.25 倍で課金される。書き込みが常に得になるわけではないため、実際に再利用される接頭辞に絞って指定する。

Persisted reasoning は次の目的で提供される。

> reuse available reasoning items across turns to improve multi-turn quality and cache efficiency

ターンをまたいで利用可能な推論アイテムを再利用し、マルチターンの品質とキャッシュ効率を改善する。挙動は `reasoning.context`（`auto` / `all_turns` / `current_turn`）で制御し、前ターンの推論の引き継ぎには `previous_response_id` を使う（第 4 章）。

## 13. Safeguards

> real-time cyber and biology misuse classifiers that are run as model outputs are generated

サイバー・生物領域の悪用に対するリアルタイム分類器が、モデル出力の生成中に走る。この結果、リクエストがブロックされるか、生成が途中で一時停止されることがある。ストリーミング前提のアプリケーションでは、生成が途中で止まるケースをハンドリングしておく。

エンドユーザー向けアプリケーションでは、安定かつプライバシーを保つ `safety_identifier` を送信することが推奨される（"stable, privacy-preserving `safety_identifier`"）。

## 14. Suggested prompt structure

[gpt-5-5.md](gpt-5-5.md)「Suggested prompt structure」の骨格をそのまま使う。

```text
Role: [1-2 sentences defining the model's function, context, and job]

# Personality
[tone, demeanor, and collaboration style]

# Goal
[user-visible outcome]

# Success criteria
[what must be true before the final answer]

# Constraints
[policy, safety, business, evidence, and side-effect limits]

# Output
[sections, length, and tone]

# Stop rules
[when to retry, fallback, abstain, ask, or stop]
```

GPT-5.6 での差分:

- 全体: 各指示は一度だけ書く。同じ制約が複数セクションに現れていないか確認する（第 5 章 / 第 6 章）
- Constraints: 承認境界は第 7 章のコンパクトな方針 1 つにまとめる。`ask first` 系の指示を各所に散らさない
- Output: 詳細度のデフォルトは `text.verbosity` で設定し、このセクションには部分的な上書きだけを書く（第 8 章）
- ツール定義: ツール説明は簡潔かつ正確に。縮約段階があるなら Programmatic Tool Calling へのルーティングを明示する（第 10 章）
- パラメータ: effort は `medium` を出発点にし（第 3 章）、難度が高く品質優先のタスクではそれとは独立に `reasoning.mode: "pro"` を検討する（第 9 章）
