# 計測ツールリファレンス

`python-refactor` で使用する計測ツールの一覧、閾値、インストール方法、コマンド集。

## ツール一覧

| ツール | 用途 | 閾値 | 主要オプション |
| --- | --- | --- | --- |
| radon | 循環的複雑度 / 保守性指数 | cyclomatic ≥ 11 (C ランク以上)、MI < 65 | `cc -n C -s`、`mi -n B` |
| lizard | 認知的複雑度 / 行数 | cognitive > 15、関数行数 > 50 | `-C 15 -L 50` |
| wily | 複雑性トレンドの履歴追跡 | — | `build .` で初期化、`diff HEAD~1` で差分 |
| xenon | 閾値ゲート (CI 用) | `--max-absolute C --max-modules B` | パイプライン用 |
| vulture | デッドコード検出 (AST 解析) | confidence ≥ 80 推奨 | `--min-confidence 80` |
| pylint | 重複コード検出 | duplicate-code-min-lines = 6 | `--disable=all --enable=duplicate-code` |
| ruff | Lint / Format | UP / S / B / SIM ルール | `check`、`format` |
| mypy | 型チェック | strict | `--strict` |
| pytest | テスト実行 | カバレッジ ≥ 80% (任意) | `--cov` |

## モード別の最小ツールセット

| モード | 必須ツール |
| --- | --- |
| complexity | radon, lizard, wily |
| code-health | vulture |
| dedupe | pylint |
| magic-numbers | (grep のみで可、ruff は任意) |
| full | radon, lizard, wily, vulture, pylint |

## 依存関係の追加

`pyproject.toml` の `[dependency-groups]` セクションに dev グループとして追加する。`python-dev-guide` のテンプレートに以下を加える。

```toml
[dependency-groups]
dev = [
    "radon",
    "lizard",
    "wily",
    "vulture",
    "pylint",
    "ruff",
    "mypy",
    "pytest",
]
```

インストール:

```bash
uv add --dev radon lizard wily vulture pylint
uv sync
```

不足ツールは Phase 0 で対象モードに必要な分のみを提示し、ユーザー承認を得てから追加する。

## 計測コマンド集

すべて `uv run` 経由で実行し、結果は標準出力にそのまま流す（ファイル保存はしない）。

### Complexity モード

```bash
uv run radon cc . -n C -s                 # cyclomatic C ランク以上
uv run radon mi . -n B                    # 保守性指数 B 未満
uv run lizard -C 15 -L 50 .               # 認知的複雑度 / 関数行数
uv run wily build .                       # 初回のみ
uv run wily diff HEAD~1                   # 直前コミットからの差分
```

### Code Health モード

```bash
uv run vulture . --min-confidence 80                      # 信頼度 80% 以上
uv run vulture . --min-confidence 80 --sort-by-size       # 大きい順
uv run vulture . --min-confidence 80 --exclude tests,.venv
```

### Dedupe モード

```bash
uv run pylint --disable=all --enable=duplicate-code --recursive=y .
uv run pylint --disable=all --enable=duplicate-code \
    --duplicate-code-min-lines=6 --recursive=y .
```

補助的に grep で類似関数名を探す:

```bash
grep -rnE 'def (process|handle|fetch|create)_[a-z_]+' --include='*.py' .
```

### Magic Numbers モード

```bash
# 2 桁以上の数値リテラル
grep -rnE '\b[0-9]{2,}\b' --include='*.py' .

# 短い文字列リテラル (キーやモード名の候補)
grep -rnE '"[a-zA-Z_]{2,20}"' --include='*.py' . \
    | grep -v 'docstring\|"""\|""'

# ruff の M (magic value) ルール
uv run ruff check . --select PLR2004
```

## 最終検証コマンド一式

Phase 4 で実行する。

```bash
uv run pytest                              # テストグリーン維持
uv run ruff check .                        # Lint
uv run ruff format --check .               # フォーマット
uv run mypy .                              # 型チェック
uv run radon cc . -n C                     # 複雑度ゲート
uv run vulture . --min-confidence 80       # デッドコード再確認
uv run wily diff HEAD~1                    # 改善度の可視化
```

## 出典

ツール選定と閾値は [l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT, Copyright 2025 Lars Marowsky-Brée) を参考に、dotfiles の `python-dev-guide` 規約に合わせて調整。
