#!/bin/bash
# Shared helper that answers one question for the Markdown hooks: which `.md`
# files did THIS tool call write?
#
# This file is meant to be sourced, never executed. Its callers run under
# `set -euo pipefail`, so nothing here may change shell options, dereference an
# unset variable, or finish with a non-zero status. A lookup that cannot run
# answers "no targets" rather than raising an error, so a defect here can never
# turn into an exit 2 on every Bash call. Bad JSON and a missing `jq` silence
# the whole helper; a missing sibling library silences only the Bash path,
# because Edit / Write need nothing from it.
#
# Sourcing this file also sources `command-segments.sh` from the same directory
# when `split_segments` is not defined yet, so callers only have to source this
# one file.
#
# Public functions
#   md_targets <hook-input-json>
#     Print one absolute path per line for every `.md` file the tool call
#     wrote. Prints nothing at all (not an empty line) when there is no target,
#     so a caller can test with `[ -n "$targets" ]`. Always returns 0.
#
#     `tool_name` decides how the input is read:
#       Edit / Write  `tool_input.file_path`, reported when it ends in `.md`
#                     and the file exists. No mtime test: the tool call itself
#                     is the proof that the file was just written.
#       Bash          `tool_input.command`, split into segments by
#                     `split_segments`. A segment is a candidate when it has
#                     the shape of a write (a `>` / `>>` whose target ends in
#                     `.md`, a heredoc marker, or a first command of `tee` /
#                     `cp` / `mv` / `sed -i`) and its first command is not
#                     `git`. Every `.md` token of such a segment is unquoted,
#                     `~` / `$HOME` expanded, resolved against that segment's
#                     own directory, and kept only when the file exists and
#                     its mtime is within MD_TARGETS_RECENT_SEC seconds of
#                     now. `cp` and `mv` are the exception: only their
#                     destination is reported, never the sources.
#       anything else nothing.
#
#     Duplicates are folded to a single line. Order follows the segments.
#
# Environment
#   MD_TARGETS_RECENT_SEC  How recent an mtime has to be for a Bash target to
#                          count, in seconds. Default 120, which is the Bash
#                          tool's own default timeout. A value that is not a
#                          plain integer falls back to 120. A file with an
#                          mtime in the future always passes.
#
# Known and accepted limits
#   - A write whose redirection target is not a `.md` path is not detected, so
#     `gen --out a.md > log.txt` reports nothing.
#   - `cat a.md > b.md` reports the source as well as the destination. Only
#     `cp` / `mv` narrow their report down to the destination; the token scan
#     itself still reads the whole segment.
#   - The destination-first flags of GNU `cp` / `mv` (`cp -t dir a.md`) are not
#     handled: the destination is always taken to be the last operand.
#   - A `cp` / `mv` segment reports its destination and nothing else, so a
#     redirection in the same segment is dropped with the sources:
#     `cp a.md b.md > out.md` reports b.md, never out.md. A redirection
#     written before the last operand takes that operand with it, which can
#     leave a source as the apparent destination: `cp a.md >log.txt b.md`
#     reports a.md.
#   - A segment whose first command is `git` is never reported, even when it
#     redirects: `git show HEAD:a.md > a.md` returns nothing. This is
#     deliberate, so that restore operations do not lint files this call did
#     not author.
#   - Only literal paths are resolved. A path that reaches the command through
#     a variable or a command substitution (`cat > "$out"`,
#     `cat > "$(pwd)/a.md"`) is dropped, because the token does not resolve to
#     an existing file.
#   - Glob tokens are never expanded, so `cat *.md > all.md` reports only
#     all.md.
#   - Tokens are whitespace separated, so a path written with an escaped space
#     (`docs/my\ file.md`) is not reported. The fragment after the space is
#     read as a token of its own, so when a file of that name exists and is
#     recent (`file.md` here), that unrelated file is reported instead.
#   - Every quote character is removed from a token, which is what makes
#     `"$HOME"/a.md` and a stray closing quote work. A file name that really
#     contains a quote therefore fails to resolve and is dropped.
#   - The heredoc test is a plain scan for `<<`. `<<<` is skipped as a
#     here-string, but a `<<WORD` that only appears inside a quoted string
#     still marks the segment as a write, so `grep "a << b" fresh.md` reports
#     fresh.md. An arithmetic shift counts too (`echo $((1 << 2)) fresh.md`).
#     Over-detection is the safe direction here.
#   - Heredoc bodies are removed before the tokens are read, so a `.md` name
#     mentioned inside the written text is not reported.
#   - A standalone `&` splits a segment, and that cut is made before quotes are
#     parsed, so a `&` inside a quoted string splits too. Both directions of
#     the resulting error are accepted:
#       missed    `sed -i 's/x/&y/' notes.md` is cut at the `&` (only `\&` is
#                 parked), so the segment holding `notes.md` no longer looks
#                 like a `sed -i` and notes.md is not linted.
#       extra     `git log --format="%h & %s" > out.md` is cut at the `&`, so
#                 the segment holding `> out.md` no longer starts with `git`
#                 and the git guard stops applying to out.md.
#   - Everything command-segments.sh cannot do is inherited: quoting is not
#     fully parsed, `eval` and command substitution are not unwrapped, and a
#     `cd` inside `sh -c '...'` is not tracked.

if ! type split_segments >/dev/null 2>&1; then
  case "${BASH_SOURCE[0]:-}" in
    */*) _mdt_lib_dir="${BASH_SOURCE[0]%/*}" ;;
    *) _mdt_lib_dir='.' ;;
  esac
  if [ -r "$_mdt_lib_dir/command-segments.sh" ]; then
    . "$_mdt_lib_dir/command-segments.sh"
  fi
  unset _mdt_lib_dir
fi

# Expand a leading ~ / $HOME / ${HOME} in a literal path token. Anything else is
# left alone so that unresolvable paths simply fail to resolve later. This is a
# copy of the same helper in command-segments.sh, kept local because that one is
# private to its file.
_mdt_expand_home() {
  local path="${1-}"
  local home="${HOME:-}"
  case "$path" in
    '~') path="$home" ;;
    '~/'*) path="$home/${path#'~/'}" ;;
    '$HOME') path="$home" ;;
    '$HOME/'*) path="$home/${path#'$HOME/'}" ;;
    '${HOME}') path="$home" ;;
    '${HOME}/'*) path="$home/${path#'${HOME}/'}" ;;
  esac
  printf '%s' "$path"
  return 0
}

# Print <path> made absolute against <base> with `.` and `..` components
# folded. Symlinks are not resolved, which matches `pwd -L`.
_mdt_abspath() {
  local path="${1-}"
  local base="${2-}"
  local rest comp out=''
  if [ -z "$path" ]; then
    return 0
  fi
  path=$(_mdt_expand_home "$path")
  case "$path" in
    /*) ;;
    *)
      if [ -z "$base" ]; then
        base="$PWD"
      fi
      path="$base/$path"
      ;;
  esac
  rest="$path"
  while [ -n "$rest" ]; do
    comp="${rest%%/*}"
    if [ "$comp" = "$rest" ]; then
      rest=''
    else
      rest="${rest#*/}"
    fi
    case "$comp" in
      ''|'.') ;;
      '..') out="${out%/*}" ;;
      *) out="$out/$comp" ;;
    esac
  done
  if [ -z "$out" ]; then
    out='/'
  fi
  printf '%s' "$out"
  return 0
}

# Print the mtime of <path> in seconds. <mode> is `gnu` or `bsd`; the caller
# decides once per run so that the probe does not repeat per file.
_mdt_mtime() {
  local path="${1-}"
  local mode="${2-}"
  if [ "$mode" = 'gnu' ]; then
    stat -c %Y -- "$path" 2>/dev/null
  else
    stat -f %m -- "$path" 2>/dev/null
  fi
  return $?
}

# Report whether the segment declares a heredoc. `<<<` is a here-string and
# does not count.
_mdt_has_heredoc() {
  local rest="${1-}"
  while :; do
    case "$rest" in
      *'<<'*) ;;
      *) return 1 ;;
    esac
    rest="${rest#*'<<'}"
    case "$rest" in
      '<'*) rest="${rest#<}" ;;
      *) return 0 ;;
    esac
  done
}

# Report whether any option token of the segment asks sed to edit in place.
# `-i`, `-i.bak`, `-ni` and `--in-place` all count; the first token (sed
# itself) is skipped, and a sed script is never an option token because it does
# not start with `-`.
_mdt_has_inplace_flag() {
  local rest="${1-}"
  local tok
  local first=1
  while [ -n "$rest" ]; do
    while :; do
      case "$rest" in
        [[:space:]]*) rest="${rest#?}" ;;
        *) break ;;
      esac
    done
    if [ -z "$rest" ]; then
      break
    fi
    tok="${rest%%[[:space:]]*}"
    rest="${rest:${#tok}}"
    if [ "$first" -eq 1 ]; then
      first=0
      continue
    fi
    case "$tok" in
      --in-place*) return 0 ;;
      --*) ;;
      -*i*) return 0 ;;
    esac
  done
  return 1
}

# Report whether the segment redirects into a path that ends in `.md`.
#
# Every `>` of the segment is scanned and one hit is enough: a `2>/dev/null`
# must not turn the segment into a write, and an operator that only appears
# inside a quoted string (`echo "a > b" > out.md`) must not hide the real one.
# The target is either glued to the operator (`>out.md`) or the next token
# (`> out.md`), which is the same shape the token scan handles.
_mdt_redirects_to_md() {
  local rest="${1-}"
  local tok
  while :; do
    case "$rest" in
      *'>'*) ;;
      *) return 1 ;;
    esac
    # Each round drops at least this `>`, so the scan always terminates.
    rest="${rest#*>}"
    # `>>`, `>&` and `>|` glue further operator characters to the first one.
    while :; do
      case "$rest" in
        [\>\&\|]*) rest="${rest#?}" ;;
        *) break ;;
      esac
    done
    while :; do
      case "$rest" in
        [[:space:]]*) rest="${rest#?}" ;;
        *) break ;;
      esac
    done
    tok="${rest%%[[:space:]]*}"
    tok="${tok//\'/}"
    tok="${tok//\"/}"
    case "$tok" in
      *.md) return 0 ;;
    esac
  done
}

# Report whether the segment has the shape of a write.
#
# The first-command tests run on the segment AFTER strip_prefixes, so that
# `xargs tee docs/a.md` and `sudo cp a.md b.md` are recognised. The redirection
# and heredoc tests run on the RAW segment instead, because those operators sit
# outside the command word and can precede it (`> out.md cat`) or follow a
# wrapper that strip_prefixes leaves in place.
_mdt_is_write_segment() {
  local raw="${1-}"
  local name="${2-}"
  local stripped="${3-}"
  if _mdt_redirects_to_md "$raw"; then
    return 0
  fi
  if _mdt_has_heredoc "$raw"; then
    return 0
  fi
  case "$name" in
    tee|cp|mv) return 0 ;;
  esac
  if [ "$name" = 'sed' ]; then
    if _mdt_has_inplace_flag "$stripped"; then
      return 0
    fi
  fi
  return 1
}

# Print the candidate paths a `cp` / `mv` segment writes, one per line.
#
# The destination is the last operand. Option tokens are skipped, and a token
# holding `<` or `>` takes the token after it out of the running as well, so
# the destination of `cp a.md b.md > log.txt` is still b.md. A destination that
# names an existing directory writes one file per `.md` source instead, which
# keeps `cp a.md docs/` from being missed. <stripped> has to be the segment
# after strip_prefixes and <base> that segment's own directory.
_mdt_copy_targets() {
  local rest="${1-}"
  local base="${2-}"
  local srcs='' dest='' tok abs src
  local first=1 skip=0
  local nl=$'\n'

  while [ -n "$rest" ]; do
    while :; do
      case "$rest" in
        [[:space:]]*) rest="${rest#?}" ;;
        *) break ;;
      esac
    done
    if [ -z "$rest" ]; then
      break
    fi
    tok="${rest%%[[:space:]]*}"
    rest="${rest:${#tok}}"
    if [ "$first" -eq 1 ]; then
      first=0
      continue
    fi
    if [ "$skip" -eq 1 ]; then
      skip=0
      continue
    fi
    case "$tok" in
      *[\<\>]*) skip=1; continue ;;
      -*) continue ;;
    esac
    # A segment after the first can carry a stray closing quote, and
    # `"$HOME"/a.md` has to keep expanding, so the quotes go entirely.
    tok="${tok//\'/}"
    tok="${tok//\"/}"
    if [ -n "$dest" ]; then
      srcs="$srcs$nl$dest"
    fi
    dest="$tok"
  done

  if [ -z "$dest" ]; then
    return 0
  fi
  abs=$(_mdt_abspath "$dest" "$base")
  if [ -n "$abs" ] && [ -d "$abs" ]; then
    while IFS= read -r src; do
      case "$src" in
        # The destination goes back as written, not as `$abs`: the caller
        # rescans this output on whitespace, so an absolute path would break
        # apart on a repository whose path contains a space.
        *.md) printf '%s/%s\n' "${dest%/}" "${src##*/}" ;;
      esac
    done <<< "$srcs"
    return 0
  fi
  printf '%s\n' "$dest"
  return 0
}

# Print the `.md` files written by the tool call described by the hook input.
md_targets() {
  local input="${1-}"
  local blob line tool_name cwd file_path command probe recent
  local now stat_mode lines seg_cwd seg stripped first name
  local rest tok path mtime seen blob_rest
  local nl=$'\n'
  local i=0

  if [ -z "$input" ]; then
    return 0
  fi
  if ! type jq >/dev/null 2>&1; then
    return 0
  fi

  # One jq call for the whole helper: it runs on every Bash tool call. The
  # command is emitted last because it is the only value that may contain
  # newlines, so every line after the third belongs to it.
  if ! blob=$(printf '%s' "$input" | jq -r '
        (.tool_name? // "" | tostring),
        (.cwd? // "" | tostring),
        (.tool_input?.file_path? // "" | tostring),
        (.tool_input?.command? // "" | tostring)
      ' 2>/dev/null); then
    return 0
  fi

  # Cut the four fields off the front with parameter expansion. Reading the
  # blob line by line and appending to `command` is quadratic in the command
  # length, which matters because a heredoc that writes Markdown is the main
  # case this helper exists for. A missing newline means jq printed fewer
  # lines than expected, so the remaining fields stay empty.
  blob_rest="$blob"
  tool_name="${blob_rest%%$nl*}"
  case "$blob_rest" in *"$nl"*) blob_rest="${blob_rest#*$nl}" ;; *) blob_rest='' ;; esac
  cwd="${blob_rest%%$nl*}"
  case "$blob_rest" in *"$nl"*) blob_rest="${blob_rest#*$nl}" ;; *) blob_rest='' ;; esac
  file_path="${blob_rest%%$nl*}"
  case "$blob_rest" in *"$nl"*) blob_rest="${blob_rest#*$nl}" ;; *) blob_rest='' ;; esac
  command="$blob_rest"

  case "$tool_name" in
    Edit|Write) probe="$file_path" ;;
    Bash) probe="$command" ;;
    *) return 0 ;;
  esac

  # Fast path (A5). Only the command / file_path is tested, never the whole
  # hook input: a PostToolUse payload carries tool_response, so `ls docs/` or
  # `git status` output would otherwise look like a Markdown write.
  case "$probe" in
    *.md*) ;;
    *) return 0 ;;
  esac

  if [ -z "$cwd" ]; then
    cwd="$PWD"
  fi

  if [ "$tool_name" != 'Bash' ]; then
    case "$file_path" in
      *.md) ;;
      *) return 0 ;;
    esac
    path=$(_mdt_abspath "$file_path" "$cwd")
    if [ -n "$path" ] && [ -f "$path" ]; then
      printf '%s\n' "$path"
    fi
    return 0
  fi

  if ! type split_segments >/dev/null 2>&1; then
    return 0
  fi

  recent="${MD_TARGETS_RECENT_SEC:-120}"
  case "$recent" in
    ''|*[!0-9]*) recent=120 ;;
  esac

  if ! now=$(date +%s 2>/dev/null); then
    return 0
  fi
  case "$now" in
    ''|*[!0-9]*) return 0 ;;
  esac

  # Probe the stat flavour once instead of once per candidate file.
  if stat -f %m -- / >/dev/null 2>&1; then
    stat_mode='bsd'
  else
    stat_mode='gnu'
  fi

  if ! lines=$(split_segments "$command" "$cwd" 2>/dev/null); then
    return 0
  fi

  seen=''
  # The first tab separates the directory from the segment; a segment may hold
  # further tabs, so the remainder has to land in the last variable.
  while IFS=$'\t' read -r seg_cwd seg; do
    if [ -z "${seg:-}" ]; then
      continue
    fi
    case "$seg" in
      *.md*) ;;
      *) continue ;;
    esac
    stripped=$(strip_prefixes "$seg")
    first="${stripped%%[[:space:]]*}"
    name="${first##*/}"
    # A3: a restore operation must not lint a file this call did not write.
    if [ "$name" = 'git' ]; then
      continue
    fi
    if ! _mdt_is_write_segment "$seg" "$name" "$stripped"; then
      continue
    fi
    # `cp` / `mv` write their destination only, so the sources are replaced
    # by the destination before the token scan runs. Every other shape offers
    # the whole segment.
    case "$name" in
      cp|mv) rest=$(_mdt_copy_targets "$stripped" "$seg_cwd") ;;
      *) rest="$seg" ;;
    esac
    while [ -n "$rest" ]; do
      while :; do
        case "$rest" in
          [[:space:]]*) rest="${rest#?}" ;;
          *) break ;;
        esac
      done
      if [ -z "$rest" ]; then
        break
      fi
      tok="${rest%%[[:space:]]*}"
      rest="${rest:${#tok}}"
      # `>docs/a.md` and `2>>docs/a.md` glue an operator to the path, so keep
      # only what follows the last redirection character.
      case "$tok" in
        *[\<\>]*) tok="${tok##*[\<\>]}" ;;
      esac
      # Quotes go entirely: a segment after the first can carry a stray closing
      # quote, and `"$HOME"/a.md` has to keep expanding.
      tok="${tok//\'/}"
      tok="${tok//\"/}"
      case "$tok" in
        *.md) ;;
        *) continue ;;
      esac
      path=$(_mdt_abspath "$tok" "$seg_cwd")
      if [ -z "$path" ] || [ ! -f "$path" ]; then
        continue
      fi
      if ! mtime=$(_mdt_mtime "$path" "$stat_mode"); then
        continue
      fi
      case "$mtime" in
        ''|*[!0-9]*) continue ;;
      esac
      # A future mtime keeps a negative difference and therefore passes.
      if [ $((now - mtime)) -gt "$recent" ]; then
        continue
      fi
      case "$nl$seen$nl" in
        *"$nl$path$nl"*) continue ;;
      esac
      seen="$seen$nl$path"
      printf '%s\n' "$path"
    done
  done <<< "$lines"

  return 0
}
