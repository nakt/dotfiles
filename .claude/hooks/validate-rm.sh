#!/bin/bash
# rm コマンドの危険なパターンを検出してブロック
#
# PreToolUse hook として使用
# 危険な rm パターン（ルートディレクトリ、ホームディレクトリ全体など）を検出し、
# ブロックする

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Bash ツール以外はスキップ
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# rm コマンドでなければスキップ
if [[ ! "$COMMAND" =~ ^rm[[:space:]] ]]; then
  exit 0
fi

# 危険なパターンのリスト
# - ルートディレクトリの削除
# - ホームディレクトリ全体の削除
# - 親ディレクトリへの再帰削除
# - カレントディレクトリの削除
DANGEROUS_PATTERNS=(
  'rm -rf /'
  'rm -rf /*'
  'rm -fr /'
  'rm -fr /*'
  'rm -rf ~'
  'rm -rf ~/'
  'rm -rf ~/\*'
  'rm -fr ~'
  'rm -fr ~/'
  'rm -rf $HOME'
  'rm -rf $HOME/'
  'rm -fr $HOME'
  'rm -rf ${HOME}'
  'rm -rf ..'
  'rm -rf ../'
  'rm -fr ..'
  'rm -rf .'
  'rm -fr .'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if [[ "$COMMAND" == *"$pattern"* ]]; then
    # JSON で block 決定を返す
    cat <<EOF
{"decision": "block", "reason": "危険な rm パターンを検出しました: $pattern"}
EOF
    exit 0
  fi
done

# 追加チェック: 変数展開を使った危険なパターン
if [[ "$COMMAND" =~ rm[[:space:]]+-[rf]+[[:space:]]+(/|/\*|\$HOME|\$\{HOME\}|~) ]]; then
  cat <<EOF
{"decision": "block", "reason": "危険な rm パターンを検出しました（変数展開の可能性）"}
EOF
  exit 0
fi

# 安全と判断 - 何も出力せずに終了
exit 0
