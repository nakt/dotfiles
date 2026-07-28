---
id: 20260715-execute-plan-implementer-self-check-gaps
title: execute-plan の implementer self-check が pre-commit hook / 実 API smoke / プラン合意事項の反映を検知できていない
created: 2026-07-15
updated: 2026-07-15
priority: med
tags:
  - skills
  - execute-plan
related: []
sources:
  - .claude/skills/execute-plan/SKILL.md
  - .claude/skills/execute-plan/references/implementer-prompt.md
  - .claude/skills/execute-plan/references/reviewer-prompt.md
---

## TL;DR

2026-07-15 の swc-voc-analyzer-v3 での execute-plan 実行で、implementer subagent の self-check が (1) ruff format の正しさ、(2) pre-commit hook (bandit) 相当のセルフチェック、(3) CLAUDE.md「Structured Output 実 API 1 コール smoke」規約、(4) プラン合意事項が implementer prompt / 生成コードに落ちているか、の 4 点をカバーできず、いずれもレビュー段階 / commit 段階 / ユーザーによる実行段階で発覚した。individual プロジェクト側の CLAUDE.md 規約を execute-plan 側でも読ませる仕組みを含めて、implementer / reviewer テンプレートを補強する。

## 背景 / 問い

execute-plan を「fresh subagent per task + review + commit」の連続実行として使い始めて実感した摩擦点を、次回改善のために整理しておく。特定プロジェクトの CLAUDE.md 規約に依存した検証を implementer / controller どちらが担うべきかの線引きが曖昧で、プロジェクトを跨いで再現する可能性が高い。

## 調査結果

### 摩擦点 1: ruff format の self-check が信頼できなかった

Task 2 (`tools/synth_channel_audit.py`) の implementer は自己報告で「`uv run ruff format --check` 通過」と主張したが、直後の reviewer が同コマンドで 4 箇所の未フォーマット (f-string の折返し) を検出。

推測される原因:

- implementer が自分の編集ファイルではなくリポジトリ全体で `ruff format --check` を先に走らせ「All checks passed」を見て安心した (他ファイルは既にフォーマット済みなので通る)
- 新規作成直後で editor 上のフォーマットは走ったが、実際に書いたバイト列と ruff の期待に微差があった
- `--check` の対象パスを明示せずに実行した

対処 (今回セッションで controller が実施): `uv run ruff format tools/synth_channel_audit.py && uv run ruff format --check tools/synth_channel_audit.py` を controller が直接実行して修正。

改善案:

- `references/implementer-prompt.md` の「自己レビュー観点」に、対象ファイル明示での実行手順を書く。例:

  ```text
  ruff / lint の self-check は必ず対象ファイルパスを引数に渡して 2 段で走らせる:
  1. `uv run ruff format <対象ファイル>` (実際に fix する)
  2. `uv run ruff format --check <対象ファイル>` (fix が入っていないことを確認)
  3. `uv run ruff check <対象ファイル>`
  リポ全体の `--check` だけで判断しない (他ファイルの pass に紛れる)
  ```

### 摩擦点 2: pre-commit hook (bandit) が controller の commit で初検出

Task 1 (`tools/synth_channel_corpus.py`) を commit しようとしたら pre-commit の bandit が `random.Random(seed)` を B311 で warning → commit fail。implementer は self-check で構文チェック・ruff・import 確認は走らせたが、リポジトリの `.pre-commit-config.yaml` に登録された hook 群は走らせていなかった。

対処: `# nosec B311 - dummy timestamp sampling, not security-sensitive` を追加して再 commit で通過。

改善案:

- `references/implementer-prompt.md` の「実行手順」に「対象ファイルに対する pre-commit hook をローカルで走らせる」を追加:

  ```text
  対象ファイルの pre-commit hook が定義されている場合、以下を走らせて事前に fail を潰す:
    uv run pre-commit run --files <対象ファイル>
    (もしくは `pre-commit run --files <対象ファイル>`)
  hook が無い / pre-commit を使っていないリポでは省略してよい。
  ```

- あるいは execute-plan の Phase 3 のコミット手順で controller が hook 失敗を検知した場合、fresh implementer に「hook のエラー内容」を Context として渡して再委譲するフォールバックを明示する (現状 SKILL.md では「NEEDS_CHANGES → fresh 再委譲」の一般ルールに含まれているが、pre-commit fail が該当することが implementer 側から見えづらい)

### 摩擦点 3: CLAUDE.md「Structured Output 実 API 1 コール smoke」規約が回されなかった

対象プロジェクトの CLAUDE.md には「Structured Output 用レスポンスモデル（`P<n><Phase>Response` 等）を変更したら、モックテストだけで完了とせず、実 API の最小スモーク（1 コール）で strict スキーマ互換を検証する」と明記されていた。今回 `SyntheticEntry` / `SyntheticBatch` という新規 Pydantic モデルを追加したが:

- implementer には「実際の LLM 呼び出しはしないでください (Azure API を消費するため、controller 側で判断)」と controller が指示 → implementer は smoke を回さなかった
- controller (私) も「operational cost なのでユーザーが手動で回す」と判断して回さなかった
- 結果、ユーザーがパイロット実行時に「たまたま」smoke に相当する検証が走った

これは今回運良く問題なかったが、strict スキーマ違反 (`title` フィールド名衝突など、CLAUDE.md 事例のような) が起きていたら user 実行段階で 400 エラーになって混乱していた。

改善案:

- Structured Output を新規追加するタスクでは、controller が implementer に「実 API 1 コール smoke を回す許可」を明示的に付与するテンプレを用意する
- あるいは Phase 3 の「バッチ後チェック」に「Structured Output 変更が入ったタスクは実 API smoke を実施済みか確認」を含める
- ただし CLAUDE.md 規約はプロジェクト固有なので、execute-plan は「プロジェクトの CLAUDE.md を controller が読んで検証項目を implementer prompt に含めた」ことを担保する形が現実的

### 摩擦点 4: プラン合意事項が implementer prompt / 生成コードに落ちない

プランモード段階で AskUserQuestion により「ドメイン: カーディーラーで統一 (推奨)」を明示的に合意していた。しかし implementer prompt からその制約が薄れ、生成された user プロンプトテンプレートには **「話題や業種は自由に変えてよい」** という真逆の記述が書かれた。パイロット実行で 40/40 レコードが car dealer 以外のドメインに流出して初めて発覚。

推測される原因:

- controller が implementer prompt を書く際に、プランの「D 番号 (確定判断)」を全て引用するが、AskUserQuestion で合意した個別項目は D 番号に紐付いていないため取りこぼしがち
- implementer は「seed に car dealer 例が並んでいる」だけを見て、「業種 free」でも文脈的に car dealer になると誤読
- reviewer は仕様適合と品質を見るが、「プラン合意事項 (AskUserQuestion 履歴含む) との整合性」までは検証範囲に入っていない

改善案:

- `references/task-format.md` を更新し、プランに「AskUserQuestion 合意事項」セクション (D 番号と重複してよい) を作る運用を推奨。controller は implementer prompt にそこを丸ごと貼る
- あるいは `references/reviewer-prompt.md` の「仕様適合」観点に「プランの合意事項 (D 番号 + AskUserQuestion 履歴) との整合性」を明示追加
- controller 側の checklist として「AskUserQuestion で確定した項目が implementer prompt に反映されているか」を Phase 2 タスク抽出後に走らせる

## 結論 / プラン

- [ ] `references/implementer-prompt.md` の「実行手順」「自己レビュー観点」に対象ファイル明示での ruff / pre-commit 実行を追記 (摩擦点 1, 2)
- [ ] `references/implementer-prompt.md` に「プロジェクト固有規約 (CLAUDE.md 等) を controller から渡されたら self-check に組み込む」旨を追記 (摩擦点 3)
- [ ] `references/reviewer-prompt.md` の「仕様適合」観点に「プランの合意事項 (D 番号 + AskUserQuestion 履歴) との整合性」を追加 (摩擦点 4)
- [ ] SKILL.md の Phase 3 コミット手順に「pre-commit hook fail は NEEDS_CHANGES として fresh implementer に再委譲」を明示 (摩擦点 2)
- [ ] SKILL.md の Phase 2 (タスク抽出) に「プランの AskUserQuestion 合意事項を implementer prompt に反映」を controller 手順として明示 (摩擦点 4)

## 未解決の論点 / リスク

- 摩擦点 3 の対応は CLAUDE.md 依存 (プロジェクト固有) なので、execute-plan スキル自身が全プロジェクトに共通する規約を持てるわけではない。「controller が CLAUDE.md を読んで implementer prompt に検証項目を組み込む」という個別対応の一般化にとどまる
- 摩擦点 1・2 対応で implementer の実行手順が肥大化すると、trivial なタスクにも重い self-check を課してオーバーヘッドになる懸念。タスクの複雑度に応じたスキップ許容が必要かもしれない
- 摩擦点 4 の AskUserQuestion 合意事項の追跡は、プランを書き終わった時点で明示セクションに寄せる運用 (プラン規約 `~/.claude/rules/plan-files.md` 側の改定) との連携が必要になるかもしれない

## ログ

- 2026-07-15 created
- 2026-07-15 done: 4 摩擦点への補強を execute-plan スキル本体 + plan-files ルールに追加し、言語別コマンドは references/lint-per-language.md に外出しした形で解決
  - 経緯: プラン `.claude/plans/issues-inbox-20260715-execute-plan-imple-elegant-crane.md` を作成 → plan-reviewer で 7 論点の曖昧点抽出 → AskUserQuestion で 4 論点確定 (残り 3 論点は default 採用) → ユーザーから「Python 実装に特化しすぎ」の指摘を受けて言語非依存に再構成 (AskUserQuestion 3 論点追加、原則本文 + References 外出しの二層構造に変更、Task 6 として `references/lint-per-language.md` 新設を追加) → 5 コミットで brancch `chore/execute-plan-self-check-gaps` に実装 (668feab, 474a12a, 7eed3c4, c33dcf2, b511ad2)
  - 学び:
    - execute-plan スキル自身の改善プランを立てるとき、直近セッションが Python プロジェクトだと無自覚に Python 特化 (ruff / uv / pyproject.toml) を持ち込みやすい。言語非依存スキルの改修では「原則を本文、言語別具体は References に外出し」の二層構造で分けると、他言語追加時のコストが下がる
    - プラン合意事項 (AskUserQuestion 履歴) は「D 番号 = 代替案比較で選んだ判断」枠に混ぜず、専用セクション (`## AskUserQuestion 合意事項`) で番号別管理しないと controller が implementer prompt に転記する契約を機械的に守れない
    - self-check 重量化のオーバーヘッド懸念は「設定ファイル検出条件付き実行」で解消できる (lint 設定が無いリポでは自動スキップ)。always-on 化 or per-task on/off より条件検出のほうが implementer の判断コストを下げつつ実運用のフィットを取れる
    - 本プランは自身の変更を dogfooding する構造 (プラン内に `## AskUserQuestion 合意事項` を持ち、新規約に沿った形にしてある) にできた。今後の execute-plan 系プランは同じ dogfood ができる
