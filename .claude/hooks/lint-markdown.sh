#!/bin/bash
# stdin から JSON を読み取り、file_path を取得
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# .md 以外は何もしない
[[ "$file_path" != *.md ]] && exit 0

# ファイルが存在しない場合も何もしない
[[ ! -f "$file_path" ]] && exit 0

# plan file は lint をスキップ
[[ "$file_path" == */.claude/plans/*.md ]] && exit 0

# markdownlint-cli2 を実行（--no-globs で設定ファイルの globs を無視）
output=$(markdownlint-cli2 --config "$HOME/.config/markdown-cli2/.markdownlint-cli2.jsonc" --no-globs "$file_path" 2>&1)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  # exit code 2 + stderr → Claude Code にエラーをフィードバック
  echo "$output" >&2
  exit 2
fi

exit 0
