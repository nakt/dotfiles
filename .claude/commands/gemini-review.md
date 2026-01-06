## Gemini Review

`gemini` is the Google Gemini CLI tool for providing feedback on plans and code about $ARGUMENTS.

Before implementing, follow these steps:
1. First, you (Claude Code) create a plan for the work.
2. Use the `gemini` command to review the plan and gather feedback.
3. If the feedback is reasonable, update the plan accordingly and proceed with implementation.

### How to use the command

Before implementation, you can request a review with the following command:
```bash
gemini -p "Review this implementation plan. Point out any flaws or suggest improvements.
<Your plan here>"
```

### Handling review results

After receiving Gemini's feedback:
1. Evaluate each suggestion individually.
2. Compare against the project context and existing design decisions.
3. Adopt only the suggestions you judge to be reasonable.
4. If you don't adopt a suggestion, clarify the reason.

You don't need to accept all suggestions unconditionally.
