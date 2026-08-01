# .pre-commit-config.yaml テンプレート

以下の内容で `.pre-commit-config.yaml` を生成する。pyproject.toml のツール設定と整合する hooks を定義する。

`rev` は 2026-07 時点の最新版。生成後に `uv run pre-commit autoupdate` で最新化する。

pyproject の `exclude-newer` は PyPI のパッケージに 1 週間の cooldown を課しているが、pre-commit の `rev` は GitHub のタグで、公開日を得る手段（`gh` / `curl` / Web 取得）がこのスキルの権限に無いため同じ制御はかけられない。cooldown を効かせたい場合は、autoupdate を回さずテンプレートの `rev` のまま使い、更新は別途 Renovate などの外部の仕組みに任せる。

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
        exclude: ^(tests/|template/|\.workspace/)
        additional_dependencies: []

  - repo: https://github.com/PyCQA/bandit
    rev: 1.9.4
    hooks:
      - id: bandit
        exclude: ^tests/
        args: [-c, pyproject.toml]
        additional_dependencies: ["bandit[toml]"]
```

## hook 側の exclude が要る理由

pyproject.toml の `[tool.mypy] exclude` と `[tool.bandit] exclude_dirs` は、ツールが自分でファイルを再帰探索するときにしか効かない。pre-commit は対象ファイルを引数で明示的に渡すため、これらの除外は無視される（実測: `mypy .` は tests/ を飛ばすが、`mypy tests/test_a.py src/m.py` は tests/ を strict 検査して落ちる）。pre-commit 経由でも同じ範囲に揃えるには、上記のように hook 側の `exclude` にも同じパターンを書く。

## mypy の additional_dependencies について

プロジェクトで型スタブが必要な場合は `additional_dependencies` に追加する（例: `types-PyYAML`、`types-requests`）。
