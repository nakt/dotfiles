# pyproject.toml テンプレート

以下の内容で `pyproject.toml` を生成する。`{project_name}`、`{package_name}`、`{description}` をプレースホルダとして置換する。

```toml
[project]
name = "{project_name}"
version = "0.1.0"
description = "{description}"
readme = "README.md"
requires-python = ">=3.14"

dependencies = []

[dependency-groups]
dev = [
    "ruff",
    "mypy",
    "pytest",
    "pytest-cov",
    "coverage",
    "pre-commit",
    "bandit",
]

[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[tool.uv]
exclude-newer = "1 week"

[tool.ruff]
line-length = 120
indent-width = 4
target-version = "py314"

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]
ignore = [
    "E501",  # line too long (formatter handles this)
]

[tool.mypy]
python_version = "3.14"
strict = true
exclude = ["tests/", "template/", ".workspace/"]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
addopts = "--cov=src --cov-report=html --cov-report=term-missing --strict-markers"
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks tests as integration tests",
]

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/__pycache__/*"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "if self.debug:",
    "if settings.DEBUG",
    "raise AssertionError",
    "raise NotImplementedError",
    "if 0:",
    "if __name__ == .__main__.:",
]

[tool.bandit]
exclude_dirs = ["tests"]
skips = ["B101"]
```

## exclude-newer

`exclude-newer` が相対期間（`1 week`、`3 days`、`P3D`）を受け付けるのは uv 0.9.17 以降。それ以前の uv では解析に失敗した旨の警告が出るだけで設定は無視され、cooldown が効かないまま解決が進む。uv を固定できない環境では `2026-07-01` のような日付か RFC 3339 タイムスタンプを指定する。

## ruff と bandit の分担

セキュリティ検査は bandit に任せ、ruff の `select` には flake8-bandit（`S`）を入れていない。テストでの `assert` 許可は `[tool.bandit]` の `exclude_dirs` / `skips` で設定済みなので、ruff 側に `per-file-ignores` で `S101` を書いても `S` が未選択である以上は何も無効化しない。
