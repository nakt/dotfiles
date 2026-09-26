#!/bin/bash
# cleanup-worktrees.sh - Clean up merged worktrees after /pr-merge.
#
# Idempotent post-merge cleanup for the worktree-based workflow:
#   1. git fetch --prune
#   2. fast-forward the main worktree to origin/<base>
#   3. remove stale copies under issues/wip/ that already exist under issues/done/
#   4. remove worktrees under <main worktree>/.claude/worktrees/ that are fully
#      merged, whose remote branch is gone, have no uncommitted changes, and
#      are not the worktree the script is running from
#
# Before removing a worktree, any plan (.claude/plans/) or design memo
# (docs/workflow/memo/, only when that path is gitignored in the main
# worktree) it holds is copied into the main worktree's same location.
# A worktree is left in place, with a reason, whenever any condition fails.
#
# Runs with no arguments, from either the main worktree or a linked worktree.
# Written for /bin/bash 3.2 (macOS default): no associative arrays, no mapfile.
#
# Exit status: non-zero only when not run inside a git repository. Warnings
# and kept worktrees are reported but still exit 0.

# NOTE: intentionally not using `set -e`/`set -o pipefail`. Several checks in
# this script (merge-base --is-ancestor, git show-ref, etc.) are expected to
# return non-zero as part of normal control flow, and bash 3.2 treats an
# empty array under `set -u` as an unbound-variable error.

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "[ERROR] not inside a git repository" >&2
  exit 1
fi

own_worktree="$(git rev-parse --show-toplevel)"

# --- Resolve the main worktree path (first "worktree" line of the porcelain list) ---
main_worktree=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*)
      main_worktree="${line#worktree }"
      break
      ;;
  esac
done < <(git worktree list --porcelain)

if [[ -z "$main_worktree" ]]; then
  echo "[ERROR] could not determine the main worktree" >&2
  exit 1
fi

# --- Resolve the base branch (same logic as pr-merge's Current state) ---
base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
if [[ -z "$base" ]]; then
  base="$(git branch --list --format='%(refname:short)' main master | head -1)"
fi

if [[ -z "$base" ]]; then
  echo "[ERROR] could not determine the base branch" >&2
  exit 1
fi

echo "[INFO] main worktree: $main_worktree"
echo "[INFO] base branch: $base"

# --- Step 1: fetch --prune ---
if ! git fetch --prune 2>&1; then
  echo "[WARN] git fetch --prune failed; continuing with existing refs"
fi

# --- Step 2: fast-forward the main worktree ---
main_branch="$(git -C "$main_worktree" branch --show-current)"
main_updated="false"
on_base_branch="false"

if [[ "$main_branch" != "$base" ]]; then
  echo "[WARN] main worktree is on branch '${main_branch:-(detached)}', not '$base'; skipping pull"
else
  on_base_branch="true"
  if git -C "$main_worktree" pull --ff-only origin "$base"; then
    main_updated="true"
  else
    echo "[WARN] git pull --ff-only origin $base failed in the main worktree"
  fi
fi

# --- Step 3: remove issues/wip/ copies that already exist under issues/done/ ---
# Only files not tracked in the main worktree are candidates: a tracked file
# belongs to a PR still in flight and must not be touched here.
if [[ "$on_base_branch" == "true" && -d "$main_worktree/issues/wip" ]]; then
  for wip_file in "$main_worktree"/issues/wip/*.md; do
    [[ -e "$wip_file" ]] || continue
    id="$(basename "$wip_file" .md)"
    rel_path="issues/wip/$(basename "$wip_file")"

    if git -C "$main_worktree" ls-files --error-unmatch "$rel_path" >/dev/null 2>&1; then
      continue
    fi

    done_match=""
    if [[ -d "$main_worktree/issues/done" ]]; then
      done_match="$(find "$main_worktree/issues/done" -type f -name "${id}.md" 2>/dev/null | head -1)"
    fi

    if [[ -n "$done_match" ]]; then
      rm -f "$wip_file"
      echo "[REMOVED] issues/wip/${id}.md (already in ${done_match#"$main_worktree"/})"
    fi
  done
fi

# --- helper: copy every file under src_dir into dest_dir, preserving relative
# paths. Prints the first conflicting relative path and returns 1 when a
# same-named file already exists in dest_dir with different content. ---
evacuate_dir() {
  local src_dir="$1"
  local dest_dir="$2"
  local f rel dest

  while IFS= read -r f; do
    rel="${f#"$src_dir"/}"
    dest="$dest_dir/$rel"
    if [[ -e "$dest" ]]; then
      if ! cmp -s "$f" "$dest"; then
        echo "$rel"
        return 1
      fi
    else
      mkdir -p "$(dirname "$dest")"
      cp "$f" "$dest"
    fi
  done < <(find "$src_dir" -type f)

  return 0
}

# --- Step 4: remove fully-merged worktrees (only once the main worktree is
# confirmed up to date; otherwise origin/<base> and issues/done/ comparisons
# would be unreliable) ---
if [[ "$main_updated" != "true" ]]; then
  echo "[WARN] main worktree was not updated; skipping worktree removal"
else
  prefix="$main_worktree/.claude/worktrees/"

  wt_paths=()
  wt_branches=()
  cur_path=""
  cur_branch=""
  flush_entry() {
    if [[ -n "$cur_path" ]]; then
      wt_paths+=("$cur_path")
      wt_branches+=("$cur_branch")
    fi
  }
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        flush_entry
        cur_path="${line#worktree }"
        cur_branch=""
        ;;
      "branch refs/heads/"*)
        cur_branch="${line#branch refs/heads/}"
        ;;
    esac
  done < <(git worktree list --porcelain)
  flush_entry

  idx=0
  while [[ $idx -lt ${#wt_paths[@]} ]]; do
    path="${wt_paths[$idx]}"
    branch="${wt_branches[$idx]}"
    idx=$((idx + 1))

    case "$path" in
      "$prefix"*) ;;
      *) continue ;;
    esac

    if [[ -z "$branch" ]]; then
      echo "[KEPT] $path: detached HEAD"
      continue
    fi

    if ! git merge-base --is-ancestor "refs/heads/$branch" "refs/remotes/origin/$base" 2>/dev/null; then
      echo "[KEPT] $path (branch: $branch): not merged into origin/$base"
      continue
    fi

    upstream="$(git for-each-ref --format='%(upstream)' "refs/heads/$branch")"
    if [[ -z "$upstream" ]] || git show-ref --verify --quiet "$upstream"; then
      echo "[KEPT] $path (branch: $branch): remote branch still exists, or was never pushed"
      continue
    fi

    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
      echo "[KEPT] $path (branch: $branch): has uncommitted changes"
      continue
    fi

    if [[ "$path" == "$own_worktree" ]]; then
      echo "[KEPT] $path (branch: $branch): this is the worktree currently in use"
      continue
    fi

    evac_ok="true"
    evac_reason=""

    if [[ -d "$path/.claude/plans" ]]; then
      conflict="$(evacuate_dir "$path/.claude/plans" "$main_worktree/.claude/plans")"
      if [[ $? -ne 0 ]]; then
        evac_ok="false"
        evac_reason="plan file conflicts with main worktree: .claude/plans/$conflict"
      fi
    fi

    if [[ "$evac_ok" == "true" ]] && [[ -d "$path/docs/workflow/memo" ]]; then
      if git -C "$main_worktree" check-ignore -q "docs/workflow/memo/" 2>/dev/null; then
        conflict="$(evacuate_dir "$path/docs/workflow/memo" "$main_worktree/docs/workflow/memo")"
        if [[ $? -ne 0 ]]; then
          evac_ok="false"
          evac_reason="design memo conflicts with main worktree: docs/workflow/memo/$conflict"
        fi
      fi
    fi

    if [[ "$evac_ok" != "true" ]]; then
      echo "[KEPT] $path (branch: $branch): $evac_reason"
      continue
    fi

    if git worktree remove "$path"; then
      if git -C "$main_worktree" branch -d "$branch" >/dev/null 2>&1; then
        echo "[REMOVED] $path (branch: $branch)"
      else
        echo "[WARN] removed worktree $path but could not delete branch $branch"
      fi
    else
      echo "[WARN] failed to remove worktree $path"
    fi
  done
fi

exit 0
