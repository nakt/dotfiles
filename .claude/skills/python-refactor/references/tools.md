# 計測ツールリファレンス

`python-refactor` で使用する計測ツールの一覧、閾値、インストール方法、コマンド集。

コマンドと閾値の正典はこのファイル。SKILL.md と各パターン references (complexity / code-health / dedupe / magic-numbers) はコマンドと閾値を再掲せず、ここを参照する。

## ツール一覧

| ツール | 用途 | 閾値 | 主要オプション |
| --- | --- | --- | --- |
| radon | 循環的複雑度 / 保守性指数 | cyclomatic ≥ 11 (C ランク以上)、MI < 65 | `cc -n C -s`、`mi -n B` |
| lizard | 認知的複雑度 / 行数 | cognitive > 15、関数行数 > 50 | `-C 15 -L 50` |
| wily | 複雑性トレンドの履歴追跡 | — | `build .` で初期化、`diff HEAD~1` で差分 |
| vulture | デッドコード検出 (AST 解析) | confidence ≥ 80 で削除候補 | `--min-confidence 80` |
| pylint | 重複コード検出 | duplicate-code-min-lines = 6 | `--disable=all --enable=duplicate-code` |
| ruff | Lint / Format / マジックナンバー検出 | PLR2004 の報告 0 件 | `check`、`format`、`check --select PLR2004` |
| mypy | 型チェック | strict | `--strict` |
| pytest | テスト実行 | 全テストグリーン | — |

ruff の `S` (セキュリティ) と `UP` (構文モダナイズ) は SKILL.md の「スコープ外」に挙げているため、本スキルでは扱わない。本スキルが ruff に使うのは Lint / Format と `PLR2004` (magic value) のみ。

### 閾値の補足

- 1 ファイル > 500 行で分割検討。専用ツールは使わず、lizard の NLOC 出力または目視で判断する
- 重複コードの閾値は 6 行。pylint の既定は 4 行なので `--duplicate-code-min-lines=6` を必ず明示する
- 重複を統合するかどうかは行数だけでは決まらない。出現箇所数を含む判断基準は [dedupe.md](dedupe.md) の「過抽象化への警戒」を参照

## モード別の最小ツールセット

| モード | 必須ツール | 追加インストール |
| --- | --- | --- |
| complexity | radon, lizard, wily | `uv add --dev radon lizard wily` |
| code-health | vulture | `uv add --dev vulture` |
| dedupe | pylint | `uv add --dev pylint` |
| magic-numbers | grep のみ (ruff は任意) | 不要 |
| full | radon, lizard, wily, vulture, pylint | `uv add --dev radon lizard wily vulture pylint` |

`ruff` / `mypy` / `pytest` は `python-dev-guide` のテンプレートで既に dev グループに入っている前提。入っていなければ Phase 0 で不足として提示する。

## 依存関係の追加

`python-dev-guide` のテンプレート ([pyproject-toml.md](../../python-dev-guide/references/pyproject-toml.md)) の `[dependency-groups]` の `dev` は `ruff` / `mypy` / `pytest` / `pytest-cov` / `coverage` / `pre-commit` / `bandit`。本スキルはここに計測ツールを追記するだけで、既存エントリは削除しない。削除すると python-dev-guide 側のカバレッジ・pre-commit・bandit の手順が動かなくなる。

追記するエントリ (既存エントリはそのまま残す):

```toml
"radon",
"lizard",
"wily",
"vulture",
"pylint",
```

追記は `uv add --dev` が自動で行うので手で編集する必要はない。Phase 0 では対象モードに必要な分のみをユーザーに提示し、承認を得てから上表の「追加インストール」を実行して `uv sync` する。

## 計測コマンド集 (Phase 1)

すべて `uv run` 経由で実行し、結果は標準出力にそのまま流す (ファイルには保存しない)。

### complexity モード

```bash
uv run radon cc . -n C -s                 # cyclomatic C ランク以上
uv run radon mi . -n B                    # 保守性指数 B 未満
uv run lizard -C 15 -L 50 .               # 認知的複雑度 / 関数行数
uv run wily build .                       # 初回のみ
uv run wily diff HEAD~1                   # 直前コミットからの差分
```

### code-health モード

```bash
uv run vulture . --min-confidence 80                      # 信頼度 80% 以上
uv run vulture . --min-confidence 80 --sort-by-size       # 大きい順
uv run vulture . --min-confidence 80 --exclude tests,.venv
uv run vulture . whitelist.py --min-confidence 80         # 意図的な除外を whitelist で指定
```

### dedupe モード

```bash
uv run pylint --disable=all --enable=duplicate-code \
    --duplicate-code-min-lines=6 --recursive=y .
```

出力の `Similar lines in N files` の N が、そのブロックの出現箇所数。統合するかどうかは N を使って判断する ([dedupe.md](dedupe.md) の「過抽象化への警戒」参照)。

補助的に grep で類似関数名を探す:

```bash
grep -rnE 'def (process|handle|fetch|create|update|delete)_[a-z_]+' \
    --include='*.py' .
```

### magic-numbers モード

```bash
# 2 桁以上の数値リテラル
grep -rnE '\b[0-9]{2,}\b' --include='*.py' .

# 短い文字列リテラル (キーやモード名の候補)
grep -rnE '"[a-zA-Z_]{2,20}"' --include='*.py' . \
    | grep -v 'docstring\|"""'

# ruff の magic value ルール
uv run ruff check . --select PLR2004
```

## 検証コマンド集 (Phase 4)

### 全モード共通

`python-dev-guide` の既定 dev グループに含まれるツールだけを使うので、どのモードでも実行できる。

```bash
uv run pytest                              # テストグリーン維持
uv run ruff check .                        # Lint
uv run ruff format --check .               # フォーマット
uv run mypy .                              # 型チェック
```

### モード別の追加検証

Phase 0 で導入したツールのみを実行する。導入していないモードのコマンドを流すとツールが見つからず失敗するので、起動したモードの行だけを実行する。

| モード | 追加検証コマンド |
| --- | --- |
| complexity | `uv run radon cc . -n C`、`uv run radon mi . -n B`、`uv run lizard -C 15 .`、`uv run wily diff HEAD~1` |
| code-health | `uv run vulture . --min-confidence 80` |
| dedupe | `uv run pylint --disable=all --enable=duplicate-code --duplicate-code-min-lines=6 --recursive=y .` |
| magic-numbers | `uv run ruff check . --select PLR2004` |
| full | 上記 4 モード分すべて |

## 出典

ツール選定と閾値は [l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT, Copyright 2025 Lars Marowsky-Brée) を参考に、dotfiles の `python-dev-guide` 規約に合わせて調整。
