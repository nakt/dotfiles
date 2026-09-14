#!/bin/bash
# JSON-input tests for the hooks in .claude/hooks/.
#
# Every hook reads a hook-input JSON on stdin and answers with an exit code
# plus stdout / stderr. These tests build that JSON with jq, feed it to the
# hook, and compare the answer with the expectation recorded in cases/.
#
# Usage
#   bash .claude/hooks/tests/run.sh [suite ...]
#     suites: validate-rm md-targets lint-markdown plan-to-html check-docs
#     With no argument every suite runs.
#
# Exit status
#   0  every case passed (a skipped case does not fail the run)
#   1  at least one case failed, or a case file could not be read
#   2  the harness could not start at all (no jq, a hook missing, bad argument)
#
# Environment
#   HOOK_TESTS_HOOKS_DIR  Directory holding the hooks under test. Defaults to
#                         the parent of this file. Point it at a copy of
#                         .claude/hooks to confirm that a deliberate defect is
#                         actually caught by these cases.
#   HOOK_TESTS_WORKDIR    Scratch directory for fixtures. Defaults to
#                         <repo>/.workspace/28_hook-tests. Nothing is ever
#                         written inside the tracked part of the repository.
#                         Each suite rebuilds its own fixtures and leaves them
#                         behind, so a failing case can be reproduced by hand.
#
# Notes for anyone extending this
#   - /bin/bash on macOS is 3.2.57, so no mapfile, no associative arrays and
#     no ${var,,}.
#   - Fields in cases/ are separated by a single TAB. A run of tabs collapses
#     into one because TAB is IFS whitespace, so every optional field uses the
#     sentinel `-` instead of an empty string.
#   - Case files are read on file descriptor 3 so that a hook (or git) reading
#     stdin cannot swallow the remaining cases.
#   - Fixtures whose mtime matters are touched right before their suite runs,
#     because md_targets only reports files written within the last 120 s.

set -u

NL=$'\n'
TAB=$'\t'

_self="${BASH_SOURCE[0]:-$0}"
case "$_self" in
  */*) _self_dir="${_self%/*}" ;;
  *) _self_dir='.' ;;
esac
TESTS_DIR=$(cd "$_self_dir" 2>/dev/null && pwd -P) || exit 2
CASES_DIR="$TESTS_DIR/cases"
# pwd -P resolves the ~/.claude symlink, so the repository root is found the
# same way whether the hook is invoked through the repo or through $HOME.
REPO_ROOT=$(cd "$TESTS_DIR/../../.." 2>/dev/null && pwd -P) || exit 2
if [ -n "${HOOK_TESTS_HOOKS_DIR:-}" ]; then
  HOOKS_DIR=$(cd "$HOOK_TESTS_HOOKS_DIR" 2>/dev/null && pwd -P) || exit 2
else
  HOOKS_DIR=$(cd "$TESTS_DIR/.." 2>/dev/null && pwd -P) || exit 2
fi
WORKDIR="${HOOK_TESTS_WORKDIR:-$REPO_ROOT/.workspace/28_hook-tests}"

# ---------------------------------------------------------------- preflight

if ! command -v jq >/dev/null 2>&1; then
  printf 'harness: jq is required by every hook and was not found on PATH\n' >&2
  exit 2
fi

for _needed in validate-rm.sh lint-markdown.sh plan-to-html.sh check-docs.sh \
               lib/md-targets.sh lib/command-segments.sh; do
  if [ ! -r "$HOOKS_DIR/$_needed" ]; then
    printf 'harness: cannot read %s\n' "$HOOKS_DIR/$_needed" >&2
    exit 2
  fi
done

case "$WORKDIR" in
  ''|/|/bin|/etc|/usr|"$HOME")
    printf 'harness: refusing to use %s as the scratch directory\n' "$WORKDIR" >&2
    exit 2
    ;;
esac
mkdir -p "$WORKDIR" || exit 2
ERRFILE="$WORKDIR/stderr.txt"
: > "$ERRFILE" || exit 2

# ---------------------------------------------------------------- reporting

TOTAL=0
NPASS=0
NFAIL=0
NSKIP=0
SUITE_NAME=''
SUITE_PASS=0
SUITE_FAIL=0
SUITE_SKIP=0

suite_begin() {
  SUITE_NAME="$1"
  SUITE_PASS=0
  SUITE_FAIL=0
  SUITE_SKIP=0
  printf '\n=== %s ===\n' "$SUITE_NAME"
}

suite_end() {
  printf -- '--- %s: pass=%d fail=%d skip=%d\n' \
    "$SUITE_NAME" "$SUITE_PASS" "$SUITE_FAIL" "$SUITE_SKIP"
}

ok() {
  TOTAL=$((TOTAL + 1)); NPASS=$((NPASS + 1)); SUITE_PASS=$((SUITE_PASS + 1))
  printf 'PASS  %s\n' "$1"
}

skipped() {
  TOTAL=$((TOTAL + 1)); NSKIP=$((NSKIP + 1)); SUITE_SKIP=$((SUITE_SKIP + 1))
  printf 'SKIP  %s  (%s)\n' "$1" "$2"
}

# Print one captured stream, indented and truncated so a long lint report does
# not bury the rest of the summary.
show_block() {
  local name="$1" value="$2"
  if [ -z "$value" ]; then
    printf '        %s: (empty)\n' "$name"
    return 0
  fi
  printf '        %s:\n' "$name"
  printf '%s\n' "$value" | head -20 | sed 's/^/          | /'
}

failed() { # failed <label> <expected> <actual> <exit> <stdout> <stderr>
  TOTAL=$((TOTAL + 1)); NFAIL=$((NFAIL + 1)); SUITE_FAIL=$((SUITE_FAIL + 1))
  printf 'FAIL  %s\n' "$1"
  printf '        expected: %s\n' "$2"
  printf '        actual  : %s\n' "$3"
  printf '        exit    : %s\n' "$4"
  show_block stdout "$5"
  show_block stderr "$6"
}

harness_error() {
  printf 'harness: %s\n' "$1" >&2
  TOTAL=$((TOTAL + 1))
  NFAIL=$((NFAIL + 1))
}

# ---------------------------------------------------------------- helpers

# Placeholder for the fixture root of the suite currently running.
FX_SUBST=''

# Turn a case field into the real string: `\n` and `\t` become the characters
# they name, @HOME@ becomes $HOME and @FX@ becomes the suite fixture root.
expand() {
  local s="${1-}"
  s="${s//\\n/$NL}"
  s="${s//\\t/$TAB}"
  s="${s//@HOME@/${HOME:-}}"
  if [ -n "$FX_SUBST" ]; then
    s="${s//@FX@/$FX_SUBST}"
  fi
  printf '%s' "$s"
  return 0
}

# Turn `a.md|sub/b.md` into absolute paths, one per line. `-` means none.
expand_paths() {
  local spec="${1-}" root="${2-}" rest item out=''
  if [ "$spec" = '-' ] || [ -z "$spec" ]; then
    return 0
  fi
  rest="$spec"
  while [ -n "$rest" ]; do
    item="${rest%%|*}"
    if [ "$item" = "$rest" ]; then rest=''; else rest="${rest#*|}"; fi
    [ -z "$item" ] && continue
    if [ -z "$out" ]; then out="$root/$item"; else out="$out$NL$root/$item"; fi
  done
  printf '%s' "$out"
  return 0
}

# Build the hook input JSON. <with_response> adds a tool_response that mentions
# .md files, so a hook that looked at the whole payload instead of at
# tool_input would be caught.
mk_json() { # mk_json <tool> <cwd> <payload> <with_response>
  local tool="$1" cwd="$2" payload="$3" resp="$4"
  local noise='noise: a.md bad1.md p1.md'
  if [ "$tool" = 'Bash' ]; then
    if [ "$resp" = 'yes' ]; then
      jq -n --arg t "$tool" --arg c "$cwd" --arg p "$payload" --arg n "$noise" \
        '{tool_name:$t, cwd:$c, tool_input:{command:$p}, tool_response:{stdout:$n}}'
    else
      jq -n --arg t "$tool" --arg c "$cwd" --arg p "$payload" \
        '{tool_name:$t, cwd:$c, tool_input:{command:$p}}'
    fi
  else
    if [ "$resp" = 'yes' ]; then
      jq -n --arg t "$tool" --arg c "$cwd" --arg p "$payload" --arg n "$noise" \
        '{tool_name:$t, cwd:$c, tool_input:{file_path:$p}, tool_response:{filePath:$n}}'
    else
      jq -n --arg t "$tool" --arg c "$cwd" --arg p "$payload" \
        '{tool_name:$t, cwd:$c, tool_input:{file_path:$p}}'
    fi
  fi
}

# Resolve a case's cwd field (relative to the fixture root, `.` for the root).
fx_cwd() {
  local root="$1" rel="$2"
  if [ "$rel" = '.' ] || [ -z "$rel" ]; then
    printf '%s' "$root"
  else
    printf '%s/%s' "$root" "$rel"
  fi
}

# Every substring in a `|` separated list must occur in the text.
contains_all() {
  local text="$1" spec="$2" rest item
  [ "$spec" = '-' ] && return 0
  rest="$spec"
  while [ -n "$rest" ]; do
    item="${rest%%|*}"
    if [ "$item" = "$rest" ]; then rest=''; else rest="${rest#*|}"; fi
    [ -z "$item" ] && continue
    case "$text" in
      *"$item"*) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# ---------------------------------------------------------------- validate-rm

# PreToolUse: a blocked command prints a permissionDecision of "deny" on stdout
# and still exits 0. Anything else on stdout is a defect of its own, so the
# three answers are kept apart.
vrm_decision() {
  local out="$1" d
  if [ -z "$out" ]; then
    printf 'pass'
    return 0
  fi
  d=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // ""' 2>/dev/null)
  if [ "$d" = 'deny' ]; then
    printf 'deny'
  else
    printf 'unexpected-stdout'
  fi
  return 0
}

vrm_file() {
  local path="$1"
  local expect raw cmd json out err rc actual label
  if [ ! -r "$path" ]; then
    harness_error "cannot read case file $path"
    return 0
  fi
  while IFS=$TAB read -r expect raw <&3; do
    case "$expect" in ''|'#'*) continue ;; esac
    cmd=$(expand "$raw")
    json=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
    : > "$ERRFILE"
    out=$(printf '%s' "$json" | /bin/bash "$HOOKS_DIR/validate-rm.sh" 2>"$ERRFILE")
    rc=$?
    err=$(cat "$ERRFILE")
    actual=$(vrm_decision "$out")
    label="validate-rm: $raw"
    if [ "$actual" = "$expect" ] && [ "$rc" -eq 0 ] && [ -z "$err" ]; then
      ok "$label"
    else
      failed "$label" "$expect, exit 0, no stderr" "$actual" "$rc" "$out" "$err"
    fi
  done 3< "$path"
  return 0
}

# validate-rm is fail-closed when jq is missing: it denies anything whose raw
# JSON mentions rm or find and lets everything else through, so that jq can
# still be reinstalled through the tool.
vrm_nojq() {
  local path="$1"
  local minpath="$WORKDIR/nojq-bin"
  local expect raw cmd json out err rc actual label catpath
  if [ ! -r "$path" ]; then
    harness_error "cannot read case file $path"
    return 0
  fi
  # A PATH holding only `cat` (the one external command the hook runs before
  # it looks for jq). /usr/bin and /bin cannot be used because macOS ships its
  # own jq there.
  catpath=$(command -v cat 2>/dev/null)
  if [ -z "$catpath" ]; then
    skipped 'validate-rm: jq-missing fail-closed cases' 'cat was not found on PATH'
    return 0
  fi
  rm -rf "$minpath"
  if ! mkdir -p "$minpath" || ! ln -s "$catpath" "$minpath/cat"; then
    skipped 'validate-rm: jq-missing fail-closed cases' 'could not build a jq-free PATH'
    return 0
  fi
  if PATH="$minpath" command -v jq >/dev/null 2>&1; then
    skipped 'validate-rm: jq-missing fail-closed cases' "jq is still reachable from $minpath"
    return 0
  fi
  while IFS=$TAB read -r expect raw <&3; do
    case "$expect" in ''|'#'*) continue ;; esac
    cmd=$(expand "$raw")
    json=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
    : > "$ERRFILE"
    out=$(printf '%s' "$json" | PATH="$minpath" /bin/bash "$HOOKS_DIR/validate-rm.sh" 2>"$ERRFILE")
    rc=$?
    err=$(cat "$ERRFILE")
    # The deny JSON is printed literally here, so parse it the same way.
    actual=$(vrm_decision "$out")
    label="validate-rm (no jq): $raw"
    if [ "$actual" = "$expect" ] && [ "$rc" -eq 0 ] && [ -z "$err" ]; then
      ok "$label"
    else
      failed "$label" "$expect, exit 0, no stderr" "$actual" "$rc" "$out" "$err"
    fi
  done 3< "$path"
  return 0
}

run_validate_rm() {
  suite_begin validate-rm
  FX_SUBST=''
  vrm_file "$CASES_DIR/validate-rm-deny.txt"
  vrm_file "$CASES_DIR/validate-rm-pass.txt"
  vrm_file "$CASES_DIR/validate-rm-limits.txt"
  vrm_nojq "$CASES_DIR/validate-rm-nojq.txt"
  suite_end
}

# ---------------------------------------------------------------- md-targets

FXMD=''

setup_md_fixtures() {
  FXMD="$WORKDIR/fx/md"
  rm -rf "$FXMD"
  mkdir -p "$FXMD/sub" || return 1
  local f
  for f in a.md b.md out.md other.md fresh.md s.md t.md d.md all.md sub/y.md sub/fresh.md; do
    printf 'fixture\n' > "$FXMD/$f" || return 1
  done
  printf 'not markdown\n' > "$FXMD/note.txt" || return 1
  printf 'fixture\n' > "$FXMD/old.md" || return 1
  # An explicit mtime keeps the "too old to be this call's output" case from
  # depending on how long the run takes.
  touch -t 202001010000 "$FXMD/old.md" || return 1
  return 0
}

run_md_targets() {
  suite_begin md-targets
  if ! setup_md_fixtures; then
    harness_error 'could not build the md-targets fixtures'
    suite_end
    return 0
  fi
  FX_SUBST="$FXMD"
  local path="$CASES_DIR/md-targets.tsv"
  if [ ! -r "$path" ]; then
    harness_error "cannot read case file $path"
    suite_end
    return 0
  fi
  local expect tool cwdrel envspec raw payload json want got cwd label rc err
  while IFS=$TAB read -r expect tool cwdrel envspec raw <&3; do
    case "$expect" in ''|'#'*) continue ;; esac
    payload=$(expand "$raw")
    cwd=$(fx_cwd "$FXMD" "$cwdrel")
    json=$(mk_json "$tool" "$cwd" "$payload" yes)
    want=$(expand_paths "$expect" "$FXMD")
    : > "$ERRFILE"
    # The redirection has to sit inside the subshell: a `2>file` written after
    # a command substitution is applied only after the substitution has run.
    got=$(
      exec 2>"$ERRFILE"
      if [ "$envspec" != '-' ]; then export "$envspec"; fi
      . "$HOOKS_DIR/lib/md-targets.sh"
      md_targets "$json"
    )
    rc=$?
    err=$(cat "$ERRFILE")
    label="md-targets [$tool cwd=$cwdrel env=$envspec]: $raw"
    if [ "$got" = "$want" ] && [ "$rc" -eq 0 ] && [ -z "$err" ]; then
      ok "$label"
    else
      failed "$label" "${want:-(no target)}" "${got:-(no target)}" "$rc" "$got" "$err"
    fi
  done 3< "$path"
  FX_SUBST=''
  suite_end
  return 0
}

# ---------------------------------------------------------------- lint-markdown

FXLINT=''

setup_lint_fixtures() {
  FXLINT="$WORKDIR/fx/lint"
  rm -rf "$FXLINT"
  mkdir -p "$FXLINT/.claude/plans" || return 1
  # MD022 (no blank line after the heading) and MD047 (no final newline).
  printf '# Bad One\nText right after heading.' > "$FXLINT/bad1.md" || return 1
  # MD012 (consecutive blank lines) and MD047.
  printf '# Bad Two\n\n\n\nText.' > "$FXLINT/bad2.md" || return 1
  printf '# Good\n\nAll fine here.\n' > "$FXLINT/good.md" || return 1
  printf 'not markdown\n' > "$FXLINT/note.txt" || return 1
  printf '# Plan\nNo blank line.' > "$FXLINT/.claude/plans/p1.md" || return 1
  printf '# Old\nNo blank line.' > "$FXLINT/old.md" || return 1
  touch -t 202001010000 "$FXLINT/old.md" || return 1
  return 0
}

run_lint_markdown() {
  suite_begin lint-markdown
  local cfg="$HOME/.config/markdown-cli2/.markdownlint-cli2.jsonc"
  if ! command -v markdownlint-cli2 >/dev/null 2>&1; then
    skipped 'lint-markdown: whole suite' 'markdownlint-cli2 is not installed'
    suite_end
    return 0
  fi
  if [ ! -r "$cfg" ]; then
    # Without the config the tool fails on every input, so a clean fixture
    # would look like a violation and a violating one would look clean.
    skipped 'lint-markdown: whole suite' "config not readable: $cfg"
    suite_end
    return 0
  fi
  if ! setup_lint_fixtures; then
    harness_error 'could not build the lint-markdown fixtures'
    suite_end
    return 0
  fi
  FX_SUBST="$FXLINT"
  local path="$CASES_DIR/lint-markdown.tsv"
  if [ ! -r "$path" ]; then
    harness_error "cannot read case file $path"
    FX_SUBST=''
    suite_end
    return 0
  fi
  local want_exit want_err tool cwdrel raw payload json cwd out err rc label
  while IFS=$TAB read -r want_exit want_err tool cwdrel raw <&3; do
    case "$want_exit" in ''|'#'*) continue ;; esac
    payload=$(expand "$raw")
    cwd=$(fx_cwd "$FXLINT" "$cwdrel")
    json=$(mk_json "$tool" "$cwd" "$payload" yes)
    : > "$ERRFILE"
    out=$(printf '%s' "$json" | /bin/bash "$HOOKS_DIR/lint-markdown.sh" 2>"$ERRFILE")
    rc=$?
    err=$(cat "$ERRFILE")
    label="lint-markdown [$tool]: $raw"
    if [ "$rc" -ne "$want_exit" ]; then
      failed "$label" "exit $want_exit" "exit $rc" "$rc" "$out" "$err"
    elif [ -n "$out" ]; then
      # The feedback channel is exit 2 + stderr; stdout must stay empty.
      failed "$label" "exit $want_exit with empty stdout" 'stdout was not empty' "$rc" "$out" "$err"
    elif [ "$want_err" = '-' ] && [ -n "$err" ]; then
      failed "$label" "exit $want_exit with empty stderr" 'stderr was not empty' "$rc" "$out" "$err"
    elif ! contains_all "$err" "$want_err"; then
      failed "$label" "stderr mentioning $want_err" 'stderr did not mention it' "$rc" "$out" "$err"
    else
      ok "$label"
    fi
  done 3< "$path"
  FX_SUBST=''
  suite_end
  return 0
}

# ---------------------------------------------------------------- plan-to-html

FXPLAN=''

setup_plan_fixtures() {
  FXPLAN="$WORKDIR/fx/plan"
  rm -rf "$FXPLAN"
  mkdir -p "$FXPLAN/.claude/plans" "$FXPLAN/docs" || return 1
  printf '# Plan One\n\nbody text\n' > "$FXPLAN/.claude/plans/p1.md" || return 1
  printf '# Other\n\nbody text\n' > "$FXPLAN/docs/other.md" || return 1
  return 0
}

# Remove the generated HTML and refresh the mtimes so every case starts from
# the same state regardless of how long the previous case took.
reset_plan_fixtures() {
  find "$FXPLAN" -type f -name '*.html' -exec rm -f {} + 2>/dev/null
  touch "$FXPLAN/.claude/plans/p1.md" "$FXPLAN/docs/other.md"
  return 0
}

run_plan_to_html() {
  suite_begin plan-to-html
  if ! command -v pandoc >/dev/null 2>&1; then
    skipped 'plan-to-html: whole suite' 'pandoc is not installed'
    suite_end
    return 0
  fi
  if ! setup_plan_fixtures; then
    harness_error 'could not build the plan-to-html fixtures'
    suite_end
    return 0
  fi
  FX_SUBST="$FXPLAN"
  local path="$CASES_DIR/plan-to-html.tsv"
  if [ ! -r "$path" ]; then
    harness_error "cannot read case file $path"
    FX_SUBST=''
    suite_end
    return 0
  fi
  local expect tool cwdrel raw payload json cwd out err rc label want got
  while IFS=$TAB read -r expect tool cwdrel raw <&3; do
    case "$expect" in ''|'#'*) continue ;; esac
    reset_plan_fixtures
    payload=$(expand "$raw")
    cwd=$(fx_cwd "$FXPLAN" "$cwdrel")
    json=$(mk_json "$tool" "$cwd" "$payload" yes)
    : > "$ERRFILE"
    out=$(printf '%s' "$json" | /bin/bash "$HOOKS_DIR/plan-to-html.sh" 2>"$ERRFILE")
    rc=$?
    err=$(cat "$ERRFILE")
    want=$(expand_paths "$expect" "$FXPLAN")
    got=$(find "$FXPLAN" -type f -name '*.html' 2>/dev/null | LC_ALL=C sort)
    label="plan-to-html [$tool]: $raw"
    if [ "$rc" -ne 0 ]; then
      failed "$label" 'exit 0' "exit $rc" "$rc" "$out" "$err"
    elif [ "$got" != "$want" ]; then
      failed "$label" "${want:-(no html)}" "${got:-(no html)}" "$rc" "$out" "$err"
    elif [ -n "$err" ]; then
      failed "$label" 'no stderr' 'stderr was not empty' "$rc" "$out" "$err"
    else
      ok "$label"
    fi
  done 3< "$path"
  reset_plan_fixtures
  FX_SUBST=''
  suite_end
  return 0
}

# ---------------------------------------------------------------- check-docs

SANDBOX=''

# check-docs looks at the process working directory, not at the cwd in the
# JSON, so the cases need a throwaway git repository that has docs/, an
# origin/HEAD and an unpushed commit.
setup_check_docs() {
  SANDBOX="$WORKDIR/sandbox"
  rm -rf "$SANDBOX"
  mkdir -p "$SANDBOX/nohooks" || return 1
  local name repo origin
  for name in code nocode; do
    repo="$SANDBOX/repo-$name"
    origin="$SANDBOX/origin-$name.git"
    git init -q --bare "$origin" >/dev/null 2>&1 || return 1
    git init -q "$repo" >/dev/null 2>&1 || return 1
    git -C "$repo" symbolic-ref HEAD refs/heads/main || return 1
    git -C "$repo" config user.email tester@example.com || return 1
    git -C "$repo" config user.name tester || return 1
    git -C "$repo" config commit.gpgsign false || return 1
    # Keep any globally configured hook from running inside the sandbox.
    git -C "$repo" config core.hooksPath "$SANDBOX/nohooks" || return 1
    git -C "$repo" remote add origin "$origin" || return 1
    printf 'echo base\n' > "$repo/app.sh" || return 1
    printf '# Doc\n\nbase\n' > "$repo/README.md" || return 1
    git -C "$repo" add -A >/dev/null 2>&1 || return 1
    git -C "$repo" commit -qm 'init' >/dev/null 2>&1 || return 1
    git -C "$repo" push -q -u origin main >/dev/null 2>&1 || return 1
    git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main || return 1
    if [ "$name" = 'code' ]; then
      printf 'echo changed\n' >> "$repo/app.sh" || return 1
    else
      printf 'more prose\n' >> "$repo/README.md" || return 1
    fi
    git -C "$repo" add -A >/dev/null 2>&1 || return 1
    git -C "$repo" commit -qm 'work' >/dev/null 2>&1 || return 1
  done
  return 0
}

apply_docs_state() { # apply_docs_state <repo> <both|arch|adr|none>
  local repo="$1" docs="$2"
  rm -rf "$repo/docs"
  case "$docs" in
    both) mkdir -p "$repo/docs/arch" "$repo/docs/adr" ;;
    arch) mkdir -p "$repo/docs/arch" ;;
    adr) mkdir -p "$repo/docs/adr" ;;
    none) ;;
    *) return 1 ;;
  esac
  return 0
}

run_check_docs() {
  suite_begin check-docs
  if ! command -v git >/dev/null 2>&1; then
    skipped 'check-docs: whole suite' 'git is not installed'
    suite_end
    return 0
  fi
  if ! setup_check_docs; then
    harness_error 'could not build the check-docs sandbox repositories'
    suite_end
    return 0
  fi
  FX_SUBST=''
  local path="$CASES_DIR/check-docs.tsv"
  if [ ! -r "$path" ]; then
    harness_error "cannot read case file $path"
    suite_end
    return 0
  fi
  local expect docs which raw cmd json repo out err rc ctx label problem
  while IFS=$TAB read -r expect docs which raw <&3; do
    case "$expect" in ''|'#'*) continue ;; esac
    repo="$SANDBOX/repo-$which"
    if ! apply_docs_state "$repo" "$docs"; then
      harness_error "unknown docs state '$docs' in $path"
      continue
    fi
    cmd=$(expand "$raw")
    json=$(mk_json Bash "$repo" "$cmd" no)
    : > "$ERRFILE"
    out=$(cd "$repo" && printf '%s' "$json" | /bin/bash "$HOOKS_DIR/check-docs.sh" 2>"$ERRFILE")
    rc=$?
    err=$(cat "$ERRFILE")
    label="check-docs [docs=$docs repo=$which]: $raw"
    ctx=''
    if [ -n "$out" ]; then
      ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
    fi
    problem=''
    if [ "$rc" -ne 0 ]; then
      problem="exit $rc"
    elif [ -n "$err" ]; then
      problem='stderr was not empty'
    elif [ "$expect" = 'quiet' ]; then
      [ -n "$out" ] && problem='stdout was not empty'
    else
      if [ -z "$ctx" ]; then
        problem='no additionalContext'
      else
        # The reminder must name exactly the docs directories that exist.
        case "$docs" in
          both|arch) case "$ctx" in *docs/arch*) ;; *) problem='does not mention docs/arch' ;; esac ;;
          adr|none) case "$ctx" in *docs/arch*) problem='mentions docs/arch although it does not exist' ;; esac ;;
        esac
        case "$docs" in
          both|adr) case "$ctx" in *docs/adr*) ;; *) problem='does not mention docs/adr' ;; esac ;;
          arch|none) case "$ctx" in *docs/adr*) problem='mentions docs/adr although it does not exist' ;; esac ;;
        esac
        if [ -z "$problem" ]; then
          case "$ctx" in
            *app.sh*) ;;
            *) problem='does not list the changed code file' ;;
          esac
        fi
      fi
    fi
    if [ -z "$problem" ]; then
      ok "$label"
    else
      failed "$label" "$expect" "$problem" "$rc" "$out" "$err"
    fi
  done 3< "$path"
  suite_end
  return 0
}

# ---------------------------------------------------------------- driver

usage() {
  printf 'usage: %s [validate-rm|md-targets|lint-markdown|plan-to-html|check-docs ...]\n' \
    "${BASH_SOURCE[0]:-run.sh}" >&2
}

run_suite() {
  case "$1" in
    validate-rm) run_validate_rm ;;
    md-targets) run_md_targets ;;
    lint-markdown) run_lint_markdown ;;
    plan-to-html) run_plan_to_html ;;
    check-docs) run_check_docs ;;
    *) usage; exit 2 ;;
  esac
  return 0
}

printf 'hooks   : %s\n' "$HOOKS_DIR"
printf 'cases   : %s\n' "$CASES_DIR"
printf 'workdir : %s\n' "$WORKDIR"

if [ $# -eq 0 ]; then
  run_suite validate-rm
  run_suite md-targets
  run_suite lint-markdown
  run_suite plan-to-html
  run_suite check-docs
else
  for _suite in "$@"; do
    run_suite "$_suite"
  done
fi

printf '\n=== summary ===\n'
printf 'total=%d pass=%d fail=%d skip=%d\n' "$TOTAL" "$NPASS" "$NFAIL" "$NSKIP"

if [ "$NFAIL" -gt 0 ]; then
  exit 1
fi
exit 0
