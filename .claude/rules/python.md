---
description: Python Development Guide
paths:
  - "**/*.py"
---

# Python Development Guide

## Quick Start

Follow these steps to start a new project:

```bash
# 1. Create virtual environment
uv venv

# 2. Install dependencies (including dev tools)
uv sync --all-extras

# 3. Set up pre-commit hooks (update and install)
uv run pre-commit autoupdate
uv run pre-commit install

# 4. Verify setup
uv run black --check .
uv run ruff check .
uv run mypy src/
```

## Daily Development Workflow

### Environment Management

#### Python Version Management

Specify the minimum version in `pyproject.toml`:

```toml
# pyproject.toml
[project]
requires-python = ">=3.12"
```

#### Virtual Environment Best Practices

```bash
# Create project-specific virtual environment
uv venv

# Verify virtual environment activation
uv run python --version
```

#### Dependency Management Strategy

- Production dependencies: Keep to a minimum
- Development dependencies: Actively adopt quality improvement tools
- Dependency pinning: Strict version management with `uv.lock`

```bash
# Update dependencies
uv sync --upgrade

# Security audit
uv run safety check

# Visualize dependencies
uv tree --depth 2
```

### Common Commands

```bash
# Dependency management
uv add requests                    # Add package
uv add --dev pytest black ruff    # Add dev packages
uv tree                           # Check dependencies

# Development tasks
uv run python script.py          # Run Python
uv run pytest                    # Run tests
uv run black .                   # Format code
uv run ruff check .              # Run linter
```

### Test-Driven Development (TDD) Workflow

```bash
# 1. Write tests first
uv run pytest tests/test_feature.py -v

# 2. Implement minimum code to pass tests
uv run pytest tests/test_feature.py

# 3. Refactor
uv run black .
uv run ruff check --fix .

# 4. Run all tests
uv run pytest --cov=src/
```

## Code Quality Management

### Recommended Tools

- Formatter: `black` - Unified code style
- Linter: `ruff` - Fast and comprehensive linter
- Testing: `pytest` - Rich features and plugins
- Type checking: `mypy` - Static type checking
- Coverage: `pytest-cov` - Test coverage measurement
- Security: `bandit` - Security vulnerability detection

### Quality Check Commands

```bash
# Code formatting
uv run black .                    # Auto-format
uv run black --check .            # Check formatting

# Linter
uv run ruff check .               # Detect issues
uv run ruff check --fix .         # Auto-fix

# Type checking
uv run mypy src/                  # Run type check

# Testing & coverage
uv run pytest                     # Run tests
uv run pytest --cov=src/          # Test with coverage
uv run pytest --cov-report=html   # Generate HTML report

# Security check
uv run bandit -r src/             # Detect security vulnerabilities
uv run safety check               # Check dependency vulnerabilities

# Comprehensive quality check
uv run black --check . && uv run ruff check . && uv run mypy src/ && uv run pytest --cov=src/
```

## Coding Conventions

### Formatting and Linting

Code style follows `black` and `ruff`. Automatically applied via pre-commit hooks.

### Comment Labels

Use standard labels for temporary comments or deferred work:

- `TODO`: Work to be done later
- `FIXME`: Known issue that needs to be fixed

```python
# TODO: Implement caching for better performance
def fetch_data():
    pass

# FIXME: This fails when input is empty
def process_input(data):
    return data[0]
```

### Docstrings

Use reStructuredText (Sphinx) style and write in English:

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

    def __init__(self, data_source: str, encoding: str = 'utf-8'):
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

### Type Hints Best Practices

```python
from typing import Optional, Union, Generic, TypeVar
from collections.abc import Sequence, Mapping

T = TypeVar('T')

# Basic type hints
def process_items(items: list[str]) -> dict[str, int]:
    return {item: len(item) for item in items}

# Using Optional
def find_user(user_id: int) -> Optional[dict]:
    # When None may be returned
    return None

# Using Union
def parse_value(value: Union[str, int]) -> float:
    return float(value)

# Using Generics
class Container(Generic[T]):
    def __init__(self, value: T) -> None:
        self.value = value

    def get(self) -> T:
        return self.value

# Using Protocol (structural subtyping)
from typing import Protocol

class Drawable(Protocol):
    def draw(self) -> None: ...

def render(item: Drawable) -> None:
    item.draw()
```

### Error Handling and Logging

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

    with open(file_path, 'r', encoding='utf-8') as f:
        data = f.read()

    logger.info("File processing completed successfully")
    return {"status": "success", "data": data}
```

## Project Structure

```
project/
├── src/                        # Source code
│   └── your_package/
│       ├── __init__.py
│       ├── main.py
│       └── utils/
├── tests/                      # Test code
│   ├── __init__.py
│   ├── test_main.py
│   └── conftest.py             # pytest configuration
├── pyproject.toml              # Project configuration
├── uv.lock                     # Lock file
└── README.md                   # Project overview
```

## Maintenance

### Regular Dependency Updates

```bash
# Check for outdated dependencies
uv tree --outdated

# Update dependencies
uv sync --upgrade

# Check for security updates
uv run safety check --json
```

### Project Health Check

```bash
# Comprehensive quality check
uv run black --check .
uv run ruff check .
uv run mypy src/
uv run pytest --cov=src/ --cov-fail-under=80
uv run bandit -r src/
uv run safety check
```

## Appendix

### Debugging Tools

```bash
# PDB (Python Debugger)
uv run python -m pdb script.py

# More powerful debugger
uv add --dev ipdb
uv run python -c "import ipdb; ipdb.set_trace()"

# Logging setup
uv add --dev rich
```

```python
# Debug logging configuration
import logging
from rich.logging import RichHandler

logging.basicConfig(
    level=logging.DEBUG,
    format="%(message)s",
    handlers=[RichHandler()]
)

logger = logging.getLogger(__name__)
```

### Security Management

```bash
# Bandit: Security vulnerability detection
uv add --dev bandit
uv run bandit -r src/

# Safety: Dependency vulnerability check
uv add --dev safety
uv run safety check

# Semgrep: Advanced static analysis
uv add --dev semgrep
uv run semgrep --config=auto src/
```

### Notes for AI Tool Usage

#### Recommended Operations

When using Claude Code or Gemini CLI, use the following package management operations:

```bash
# Package management
uv add package_name              # Add package
uv add --dev package_name        # Add dev package
uv sync                          # Sync dependencies
uv tree                          # Check dependencies
```

#### Operations to Avoid

- `pip install` (direct installation without uv)
- `pip freeze > requirements.txt` (use pyproject.toml instead)
- Direct installation to global environment

#### Important Notes

- Always commit `uv.lock`
- Avoid direct use of `pip`
- Package installation outside virtual environment is prohibited
- Verify code formatting before running tests
