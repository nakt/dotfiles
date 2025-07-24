## Gemini Review

`gemini` is the Google Gemini CLI tool for providing feedback on plans and code about $ARGUMENTS.

Before implementing, follow these steps:
1. First, you (Claude Code) create a plan for the work.
2. Use `gemini` to review the plan and gather feedback.
3. If the feedback is reasonable, update the plan accordingly and proceed with implementation.

### How to use the command

Before implementation, you can request a review with the following command:
```bash
gemini -p "Review this implementation plan. Point out any flaws or suggest improvements.  
<Your plan here>"
```