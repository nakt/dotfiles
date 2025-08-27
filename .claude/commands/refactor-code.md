---
allowed-tools: Read(*), Glob(*), Grep(*), Edit(*), MultiEdit(*), Bash(find:*), Bash(grep:*), Bash(git:*), Bash(pytest:*), Bash(npm:*), Bash(cargo:*)
description: Improve code quality through refactoring, comment cleanup, and unused code elimination
---

Improve code quality by refactoring code structure, cleaning up comments, removing unused code, and ensuring tests pass.

## Refactoring Procedure

### Phase 1: Pre-refactoring Preparation
1. Check git status and ensure working directory is clean
2. Create backup branch if performing major refactoring
3. Identify project type and test framework
4. Run existing tests to establish baseline

### Phase 2: Comment Quality Improvement
1. **Scan code files for comment types**:
   - Update history comments ("2024/01/15 modified", "v1.2 changes")
   - Ad-hoc temporary comments ("TODO: fix later", "HACK:", "quick fix")
   - Commented-out old code blocks
2. **Identify permanent comments to preserve**:
   - Design intent and architectural decisions
   - Algorithm explanations and business logic
   - Important constraints and gotchas
3. **Refactor comments**:
   - Remove or convert update history to git commits
   - Clean up ad-hoc comments or convert to proper documentation
   - Remove commented-out dead code
   - Improve clarity of preserved comments

### Phase 3: Code Structure Refactoring
1. **Identify refactoring opportunities**:
   - Long functions/methods that should be split
   - Duplicated code that can be extracted
   - Poor naming that can be improved
   - Complex conditional logic that can be simplified
2. **Apply refactoring techniques**:
   - Extract functions/methods
   - Rename variables, functions, classes for clarity
   - Simplify complex expressions
   - Remove code duplication
3. **Maintain functionality**:
   - Run tests after each significant refactoring
   - Ensure behavior remains unchanged

### Phase 4: Unused Code Elimination
1. **Static analysis for unused elements**:
   - Unused functions, classes, variables
   - Unused import statements
   - Dead code (unreachable code paths)
   - Obsolete configuration or utility files
2. **Cross-reference analysis**:
   - Check actual usage across codebase
   - Identify dependencies and references
   - Consider dynamic usage (reflection, string-based calls)
3. **Safe removal with verification**:
   - Present findings to user
   - Remove confirmed unused code
   - Verify no functionality is broken

### Phase 5: Test Execution and Improvement
1. **Check for test existence**:
   - Scan for test directories (test/, tests/, spec/)
   - Identify test files and test frameworks
   - Check for test configuration files (pytest.ini, jest.config.js, etc.)
2. **Run existing tests**:
   - Execute test suite using appropriate test runner
   - Identify failing tests caused by refactoring changes
3. **Fix test failures**:
   - Analyze test failures and root causes
   - Update tests to reflect code changes from refactoring
   - Fix broken imports or references
   - Remove tests for deleted code/functions
   - Update test data or mocks if needed
4. **Improve test coverage** (optional):
   - Identify areas where refactoring revealed missing test coverage
   - Suggest additional tests for critical functionality

### Phase 6: Final Verification
1. Ensure all tests pass after refactoring and fixes
2. Check that application still runs correctly
3. Review git diff to confirm all changes improve code quality
4. Verify no functionality regression occurred
5. Run linting/formatting tools if available

## Constraints

### Safety and Quality
- Always run tests after significant refactoring changes
- Preserve existing functionality while improving code structure
- Ask for user confirmation before major structural changes
- Ensure refactoring improves readability and maintainability

### Code Quality Standards
- Only remove comments that are clearly outdated or temporary
- Preserve comments that explain complex logic, design decisions, or important constraints
- When in doubt about code usage, ask user for confirmation rather than assuming it's unused
- Follow established coding conventions and style guides

### Test Requirements
- Always run tests after refactoring if test suite exists
- Fix all test failures before completing refactoring process
- Do not consider refactoring complete until all tests pass
- Update or remove tests that are no longer relevant after code changes

### Communication
- .mdファイルなどのアウトプット、その他のコミュニケーションも全て日本語で出力してください
- Provide clear rationale for each refactoring recommendation
- Explain the benefits of proposed changes
- Present organized lists of refactoring candidates for user review