---
name: commit
description: 未コミットの変更を分析し、論理的なグループに分類して適切な粒度でコミットするスキル。ユーザーが「コミットして」「変更をコミット」「commit」と言ったとき、または作業完了後にコミットを求められたときに使用する。
disable-model-invocation: true
effort: low
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git checkout:*), Bash(git branch:*), Bash(git diff:*), Bash(git log:*), Bash(pre-commit:*), Bash(echo:*)
---

# Git Commit

Analyze uncommitted files and commit logically related changes with appropriate granularity.

## Current state

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Diff summary: !`git diff HEAD --stat 2>/dev/null || echo '(no commits yet)'`
- Recent commits: !`git log --oneline -10 2>/dev/null || echo '(no commits yet)'`

## Your Tasks

1. Review the current state above and list the necessary work to be done
2. Handle initial commit (HEAD not yet established)
   - If Recent commits shows `(no commits yet)`:
     a. This is the repository's first commit. Skip branch inference (stay on the current branch)
     b. `git status --short` (Status above) is the only inventory available in this state — Diff summary / Recent commits are placeholders. Review the untracked list there and stage the relevant files with `git add`
     c. Create the root commit (typically `chore: initial commit` or similar)
     d. Then continue with Step 6 (`Check pre-commit hook updates`), skipping Steps 3-5 (branch inference / categorization / normal commit granularity)
   - Otherwise: proceed to Step 3
3. Ensure feature branch
   - If Branch is `main` or `master`: create a feature branch, inferring the name from the status and diff summary above, then report the created name to the user
   - Otherwise: proceed without changes
4. Categorize changes into logical groups
5. Commit with appropriate granularity
   - Explain why the change was made, not what was changed
6. Check pre-commit hook updates (if `.pre-commit-config.yaml` exists in the project root)
   - Run `pre-commit autoupdate`
   - If the config was updated, commit the change separately:
     `git add .pre-commit-config.yaml && git commit -m "chore: update pre-commit hooks"`
   - If no updates were made, skip silently
