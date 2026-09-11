#!/bin/bash
# stdin から JSON を読み取り、書き込まれた .md ファイルのうちプラン配下
# (.claude/plans/*.md) のものだけを pandoc で HTML に変換する。
#
# 書き込まれた .md の特定は lib/md-targets.sh (md_targets) に委譲する。
# Edit / Write は tool_input.file_path、Bash はコマンド中の書き込みの跡
# (リダイレクト・ヒアドキュメント等) から .md トークンを抽出して返す。
# プラン配下かどうかの絞り込みと、pandoc による変換自体はこのスクリプトの
# 責務。lint-markdown.sh がプラン配下を除外し、このフックがプラン配下だけ
# を扱う相補的な関係になっている。
input=$(cat)

# パス解決は lib/md-targets.sh と同じく展開だけで済ませる (dirname を fork しない)
case "${BASH_SOURCE[0]:-}" in
  */*) hook_dir="${BASH_SOURCE[0]%/*}" ;;
  *) hook_dir='.' ;;
esac
md_targets_lib="$hook_dir/lib/md-targets.sh"
if [ -r "$md_targets_lib" ]; then
  . "$md_targets_lib"
fi

# ライブラリを読み込めなかった場合 (欠落・壊れている等) は何もしない
if ! type md_targets >/dev/null 2>&1; then
  exit 0
fi

# 書き込まれた .md のうち、プラン配下 (.claude/plans/*.md) のものだけを残す
plan_targets=''
while IFS= read -r path; do
  case "$path" in
    */.claude/plans/*.md) plan_targets="$plan_targets$path"$'\n' ;;
  esac
done < <(md_targets "$input")

# 対象が 0 件なら何もしない
[ -z "$plan_targets" ] && exit 0

# pandoc が無ければ何もしない
command -v pandoc >/dev/null 2>&1 || exit 0

# 1 ファイル分の変換: タイトルを決めて pandoc で HTML を生成する
# (失敗しても Claude の作業は止めない)
convert_plan() {
  local file_path="$1"
  local output_path first_line title base_name

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

  if ! pandoc -s -f gfm -t html5 --toc --toc-depth=3 --embed-resources \
    --css "$HOME/.claude/hooks/plan-html.css" \
    --metadata title="$title" \
    -o "$output_path" "$file_path" 2>/dev/null; then
    echo "plan-to-html: pandoc によるプランの HTML 変換に失敗しました: $file_path" >&2
  fi
}

while IFS= read -r file_path; do
  [ -z "$file_path" ] && continue
  # md_targets は存在確認済みのパスしか返さないが、念のため再確認する
  [ -f "$file_path" ] && convert_plan "$file_path"
done <<< "$plan_targets"

exit 0
