#!/bin/bash
# rm / find による危険な削除を検出してブロック
#
# PreToolUse hook として使用
# コマンド文字列をセグメント単位に分解し、ルート・ホーム・親ディレクトリ・
# カレントディレクトリを消す再帰削除をブロックする
#
# 判定の流れ
#   1. tool_name が Bash で、コマンドに語としての rm / find が現れるかを見る
#      (ここを抜けるコマンドは以降の処理をしない)
#   2. lib/command-segments.sh でヒアドキュメント本文を除去し、`&&` `||` `;`
#      `|` `&` 改行でセグメントへ分割する
#   3. 各セグメントから前置きコマンド (sudo / xargs / sh -c など) を剥がし、
#      先頭トークンが rm または find のものだけを判定する
#
# 既知の制限 (危険だが通過する形)
#   - `sudo --user root rm -rf /` のような長形式オプションはライブラリが剥がせず、
#     先頭トークンが root になるため通過する。「セグメント内のどこかに rm があれば
#     判定する」方式は、シェル演算子を含まない引用符やコメントの中の記述
#     (`echo "rm -rf ~"` と `# rm -rf ~ は危険` はどちらも現状通過する) まで
#     deny してしまい、ヒアドキュメント本文を除去している方針
#     (危険コマンドを説明する文書は書ける) と衝突するため採らない。
#   - 削除対象が実行時にしか決まらない形は捕捉しない。実測で通過するのは
#     `rm -rf "$(cat target.txt)"` / `TARGET=~; rm -rf "$TARGET"` /
#     `rm -rf ${HOME:-/}` / `eval "rm -rf ~"` など。
#   - パスがコマンド文字列に現れない間接的な削除は捕捉しない
#     (`find / -print0 | xargs -0 rm -rf`)。
#   - `sh -c "rm -rf \"$HOME\""` のような入れ子の引用符はライブラリが
#     途中で切るため通過する。
#   - `echo 'rm -rf ~' | sh` のようにシェルへパイプで流す形は通過する。
#     パイプ右側のセグメントは `sh` だけで、削除対象が引数の位置に現れない。
#   - 前置きとして剥がすコマンドの一覧に `nice` が無いため `nice rm -rf /` は
#     通過する (先頭トークンが nice のままになる)。
#   - 危険な位置の一覧に `$PWD` が無いため `rm -rf $PWD` は通過する。
#   - find の起点判定は完全一致なので、`find ~/.. -delete` や
#     `find ~nakt -delete` は通過する (rm 側では両方とも deny する)。
#
# 既知の制限 (安全だが deny してしまう形)
#   - 引用符の中にシェル演算子と rm の記述が同時にあると deny する。実測例は
#     `echo "cd /tmp && rm -rf ~"` と
#     `git commit -m "feat(hooks): deny cd /tmp && rm -rf ~"` と
#     `echo "a & rm -rf ~"`。
#     引用符を解釈する前にセグメントへ分割するため、引用符の中の `&&` や
#     単独の `&` で切れる。
#     引用符の対で分割を抑止すると `sh -c 'rm -rf ~'` が通過するので採らない。

set -euo pipefail
# パス名展開を止め、`rm -rf *` の `*` をリテラルのまま扱う
set -f

INPUT=$(cat)

# jq が無いと入力を解釈できないため、ライブラリを読み込めないときと同じく
# fail-closed にして deny を返す (`Bash(rm *)` は permissions allow に入っており、
# このフックが唯一の防壁)。emit_deny 自身が jq を使うので、ここはリテラルの JSON を
# printf で出す。
# 絞り込みは生の JSON への部分文字列判定で行う。語としての判定にしないのは、
# エスケープが語の境界を隠すため (`echo hi\nrm -rf ~` は JSON 上 `n` と `rm` が
# 隣接する)。Claude Code の出す JSON は ASCII を `\uXXXX` にエスケープしないので、
# 部分文字列なら `rm` はそのまま現れる。
# 絞り込み自体を省いて全部 deny にはしない。それをすると jq が無い間は `ls` も
# `brew install jq` も通らなくなり、ツール経由で復旧できなくなる。
# 代償として、部分一致する無関係なコマンド (`npm run format` の "format" や
# `echo confirm` の "confirm") も jq が無い間は deny する。
if ! command -v jq >/dev/null 2>&1; then
  case "$INPUT" in
    *rm*|*find*)
      printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq が見つからないため削除チェックを実行できませんでした。安全のためコマンドをブロックします"}}'
      ;;
  esac
  exit 0
fi

emit_deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

# jq は 1 回だけ呼び、1 行目に tool_name、2 行目以降にコマンドを出させる
# (コマンドは複数行になりうるので、最初の改行だけで分ける)
PARSED=$(printf '%s' "$INPUT" | jq -r '(.tool_name? // ""), (.tool_input?.command? // "")' 2>/dev/null) || exit 0
case "$PARSED" in
  *$'\n'*)
    TOOL_NAME="${PARSED%%$'\n'*}"
    COMMAND="${PARSED#*$'\n'}"
    ;;
  *)
    TOOL_NAME="$PARSED"
    COMMAND=""
    ;;
esac

# Bash ツール以外はスキップ
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# 語としての rm / find を含まないコマンドはスキップ
# (`/bin/rm` を拾うため `/` は語の区切りとして扱う)
WORD_RE='(^|[^[:alnum:]_-])(rm|find)([^[:alnum:]_-]|$)'
if [[ ! "$COMMAND" =~ $WORD_RE ]]; then
  exit 0
fi

# 共通ライブラリを読み込む
# 読み込めないときは判定できないため、通過させずに deny する
# (`Bash(rm *)` は permissions allow に入っており、このフックが唯一の防壁)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd) || SCRIPT_DIR=""
LIB="$SCRIPT_DIR/lib/command-segments.sh"
# source 前に構文チェックする。壊れたファイルを source すると
# シェル自体が終了コード 2 で落ち、何も出力できなくなるため
# 検査するのはこのフックが実際に呼ぶ関数だけにする。呼ばない関数を検査すると、
# 呼ぶ側の関数が欠けていても素通りし、未定義コマンドの終了コード 127 で終わる。
# PreToolUse は 2 以外の非ゼロをブロックしないため、それは deny ではなく通過になる
if [ -n "$SCRIPT_DIR" ] && [ -r "$LIB" ] \
  && "${BASH:-/bin/bash}" -n "$LIB" 2>/dev/null \
  && . "$LIB" 2>/dev/null \
  && [ "$(type -t split_segments 2>/dev/null || true)" = "function" ] \
  && [ "$(type -t strip_prefixes_into 2>/dev/null || true)" = "function" ]; then
  :
else
  emit_deny "削除チェック用ライブラリを読み込めませんでした: ${LIB}。安全のためコマンドをブロックします"
  exit 0
fi

# 実体のホームディレクトリ (末尾 / を落としたもの)。`rm -rf /Users/foo` のように
# 展開済みのパスで書かれた場合にも同じ判定を効かせる
HOME_REAL="${HOME:-}"
while :; do
  case "$HOME_REAL" in
    /) HOME_REAL=''; break ;;
    */) HOME_REAL="${HOME_REAL%/}" ;;
    *) break ;;
  esac
done

# 引数を比較用に正規化する
#   - 引用符 (' ") を取り除く (セグメント分割で閉じ引用符が残るため必須)
#   - トークンにくっついたリダイレクトを切り落とす (`rm -rf ~>/dev/null`)
#   - 末尾の `/` `/.` `/*` `/.*` を繰り返し取り除く (`/` 単体はそのまま)
normalize_arg() {
  local arg="${1-}"
  local prev
  arg="${arg//\'/}"
  arg="${arg//\"/}"
  arg="${arg//\\/}"
  arg="${arg%%[<>]*}"
  while [ -n "$arg" ]; do
    prev="$arg"
    case "$arg" in
      /) break ;;
      *\*\*) arg="${arg%\*}" ;;
      */.\*) arg="${arg%/.\*}" ;;
      */\*) arg="${arg%/\*}" ;;
      */.) arg="${arg%/.}" ;;
      */) arg="${arg%/}" ;;
    esac
    if [ "$arg" = "$prev" ]; then
      break
    fi
    if [ -z "$arg" ]; then
      # `/*` や `/` だけが残った形はルートを指す
      arg='/'
      break
    fi
  done
  printf '%s' "$arg"
  return 0
}

# 危険な位置を指す引数かどうかを判定する
#   mode=rm   : / ~ $HOME ${HOME} .. . * とホーム実体パスに加え、末尾が `..` の
#               パス (`~/..` `build/..`) と `~user` 形式
#   mode=find : / ~ $HOME ${HOME} .. とホーム実体パスの完全一致のみ (探索起点用)。
#               `find . -name '*.tmp' -delete` のような通常作業や、
#               `find ~/Documents -name '~*' -delete` のように `-name` の値が
#               `~` で始まる形を止めないため。この絞り込みの結果、
#               `find ~/.. -delete` のように起点が完全一致しない形は通過する
is_dangerous_target() {
  local mode="${1-}"
  local arg
  arg=$(normalize_arg "${2-}")
  if [ -z "$arg" ]; then
    return 1
  fi
  case "$arg" in
    /|'~'|'$HOME'|'${HOME}'|..) return 0 ;;
  esac
  if [ "$mode" = "find" ]; then
    if [ -n "$HOME_REAL" ] && [ "$arg" = "$HOME_REAL" ]; then return 0; fi
    return 1
  fi
  case "$arg" in
    # 末尾が .. のパスは親ディレクトリを消す (`~/..` `build/..`)
    */..) return 0 ;;
    # `~user` 形式もホームを指す (`~/` を含む形は上の正規化で `~` になっている)
    # `rm -rf $(echo ~)` の残りトークン `~)` もここで捕まる
    '~'*) case "$arg" in */*) : ;; *) return 0 ;; esac ;;
  esac
  if [ -n "$HOME_REAL" ] && [ "$arg" = "$HOME_REAL" ]; then
    return 0
  fi
  if [ "$mode" = "rm" ]; then
    case "$arg" in
      .|'*') return 0 ;;
    esac
  fi
  return 1
}

while IFS=$'\t' read -r SEG_CWD SEGMENT; do
  # SEG_CWD (セグメントの実行ディレクトリ) は使わない。危険な位置は引数側の
  # `/` `~` `..` `.` `*` で判定できるため、cd の追跡結果は判定に影響しない
  : "$SEG_CWD"
  set -- $SEGMENT
  if [ $# -eq 0 ]; then
    continue
  fi
  # 先頭のシェルキーワードとビルトインの `exec` を読み飛ばす
  # (`if rm -rf ~; then` `! rm -rf ~` `for i in 1; do rm -rf ~; done`
  # `exec rm -rf ~` など)。ライブラリが落とすのは `(` `{` だけなので、ここで補う。
  # 本来は strip_prefixes 側の仕事だが、ライブラリは変更禁止のため当座の処置とする
  KEYWORD_SKIPPED=0
  while [ $# -gt 0 ]; do
    case "$1" in
      '!'|if|then|elif|else|do|while|until|exec) shift; KEYWORD_SKIPPED=1 ;;
      *) break ;;
    esac
  done
  if [ $# -eq 0 ]; then
    continue
  fi
  if [ "$KEYWORD_SKIPPED" -eq 1 ]; then
    strip_prefixes_into STRIPPED "$*"
  else
    strip_prefixes_into STRIPPED "$SEGMENT"
  fi
  set -- $STRIPPED
  if [ $# -eq 0 ]; then
    continue
  fi
  # コマンド名は引用符を外し、ベース名で見る (`/bin/rm` 対応)
  CMD="${1-}"
  CMD="${CMD//\'/}"
  CMD="${CMD//\"/}"
  CMD="${CMD//\\/}"
  CMD="${CMD##*/}"
  shift

  case "$CMD" in
    rm)
      RECURSIVE=0
      TARGET=''
      END_OPTS=0
      while [ $# -gt 0 ]; do
        TOK="$1"
        shift
        if [ "$END_OPTS" -eq 0 ]; then
          case "$TOK" in
            '--') END_OPTS=1; continue ;;
            '--recursive') RECURSIVE=1; continue ;;
            '--'*) continue ;;
            # `-rf` のような結合形もまとめて見る
            '-'?*) case "$TOK" in *[rR]*) RECURSIVE=1 ;; esac; continue ;;
          esac
        fi
        if [ -z "$TARGET" ] && is_dangerous_target rm "$TOK"; then
          TARGET="$TOK"
        fi
      done
      if [ "$RECURSIVE" -eq 1 ] && [ -n "$TARGET" ]; then
        emit_deny "危険な再帰削除を検出しました: 「${SEGMENT}」 の ${TARGET}。ルート・ホーム・親ディレクトリ・カレントディレクトリの再帰削除は許可されていません"
        exit 0
      fi
      ;;
    find)
      ACTION=''
      START=''
      while [ $# -gt 0 ]; do
        TOK="$1"
        shift
        case "$TOK" in
          -delete)
            if [ -z "$ACTION" ]; then ACTION='-delete'; fi
            ;;
          -exec|-execdir|-ok|-okdir)
            # 終端 (`\;` または `+`) までのトークンを集め、前置きを剥がしてから
            # 先頭トークンのベース名が rm かどうかを見る。直後の 1 トークンだけでは
            # `-exec sudo rm -rf {} \;` や `-exec sh -c 'rm ...' {} \;` を逃し、
            # 終端までのどこかに rm があれば deny とすると
            # `-exec grep -n rm {} \;` のような検索まで止めてしまう。
            # トークンからバックスラッシュを外すため、終端の `\;` は `;` になる
            EXEC_TOK="$TOK"
            EXEC_ARGS=''
            while [ $# -gt 0 ]; do
              NEXT="${1//\'/}"
              NEXT="${NEXT//\"/}"
              NEXT="${NEXT//\\/}"
              shift
              case "$NEXT" in
                ';'|'+') break ;;
              esac
              EXEC_ARGS="$EXEC_ARGS $NEXT"
            done
            strip_prefixes_into EXEC_CMD "$EXEC_ARGS"
            EXEC_CMD="${EXEC_CMD%%[[:space:]]*}"
            if [ "${EXEC_CMD##*/}" = "rm" ] && [ -z "$ACTION" ]; then
              ACTION="$EXEC_TOK rm"
            fi
            ;;
          *)
            # 探索起点は `find -L / -delete` のようにオプションの後ろにも来る。
            # 位置で絞らず、削除アクション以外のトークンをすべて起点候補として見る。
            # find モードは完全一致だけを危険とみなすので、`-name` などの
            # オプション名やその引数 (`'~*'` `'~$*'` など) は起点候補に一致しない
            if [ -z "$START" ] && is_dangerous_target find "$TOK"; then
              START="$TOK"
            fi
            ;;
        esac
      done
      if [ -n "$ACTION" ] && [ -n "$START" ]; then
        emit_deny "危険な find 経由の削除を検出しました: 「${SEGMENT}」 の ${START} と ${ACTION}。ルート・ホーム・親ディレクトリを起点とする削除は許可されていません"
        exit 0
      fi
      ;;
  esac
done <<< "$(split_segments "$COMMAND" "$PWD")"

# 安全と判断 - 何も出力せずに終了
exit 0
