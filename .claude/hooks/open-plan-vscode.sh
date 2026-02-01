#!/bin/bash
# プランファイルが作成・更新されたら VS Code で開く

# stdin から JSON を読み取り、file_path を取得
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# file_path がなければ何もしない
[[ -z "$file_path" ]] && exit 0

# .claude/plans/ 配下の .md ファイルのみ対象
[[ "$file_path" != */.claude/plans/*.md ]] && exit 0

# ファイルが存在しない場合も何もしない
[[ ! -f "$file_path" ]] && exit 0

# code コマンドが利用可能か確認
if ! command -v code &>/dev/null; then
  exit 0
fi

# VS Code で開く（バックグラウンドで実行、失敗しても無視）
code "$file_path" &>/dev/null &

exit 0
