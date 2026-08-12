#!/bin/bash
# stdin から JSON を読み取り、file_path を取得
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# プランファイル (.claude/plans/*.md) 以外は何もしない
[[ "$file_path" != */.claude/plans/*.md ]] && exit 0

# ファイルが存在しない場合も何もしない
[[ ! -f "$file_path" ]] && exit 0

# pandoc が無ければ何もしない
command -v pandoc >/dev/null 2>&1 || exit 0

# 出力先: 拡張子 .md を .html に置き換えたパス
output_path="${file_path%.md}.html"

# タイトル: 1 行目が "# " で始まればその見出し、そうでなければ拡張子を除いたファイル名
first_line=$(head -n 1 "$file_path")
if [[ "$first_line" == "# "* ]]; then
  title="${first_line#\# }"
else
  base_name=$(basename "$file_path")
  title="${base_name%.md}"
fi

# HTML に変換（失敗しても Claude の作業は止めない）
if ! pandoc -s -f gfm -t html5 --toc --toc-depth=3 --embed-resources \
  --css "$HOME/.claude/hooks/plan-html.css" \
  --metadata title="$title" \
  -o "$output_path" "$file_path" 2>/dev/null; then
  echo "plan-to-html: pandoc によるプランの HTML 変換に失敗しました" >&2
fi

exit 0
