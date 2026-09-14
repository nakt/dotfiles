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
#     `&&`, `||`, `;`, `|`, `&` and newlines. The `&` of `\&`, `>&`, `&>` and
#     `<&` is not an operator and does not split. Consumers must split each
#     line on its FIRST tab, since a segment may legitimately contain further
#     tabs.
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
#   strip_prefixes_into <varname> <segment>
#     Assign what strip_prefixes would print to the named variable instead of
#     printing it. A caller that strips one segment at a time should prefer
#     this form: reading the printed value through a command substitution forks
#     a subshell per call, and a command holding a few thousand segments then
#     spends seconds on the forks alone. <varname> must not begin with
#     `__csp_`, which is the prefix the locals of this function use.
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
#   - Quoting is not fully parsed. A `&&`, `||`, `;`, `|` or `&` inside a
#     quoted string is treated as an operator.
#   - A `<<WORD` inside a quoted string is still read as a heredoc marker. Its
#     body is put back only when no terminator line follows, so a string that
#     happens to be followed by a line equal to WORD still loses those lines.
#     When a real heredoc is declared after such a false marker, its body is
#     put back together with the rest. That fails towards over-detection (an
#     extra deny or lint), which is the safe direction for this library.
#   - `eval` and command substitution are deliberately not unwrapped.
#   - The short wrapper options listed above, and a fixed set of long forms
#     that always take a separate-token argument, have their argument taken
#     with them; see `_cmdseg_takes_arg` for the exact list (sudo, xargs, env
#     and timeout options). `--opt=value` forms and options whose argument is
#     optional (`sudo --preserve-env[=list]`, `xargs --replace[=str]`) are
#     deliberately left off that list: registering them would swallow the
#     real command as if it were their argument. Any long form not on the
#     list is only dropped itself, so e.g.
#     `xargs --process-slot-var X rm -rf /` leaves `rm` behind `X` instead of
#     at the front.
#   - `cd` option tokens (`cd -P docs`, `cd -L /etc`, `cd -- docs`) are skipped,
#     but `cd -P` with no operand is treated like a bare `cd` and returns to
#     <base_cwd> rather than to $HOME.
#   - A `cd` inside `sh -c '...'` is not tracked, because the segment begins
#     with the wrapper instead of with `cd`.
#   - The `-c` argument ends at the first matching quote, so a nested quote as
#     in `sh -c "rm -rf \"$HOME\""` comes back truncated.
#   - Prefix removal gives up after 16 tokens, so a segment carrying more than
#     16 leading wrappers or options keeps the remainder as-is.

# Every helper below assigns its result to a caller-named variable instead of
# printing it, because `$(helper ...)` forks a subshell and these run once per
# segment, per token or per line. Each helper prefixes its own locals so that a
# caller can hand it any variable name that does not carry that prefix.

# Assign <text> with leading and trailing whitespace removed to <varname>.
_cmdseg_trim_into() {
  local __cst_name="${1-}"
  local __cst_text="${2-}"
  while :; do
    case "$__cst_text" in
      [[:space:]]*) __cst_text="${__cst_text#?}" ;;
      *) break ;;
    esac
  done
  while :; do
    case "$__cst_text" in
      *[[:space:]]) __cst_text="${__cst_text%?}" ;;
      *) break ;;
    esac
  done
  printf -v "$__cst_name" '%s' "$__cst_text"
  return 0
}

# Assign <path> with a leading ~ / $HOME / ${HOME} expanded to <varname>.
# Anything else is left alone so that unresolvable paths simply fail to resolve
# later.
_cmdseg_expand_home_into() {
  local __ceh_name="${1-}"
  local __ceh_path="${2-}"
  local __ceh_home="${HOME:-}"
  case "$__ceh_path" in
    '~') __ceh_path="$__ceh_home" ;;
    '~/'*) __ceh_path="$__ceh_home/${__ceh_path#'~/'}" ;;
    '$HOME') __ceh_path="$__ceh_home" ;;
    '$HOME/'*) __ceh_path="$__ceh_home/${__ceh_path#'$HOME/'}" ;;
    '${HOME}') __ceh_path="$__ceh_home" ;;
    '${HOME}/'*) __ceh_path="$__ceh_home/${__ceh_path#'${HOME}/'}" ;;
  esac
  printf -v "$__ceh_name" '%s' "$__ceh_path"
  return 0
}

# Assign the heredoc delimiters declared on one command line to <varname>, one
# per line, each prefixed with `-` for the `<<-` form or `=` for the plain `<<`
# form. The value carries no trailing newline, so the caller decides how these
# lines join the ones it already holds. An empty value means the line declares
# no heredoc.
_cmdseg_heredoc_delims_into() {
  local __chd_name="${1-}"
  local __chd_rest="${2-}"
  local __chd_before __chd_dash __chd_delim
  local __chd_out=''
  local __chd_nl=$'\n'
  local __chd_word_re='^[A-Za-z_][A-Za-z0-9_.-]*'
  while :; do
    case "$__chd_rest" in
      *'<<'*) ;;
      *) break ;;
    esac
    __chd_before="${__chd_rest%%'<<'*}"
    __chd_rest="${__chd_rest:${#__chd_before}}"
    __chd_rest="${__chd_rest#'<<'}"
    # `<<<` is a here-string and has no body.
    case "$__chd_rest" in
      '<'*) __chd_rest="${__chd_rest#<}"; continue ;;
    esac
    __chd_dash='='
    case "$__chd_rest" in
      '-'*) __chd_dash='-'; __chd_rest="${__chd_rest#-}" ;;
    esac
    while :; do
      case "$__chd_rest" in
        [[:space:]]*) __chd_rest="${__chd_rest#?}" ;;
        *) break ;;
      esac
    done
    case "$__chd_rest" in
      '\'*) __chd_rest="${__chd_rest#\\}" ;;
    esac
    __chd_delim=''
    case "$__chd_rest" in
      "'"*)
        __chd_rest="${__chd_rest#\'}"
        case "$__chd_rest" in
          *"'"*)
            __chd_delim="${__chd_rest%%\'*}"
            __chd_rest="${__chd_rest:$(( ${#__chd_delim} + 1 ))}"
            ;;
          # No closing quote on this line, so this `<<` opens no heredoc. Keep
          # scanning the remainder: a real marker may still follow.
          *) __chd_delim='' ;;
        esac
        ;;
      '"'*)
        __chd_rest="${__chd_rest#\"}"
        case "$__chd_rest" in
          *'"'*)
            __chd_delim="${__chd_rest%%\"*}"
            __chd_rest="${__chd_rest:$(( ${#__chd_delim} + 1 ))}"
            ;;
          *) __chd_delim='' ;;
        esac
        ;;
      [A-Za-z_]*)
        if [[ "$__chd_rest" =~ $__chd_word_re ]]; then
          __chd_delim="${BASH_REMATCH[0]}"
          __chd_rest="${__chd_rest:${#__chd_delim}}"
        fi
        ;;
      *)
        # Not a heredoc marker, e.g. the `<<` of an arithmetic shift.
        continue
        ;;
    esac
    if [ -n "$__chd_delim" ]; then
      if [ -z "$__chd_out" ]; then
        __chd_out="$__chd_dash$__chd_delim"
      else
        __chd_out="$__chd_out$__chd_nl$__chd_dash$__chd_delim"
      fi
    fi
  done
  printf -v "$__chd_name" '%s' "$__chd_out"
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
    _cmdseg_heredoc_delims_into added "$line"
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
  local amp=$'\003'
  # Same glob trick as esc_semi_pat: this matches a literal `\&` only.
  local esc_amp_pat='\\&'

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
  # Only a standalone `&` backgrounds a command. Park the `&` character of
  # `\&`, `2>&1`, `&>out` and `<&0` so that the split below leaves them alone.
  # This runs after the `&&` replacement, because parking first would break
  # `&&` and with it every segment boundary.
  body="${body//$esc_amp_pat/\\$amp}"
  body="${body//>&/>$amp}"
  body="${body//&>/$amp>}"
  body="${body//<&/<$amp}"
  body="${body//&/$nl}"
  body="${body//||/$nl}"
  body="${body//;/$nl}"
  body="${body//|/$nl}"

  while IFS= read -r line; do
    _cmdseg_trim_into seg "$line"
    # Drop grouping punctuation so `(cd docs && ...)` is tracked like `cd docs`.
    while :; do
      case "$seg" in
        '('*) _cmdseg_trim_into seg "${seg#\(}" ;;
        '{'[[:space:]]*) _cmdseg_trim_into seg "${seg#\{}" ;;
        *) break ;;
      esac
    done
    # A closing paren is only punctuation when the segment opened none itself,
    # so `rm -rf $(pwd)` keeps its own parenthesis.
    case "$seg" in
      *'('*) : ;;
      *')') _cmdseg_trim_into seg "${seg%\)}" ;;
    esac
    seg="${seg//$sep/$esc_semi_rep}"
    seg="${seg//$sep2/$clobber}"
    # An `&` in the replacement of ${var//pat/rep} means "the matched text" on
    # bash 5.2 and newer (patsub_replacement), so ${seg//$amp/&} restores
    # nothing there, while `\&` leaves a literal backslash behind on 3.2.
    # Rebuild the string instead: `&` in an assignment is literal everywhere.
    while :; do
      case "$seg" in
        *"$amp"*) seg="${seg%%"$amp"*}&${seg#*"$amp"}" ;;
        *) break ;;
      esac
    done
    if [ -z "$seg" ]; then
      continue
    fi
    printf '%s\t%s\n' "$cwd" "$seg"
    case "$seg" in
      cd|cd[[:space:]]*)
        _cmdseg_trim_into dir "${seg#cd}"
        # Skip the option forms (`cd -P docs`, `cd -L /etc`, `cd -- docs`) so
        # that the operand is tracked. A bare `-` is the previous-directory
        # form and is handled with the no-operand case below.
        cd_guard=0
        while [ "$cd_guard" -lt 16 ]; do
          cd_guard=$((cd_guard + 1))
          case "$dir" in
            '--') dir=''; break ;;
            '--'[[:space:]]*) _cmdseg_trim_into dir "${dir#--}"; break ;;
            -?*)
              tok="${dir%%[[:space:]]*}"
              _cmdseg_trim_into dir "${dir:${#tok}}"
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
          _cmdseg_expand_home_into dir "$dir"
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

# Assign the argument of `sh -c` / `bash -c` / `zsh -c` to <varname>, or the
# empty string when the wrapper carries no -c. Every path assigns, so a caller
# looping over tokens never reads the value left by an earlier round.
_cmdseg_shell_c_arg_into() {
  local __csc_name="${1-}"
  local __csc_rest="${2-}"
  local __csc_guard=0
  local __csc_token __csc_arg=''
  local __csc_c_re='^-[A-Za-z]*c[A-Za-z]*$'
  while [ "$__csc_guard" -lt 16 ]; do
    __csc_guard=$((__csc_guard + 1))
    _cmdseg_trim_into __csc_rest "$__csc_rest"
    __csc_token="${__csc_rest%%[[:space:]]*}"
    if [ -z "$__csc_token" ]; then
      break
    fi
    case "$__csc_token" in
      '--'*) __csc_rest="${__csc_rest:${#__csc_token}}"; continue ;;
      '-'*)
        if [[ "$__csc_token" =~ $__csc_c_re ]]; then
          _cmdseg_trim_into __csc_rest "${__csc_rest:${#__csc_token}}"
          case "$__csc_rest" in
            "'"*)
              __csc_rest="${__csc_rest#\'}"
              case "$__csc_rest" in
                *"'"*) __csc_arg="${__csc_rest%%\'*}" ;;
                *) __csc_arg="$__csc_rest" ;;
              esac
              ;;
            '"'*)
              __csc_rest="${__csc_rest#\"}"
              case "$__csc_rest" in
                *'"'*) __csc_arg="${__csc_rest%%\"*}" ;;
                *) __csc_arg="$__csc_rest" ;;
              esac
              ;;
            *) __csc_arg="$__csc_rest" ;;
          esac
          printf -v "$__csc_name" '%s' "$__csc_arg"
          return 0
        fi
        __csc_rest="${__csc_rest:${#__csc_token}}"
        continue
        ;;
    esac
    break
  done
  printf -v "$__csc_name" '%s' ''
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
        --user|--group|--prompt|--other-user|--role|--type|--command-timeout|--host|--chroot|--chdir|--close-from) return 0 ;;
      esac
      ;;
    xargs)
      case "$flag" in
        -I|-L|-n|-P|-s|-E|-a|-d|-J) return 0 ;;
        --max-args|--max-procs|--max-chars|--arg-file|--delimiter) return 0 ;;
      esac
      ;;
    env)
      case "$flag" in
        # `-S` / `--split-string` is left off on purpose even though it does
        # take a separate argument: that argument IS the command
        # (`env -S 'rm -rf /'` runs the deletion), so skipping it would carry
        # the real command away exactly as registering an option that takes
        # no argument would.
        -u|-C) return 0 ;;
        --unset|--chdir) return 0 ;;
      esac
      ;;
    timeout)
      case "$flag" in
        -s|--signal|-k|--kill-after) return 0 ;;
      esac
      ;;
  esac
  return 1
}

# Assign <rest> with the options the wrapper owns dropped, plus the duration of
# `timeout`, to <varname>.
_cmdseg_drop_options_into() {
  local __cdo_name="${1-}"
  local __cdo_rest="${2-}"
  local __cdo_wrapper="${3-}"
  local __cdo_guard=0
  local __cdo_token __cdo_next
  local __cdo_duration_re='^[0-9]+([.][0-9]+)?[smhd]?$'
  while [ "$__cdo_guard" -lt 16 ]; do
    __cdo_guard=$((__cdo_guard + 1))
    _cmdseg_trim_into __cdo_rest "$__cdo_rest"
    __cdo_token="${__cdo_rest%%[[:space:]]*}"
    if [ -z "$__cdo_token" ]; then
      break
    fi
    if [ "$__cdo_token" = '--' ]; then
      # End of the wrapper's own options; the real command starts here.
      _cmdseg_trim_into __cdo_rest "${__cdo_rest:${#__cdo_token}}"
      break
    fi
    case "$__cdo_token" in
      '-'*)
        _cmdseg_trim_into __cdo_rest "${__cdo_rest:${#__cdo_token}}"
        # `sudo -u root rm -rf /` must not leave `root` as the command name.
        if _cmdseg_takes_arg "$__cdo_wrapper" "$__cdo_token"; then
          __cdo_next="${__cdo_rest%%[[:space:]]*}"
          if [ -n "$__cdo_next" ]; then
            _cmdseg_trim_into __cdo_rest "${__cdo_rest:${#__cdo_next}}"
          fi
        fi
        continue
        ;;
    esac
    if [ "$__cdo_wrapper" = 'timeout' ] && [[ "$__cdo_token" =~ $__cdo_duration_re ]]; then
      __cdo_rest="${__cdo_rest:${#__cdo_token}}"
      __cdo_wrapper=''
      continue
    fi
    break
  done
  _cmdseg_trim_into "$__cdo_name" "$__cdo_rest"
  return 0
}

# Assign the segment with leading env assignments and command wrappers removed
# to <varname>.
strip_prefixes_into() {
  local __csp_name="${1-}"
  local __csp_segment="${2-}"
  local __csp_guard=0
  local __csp_token __csp_rest __csp_base __csp_inner
  local __csp_assign_re='^[A-Za-z_][A-Za-z0-9_]*='

  _cmdseg_trim_into __csp_segment "$__csp_segment"
  while [ "$__csp_guard" -lt 16 ]; do
    __csp_guard=$((__csp_guard + 1))
    __csp_token="${__csp_segment%%[[:space:]]*}"
    if [ -z "$__csp_token" ]; then
      break
    fi
    _cmdseg_trim_into __csp_rest "${__csp_segment:${#__csp_token}}"
    # Match on the basename so that /bin/sh and /usr/bin/env are covered too.
    __csp_base="${__csp_token##*/}"

    if [[ "$__csp_token" =~ $__csp_assign_re ]]; then
      __csp_segment="$__csp_rest"
      continue
    fi

    case "$__csp_base" in
      sh|bash|zsh)
        # Only the `-c` form is a wrapper; `bash script.sh` is the real command.
        _cmdseg_shell_c_arg_into __csp_inner "$__csp_rest"
        if [ -n "$__csp_inner" ]; then
          _cmdseg_trim_into __csp_segment "$__csp_inner"
          continue
        fi
        break
        ;;
      sudo|env|command|time|timeout|nohup|xargs)
        _cmdseg_drop_options_into __csp_segment "$__csp_rest" "$__csp_base"
        continue
        ;;
    esac
    break
  done
  printf -v "$__csp_name" '%s' "$__csp_segment"
  return 0
}

# Print the segment with leading env assignments and command wrappers removed.
# Kept for callers that want the value through a command substitution; a caller
# in a per-segment loop should use strip_prefixes_into instead.
strip_prefixes() {
  local __spw_out=''
  strip_prefixes_into __spw_out "${1-}"
  printf '%s' "$__spw_out"
  return 0
}
