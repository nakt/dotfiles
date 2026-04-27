# GPT-5.5 プロンプティングガイド

GPT-5.5 は "outcome-first" 哲学を打ち出し、プロセス指示を積み重ねるよりゴール定義 + 停止条件で短く書くことを推奨する世代。本ファイルは公式 [Prompt Guidance](https://developers.openai.com/api/docs/guides/prompt-guidance) の GPT-5.5 セクションをベースに、推奨プロンプトを原文で掲載する。

共通原則は [common.md](common.md)、初期世代は [gpt-5-series.md](gpt-5-series.md)、Codex は [gpt-5-3-codex.md](gpt-5-3-codex.md)、5.4 は [gpt-5-4.md](gpt-5-4.md) を参照。

## 目次

- [GPT-5.5 プロンプティングガイド](#gpt-55-プロンプティングガイド)
  - [目次](#目次)
  - [1. New in GPT-5.5 vs GPT-5.4](#1-new-in-gpt-55-vs-gpt-54)
  - [2. Automated migration with Codex](#2-automated-migration-with-codex)
  - [3. Personality and behavior](#3-personality-and-behavior)
    - [タスク志向型](#タスク志向型)
    - [表現的協調型](#表現的協調型)
  - [4. Improve time to first visible token with a preamble](#4-improve-time-to-first-visible-token-with-a-preamble)
  - [5. Outcome-first prompts and stopping conditions](#5-outcome-first-prompts-and-stopping-conditions)
  - [6. Avoid unnecessary absolute rules](#6-avoid-unnecessary-absolute-rules)
  - [7. Formatting](#7-formatting)
  - [8. Grounding, citations, and retrieval budgets](#8-grounding-citations-and-retrieval-budgets)
  - [9. Creative drafting guardrails](#9-creative-drafting-guardrails)
  - [10. Frontend engineering and visual taste](#10-frontend-engineering-and-visual-taste)
  - [11. Prompt the model to check its work](#11-prompt-the-model-to-check-its-work)
  - [12. Phase parameter](#12-phase-parameter)
  - [13. Suggested prompt structure](#13-suggested-prompt-structure)

---

## 1. New in GPT-5.5 vs GPT-5.4

> Shorter, outcome-first prompts usually work better than process-heavy prompt stacks. More efficient reasoning means `low` and `medium` effort should be re-evaluated before escalating. Preambles, `phase` handling, and assistant-item replay remain important for tool-heavy Responses workflows.

要約:

- 短く outcome-first なプロンプトを優先（process-heavy なスタックは逆効果になりやすい）
- 推論効率向上により、`low` / `medium` の運用余地が広がる前にエスカレートしないことを推奨
- Preamble、`phase` ハンドリング、assistant アイテム再生は ツール多用 Responses ワークフローで引き続き重要

## 2. Automated migration with Codex

GPT-5.5 への移行は Codex を介した自動移行ワークフローでサポートされる。詳細は公式ドキュメントを参照。

## 3. Personality and behavior

GPT-5.5 ではパーソナリティと作業スタイルを別ブロックで分けることを推奨する。パーソナリティ定義は短く、タスク挙動とは混ぜない（[common.md](common.md)「ロール指定とパーソナリティの区別」原則と一致）。

### タスク志向型

```text
# Personality
You are a capable collaborator: approachable, steady, and direct. 
Assume the user is competent and acting in good faith, and respond 
with patience, respect, and practical helpfulness.

Prefer making progress over stopping for clarification when the 
request is already clear enough to attempt. Use context and 
reasonable assumptions to move forward.
```

### 表現的協調型

```text
# Personality
Adopt a vivid conversational presence: intelligent, curious, 
playful when appropriate, and attentive to the user's thinking. 
Ask good questions when the problem is blurry, then become 
decisive once there is enough context.
```

## 4. Improve time to first visible token with a preamble

> In streaming applications, users notice how long it takes before the first visible response appears. GPT-5.5 may spend time reasoning, planning, or preparing tool calls before emitting visible text.

ストリーミング向け推奨パターン:

```text
Before any tool calls for a multi-step task, send a short 
user-visible update that acknowledges the request and states 
the first step. Keep it to one or two sentences.
```

コーディングエージェント向け:

```text
You must always start with an intermediary update before any 
content in the analysis channel if the task will require calling 
tools. The user update should acknowledge the request and explain 
your first step.
```

## 5. Outcome-first prompts and stopping conditions

ゴールと成功基準を主役にし、プロセスの細部はモデルに委ねる:

```text
Resolve the customer's issue end to end.

Success means:
- the eligibility decision is made from the available policy and account data
- any allowed action is completed before responding
- the final answer includes completed_actions, customer_message, and blockers
- if evidence is missing, ask for the smallest missing field
```

## 6. Avoid unnecessary absolute rules

> Avoid unnecessary absolute rules. Older prompts often use strict instructions like `ALWAYS`, `NEVER`, `must`, and `only` to control model behavior. Use those words for true invariants, such as safety rules, required output fields, or actions that should never happen.

`ALWAYS` / `NEVER` / `must` / `only` は本当に不変条件であるとき（安全ルール、必須出力フィールド、絶対禁止アクション）に限定する。

## 7. Formatting

> Let formatting serve comprehension. Use plain paragraphs as the default format for normal conversation, explanations, reports, documentation, and technical writeups.
>
> Use headers, bold text, bullets, and numbered lists sparingly.

通常はプレーン散文をデフォルトに、見出し・太字・箇条書きは抑制的に使う。

## 8. Grounding, citations, and retrieval budgets

検索の停止条件・追加検索の発動条件を明示する:

```text
For ordinary Q&A, start with one broad search using short, 
discriminative keywords. If the top results contain enough citable 
support for the core request, answer from those results instead of 
searching again.

Make another retrieval call only when:
- The top results do not answer the core question.
- A required fact, parameter, owner, date, ID, or source is missing.
- The user asked for exhaustive coverage, a comparison, or a 
  comprehensive list.
```

引用ルール本体は [gpt-5-4.md](gpt-5-4.md)「Citation Rules / Grounding Rules」を参照。

## 9. Creative drafting guardrails

```text
- Use retrieved or provided facts for concrete product, customer, 
  metric, roadmap, date, capability, and competitive claims, and 
  cite those claims.
- Do not invent specific names, first-party data claims, metrics, 
  roadmap status, customer outcomes, or product capabilities to 
  make the draft sound stronger.
```

## 10. Frontend engineering and visual taste

GPT-5.5 でも frontend のハードルールは GPT-5.4 系と共通の `<frontend_tasks>`（[gpt-5-4.md](gpt-5-4.md)「Frontend Tasks」）を流用する。

公式は frontend 専用ガイドへのリンクも案内している:

> Refer to the [example instructions](/api/docs/guides/frontend-prompt) for practical ways to steer UI quality covering product and user context, design-system alignment, first-screen usability, familiar controls.

## 11. Prompt the model to check its work

最終化前に自己チェックを促す（[gpt-5-4.md](gpt-5-4.md)「Verification Loop」と整合）。Outcome-first 構造の中で「何が成功か」を明示し、その達成をモデルに自己確認させる。

## 12. Phase parameter

GPT-5.4 と同じ `phase`（commentary / final_answer）の使い分けが GPT-5.5 でも引き続き重要。

> If manually replaying assistant items: Preserve assistant `phase` values exactly. Use `phase: 'commentary'` for intermediate user-visible updates. Use `phase: 'final_answer'` for the completed answer. Do not add `phase` to user messages.

## 13. Suggested prompt structure

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
