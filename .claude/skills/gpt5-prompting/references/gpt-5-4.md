# GPT-5.4 プロンプティングガイド

GPT-5.4 は long-running multi-step タスク、強いパーソナリティ/トーン遵守、エビデンス豊富な合成、規律的な実行に特化した世代。本ファイルは公式 [Prompt Guidance](https://developers.openai.com/api/docs/guides/prompt-guidance) の GPT-5.4 セクションをベースに、XML ブロックを原文で掲載する。

共通原則は [common.md](common.md)、初期世代は [gpt-5-series.md](gpt-5-series.md)、Codex は [gpt-5-3-codex.md](gpt-5-3-codex.md)、最新世代は [gpt-5-5.md](gpt-5-5.md) を参照。

## 目次

- [GPT-5.4 プロンプティングガイド](#gpt-54-プロンプティングガイド)
  - [目次](#目次)
  - [1. 強み・弱みの概要](#1-強み弱みの概要)
  - [2. Output Contract](#2-output-contract)
  - [3. Verbosity Controls](#3-verbosity-controls)
  - [4. Default Follow-Through Policy](#4-default-follow-through-policy)
  - [5. Instruction Priority](#5-instruction-priority)
  - [6. Tool Persistence Rules](#6-tool-persistence-rules)
  - [7. Dependency Checks](#7-dependency-checks)
  - [8. Parallel Tool Calling](#8-parallel-tool-calling)
  - [9. Completeness Contract](#9-completeness-contract)
  - [10. Empty Result Recovery](#10-empty-result-recovery)
  - [11. Verification Loop](#11-verification-loop)
  - [12. Missing Context Gating](#12-missing-context-gating)
  - [13. Action Safety](#13-action-safety)
  - [14. Vision \& Computer Use（detail パラメータ）](#14-vision--computer-usedetail-パラメータ)
  - [15. Citation Rules](#15-citation-rules)
  - [16. Grounding Rules](#16-grounding-rules)
  - [17. Research Mode](#17-research-mode)
  - [18. Structured Output Contract](#18-structured-output-contract)
  - [19. BBox Extraction](#19-bbox-extraction)
  - [20. Coding Tasks](#20-coding-tasks)
    - [Autonomy \& Persistence](#autonomy--persistence)
    - [User Updates Spec](#user-updates-spec)
    - [Formatting Rules](#formatting-rules)
    - [Terminal Tool Hygiene](#terminal-tool-hygiene)
  - [21. Frontend Tasks](#21-frontend-tasks)
  - [22. Personality \& Customer-Facing Workflows](#22-personality--customer-facing-workflows)
    - [Personality \& Writing Controls](#personality--writing-controls)
    - [Memo Mode](#memo-mode)
  - [23. Phase Parameter](#23-phase-parameter)
  - [24. Reasoning Effort 推奨](#24-reasoning-effort-推奨)
    - [Dig Deeper Nudge](#dig-deeper-nudge)
  - [25. Compaction for Long Sessions](#25-compaction-for-long-sessions)
  - [26. Small Model Guidance（gpt-5.4-mini / nano）](#26-small-model-guidancegpt-54-mini--nano)
  - [27. Migration Path](#27-migration-path)
  - [28. Suggested Prompt Structure](#28-suggested-prompt-structure)

---

## 1. 強み・弱みの概要

**Strengths**: Strong personality/tone adherence, agentic workflow robustness, evidence-rich synthesis, instruction adherence, long-context analysis, parallel tool calling, spreadsheet/finance workflows.

**Areas needing explicit prompting**: Low-context tool routing, dependency-aware workflows, reasoning effort selection, research tasks, irreversible actions, terminal environments.

## 2. Output Contract

```xml
<output_contract>
- Return exactly the sections requested, in the requested order.
- If the prompt defines a preamble, analysis block, or working section, do not treat it as extra output.
- Apply length limits only to the section they are intended for.
- If a format is required (JSON, Markdown, SQL, XML), output only that format.
</output_contract>
```

## 3. Verbosity Controls

```xml
<verbosity_controls>
- Prefer concise, information-dense writing.
- Avoid repeating the user's request.
- Keep progress updates brief.
- Do not shorten the answer so aggressively that required evidence, reasoning, or completion checks are omitted.
</verbosity_controls>
```

## 4. Default Follow-Through Policy

```xml
<default_follow_through_policy>
- If the user's intent is clear and the next step is reversible and low-risk, proceed without asking.
- Ask permission only if the next step is:
  (a) irreversible,
  (b) has external side effects (for example sending, purchasing, deleting, or writing to production), or
  (c) requires missing sensitive information or a choice that would materially change the outcome.
- If proceeding, briefly state what you did and what remains optional.
</default_follow_through_policy>
```

## 5. Instruction Priority

```xml
<instruction_priority>
- User instructions override default style, tone, formatting, and initiative preferences.
- Safety, honesty, privacy, and permission constraints do not yield.
- If a newer user instruction conflicts with an earlier one, follow the newer instruction.
- Preserve earlier instructions that do not conflict.
</instruction_priority>
```

## 6. Tool Persistence Rules

```xml
<tool_persistence_rules>
- Use tools whenever they materially improve correctness, completeness, or grounding.
- Do not stop early when another tool call is likely to materially improve correctness or completeness.
- Keep calling tools until:
  (1) the task is complete, and
  (2) verification passes (see <verification_loop>).
- If a tool returns empty or partial results, retry with a different strategy.
</tool_persistence_rules>
```

## 7. Dependency Checks

```xml
<dependency_checks>
- Before taking an action, check whether prerequisite discovery, lookup, or memory retrieval steps are required.
- Do not skip prerequisite steps just because the intended final action seems obvious.
- If the task depends on the output of a prior step, resolve that dependency first.
</dependency_checks>
```

## 8. Parallel Tool Calling

```xml
<parallel_tool_calling>
- When multiple retrieval or lookup steps are independent, prefer parallel tool calls to reduce wall-clock time.
- Do not parallelize steps that have prerequisite dependencies or where one result determines the next action.
- After parallel retrieval, pause to synthesize the results before making more calls.
- Prefer selective parallelism: parallelize independent evidence gathering, not speculative or redundant tool use.
</parallel_tool_calling>
```

## 9. Completeness Contract

```xml
<completeness_contract>
- Treat the task as incomplete until all requested items are covered or explicitly marked [blocked].
- Keep an internal checklist of required deliverables.
- For lists, batches, or paginated results:
  - determine expected scope when possible,
  - track processed items or pages,
  - confirm coverage before finalizing.
- If any item is blocked by missing data, mark it [blocked] and state exactly what is missing.
</completeness_contract>
```

## 10. Empty Result Recovery

```xml
<empty_result_recovery>
If a lookup returns empty, partial, or suspiciously narrow results:
- do not immediately conclude that no results exist,
- try at least one or two fallback strategies,
  such as:
  - alternate query wording,
  - broader filters,
  - a prerequisite lookup,
  - or an alternate source or tool,
- Only then report that no results were found, along with what you tried.
</empty_result_recovery>
```

## 11. Verification Loop

```xml
<verification_loop>
Before finalizing:
- Check correctness: does the output satisfy every requirement?
- Check grounding: are factual claims backed by the provided context or tool outputs?
- Check formatting: does the output match the requested schema or style?
- Check safety and irreversibility: if the next step has external side effects, ask permission first.
</verification_loop>
```

## 12. Missing Context Gating

```xml
<missing_context_gating>
- If required context is missing, do NOT guess.
- Prefer the appropriate lookup tool when the missing context is retrievable; ask a minimal clarifying question only when it is not.
- If you must proceed, label assumptions explicitly and choose a reversible action.
</missing_context_gating>
```

## 13. Action Safety

```xml
<action_safety>
- Pre-flight: summarize the intended action and parameters in 1-2 lines.
- Execute via tool.
- Post-flight: confirm the outcome and any validation that was performed.
</action_safety>
```

## 14. Vision & Computer Use（detail パラメータ）

| 値 | 用途 |
|---|---|
| `high` | 標準の高精細理解 |
| `original` | 大規模・密集・空間的に敏感な画像（computer use、OCR、クリック精度） |
| `low` | 速度・コストが精度より重要な場合 |

## 15. Citation Rules

```xml
<citation_rules>
- Only cite sources retrieved in the current workflow.
- Never fabricate citations, URLs, IDs, or quote spans.
- Use exactly the citation format required by the host application.
- Attach citations to the specific claims they support, not only at the end.
</citation_rules>
```

## 16. Grounding Rules

```xml
<grounding_rules>
- Base claims only on provided context or tool outputs.
- If sources conflict, state the conflict explicitly and attribute each side.
- If the context is insufficient or irrelevant, narrow the answer or say you cannot support the claim.
- If a statement is an inference rather than a directly supported fact, label it as an inference.
</grounding_rules>
```

## 17. Research Mode

```xml
<research_mode>
- Do research in 3 passes:
  1) Plan: list 3-6 sub-questions to answer.
  2) Retrieve: search each sub-question and follow 1-2 second-order leads.
  3) Synthesize: resolve contradictions and write the final answer with citations.
- Stop only when more searching is unlikely to change the conclusion.
</research_mode>
```

## 18. Structured Output Contract

```xml
<structured_output_contract>
- Output only the requested format.
- Do not add prose or markdown fences unless they were requested.
- Validate that parentheses and brackets are balanced.
- Do not invent tables or fields.
- If required schema information is missing, ask for it or return an explicit error object.
</structured_output_contract>
```

## 19. BBox Extraction

```xml
<bbox_extraction_spec>
- Use the specified coordinate format exactly, such as [x1,y1,x2,y2] normalized to 0..1.
- For each box, include page, label, text snippet, and confidence.
- Add a vertical-drift sanity check so boxes stay aligned with the correct line of text.
- If the layout is dense, process page by page and do a second pass for missed items.
</bbox_extraction_spec>
```

## 20. Coding Tasks

### Autonomy & Persistence

```xml
<autonomy_and_persistence>
Persist until the task is fully handled end-to-end within the current turn whenever feasible: do not stop at analysis or partial fixes; carry changes through implementation, verification, and a clear explanation of outcomes unless the user explicitly pauses or redirects you.

Unless the user explicitly asks for a plan, assumes the user wants code changes or tool usage to solve the problem. Implement rather than propose unless intent is clearly exploratory.
</autonomy_and_persistence>
```

### User Updates Spec

```xml
<user_updates_spec>
- Only update the user when starting a new major phase or when something changes the plan.
- Each update: 1 sentence on outcome + 1 sentence on next step.
- Do not narrate routine tool calls.
- Keep the user-facing status short; keep the work exhaustive.
</user_updates_spec>
```

### Formatting Rules

> Never use nested bullets. Keep lists flat (single level)... For numbered lists, only use the `1. 2. 3.` style markers (with a period), never `1)`.

### Terminal Tool Hygiene

```xml
<terminal_tool_hygiene>
- Only run shell commands via the terminal tool.
- Never "run" tool names as shell commands.
- If a patch or edit tool exists, use it directly; do not attempt it in bash.
- After changes, run a lightweight verification step such as ls, tests, or a build before declaring the task done.
</terminal_tool_hygiene>
```

## 21. Frontend Tasks

```xml
<frontend_tasks>
When doing frontend design tasks, avoid generic, overbuilt layouts.

Use these hard rules:
- One composition: The first viewport must read as one composition, not a dashboard, unless it is a dashboard.
- Brand first: On branded pages, the brand or product name must be a hero-level signal, not just nav text or an eyebrow. No headline should overpower the brand.
- Brand test: If the first viewport could belong to another brand after removing the nav, the branding is too weak.
- Full-bleed hero only: On landing pages and promotional surfaces, the hero image should usually be a dominant edge-to-edge visual plane or background. Do not default to inset hero images, side-panel hero images, rounded media cards, tiled collages, or floating image blocks unless the existing design system clearly requires them.
- Hero budget: The first viewport should usually contain only the brand, one headline, one short supporting sentence, one CTA group, and one dominant image. Do not place stats, schedules, event listings, address blocks, promos, "this week" callouts, metadata rows, or secondary marketing content there.
- No hero overlays: Do not place detached labels, floating badges, promo stickers, info chips, or callout boxes on top of hero media.
- Cards: Default to no cards. Never use cards in the hero unless they are the container for a user interaction. If removing a border, shadow, background, or radius does not hurt interaction or understanding, it should not be a card.
- One job per section: Each section should have one purpose, one headline, and usually one short supporting sentence.
- Real visual anchor: Imagery should show the product, place, atmosphere, or context.
- Reduce clutter: Avoid pill clusters, stat strips, icon rows, boxed promos, schedule snippets, and competing text blocks.
- Use motion to create presence and hierarchy, not noise. Ship 2-3 intentional motions for visually led work, and prefer Framer Motion when it is available.

Exception: If working within an existing website or design system, preserve the established patterns, structure, and visual language.
</frontend_tasks>
```

## 22. Personality & Customer-Facing Workflows

### Personality & Writing Controls

```xml
<personality_and_writing_controls>
- Persona: <one sentence>
- Channel: <Slack | email | memo | PRD | blog>
- Emotional register: <direct/calm/energized/etc.> + "not <overdo this>"
- Formatting: <ban bullets/headers/markdown if you want prose>
- Length: <hard limit, e.g. <=150 words or 3-5 sentences>
- Default follow-through: if the request is clear and low-risk, proceed without asking permission.
</personality_and_writing_controls>
```

### Memo Mode

```xml
<memo_mode>
- Write in a polished, professional memo style.
- Use exact names, dates, entities, and authorities when supported by the record.
- Follow domain-specific structure if one is requested.
- Prefer precise conclusions over generic hedging.
- When uncertainty is real, tie it to the exact missing fact or conflicting source.
- Synthesize across documents rather than summarizing each one independently.
</memo_mode>
```

## 23. Phase Parameter

Responses API のツール多用フローでは `phase` を使い、中間更新と最終回答を区別する。

| 値 | 用途 |
|---|---|
| `commentary` | 中間のユーザー可視更新（プリアンブル、進捗説明） |
| `final_answer` | 完成した最終回答 |

ルール:

- 過去の assistant アイテムを再生する際は `phase` 値を厳密に保持
- ユーザーメッセージには `phase` を付けない
- `phase` の欠落・誤りは、preamble が最終回答として誤認される原因になる

## 24. Reasoning Effort 推奨

| レベル | 推奨用途 |
|---|---|
| `none` | 高速・コスト/レイテンシ最優先タスク |
| `low` | レイテンシ重視で僅かな思考利得が欲しいワークロード |
| `medium` | 真の推論が必要なタスク（perf gain で選ぶ） |
| `high` | 同上、より重い推論 |
| `xhigh` | デフォルト不可。長時間 agentic な reasoning-heavy タスクで eval が利得を示した場合のみ |

スタートポイント:

- 実行重視ワークロード（triage、抽出）: `none`
- 研究重視ワークロード（合成、レビュー）: `medium` 以上
- GPT-5.4 のアクション選択 / ツール規律: `none` で十分なことが多い

effort を上げる前に追加推奨:

- `<completeness_contract>`
- `<verification_loop>`
- `<tool_persistence_rules>`

### Dig Deeper Nudge

```xml
<dig_deeper_nudge>
- Don't stop at the first plausible answer.
- Look for second-order issues, edge cases, and missing constraints.
- If the task is safety or accuracy critical, perform at least one verification step.
</dig_deeper_nudge>
```

## 25. Compaction for Long Sessions

- マルチアワー推論のコンテキスト制限解除と、長時間会話のセッションリセット回避
- エンドポイント: `/responses/compact`、主要マイルストーン後に呼ぶ
- 圧縮されたアイテムは不透明な状態として扱う
- 圧縮後もプロンプトは機能的に同一に保つ
- ZDR 互換、`encrypted_content` を返却

## 26. Small Model Guidance（gpt-5.4-mini / nano）

**gpt-5.4-mini の特性**:

- より literal、暗黙の推論が少ない
- 構造化された指示に強い
- 暗黙的なワークフローには弱い
- 抑制しないとフォローアップ質問を発しがち

**mini プロンプティングの 7 原則**:

1. 重要ルールを最初に置く
2. ツール使用の完全な実行順序を指定
3. 構造的足場（番号付きステップ、判定ルール）を使う
4. 「アクション実行」と「アクション報告」を分離
5. 曖昧時の挙動を明示的に定義
6. パッケージング（長さ、フォローアップ挙動、引用スタイル、セクション順）を直接指定
7. 「output nothing else」は使わず、スコープ指定を選ぶ

**gpt-5.4-nano**:

- 狭く well-bounded なタスクのみで使用
- closed output（ラベル、列挙、短い JSON、テンプレート）を選ぶ
- マルチステップ調整は避ける
- 曖昧 / 計画タスクは強モデルにルーティング

**小型モデル向けの良いパターン**:

1. Task
2. Critical rule
3. Exact step order
4. Edge cases / clarification behavior
5. Output format
6. One correct example

## 27. Migration Path

「One change at a time」原則: モデル切替 → `reasoning_effort` 固定 → eval → 反復。

| 現在の設定 | 推奨スタート | 備考 |
|---|---|---|
| `gpt-5.2` | 現在の reasoning effort を維持 | 既存プロファイルをまず保つ |
| `gpt-5.3-codex` | 現在の reasoning effort を維持 | コーディングプロファイルを保つ |
| `gpt-4.1` / `gpt-4o` | `none` | snappy を保ち、eval 回帰時のみ上げる |
| Research-heavy | `medium` または `high` | 明示的な research 多段 + citation gating を併用 |
| Long-horizon agents | `medium` または `high` | tool persistence + completeness accounting を追加 |

## 28. Suggested Prompt Structure

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
