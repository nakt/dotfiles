---
name: commit
description: 未コミットの変更を分析し、論理的なグループに分類して適切な粒度でコミットするスキル。ユーザーが「コミットして」「変更をコミット」「commit」と言ったとき、または作業完了後にコミットを求められたときに使用する。
disable-model-invocation: true
effort: low
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git checkout:*), Bash(git branch:*), Bash(git diff:*), Bash(git log:*), Bash(pre-commit:*), Write
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
2. Ensure feature branch
   - If Branch is `main`:
     a. Analyze the status and diff summary above
     b. Infer branch name: `type/short-description` format
        - Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`
        - Description: lowercase, hyphen-separated
        - Examples: `feat/add-login-page`, `fix/null-pointer-error`
     c. Create and switch: `git checkout -b {branch-name}`
     d. Report the created branch name to the user
   - If not on `main`: proceed without changes
3. Categorize changes into logical groups
4. Commit with appropriate granularity
   - Message format: `<type>: <description>` (same types as above)
   - Explain why the change was made, not what was changed
5. Check pre-commit hook updates (if `.pre-commit-config.yaml` exists in the project root)
   - Run `pre-commit autoupdate`
   - If the config was updated, commit the change separately:
     `git add .pre-commit-config.yaml && git commit -m "chore: update pre-commit hooks"`
   - If no updates were made, skip silently

## Constraints

- コミットログは英語で記載してください
- その他の会話は特別な指定がない限り日本語で回答してください
