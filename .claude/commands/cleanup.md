---
allowed-tools: Bash(ls:*), Bash(mv:*), Bash(rm:*), Bash(cat:*), Bash(cp:*), Bash(mkdir:*), Bash(echo:*), Bash(tail:*), Bash(head:*), Bash(find:*), Bash(grep:*)
description: Summarize and clean up experiment workspace
---

Summarize the contents of completed experiments in `.workspace/{experiments, analysis}/` and store the summary in `.workspace/knowledge/` using the experiment directory's prefix (e.g., `exp001`) as the file name.

## Your Tasks

1. List all directories under `.workspace/{experiments, analysis}/` and identify completed experiments
2. For each completed experiment:
   - Extract key files and commands used (e.g., scripts, logs, notebooks)
   - Summarize the experiment’s purpose, steps, results, and any insights or learnings
   - Save the summary in `.workspace/knowledge/expXYZ_summary.md`
3. After confirming the summary is complete:
   - Prompt the user to confirm cleanup
   - Remove the corresponding directory under `.workspace/{experiments, analysis}/` to free up space

## Constraints

- Make sure to preserve useful insights and reproducibility information in the summary
- Summaries should be in English and follow Markdown format
- Experiment summaries must be stored with a filename that matches the experiment’s prefix
- Do not delete any data without confirmation
- .mdファイルなどのアウトプット、その他のコミュニケーションも全て日本語で出力してください