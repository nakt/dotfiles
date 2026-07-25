# gh repo create リファレンス

## Table of Contents

- [フラグと gitignore テンプレート](#フラグと-gitignore-テンプレート)
- [gitignore テンプレートのよくある間違い](#gitignore-テンプレートのよくある間違い)
- [Owner 情報の取得](#owner-情報の取得)
- [gitignore テンプレートの検証](#gitignore-テンプレートの検証)
- [検証コマンド](#検証コマンド)

## フラグと gitignore テンプレート

`gh repo create` の全フラグは `gh repo create --help` で、gitignore テンプレートの完全なリストは `gh api /gitignore/templates` で都度取得する（陳腐化を避けるため本リファレンスには転記しない）。テンプレート名は大文字小文字を正確に指定する必要がある。

このスキル固有の方針:

- `--clone` の代わりに `ghq get` を使用する
- `--license` は使用しない

## gitignore テンプレートのよくある間違い

指定名は正確な名前が必要で、次のような取り違えが起きやすい。

| 間違い | 正しい名前 |
|--------|-----------|
| `python` | `Python` |
| `node`, `nodejs` | `Node` |
| `golang` | `Go` |
| `go` | `Go` |
| `c++`, `cpp` | `C++` |
| `objective-c` | `Objective-C` |
| `rust` | `Rust` |
| `typescript` | `Node`（TypeScript 専用はない） |
| `react`, `vue`, `nextjs` | `Node`（フレームワーク専用はない） |

## Owner 情報の取得

```bash
# 現在ログインしているユーザーの GitHub ログイン名を取得
gh api user --jq .login
# 出力例: nakt
```

## gitignore テンプレートの検証

```bash
# 利用可能なテンプレート一覧を取得（JSON 配列）
gh api /gitignore/templates
# 出力例: ["Actionscript","Android","Angular",...,"Python",...,"Zig"]

# 特定のテンプレートが存在するか確認（大文字小文字を無視して検索、正確な名前を返す）
gh api /gitignore/templates | jq -r '.[]' | grep -ix "python"
# 出力: Python

gh api /gitignore/templates | jq -r '.[]' | grep -ix "node"
# 出力: Node
```

## 検証コマンド

```bash
gh repo view {owner}/{repo} --json visibility,defaultBranchRef,description,isPrivate
```

### JSON フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `isPrivate` | boolean | true ならプライベート |
| `visibility` | string | `PUBLIC`, `PRIVATE`, `INTERNAL` |
| `defaultBranchRef.name` | string | デフォルトブランチ名 |
| `description` | string | リポジトリの説明 |

### gitignore / README の存在確認

```bash
# .gitignore の存在確認（404 なら存在しない）
gh api /repos/{owner}/{repo}/contents/.gitignore --jq .name 2>/dev/null

# README の存在確認
gh api /repos/{owner}/{repo}/contents/README.md --jq .name 2>/dev/null
```
