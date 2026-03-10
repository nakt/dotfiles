---
name: python-init
description: Python プロジェクトの初期セットアップスキル。pyproject.toml、.gitignore、.pre-commit-config.yaml のテンプレート生成とプロジェクト構造の作成を行う。Python プロジェクトの新規作成、テンプレート生成、初期セットアップ、プロジェクト初期化に使用する。
allowed-tools:
  - Write
  - Read
  - Glob
  - Bash(uv:*)
  - Bash(git:*)
  - Bash(mkdir:*)
  - Bash(ls:*)
---

## ワークフロー

### 1. プロジェクト情報の確認

ユーザーに以下を確認する:

- プロジェクト名（ディレクトリ名・パッケージ名に使用）
- プロジェクトの簡単な説明（pyproject.toml の description に使用）
- 作成先ディレクトリ（デフォルト: カレントディレクトリ配下）

### 2. ディレクトリ構造の作成

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

### 3. テンプレートからファイル生成

各テンプレートは `references/` ディレクトリを参照:

- `.gitignore` → [references/gitignore.md](references/gitignore.md)
- `pyproject.toml` → [references/pyproject-toml.md](references/pyproject-toml.md)
- `.pre-commit-config.yaml` → [references/pre-commit-config.md](references/pre-commit-config.md)

テンプレート内のプレースホルダを置換:

- `{project_name}`: プロジェクト名
- `{package_name}`: パッケージ名（ハイフン → アンダースコア）
- `{description}`: プロジェクトの説明

### 4. 初期ファイルの作成

- `src/{package_name}/__init__.py`: 空ファイル
- `tests/__init__.py`: 空ファイル
- `tests/conftest.py`: 空ファイル
- `README.md`: プロジェクト名と説明のみの最小限の内容

### 5. 環境セットアップ

```bash
cd {project_name}
git init
uv venv
uv sync
uv run pre-commit autoupdate
uv run pre-commit install
```

テンプレートの `rev` はプレースホルダなので、`pre-commit autoupdate` で必ず最新バージョンに更新する。

### 6. 完了報告

作成したファイル一覧と次のステップを提示する:

- `uv add <package>` で依存パッケージを追加
- `src/{package_name}/` にコードを実装
- `tests/` にテストを追加
