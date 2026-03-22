---
name: commit
description: 未コミットの変更を分析し、論理的なグループに分類して適切な粒度でコミットするスキル。ユーザーが「コミットして」「変更をコミット」「commit」と言ったとき、または作業完了後にコミットを求められたときに使用する。
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git checkout:*), Bash(git branch:*)
---

Analyze uncommitted files and commit logically related changes with appropriate granularity.

## Current state

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Diff summary: !`git diff HEAD --stat`
- Recent commits: !`git log --oneline -10`

## Your Tasks

1. Review the current state above and list the necessary work to be done
2. Ensure feature branch
   - If Branch is `main`:
     a. Analyze the status and diff summary above
     b. Infer branch name: `type/short-description` format
        - Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
        - Description: lowercase, hyphen-separated
        - Examples: `feat/add-login-page`, `fix/null-pointer-error`
     c. Create and switch: `git checkout -b {branch-name}`
     d. Report the created branch name to the user
   - If not on `main`: proceed without changes
3. Categorize changes into logical groups
4. Commit with appropriate granularity
5. Consider updating project memory
   - Consider adding important policy changes, technical challenges, and solutions to `.workspace/knowledge/`
   - Accumulate knowledge that leads to improved implementation quality and development efficiency in the future

## Constraints

- コミットログは英語で記載してください
- その他の会話は特別な指定がない限り日本語で回答してください
