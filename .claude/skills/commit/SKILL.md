---
name: commit
description: 未コミットの変更を分析し、論理的なグループに分類して適切な粒度でコミットするスキル。ユーザーが「コミットして」「変更をコミット」「commit」と言ったとき、または作業完了後にコミットを求められたときに使用する。
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
---

Analyze uncommitted files and commit logically related changes with appropriate granularity.

## Your Tasks

1. List the necessary work to be done
2. Check uncommitted status
   - Current git status: `git status`
   - Current git diff (staged and unstaged changes): `git diff HEAD`
   - Current branch: `git branch --show-current`
   - Recent commits: `git log --oneline -10`
3. Categorize changes into logical groups
4. Commit with appropriate granularity
5. Consider updating project memory
   - Consider adding important policy changes, technical challenges, and solutions to `.workspace/knowledge/`
   - Accumulate knowledge that leads to improved implementation quality and development efficiency in the future

## Constraints

- コミットログは英語で記載してください
- その他の会話は特別な指定がない限り日本語で回答してください
