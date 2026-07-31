# .pre-commit-config.yaml テンプレート

以下の内容で `.pre-commit-config.yaml` を生成する。pyproject.toml のツール設定と整合する hooks を定義する。

`rev` は 2026-07 時点の最新版。生成後に必ず `uv run pre-commit autoupdate` を実行して最新化する。

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-toml
      - id: check-json

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.16.1
    hooks:
      - id: ruff-format
      - id: ruff-check
        args: [--fix, --exit-non-zero-on-fix]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v2.3.0
    hooks:
      - id: mypy
        additional_dependencies: []

  - repo: https://github.com/PyCQA/bandit
    rev: 1.9.4
    hooks:
      - id: bandit
        args: [-c, pyproject.toml]
        additional_dependencies: ["bandit[toml]"]
```

## mypy の additional_dependencies について

プロジェクトで型スタブが必要な場合は `additional_dependencies` に追加する（例: `types-PyYAML`、`types-requests`）。
