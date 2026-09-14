#!/bin/bash
# 書き込まれた Markdown に markdownlint-cli2 をかける PostToolUse フック。
#
# lint 対象の決定は lib/md-targets.sh に任せる。Edit / Write の file_path だけで
# なく、Bash のヒアドキュメント・リダイレクト・sed -i などで書かれた .md も
# 対象になる。.md 判定とファイルの存在確認はライブラリ側で行うため、ここでは
# 行わない。プラン配下の除外はライブラリの責務ではないのでここで行う。
#
# exit code 2 + stderr が Claude Code へのフィードバック経路。lint 違反が
# あったときだけこの経路を使い、それ以外は必ず exit 0 で終わる。対象が 0 件の
# とき、および対象を決められない状況 (ライブラリが読めない / markdownlint-cli2
# が無い) では lint せずに exit 0 で抜ける。settings.json の matcher 次第で
# Bash ツールの全呼び出しでも起動するため、判定不能をエラーとして返すと lint と
# 無関係な作業まで止まってしまう。
#
# set -e は使わない。markdownlint-cli2 は lint 違反があると非 0 で終了するので、
# set -e だと下の if に到達する前にスクリプトが終わってしまう。

# stdin から hook 入力 JSON を読み取る
input=$(cat)

# 同階層の lib/ からライブラリを読み込む。読めない場合は対象を決められないので
# 何もしない (フェイルオープン)。
lib_dir="$(dirname "${BASH_SOURCE[0]}")/lib"
[[ -r "$lib_dir/md-targets.sh" ]] || exit 0
. "$lib_dir/md-targets.sh"

# md_targets は書き込まれた .md の絶対パスを 1 行 1 件で返し、対象が無ければ
# 1 バイトも出力しない。プロセス置換で読むのは、コマンド置換 + here-string
# (<<< "$t") だと 0 件でも 1 周回って空文字列が渡るため。stderr を捨てるのは、
# ライブラリ側の想定外のエラー出力をこのフックの出力に混ぜないため。
targets=()
while IFS= read -r target_path; do
  # 空行は md_targets の契約上出てこない。ただし空文字列を引数に渡すと
  # markdownlint-cli2 はカレントディレクトリ配下の全ファイルを lint 対象に
  # してしまう (実測) ため、影響が大きいので念のため弾く。
  [[ -z "$target_path" ]] && continue
  # plan file は lint をスキップ
  [[ "$target_path" == */.claude/plans/*.md ]] && continue
  targets+=("$target_path")
done < <(md_targets "$input" 2>/dev/null)

# 対象が 0 件なら何も出力せずに終了
[[ ${#targets[@]} -eq 0 ]] && exit 0

# markdownlint-cli2 が入っていない環境では lint せずに終了
command -v markdownlint-cli2 >/dev/null 2>&1 || exit 0

# markdownlint-cli2 は 1 回だけ呼び、全対象をまとめて引数に渡す。
# 1 ファイルずつ回さない理由:
#   - Node の起動コストはプロセスごとにかかるので、起動回数を対象数に
#     比例させたくない
#   - 違反行はファイルパスから始まるので (プロセスの作業ディレクトリからの
#     相対パス)、まとめて出してもどのファイルの違反かは判別できる
#   - 終了コードは 1 件でも違反があれば非 0 になるので、1 ファイルずつ回して
#     結果を OR する場合と同じ判定になる
# --no-globs は設定ファイル側の globs を無視させるためのもの。
output=$(markdownlint-cli2 --config "$HOME/.config/markdown-cli2/.markdownlint-cli2.jsonc" --no-globs "${targets[@]}" 2>&1)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  # exit code 2 + stderr → Claude Code にエラーをフィードバック
  printf '%s\n' "$output" >&2
  exit 2
fi

exit 0
