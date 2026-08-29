---
name: python-dev-guide
description: uv + ruff を使った Python 開発の支援スキル。プロジェクト固有の構成、コーディング規約、推奨ツールのガイドラインを提供する。Python プロジェクトの新規作成、pyproject.toml の設定、型チェック・Lint・テスト等の技術選定、プロジェクト構成の整備に使用する。
allowed-tools:
  - Write
  - Read
  - Edit
  - Glob
  - Bash(uv:*)
  - Bash(git:*)
---

# Python Development Guide

## Tech Stack

uv + ruff を標準とし、Python 3.14+ を対象として最新の言語機能を活用する。

## Common Commands

```bash
uv run python -m {package_name}  # 実行
uv run pytest                    # テスト実行
uv run ruff check .              # Lint チェック
uv run ruff format .             # フォーマット
uv run mypy src/                 # 型チェック
```

## pyproject.toml

[references/pyproject-toml.md](references/pyproject-toml.md) を唯一の定義とする。uv / ruff / mypy / pyright / pytest / coverage / bandit / build-system / dependency-groups の設定はすべてそこにある。

## Project Structure

```text
{project_name}/
├── src/
│   └── {package_name}/
│       ├── __init__.py
│       └── __main__.py      # エントリーポイント (`python -m {package_name}`)
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

- 型ヒントを積極的に使用し、mypy strict モードで検証
- 外部データのバリデーションには Pydantic を使用
- コードスタイルは ruff で統一
- テストは pytest を使用
- シンプルな設計を優先し、過度な抽象化を避ける

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

# Optional/Union は X | Y 構文で書く（typing.Optional / typing.Union は使わない）
def find_user(user_id: int) -> dict | None: ...

# ジェネリクスは PEP 695 構文で書く（typing.TypeVar は使わない）
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

# 4. カバレッジ確認 (pyproject の addopts で常に付くのでレポートを読むだけ)
uv run pytest
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

`cd` を含む複合コマンドは実行のたびに権限プロンプトを誘発し、シェルの作業ディレクトリも呼び出しをまたいで保持されない。`cd` せずに `git init <dir>` と `uv --directory` で対象を指定する。

```bash
git init {project_name}
uv venv --directory {project_name}
uv sync --directory {project_name}
uv run --directory {project_name} pre-commit autoupdate
uv run --directory {project_name} pre-commit install
```

## Security

bandit はテンプレートの dev グループに入っているのでそのまま実行できる。pip-audit だけは入っていないので、依存関係の監査をする回に追加する。

```bash
uv run bandit -r src/                   # コードのセキュリティ脆弱性
uv add --dev pip-audit && uv run pip-audit   # 依存関係の脆弱性
```
