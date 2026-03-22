# .pre-commit-config.yaml テンプレート

以下の内容で `.pre-commit-config.yaml` を生成する。pyproject.toml のツール設定と整合する hooks を定義する。

`rev` の値はプレースホルダであり、生成後に `uv run pre-commit autoupdate` で最新化すること。

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-toml
      - id: check-json

  - repo: https://github.com/psf/black
    rev: 25.1.0
    hooks:
      - id: black

  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.12.3
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.13.0
    hooks:
      - id: mypy
        additional_dependencies: []

  - repo: https://github.com/PyCQA/bandit
    rev: 1.8.6
    hooks:
      - id: bandit
        args: [-c, pyproject.toml]
        additional_dependencies: ["bandit[toml]"]
```

## mypy の additional_dependencies について

プロジェクトで型スタブが必要な場合は `additional_dependencies` に追加する（例: `types-PyYAML`、`types-requests`）。
