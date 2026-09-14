#!/bin/bash
# Timing benchmark for validate-rm.sh at a growing segment count.
#
# validate-rm.sh runs under `timeout: 5` in settings.json, and a hook that
# times out does not block the tool call (the Timeouts section of
# https://code.claude.com/docs/en/hooks says so), so a command with many
# segments has to stay well inside that budget or a deletion goes through
# unjudged. This script measures one hook run over a command built from N
# copies of `rm -f tmp.txt`. Both joins are measured because they take
# different paths through the library: the newline join also runs the heredoc
# scan once per line.
#
# This is a measurement, not a test. It never fails on a slow number and
# run.sh does not call it, because wall-clock timings depend on machine load.
#
# Usage
#   bash .claude/hooks/tests/bench.sh [count ...]
#     counts: how many segments to build. With no argument 500 1000 2000 run.
#
#   Comparing a change against its baseline:
#     cp -R .claude/hooks .workspace/NN_name/hooks-head   # the old copy
#     HOOK_TESTS_HOOKS_DIR=.workspace/NN_name/hooks-head \
#       bash .claude/hooks/tests/bench.sh
#     bash .claude/hooks/tests/bench.sh
#
# Exit status
#   0  every measurement was taken
#   2  the benchmark could not run at all (no jq, no clock, hook unreadable,
#      or an argument that is not a count)
#
# Environment
#   HOOK_TESTS_HOOKS_DIR  Directory holding the hook under test. Defaults to
#                         the parent of this file, which is the same name and
#                         meaning run.sh gives it. Point it at a copy of
#                         .claude/hooks to measure a baseline.
#
# Notes
#   - The hook is started through its own shebang, the way settings.json
#     starts it, so the shell under test is always the one production uses
#     (/bin/bash, 3.2.57 on macOS) no matter which bash runs this script. The
#     header line of the output names it. Measuring the hook under the bash on
#     PATH instead reports numbers that are not comparable: a `${var//pat/rep}`
#     whose pattern matches thousands of times is super-quadratic on 3.2.57
#     and linear from 5.2 on, which is a factor of sixty on the `&&` join.
#   - The acceptance number is under 2000 ms at 2000 segments, and both joins
#     are held to it. The `&&` join was exempt for as long as split_segments
#     cut with `${body//&&/$nl}`: that one substitution, not any fork,
#     accounted for nearly all of the minute and a half a 2000 segment `&&`
#     command took on 3.2.57. The operators are cut in a single awk pass now,
#     so the two joins land within a few hundred milliseconds of each other.
#   - What `${var//pat/rep}` costs is set by how many times the pattern
#     matches, not by how long the string is: 34 KB holding no `&&` at all
#     took the same 16 ms as an empty one. One such substitution still runs
#     ahead of the awk pass (the `\` + newline line continuation), and the
#     fallback split runs the whole chain, so a machine with no awk on PATH is
#     back on the old numbers.
#   - The built command holds no `cd`, so the directory-resolving subshell of
#     split_segments is deliberately not part of what is measured.

set -u

NL=$'\n'

_self="${BASH_SOURCE[0]:-$0}"
case "$_self" in
  */*) _self_dir="${_self%/*}" ;;
  *) _self_dir='.' ;;
esac
TESTS_DIR=$(cd "$_self_dir" 2>/dev/null && pwd -P) || exit 2
if [ -n "${HOOK_TESTS_HOOKS_DIR:-}" ]; then
  HOOKS_DIR=$(cd "$HOOK_TESTS_HOOKS_DIR" 2>/dev/null && pwd -P) || exit 2
else
  HOOKS_DIR=$(cd "$TESTS_DIR/.." 2>/dev/null && pwd -P) || exit 2
fi
HOOK="$HOOKS_DIR/validate-rm.sh"
# The shell the hook's shebang names. Read it from the file rather than
# assuming, so that the output reports the shell that was really measured.
HOOK_SHELL=$(head -1 "$HOOK" 2>/dev/null)
HOOK_SHELL="${HOOK_SHELL#\#!}"
HOOK_SHELL="${HOOK_SHELL%% *}"
case "$HOOK_SHELL" in
  /*) ;;
  *) HOOK_SHELL='/bin/bash' ;;
esac

# ---------------------------------------------------------------- preflight

if ! command -v jq >/dev/null 2>&1; then
  printf 'bench: jq is required to build the hook input and was not found on PATH\n' >&2
  exit 2
fi
if [ ! -x "$HOOK" ]; then
  printf 'bench: cannot execute %s\n' "$HOOK" >&2
  exit 2
fi

# bash 5 carries a sub-second clock of its own; bash 3.2 has none, so python3
# stands in there. One probe here keeps the check out of the timed section.
PYTHON3=''
if [ -z "${EPOCHREALTIME:-}" ]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON3='python3'
  else
    printf 'bench: need bash 5 (EPOCHREALTIME) or python3 for a millisecond clock\n' >&2
    exit 2
  fi
fi

# ---------------------------------------------------------------- helpers

# Print the wall clock in milliseconds since the epoch.
now_ms() {
  local t
  if [ -n "${EPOCHREALTIME:-}" ]; then
    # A locale may write the fraction after a comma. `10#` keeps a fraction
    # such as 012345 from being read as octal.
    t="${EPOCHREALTIME/,/.}"
    printf '%s' "$(( ${t%%.*} * 1000 + 10#${t#*.} / 1000 ))"
    return 0
  fi
  "$PYTHON3" -c 'import time; print(int(time.time() * 1000))'
  return $?
}

# Print <count> copies of a harmless `rm` segment joined with <sep>.
build() {
  local count="${1-}"
  local sep="${2-}"
  local tpl='rm -f tmp.txt'
  local out='' i=1
  while [ "$i" -le "$count" ]; do
    if [ -z "$out" ]; then
      out="$tpl"
    else
      out="$out$sep$tpl"
    fi
    i=$((i + 1))
  done
  printf '%s' "$out"
  return 0
}

# ---------------------------------------------------------------- run

COUNTS="$*"
if [ -z "$COUNTS" ]; then
  COUNTS='500 1000 2000'
fi
for count in $COUNTS; do
  case "$count" in
    ''|*[!0-9]*)
      printf 'bench: not a segment count: %s\n' "$count" >&2
      exit 2
      ;;
  esac
done

printf 'hook : %s\n' "$HOOK"
printf 'shell: %s\n' "$("$HOOK_SHELL" --version 2>/dev/null | head -1)"
printf '%-8s  %-8s  %s\n' 'count' 'join' 'elapsed'

for count in $COUNTS; do
  for join in and nl; do
    case "$join" in
      and) cmd=$(build "$count" ' && '); label='&&' ;;
      *) cmd=$(build "$count" "$NL"); label='newline' ;;
    esac
    json=$(jq -n --arg c "$cmd" --arg d "$TESTS_DIR" \
      '{tool_name:"Bash", cwd:$d, tool_input:{command:$c}}') || exit 2
    start=$(now_ms) || exit 2
    printf '%s' "$json" | "$HOOK" >/dev/null
    end=$(now_ms) || exit 2
    printf '%-8s  %-8s  %sms\n' "$count" "$label" "$((end - start))"
  done
done

exit 0
