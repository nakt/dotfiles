---
allowed-tools: Bash(ls:*), Bash(mv:*), Bash(rm:*), Bash(cat:*), Bash(cp:*), Bash(mkdir:*), Bash(echo:*), Bash(tail:*), Bash(head:*), Bash(find:*), Bash(grep:*), Bash(git:*), Read(*), Glob(*), Grep(*)
description: Clean up experiment workspace and scan/remove unnecessary files project-wide
---

Clean up experiment workspace and scan/remove unnecessary files project-wide based on content analysis, usage patterns, and git activity.

## Cleanup Procedure

### Phase 1: Pre-cleanup Preparation
1. Check git status and ensure working directory is clean
2. Create backup if needed
3. Identify cleanup scope (workspace only vs full project files)

### Phase 2: Experiment Workspace Cleanup
1. List all directories under `.workspace/{experiments, analysis}/` and identify completed experiments
2. For each completed experiment:
   - Extract key files and commands used (e.g., scripts, logs, notebooks)
   - Summarize the experiment's purpose, steps, results, and any insights or learnings
   - Save the summary in `.workspace/knowledge/expXYZ_summary.md`
3. After confirming the summary is complete:
   - Prompt the user to confirm cleanup
   - Remove the corresponding directory under `.workspace/{experiments, analysis}/` to free up space

### Phase 3: Project-wide File Cleanup
1. **Scan entire project for unnecessary files** (content-based analysis, not just extension):
   - Temporary files: *.tmp, *.temp, *.bak, *.orig, *.swp, *~
   - Build artifacts: __pycache__/, .pytest_cache/, node_modules/, target/, dist/, build/
   - IDE/Editor files: .vscode/settings.json, .idea/, *.pyc, .DS_Store
   - Test scripts and experimental code created during development
   - Temporary data files and working files
   - Files with patterns like: test_, tmp_, old_, backup_, draft_, experimental_
   - Log files: *.log, logs/
   - Files with outdated modification dates and low git activity
2. **Analyze file content and usage**:
   - Check git history for file activity
   - Identify files not referenced by main codebase
   - Look for TODO or FIXME comments indicating temporary nature
   - Check file size and creation patterns
3. **Categorize files by importance**:
   - Critical: Core functionality files, main source code
   - Important: Configuration, documentation, active tests
   - Low priority: Old documentation, unused configs
   - Candidate for removal: Experimental, temporary, unused, build artifacts
4. **Present organized removal candidates to user for confirmation**:
   - Group by type (temporary, build artifacts, experimental, etc.)
   - Show file paths, sizes, and last modification dates
   - Provide rationale for each deletion candidate

### Phase 4: Final File Verification
1. Review git diff to confirm all file changes are intentional
2. Verify no critical files were accidentally removed
3. Check that project structure remains intact

## Constraints

### Safety and Confirmation
- Always ask for user confirmation before deleting any files
- Create backups when performing destructive operations
- Verify git status is clean before starting major cleanup operations
- Do not delete any data without explicit user approval

### Experiment Workspace
- Preserve useful insights and reproducibility information in summaries
- Experiment summaries should be in English and follow Markdown format
- Experiment summaries must be stored with a filename that matches the experiment's prefix

### Communication
- .mdファイルなどのアウトプット、その他のコミュニケーションも全て日本語で出力してください
- Provide clear rationale for each cleanup recommendation
- Present organized lists of cleanup candidates for user review