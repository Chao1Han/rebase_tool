# Design Document

## Architecture
The rebase tool uses a multi-stage pipeline:
1. Fetch upstream changes
2. Attempt rebase
3. If conflict: create issue + assign Copilot
4. If success: create PR + tag
