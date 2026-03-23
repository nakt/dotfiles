# pyproject.toml テンプレート

以下の内容で `pyproject.toml` を生成する。`{project_name}`、`{package_name}`、`{description}` をプレースホルダとして置換する。

```toml
[project]
name = "{project_name}"
version = "0.1.0"
description = "{description}"
readme = "README.md"
requires-python = ">=3.12"

dependencies = []

[dependency-groups]
dev = [
    "black",
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

[tool.black]
line-length = 128
target-version = ["py312"]

[tool.ruff]
line-length = 128
indent-width = 4
target-version = "py312"

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.ruff.lint]
select = ["E", "W", "F", "I"]
ignore = [
    "E501",  # line too long (formatter handles this)
    "E203",  # whitespace before ':'
    "F401",  # imported but unused
    "F841",  # local variable assigned but never used
    "S101",  # use of assert
    "S105",  # hardcoded password string
    "S106",  # hardcoded password argument
    "S107",  # hardcoded password default
    "E731",  # lambda assignment
]

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101", "F401", "F841"]

[tool.mypy]
python_version = "3.12"
warn_return_any = false
warn_unused_configs = true
disallow_untyped_defs = false
show_error_codes = true
ignore_missing_imports = true
no_implicit_optional = false
exclude = ["tests/", "template/", ".workspace/"]
warn_unused_ignores = false

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
