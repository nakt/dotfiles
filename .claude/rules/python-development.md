---
description: Python 開発ガイド
paths:
  - "**/*.py"
---

# Python 開発ガイド

## クイックスタート

> 新規プロジェクトの場合は `/python-init` スキルでテンプレートを生成できます。

新規プロジェクトの開始手順:

```bash
# 1. 仮想環境を作成
uv venv

# 2. 依存関係をインストール（開発ツール含む）
uv sync --all-extras

# 3. pre-commit フックのセットアップ（更新とインストール）
uv run pre-commit autoupdate
uv run pre-commit install

# 4. セットアップの確認
uv run black --check .
uv run ruff check .
uv run mypy src/
```

## 日常の開発ワークフロー

### 環境管理

#### Python バージョン管理

`pyproject.toml` で最小バージョンを指定する:

```toml
# pyproject.toml
[project]
requires-python = ">=3.12"
```

#### 仮想環境のベストプラクティス

```bash
# プロジェクト固有の仮想環境を作成
uv venv

# 仮想環境の有効化を確認
uv run python --version
```

#### 依存関係管理の方針

- 本番依存: 最小限に抑える
- 開発依存: 品質向上ツールを積極的に導入
- バージョン固定: `uv.lock` で厳密なバージョン管理

```bash
# 依存関係の更新
uv sync --upgrade

# セキュリティ監査
uv run safety check

# 依存関係の可視化
uv tree --depth 2
```

### よく使うコマンド

```bash
# 依存関係管理
uv add requests                    # パッケージ追加
uv add --dev pytest black ruff    # 開発パッケージ追加
uv tree                           # 依存関係確認

# 開発タスク
uv run python script.py          # Python 実行
uv run pytest                    # テスト実行
uv run black .                   # コードフォーマット
uv run ruff check .              # リンター実行
```

### テスト駆動開発 (TDD) ワークフロー

```bash
# 1. テストを先に書く
uv run pytest tests/test_feature.py -v

# 2. テストが通る最小限のコードを実装
uv run pytest tests/test_feature.py

# 3. リファクタリング
uv run black .
uv run ruff check --fix .

# 4. 全テストを実行
uv run pytest --cov=src/
```

## コード品質管理

### 推奨ツール

- フォーマッター: `black` - 統一されたコードスタイル
- リンター: `ruff` - 高速で包括的なリンター
- テスト: `pytest` - 豊富な機能とプラグイン
- 型チェック: `mypy` - 静的型チェック
- カバレッジ: `pytest-cov` - テストカバレッジ計測
- セキュリティ: `bandit` - セキュリティ脆弱性検出

### 品質チェックコマンド

```bash
# コードフォーマット
uv run black .                    # 自動フォーマット
uv run black --check .            # フォーマットチェック

# リンター
uv run ruff check .               # 問題の検出
uv run ruff check --fix .         # 自動修正

# 型チェック
uv run mypy src/                  # 型チェック実行

# テストとカバレッジ
uv run pytest                     # テスト実行
uv run pytest --cov=src/          # カバレッジ付きテスト
uv run pytest --cov-report=html   # HTML レポート生成

# セキュリティチェック
uv run bandit -r src/             # セキュリティ脆弱性検出
uv run safety check               # 依存関係の脆弱性チェック

# 総合品質チェック
uv run black --check . && uv run ruff check . && uv run mypy src/ && uv run pytest --cov=src/
```

## コーディング規約

### フォーマットとリンティング

コードスタイルは `black` と `ruff` に従う。pre-commit フックで自動適用される。

### コメントラベル

一時的なコメントや保留事項には標準ラベルを使用する:

- `TODO`: 後で対応する作業
- `FIXME`: 修正が必要な既知の問題

```python
# TODO: パフォーマンス向上のためキャッシュを実装する
def fetch_data():
    pass

# FIXME: 入力が空の場合に失敗する
def process_input(data):
    return data[0]
```

### Docstring

reStructuredText (Sphinx) スタイルを使用し、英語で記述する:

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


class DataProcessor:
    """
    A class for processing and analyzing data.

    :param data_source: Path to the data source file
    :param encoding: File encoding (default: 'utf-8')
    """

    def __init__(self, data_source: str, encoding: str = "utf-8"):
        self.data_source = data_source
        self.encoding = encoding

    def process_data(self) -> list[dict]:
        """
        Process the data from the source file.

        :return: List of processed data records
        :raises FileNotFoundError: If the data source file doesn't exist
        """
        # Implementation here
        pass
```

### 型ヒントのベストプラクティス

```python
from typing import Protocol

# 基本的な型ヒント
def process_items(items: list[str]) -> dict[str, int]:
    return {item: len(item) for item in items}

# X | Y 構文の使用 (Python 3.10+)
def find_user(user_id: int) -> dict | None:
    # None を返す可能性がある場合
    return None

def parse_value(value: str | int) -> float:
    return float(value)

# ジェネリクスの使用 (PEP 695, Python 3.12+)
class Container[T]:
    def __init__(self, value: T) -> None:
        self.value = value

    def get(self) -> T:
        return self.value

# Protocol の使用（構造的部分型）
class Drawable(Protocol):
    def draw(self) -> None: ...

def render(item: Drawable) -> None:
    item.draw()
```

### エラーハンドリングとロギング

```python
import logging

logger = logging.getLogger(__name__)


def process_file(file_path: str) -> dict:
    """
    Process a file and return the result.

    :param file_path: Path to the file to process
    :return: Processing result
    :raises FileNotFoundError: If the file doesn't exist
    :raises PermissionError: If the file cannot be read
    """
    logger.info(f"Processing file: {file_path}")

    with open(file_path, "r", encoding="utf-8") as f:
        data = f.read()

    logger.info("File processing completed successfully")
    return {"status": "success", "data": data}
```

## プロジェクト構成

```text
project/
├── src/                        # ソースコード
│   └── your_package/
│       ├── __init__.py
│       ├── main.py
│       └── utils/
├── tests/                      # テストコード
│   ├── __init__.py
│   ├── test_main.py
│   └── conftest.py             # pytest 設定
├── pyproject.toml              # プロジェクト設定
├── uv.lock                     # ロックファイル
└── README.md                   # プロジェクト概要
```

## メンテナンス

### 定期的な依存関係の更新

```bash
# 古い依存関係の確認
uv tree --outdated

# 依存関係の更新
uv sync --upgrade

# セキュリティ更新の確認
uv run safety check --json
```

### プロジェクトヘルスチェック

```bash
# 総合品質チェック
uv run black --check .
uv run ruff check .
uv run mypy src/
uv run pytest --cov=src/ --cov-fail-under=80
uv run bandit -r src/
uv run safety check
```

## 付録

### デバッグツール

```bash
# PDB (Python デバッガ)
uv run python -m pdb script.py

# より高機能なデバッガ
uv add --dev ipdb
uv run python -c "import ipdb; ipdb.set_trace()"

# ロギングのセットアップ
uv add --dev rich
```

```python
# デバッグ用ロギング設定
import logging
from rich.logging import RichHandler

logging.basicConfig(
    level=logging.DEBUG,
    format="%(message)s",
    handlers=[RichHandler()]
)

logger = logging.getLogger(__name__)
```

### セキュリティ管理

```bash
# Bandit: セキュリティ脆弱性検出
uv add --dev bandit
uv run bandit -r src/

# Safety: 依存関係の脆弱性チェック
uv add --dev safety
uv run safety check

# Semgrep: 高度な静的解析
uv add --dev semgrep
uv run semgrep --config=auto src/
```

### AI ツール使用時の注意事項

#### 推奨する操作

Claude Code や Gemini CLI を使用する際は、以下のパッケージ管理操作を行う:

```bash
# パッケージ管理
uv add package_name              # パッケージ追加
uv add --dev package_name        # 開発パッケージ追加
uv sync                          # 依存関係の同期
uv tree                          # 依存関係確認
```

#### 避けるべき操作

- `pip install`（uv を介さない直接インストール）
- `pip freeze > requirements.txt`（pyproject.toml を使用すること）
- グローバル環境への直接インストール

#### 重要な注意点

- `uv.lock` は必ずコミットする
- `pip` の直接使用を避ける
- 仮想環境外へのパッケージインストールは禁止
- テスト実行前にコードフォーマットを確認する
