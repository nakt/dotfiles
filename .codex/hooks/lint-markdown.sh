#!/bin/bash
# Codex PostToolUse 入力を既存の Markdown lint hook に渡す。
# Bash の対象検出・lint 設定・プラン除外は Claude 側と共用する。

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
shared_hook="$HOME/.claude/hooks/lint-markdown.sh"
[[ -r "$shared_hook" ]] || exit 0
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

case "$tool" in
  Bash|Edit|Write)
    printf '%s' "$input" | bash "$shared_hook"
    exit $?
    ;;
  apply_patch) ;;
  *) exit 0 ;;
esac

# パッチの本文行（+/-/空白で始まる）は見ず、ヘッダーだけを解析する。
# Move to は Update File の対象を置き換える。削除ファイルは lint しない。
paths=$(printf '%s' "$input" | jq -r '
  .tool_input.command | select(type == "string") | split("\n") |
  reduce .[] as $line ({paths: [], pending: null};
    if ($line | startswith("*** Add File: ")) then
      .paths += [.pending] | .pending = ($line | ltrimstr("*** Add File: "))
    elif ($line | startswith("*** Update File: ")) then
      .paths += [.pending] | .pending = ($line | ltrimstr("*** Update File: "))
    elif ($line | startswith("*** Move to: ")) then
      .pending = ($line | ltrimstr("*** Move to: "))
    elif ($line | startswith("*** Delete File: ")) then
      .paths += [.pending] | .pending = null
    else . end
  ) | (.paths + [.pending]) | map(select(. != null)) | unique[]
' 2>/dev/null) || exit 0

status=0
while IFS= read -r target; do
  [[ "$target" == *.md ]] || continue
  # Edit 形式なら共用 hook が cwd に対する相対パスを解決し、存在も確認する。
  payload=$(printf '%s' "$input" | jq --arg target "$target" '
    .tool_name = "Edit" | .tool_input = {file_path: $target}
  ') || continue
  printf '%s' "$payload" | bash "$shared_hook"
  result=$?
  if [[ "$result" -ne 0 ]]; then
    status=2
  fi
done <<< "$paths"
exit "$status"
