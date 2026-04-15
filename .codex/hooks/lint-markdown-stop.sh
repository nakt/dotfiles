#!/bin/bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root"

if ! command -v markdownlint-cli2 >/dev/null 2>&1; then
  echo "markdownlint-cli2 is not installed or not in PATH" >&2
  exit 2
fi

config_path="$HOME/.config/markdown-cli2/.markdownlint-cli2.jsonc"
if [[ ! -f "$config_path" ]]; then
  echo "markdownlint config not found: $config_path" >&2
  exit 2
fi

declare -a candidates=()
tmp_paths=$(mktemp)
trap 'rm -f "$tmp_paths"' EXIT

{
  git diff --name-only --diff-filter=ACM --relative HEAD -- '*.md'
  git diff --name-only --diff-filter=ACM --cached --relative -- '*.md'
  git ls-files --others --exclude-standard -- '*.md'
} | sort -u >"$tmp_paths"

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  [[ "$path" == *.md ]] || continue
  [[ "$path" == .claude/plans/* ]] && continue
  [[ -f "$path" ]] || continue
  candidates+=("$path")
done <"$tmp_paths"

if [[ ${#candidates[@]} -eq 0 ]]; then
  exit 0
fi

output=$(markdownlint-cli2 --config "$config_path" --no-globs "${candidates[@]}" 2>&1) || {
  echo "$output" >&2
  exit 2
}

exit 0
