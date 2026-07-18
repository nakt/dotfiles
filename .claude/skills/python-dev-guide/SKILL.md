---
name: python-dev-guide
description: uv + ruff を使った Python 開発の支援スキル。プロジェクト固有の構成、コーディング規約、推奨ツールのガイドラインを提供する。Python プロジェクトの新規作成、pyproject.toml の設定、型チェック・Lint・テスト等の技術選定、プロジェクト構成の整備に使用する。
allowed-tools:
  - Write
  - Read
  - Glob
  - Bash(uv:*)
  - Bash(git:*)
  - Bash(mkdir:*)
---

# Python Development Guide

## Tech Stack

uv + ruff を標準とする。

## Quick Start

```bash
mkdir my-app && cd my-app
git init
uv init
uv add -d ruff mypy pytest
uv venv && uv sync
```

## Common Commands

```bash
uv run python src/main.py        # 実行
uv run pytest                    # テスト実行
uv run ruff check .              # Lint チェック
uv run ruff format .             # フォーマット
uv run mypy src/                 # 型チェック
```

## Recommended pyproject.toml

```toml
[project]
requires-python = ">=3.12"

[tool.uv]
exclude-newer = "1 week"

[tool.ruff]
target-version = "py312"
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]

[tool.mypy]
python_version = "3.12"
strict = true
```

## Project Structure

```text
{project_name}/
├── src/
│   └── {package_name}/
│       └── __init__.py
├── tests/
│   ├── __init__.py
│   └── conftest.py
├── .gitignore
├── .pre-commit-config.yaml
├── pyproject.toml
└── README.md
```

- `package_name` は `project_name` のハイフンをアンダースコアに変換したもの

## Coding Conventions

- 一時コメントには `TODO` / `FIXME` ラベルを使用
- 型ヒントを積極的に使用し、mypy strict モードで検証
- 外部データのバリデーションには Pydantic を使用
- コードスタイルは ruff で統一
- テストは pytest を使用

### Docstring

reStructuredText (Sphinx) 形式で英語記述。

```python
def calculate_area(length: float, width: float) -> float:
    """
    Calculate the area of a rectangle.

    :param length: The length of the rectangle in meters
    :param width: The width of the rectangle in meters
    :return: The area in square meters
    :raises ValueError: If length or width is negative
    """
    if length < 0 or width < 0:
        raise ValueError("Length and width must be positive values")
    return length * width
```

### Type Hints

```python
from typing import Protocol

# X | Y 構文 (Python 3.10+)
def find_user(user_id: int) -> dict | None: ...

# Generics (PEP 695, Python 3.12+)
class Container[T]:
    def __init__(self, value: T) -> None:
        self.value = value

# Protocol (structural subtyping)
class Drawable(Protocol):
    def draw(self) -> None: ...
```

### Error Handling

```python
import logging

logger = logging.getLogger(__name__)


def process_file(file_path: str) -> dict:
    """
    :raises FileNotFoundError: If the file doesn't exist
    :raises PermissionError: If the file cannot be read
    """
    logger.info(f"Processing file: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        return {"status": "success", "data": f.read()}
```

## Decision Guide

### Type Strategy

| Situation | Choice | Rationale |
|---|---|---|
| API response | Pydantic model | Runtime validation + type safety |
| Internal data | dataclass / TypedDict | Lightweight, stdlib |
| Config | Pydantic Settings | Env vars + validation |
| String literals | Literal type | Exhaustive check |

### Error Handling Strategy

| Situation | Choice | Rationale |
|---|---|---|
| Recoverable error | Custom exception | Explicit error hierarchy |
| Unexpected error | Let it propagate | Catch at upper level |
| External input | Pydantic | Unified parsing and validation |

## TDD Workflow

```bash
# 1. テストを先に書く
uv run pytest tests/test_feature.py -v

# 2. 最小実装
uv run pytest tests/test_feature.py

# 3. リファクタリング
uv run ruff format . && uv run ruff check --fix .

# 4. カバレッジ確認
uv run pytest --cov=src/
```

## Project Init Workflow

新規プロジェクト作成時は以下のワークフローに従う。

### 1. プロジェクト情報の確認

ユーザーに以下を確認する:

- プロジェクト名（ディレクトリ名・パッケージ名に使用）
- プロジェクトの簡単な説明（pyproject.toml の description に使用）
- 作成先ディレクトリ（デフォルト: カレントディレクトリ配下）

### 2. テンプレートからファイル生成

各テンプレートは `references/` ディレクトリを参照:

- `.gitignore` → [references/gitignore.md](references/gitignore.md)
- `pyproject.toml` → [references/pyproject-toml.md](references/pyproject-toml.md)
- `.pre-commit-config.yaml` → [references/pre-commit-config.md](references/pre-commit-config.md)

テンプレート内のプレースホルダを置換:

- `{project_name}`: プロジェクト名
- `{package_name}`: パッケージ名（ハイフン → アンダースコア）
- `{description}`: プロジェクトの説明

### 3. 環境セットアップ

```bash
cd {project_name}
git init
uv venv
uv sync
uv run pre-commit autoupdate
uv run pre-commit install
```

テンプレートの `rev` はプレースホルダなので、`pre-commit autoupdate` で必ず最新バージョンに更新する。

## Security

```bash
uv add --dev bandit pip-audit
uv run bandit -r src/                   # コードのセキュリティ脆弱性
uv run pip-audit                        # 依存関係の脆弱性
```

## AI Tool Usage Notes

Claude Code や Gemini CLI から Python プロジェクトを操作する際:

- パッケージ管理は `uv add` / `uv sync` / `uv remove` を使用（`pip install` を避ける）
- `pyproject.toml` と `uv.lock` の両方をコミット
- 仮想環境外へのインストールは禁止
- テスト実行前に `uv run ruff format .` を通す

## Key Principles

1. uv + ruff の技術スタックを使用する
2. Python 3.12+ を対象とし、最新の言語機能を活用する
3. mypy strict モードで型安全性を強化
4. 型ヒントを積極的に使用する
5. 外部データのバリデーションには Pydantic を使用
6. コードスタイルは ruff で統一する
7. シンプルな設計を優先し、過度な抽象化を避ける
