# .gitignore テンプレート

以下の内容で `.gitignore` を生成する。

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so

# Virtual environment
.venv/

# Distribution / packaging
dist/
build/
*.egg-info/
*.egg

# Tools
.mypy_cache/
.ruff_cache/
.pytest_cache/
.coverage
htmlcov/

# IDE
.vscode/
.idea/

# Workspace (Claude Code temporary files)
.workspace/

# Credentials / secrets
.env
.env.*
*.pem
*.key
*.p12
*.pfx
*.crt
*.cer
credentials.json
service-account*.json
secrets.yaml
secrets.yml

# Binary / data
*.db
*.sqlite3
*.pkl
*.pickle
*.h5
*.hdf5
*.parquet
*.arrow
*.npy
*.npz
*.bin
*.dat
```
