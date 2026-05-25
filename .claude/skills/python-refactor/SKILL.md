---
name: python-refactor
description: Python コードの計測駆動リファクタリング支援。radon/lizard/vulture/pylint で計測し、複雑性削減・デッドコード除去・類似処理の共通化・マジックナンバー定数化を行う。「Python の複雑度を下げて」「Python の重複を統合」「Python のマジックナンバーを定数化」と言われたとき、または引数 complexity/code-health/dedupe/magic-numbers/full でモード指定された場合に使用する。
argument-hint: "[full|complexity|code-health|dedupe|magic-numbers] [path]"
effort: high
allowed-tools:
  - Read
  - Edit
  - Glob
  - Grep
  - Bash(uv:*)
  - Bash(git:*)
  - Bash(ls:*)
  - Bash(find:*)
  - Bash(grep:*)
---

# Python Refactor

Python プロジェクト専用の計測駆動リファクタリング支援。計測ツール (radon / lizard / vulture / pylint) の出力をもとに、複雑性削減・デッドコード除去・類似処理の共通化・マジックナンバー定数化を進める。

`$ARGUMENTS` の第 1 引数でモードを指定して個別実行できる。指定なしならフルモードで全フェーズを順に実施する。

## refactor-code との棲み分け

| スキル | 対象 | 駆動 |
| --- | --- | --- |
| `refactor-code` | 任意言語の汎用リファクタリング | 手作業ベース、6 フェーズ |
| `python-refactor` | Python 限定 | 計測ツール駆動、モード分岐対応 |

Python プロジェクトで計測値を見ながら進めたいなら本スキル、それ以外、または計測ツールを入れる前の整理は `refactor-code` を使う。

## 機能インデックス

個別実行したいモードを引数に渡す。`$ARGUMENTS` の第 1 トークンがモード、第 2 トークンが対象パス (省略時は `.`)。

| モード | 引数 | 目的 | 主要ツール | 参照 |
| --- | --- | --- | --- | --- |
| フル | (空) または `full` | 全フェーズ順次実行 | radon / lizard / vulture / pylint | 本ファイル全体 |
| 複雑性削減 | `complexity` | cyclomatic / cognitive 削減 | radon, lizard, wily | [references/complexity.md](references/complexity.md) |
| コード健全性 | `code-health` | デッドコード除去・コメント整理 | vulture | [references/code-health.md](references/code-health.md) |
| 類似処理共通化 | `dedupe` | パラメタライズ・設定駆動化・命名統一 | pylint, grep | [references/dedupe.md](references/dedupe.md) |
| マジックナンバー定数化 | `magic-numbers` | 数値・文字列を定数 / Config 化 | grep, ruff | [references/magic-numbers.md](references/magic-numbers.md) |

計測コマンドとツール一覧はすべて [references/tools.md](references/tools.md) に集約。

## 引数によるモード分岐

第 1 トークンを以下と完全一致で照合する (大文字小文字は区別、ハイフン必須)。

- `complexity` / `code-health` / `dedupe` / `magic-numbers` / `full`

一致しない場合はエラーとし、候補を提示してユーザー確認を取る。例:

```
入力: complex
→ 不明なモード `complex` です。次のいずれかを指定してください: complexity / code-health / dedupe / magic-numbers / full
```

引数なしまたは `full` の場合、Phase 0 → 5 を順に実行する。それ以外は Phase 0 (準備) → Phase 1 の該当モード計測のみ → Phase 2 の該当改善 → Phase 4 (検証) → Phase 5 (ドキュメント整合) を実行する。

## Phase 0: 準備

1. `pyproject.toml` を Read し、`[dependency-groups]` の `dev` に必要ツール (モード別の最小セットは [tools.md](references/tools.md) 参照) が揃っているか確認
2. 不足ツールがあればユーザーに一覧を提示し承認を得る:

   ```
   このモード (例: complexity) には radon, lizard, wily が必要ですが、現在 pyproject.toml に含まれていません。
   `uv add --dev radon lizard wily` で追加してよいですか？
   ```
3. 承認後に `uv add --dev <tools>` を実行し、`uv sync` で同期
4. `uv run pytest` を実行し、ベースラインのテストグリーンを確認。失敗があればリファクタリング前に修正する旨をユーザーに通知

## Phase 1: 計測

該当モードの計測コマンドを `uv run <tool>` 形式で実行し、結果を標準出力にそのまま提示する。ファイル保存はしない (`reports/` ディレクトリは作らない)。

出力例の解釈 (各モードの読み方):

- complexity: 関数単位で C 以上のランクが付いた箇所を改善対象として要約
- code-health: 信頼度別に分類し、80% 以上を主対象、60-70% は偽陽性候補として注意喚起
- dedupe: 6 行以上の重複ブロックを箇所ペアでリスト化
- magic-numbers: ファイル × 行 × リテラル値で表化

完全なコマンド一覧は [references/tools.md](references/tools.md) を参照。

## Phase 2: 改善 (モード別)

該当 references ファイルのパターンを適用する。SKILL.md には各モード 1 例だけ載せる。

### complexity モード例 (Guard Clauses)

```python
# BEFORE
def get_user_status(user):
    if user:
        if user.is_active:
            if user.is_verified:
                return "ok"
    return "denied"

# AFTER
def get_user_status(user):
    if user is None or not user.is_active or not user.is_verified:
        return "denied"
    return "ok"
```

→ 詳細パターン: [references/complexity.md](references/complexity.md)

### code-health モード例 (Remove Commented Code)

```python
# BEFORE
def total(items):
    # total = 0
    # for i in items: total += i.price
    # return total
    return sum(i.price for i in items)

# AFTER
def total(items):
    return sum(i.price for i in items)
```

→ 詳細パターン: [references/code-health.md](references/code-health.md)

### dedupe モード例 (Configuration Over Duplication)

```python
# BEFORE
def process_csv(p): return parse(p, delimiter=",")
def process_tsv(p): return parse(p, delimiter="\t")

# AFTER
FORMATS = {"csv": ",", "tsv": "\t"}
def process_file(p, fmt): return parse(p, delimiter=FORMATS[fmt])
```

→ 詳細パターン: [references/dedupe.md](references/dedupe.md)

### magic-numbers モード例 (Extract to Constants)

```python
# BEFORE
if amount < 100:
    fee = 2.50

# AFTER
from typing import Final
SMALL_AMOUNT_THRESHOLD: Final = 100
SMALL_FEE: Final = 2.50

if amount < SMALL_AMOUNT_THRESHOLD:
    fee = SMALL_FEE
```

→ 詳細パターン: [references/magic-numbers.md](references/magic-numbers.md)

各改善ステップの後で `uv run pytest` を流し、テストがグリーンであることを確認する。

## Phase 3: 横断適用順 (フルモードのみ)

複数モードをまとめて適用するときは以下の順で行う。理由は、後段の効果が前段の整理に依存するため。

1. `code-health` — デッドコードを先に消してノイズを減らす
2. `dedupe` — 残ったコードの重複を統合
3. `magic-numbers` — 統合後の関数で散らばっていた定数を整理
4. `complexity` — 上記で簡素になったコードに対し最終的な複雑度調整

## Phase 4: 検証

```bash
uv run pytest                         # テストグリーン
uv run ruff check .                   # Lint
uv run ruff format --check .          # フォーマット
uv run mypy .                         # 型チェック
uv run radon cc . -n C                # 複雑度ゲート
uv run vulture . --min-confidence 80  # デッドコード再確認
uv run wily diff HEAD~1               # 改善度
```

完全な検証コマンドリストは [references/tools.md](references/tools.md) の「最終検証コマンド一式」を参照。

## Phase 5: ドキュメント整合性チェック

リファクタリングで生じた構造変更がドキュメントと乖離していないか確認し、必要なら更新へ誘導する。

判定とアクション:

| 対象 | 判定基準 | アクション |
| --- | --- | --- |
| `docs/arch/` | 存在し、かつ処理フロー・モジュール構造・公開 API が変更された | `update-arch` スキルの呼び出しを提案 |
| `README.md` | Quick Start / コマンド例 / プロジェクト構造のいずれかが変更された | `update-readme` スキルの呼び出しを提案 |
| いずれも | 影響なし | 「ドキュメント影響なし: <理由>」を 1 行表示してスキップ |

判定は `git diff --stat` と変更ファイル一覧から自動で見積もり、最終判断はユーザーに確認する。

## 閾値要約

| 観点 | 閾値 |
| --- | --- |
| 循環的複雑度 | C 以上 (≥ 11) で改善対象 |
| 認知的複雑度 | > 15 で改善対象 |
| 保守性指数 | < 65 で改善対象 |
| 1 ファイル行数 | > 500 行で分割検討 |
| 重複コード | ≥ 6 行のブロックは統合検討 |
| デッドコード信頼度 | ≥ 80% で削除候補 |

根拠と詳細は [references/tools.md](references/tools.md) を参照。

## スコープ外

以下は本スキルでは扱わない。

- セキュリティスキャン (bandit / ruff S ルール)
- テストカバレッジ・ミューテーションテスト (pytest-cov / mutmut)
- 構文モダナイズ (pyupgrade / ruff UP ルール)
- 品質ツール初期設定 (ruff / mypy 設定) — `python-dev-guide` を参照
- pre-commit セットアップ — `python-dev-guide` を参照

必要に応じて参考リポ [l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) の py-security / py-test-quality / py-modernize / py-quality-setup / py-git-hooks を直接参照する。

## Key Principles

1. 計測 → 改善 → 検証 → ドキュメント整合の順を守る
2. テストグリーンを維持。テスト未整備のコードは先にテストを書く
3. 大きな構造変更の前にユーザー確認を取る
4. 過抽象化を避ける (`dedupe` の 3 回ルール参照)
5. 出力・対話は日本語、コード内コメントは英語

## 出典

[l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT, Copyright 2025 Lars Marowsky-Brée) の py-refactor / py-complexity / py-code-health を参考に、dotfiles の規約 (`python-dev-guide`、`markdown-style`) に合わせて再構成。
