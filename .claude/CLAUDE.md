# CLAUDE.md

## Communication Rules
- 常に日本語で会話する

## Basic Rules
- 一時ファイルは workspace/ ディレクトリを使用して、このディレクトリは git の管理対象からは除く
- むやみやたらと絵文字を使わない
- Markdownを生成する際にむやみやらたと強調(** **)を使わない

## Git戦略

### ブランチ運用
- `main`: 本番用（直接pushは禁止）
- `dev`: 開発用（ここで作業）

### Claude Codeの実行ルール

#### 自動実行OK
```bash
git status
git log --oneline -5
git diff
git branch
```

#### 確認が必要
以下は実行前に必ず確認：
- `git commit`
- `git push`
- `git merge`

#### 避けるべき操作
- `git push --force`
- `git reset --hard`
- mainブランチへの直接push

### 基本ワークフロー

#### 作業開始
```bash
# 必ずdevブランチで作業開始
git checkout dev
git pull origin dev
```

#### 開発・コミット
```bash
git add .
git commit -m "feat: 変更内容"
git push origin dev
```

#### 本番反映
devブランチの内容をmainにマージ（PR経由）

### コミットメッセージ
```
feat: 新機能
fix: バグ修正
docs: ドキュメント更新
refactor: リファクタリング
```

### 注意事項
- **必ずdevブランチで作業**
- 機密情報をコミットしない
- mainブランチは触らない
- commit メッセージは英語で作成する


## Python開発戦略

### 環境管理
- **パッケージ管理**: `uv` を使用
- **Pythonバージョン**: プロジェクトの `pyproject.toml` で指定
- **仮想環境**: `uv venv` で作成・管理

### Claude Codeの実行ルール

#### 避けるべき操作
- `pip install` (uvを使わない直接インストール)
- `pip freeze > requirements.txt` (pyproject.tomlを使用)
- グローバル環境への直接インストール

### 基本ワークフロー

#### 依存関係管理
```bash
# パッケージ追加
uv add requests

# 開発用パッケージ追加
uv add --dev pytest black ruff

# 依存関係確認
uv tree
```

#### 開発作業
```bash
# 仮想環境でPython実行
uv run python script.py

# テスト実行
uv run pytest

# コード整形
uv run black .
uv run ruff check .
```

### プロジェクト構成
```
project/
├── pyproject.toml      # プロジェクト設定・依存関係
├── uv.lock            # ロックファイル（コミット必須）
├── src/               # ソースコード
│   └── package/
├── tests/             # テストコード
├── README.md
└── .gitignore
```

### コーディング規約

#### docstring
reStructuredText（Sphinx）スタイルを使用（英語）：

```python
def calculate_area(length: float, width: float) -> float:
    """
    Calculate the area of a rectangle.

    :param length: The length of the rectangle in meters
    :type length: float
    :param width: The width of the rectangle in meters
    :type width: float
    :return: The area in square meters
    :rtype: float
    :raises ValueError: If length or width is negative

    .. note::
       This function only accepts positive values.

    .. example::
       >>> calculate_area(3.0, 4.0)
       12.0
    """
    if length < 0 or width < 0:
        raise ValueError("Length and width must be positive values")
    return length * width


class DataProcessor:
    """
    A class for processing data.

    :param data_source: Path to the data source
    :type data_source: str
    :param encoding: File encoding
    :type encoding: str, optional

    .. versionadded:: 1.0.0
    """

    def __init__(self, data_source: str, encoding: str = 'utf-8'):
        self.data_source = data_source
        self.encoding = encoding
```

### コード品質

#### 推奨ツール
- **フォーマッター**: `black`
- **リンター**: `ruff`
- **テスト**: `pytest`
- **型チェック**: `mypy`

#### 実行例
```bash
# 全体チェック
uv run black --check .
uv run ruff check .
uv run mypy src/
uv run pytest
```

### 注意事項
- `uv.lock` は必ずコミットする
- `pip` の直接使用は避ける
- 仮想環境外でのパッケージインストールは禁止
- テスト実行前にコードフォーマットを確認
