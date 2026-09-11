#!/bin/bash
# Shared helpers that break a Bash tool command string into segments the hooks
# can judge one at a time.
#
# This file is meant to be sourced, never executed. Its callers run under
# `set -euo pipefail`, so nothing here may change shell options, dereference an
# unset variable, or finish with a non-zero status.
#
# Public functions
#   strip_heredoc_bodies <command>
#     Print the command with heredoc bodies and their terminator lines removed.
#     The `<<'EOF'` / `<<EOF` / `<<-EOF` markers stay on the command line so a
#     caller can still tell that the segment writes through a heredoc. When a
#     declared delimiter never appears on a line of its own, the `<<` was not a
#     real marker (a quoted string can hold one), so the skipped lines are put
#     back instead of being dropped.
#
#   split_segments <command> <base_cwd>
#     Print one `<cwd><TAB><segment>` line per segment after splitting on
#     `&&`, `||`, `;`, `|` and newlines. Consumers must split each line on its
#     FIRST tab, since a segment may legitimately contain further tabs.
#     `cd` is tracked so that later segments report the directory they run in;
#     a `cd` segment itself carries the directory it was issued from. `cd` with
#     no operand and `cd -` return to <base_cwd>, and a directory that cannot
#     be resolved leaves the previous value in place.
#
#   strip_prefixes <segment>
#     Print the segment with leading environment assignments and the wrappers
#     `sudo` `env` `command` `time` `timeout` `nohup` `xargs` `sh -c` `bash -c`
#     `zsh -c` removed. Options belonging to a stripped wrapper go too, and the
#     short options that take a separate argument (`sudo -u root`,
#     `xargs -I {}`, `env -u FOO`) take that argument with them.
#
# Intended pipeline
#   The caller runs split_segments first and strip_prefixes on each segment.
#   Splitting happens before quotes are parsed, so a wrapped list is cut apart:
#
#     sh -c 'cd docs && rm -rf ~'
#       segment 1: sh -c 'cd docs   -> strip_prefixes -> cd docs
#       segment 2: rm -rf ~'        -> strip_prefixes -> rm -rf ~'
#
#   The opening quote is consumed by strip_prefixes but the closing one is not,
#   so every segment after the first can carry stray quote characters. Removing
#   those quotes is required of the consumer (validate-rm.sh) before it compares
#   arguments.
#
# Known and accepted limits
#   - Quoting is not fully parsed. A `&&`, `||`, `;` or `|` inside a quoted
#     string is treated as an operator.
#   - A `<<WORD` inside a quoted string is still read as a heredoc marker. Its
#     body is put back only when no terminator line follows, so a string that
#     happens to be followed by a line equal to WORD still loses those lines.
#     When a real heredoc is declared after such a false marker, its body is
#     put back together with the rest. That fails towards over-detection (an
#     extra deny or lint), which is the safe direction for this library.
#   - `eval` and command substitution are deliberately not unwrapped.
#   - Only the short wrapper options listed above take their argument with them.
#     Long forms such as `sudo --user root` leave `root` in front of the real
#     command.
#   - `cd` option tokens (`cd -P docs`, `cd -L /etc`, `cd -- docs`) are skipped,
#     but `cd -P` with no operand is treated like a bare `cd` and returns to
#     <base_cwd> rather than to $HOME.
#   - A `cd` inside `sh -c '...'` is not tracked, because the segment begins
#     with the wrapper instead of with `cd`.
#   - The `-c` argument ends at the first matching quote, so a nested quote as
#     in `sh -c "rm -rf \"$HOME\""` comes back truncated.
#   - Prefix removal gives up after 16 tokens, so a segment carrying more than
#     16 leading wrappers or options keeps the remainder as-is.

# Remove leading and trailing whitespace from a string.
_cmdseg_trim() {
  local text="${1-}"
  while :; do
    case "$text" in
      [[:space:]]*) text="${text#?}" ;;
      *) break ;;
    esac
  done
  while :; do
    case "$text" in
      *[[:space:]]) text="${text%?}" ;;
      *) break ;;
    esac
  done
  printf '%s' "$text"
  return 0
}

# Expand a leading ~ / $HOME / ${HOME} in a literal path token. Anything else is
# left alone so that unresolvable paths simply fail to resolve later.
_cmdseg_expand_home() {
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

# Print the heredoc delimiters declared on one command line, one per line, each
# prefixed with `-` for the `<<-` form or `=` for the plain `<<` form.
_cmdseg_heredoc_delims() {
  local rest="${1-}"
  local before dash delim
  local word_re='^[A-Za-z_][A-Za-z0-9_.-]*'
  while :; do
    case "$rest" in
      *'<<'*) ;;
      *) break ;;
    esac
    before="${rest%%'<<'*}"
    rest="${rest:${#before}}"
    rest="${rest#'<<'}"
    # `<<<` is a here-string and has no body.
    case "$rest" in
      '<'*) rest="${rest#<}"; continue ;;
    esac
    dash='='
    case "$rest" in
      '-'*) dash='-'; rest="${rest#-}" ;;
    esac
    while :; do
      case "$rest" in
        [[:space:]]*) rest="${rest#?}" ;;
        *) break ;;
      esac
    done
    case "$rest" in
      '\'*) rest="${rest#\\}" ;;
    esac
    delim=''
    case "$rest" in
      "'"*)
        rest="${rest#\'}"
        case "$rest" in
          *"'"*) delim="${rest%%\'*}"; rest="${rest:$(( ${#delim} + 1 ))}" ;;
          # No closing quote on this line, so this `<<` opens no heredoc. Keep
          # scanning the remainder: a real marker may still follow.
          *) delim='' ;;
        esac
        ;;
      '"'*)
        rest="${rest#\"}"
        case "$rest" in
          *'"'*) delim="${rest%%\"*}"; rest="${rest:$(( ${#delim} + 1 ))}" ;;
          *) delim='' ;;
        esac
        ;;
      [A-Za-z_]*)
        if [[ "$rest" =~ $word_re ]]; then
          delim="${BASH_REMATCH[0]}"
          rest="${rest:${#delim}}"
        fi
        ;;
      *)
        # Not a heredoc marker, e.g. the `<<` of an arithmetic shift.
        continue
        ;;
    esac
    if [ -n "$delim" ]; then
      printf '%s%s\n' "$dash" "$delim"
    fi
  done
  return 0
}

# Print the command with every heredoc body removed, keeping the marker.
strip_heredoc_bodies() {
  local command="${1-}"
  local pending='' out='' buf='' first=1
  local line entry flag delim probe added
  local nl=$'\n'
  while IFS= read -r line; do
    if [ -n "$pending" ]; then
      # Hold on to what is skipped. If no terminator ever arrives the `<<` was
      # not a marker but text, and these lines have to go back into the output.
      buf="$buf$line$nl"
      entry="${pending%%$nl*}"
      flag="${entry:0:1}"
      delim="${entry:1}"
      probe="$line"
      if [ "$flag" = '-' ]; then
        while :; do
          case "$probe" in
            $'\t'*) probe="${probe#?}" ;;
            *) break ;;
          esac
        done
      fi
      if [ "$probe" = "$delim" ]; then
        pending="${pending#*$nl}"
        if [ -z "$pending" ]; then
          buf=''
        fi
      fi
      continue
    fi
    if [ "$first" -eq 1 ]; then
      out="$line"
      first=0
    else
      out="$out$nl$line"
    fi
    added=$(_cmdseg_heredoc_delims "$line")
    if [ -n "$added" ]; then
      pending="$pending$added$nl"
    fi
  done <<< "$command"
  # An unterminated heredoc is a syntax error for bash itself, so restoring the
  # buffered lines cannot let a command through that would otherwise be judged.
  if [ -n "$pending" ] && [ -n "$buf" ]; then
    buf="${buf%$nl}"
    if [ "$first" -eq 1 ]; then
      out="$buf"
      first=0
    else
      out="$out$nl$buf"
    fi
  fi
  printf '%s' "$out"
  return 0
}

# Print `<cwd><TAB><segment>` for every segment of the command.
split_segments() {
  local command="${1-}"
  local base_cwd="${2-}"
  local body cwd line seg dir resolved tok cd_guard
  local nl=$'\n'
  local sep=$'\001'
  local sep2=$'\002'
  # As a glob the first backslash escapes the second, so this pattern matches a
  # literal `\;` only. A bare `;` stays a separator.
  local esc_semi_pat='\\;'
  local esc_semi_rep='\;'
  # `>|` is a redirection, not a pipe.
  local clobber='>|'

  if [ -z "$base_cwd" ]; then
    base_cwd="$PWD"
  fi
  cwd="$base_cwd"

  body=$(strip_heredoc_bodies "$command")
  # A backslash-newline is a line continuation, not a segment boundary.
  body="${body//\\$nl/ }"
  # Keep `find ... -exec rm {} \;` and `cat >| out` in one piece across the
  # `;` and `|` splits.
  body="${body//$esc_semi_pat/$sep}"
  body="${body//$clobber/$sep2}"
  body="${body//&&/$nl}"
  body="${body//||/$nl}"
  body="${body//;/$nl}"
  body="${body//|/$nl}"

  while IFS= read -r line; do
    seg=$(_cmdseg_trim "$line")
    # Drop grouping punctuation so `(cd docs && ...)` is tracked like `cd docs`.
    while :; do
      case "$seg" in
        '('*) seg=$(_cmdseg_trim "${seg#\(}") ;;
        '{'[[:space:]]*) seg=$(_cmdseg_trim "${seg#\{}") ;;
        *) break ;;
      esac
    done
    # A closing paren is only punctuation when the segment opened none itself,
    # so `rm -rf $(pwd)` keeps its own parenthesis.
    case "$seg" in
      *'('*) : ;;
      *')') seg=$(_cmdseg_trim "${seg%\)}") ;;
    esac
    seg="${seg//$sep/$esc_semi_rep}"
    seg="${seg//$sep2/$clobber}"
    if [ -z "$seg" ]; then
      continue
    fi
    printf '%s\t%s\n' "$cwd" "$seg"
    case "$seg" in
      cd|cd[[:space:]]*)
        dir=$(_cmdseg_trim "${seg#cd}")
        # Skip the option forms (`cd -P docs`, `cd -L /etc`, `cd -- docs`) so
        # that the operand is tracked. A bare `-` is the previous-directory
        # form and is handled with the no-operand case below.
        cd_guard=0
        while [ "$cd_guard" -lt 16 ]; do
          cd_guard=$((cd_guard + 1))
          case "$dir" in
            '--') dir=''; break ;;
            '--'[[:space:]]*) dir=$(_cmdseg_trim "${dir#--}"); break ;;
            -?*)
              tok="${dir%%[[:space:]]*}"
              dir=$(_cmdseg_trim "${dir:${#tok}}")
              ;;
            *) break ;;
          esac
        done
        case "$dir" in
          "'"*) dir="${dir#\'}"; dir="${dir%%\'*}" ;;
          '"'*) dir="${dir#\"}"; dir="${dir%%\"*}" ;;
          *) dir="${dir%%[[:space:]]*}" ;;
        esac
        if [ -z "$dir" ] || [ "$dir" = '-' ]; then
          cwd="$base_cwd"
        else
          dir=$(_cmdseg_expand_home "$dir")
          # `--` keeps an option-looking operand from sending `cd` to $HOME,
          # which would silently succeed and overwrite the tracked directory.
          if resolved=$(unset CDPATH; cd -- "$cwd" 2>/dev/null && cd -- "$dir" 2>/dev/null && pwd -L); then
            cwd="$resolved"
          fi
        fi
        ;;
    esac
  done <<< "$body"
  return 0
}

# Print the argument of `sh -c` / `bash -c` / `zsh -c`, or nothing without -c.
_cmdseg_shell_c_arg() {
  local rest="${1-}"
  local guard=0
  local token arg=''
  local c_re='^-[A-Za-z]*c[A-Za-z]*$'
  while [ "$guard" -lt 16 ]; do
    guard=$((guard + 1))
    rest=$(_cmdseg_trim "$rest")
    token="${rest%%[[:space:]]*}"
    if [ -z "$token" ]; then
      break
    fi
    case "$token" in
      '--'*) rest="${rest:${#token}}"; continue ;;
      '-'*)
        if [[ "$token" =~ $c_re ]]; then
          rest=$(_cmdseg_trim "${rest:${#token}}")
          case "$rest" in
            "'"*)
              rest="${rest#\'}"
              case "$rest" in
                *"'"*) arg="${rest%%\'*}" ;;
                *) arg="$rest" ;;
              esac
              ;;
            '"'*)
              rest="${rest#\"}"
              case "$rest" in
                *'"'*) arg="${rest%%\"*}" ;;
                *) arg="$rest" ;;
              esac
              ;;
            *) arg="$rest" ;;
          esac
          printf '%s' "$arg"
          return 0
        fi
        rest="${rest:${#token}}"
        continue
        ;;
    esac
    break
  done
  return 0
}

# Report whether a wrapper option consumes the token that follows it.
_cmdseg_takes_arg() {
  local wrapper="${1-}"
  local flag="${2-}"
  case "$wrapper" in
    sudo)
      case "$flag" in
        -u|-g|-C|-p|-U|-r|-t|-T|-h|-R|-D) return 0 ;;
      esac
      ;;
    xargs)
      case "$flag" in
        -I|-L|-n|-P|-s|-E|-a|-d|-J) return 0 ;;
      esac
      ;;
    env)
      case "$flag" in
        -u) return 0 ;;
      esac
      ;;
  esac
  return 1
}

# Drop the options a stripped wrapper owns, plus the duration of `timeout`.
_cmdseg_drop_options() {
  local rest="${1-}"
  local wrapper="${2-}"
  local guard=0
  local token next
  local duration_re='^[0-9]+([.][0-9]+)?[smhd]?$'
  while [ "$guard" -lt 16 ]; do
    guard=$((guard + 1))
    rest=$(_cmdseg_trim "$rest")
    token="${rest%%[[:space:]]*}"
    if [ -z "$token" ]; then
      break
    fi
    if [ "$token" = '--' ]; then
      # End of the wrapper's own options; the real command starts here.
      rest=$(_cmdseg_trim "${rest:${#token}}")
      break
    fi
    case "$token" in
      '-'*)
        rest=$(_cmdseg_trim "${rest:${#token}}")
        # `sudo -u root rm -rf /` must not leave `root` as the command name.
        if _cmdseg_takes_arg "$wrapper" "$token"; then
          next="${rest%%[[:space:]]*}"
          if [ -n "$next" ]; then
            rest=$(_cmdseg_trim "${rest:${#next}}")
          fi
        fi
        continue
        ;;
    esac
    if [ "$wrapper" = 'timeout' ] && [[ "$token" =~ $duration_re ]]; then
      rest="${rest:${#token}}"
      wrapper=''
      continue
    fi
    break
  done
  printf '%s' "$(_cmdseg_trim "$rest")"
  return 0
}

# Print the segment with leading env assignments and command wrappers removed.
strip_prefixes() {
  local segment="${1-}"
  local guard=0
  local token rest name inner
  local assign_re='^[A-Za-z_][A-Za-z0-9_]*='

  segment=$(_cmdseg_trim "$segment")
  while [ "$guard" -lt 16 ]; do
    guard=$((guard + 1))
    token="${segment%%[[:space:]]*}"
    if [ -z "$token" ]; then
      break
    fi
    rest=$(_cmdseg_trim "${segment:${#token}}")
    # Match on the basename so that /bin/sh and /usr/bin/env are covered too.
    name="${token##*/}"

    if [[ "$token" =~ $assign_re ]]; then
      segment="$rest"
      continue
    fi

    case "$name" in
      sh|bash|zsh)
        # Only the `-c` form is a wrapper; `bash script.sh` is the real command.
        inner=$(_cmdseg_shell_c_arg "$rest")
        if [ -n "$inner" ]; then
          segment=$(_cmdseg_trim "$inner")
          continue
        fi
        break
        ;;
      sudo|env|command|time|timeout|nohup|xargs)
        segment=$(_cmdseg_drop_options "$rest" "$name")
        continue
        ;;
    esac
    break
  done
  printf '%s' "$segment"
  return 0
}
