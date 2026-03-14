---
name: help
description: "List available agent-workflow commands and usage examples. Invoke with /agent-workflow:help."
---

# agent-workflow Help

## Slash Commands

| Command | Description |
|---------|-------------|
| `/agent-workflow:orchestrating-agents` | Start or resume the Orchestrating Agent |
| `/agent-workflow:status` | Show a status table of all active agents |
| `/agent-workflow:config` | Show the full config schema and help configure `.agent-workflow.json` |
| `/agent-workflow:help` | Show this help reference |

## Talking to the Orchestrating Agent

Once the Orchestrating Agent is active, interact in plain language:

**Start new work**
> "Build a user authentication system: registration, login, JWT tokens."

**Check status**
> "What are the agents doing?" / "Status update" / "Show me agent status"

**Review a diff**
> "Approve" / "Reject. The error handling in auth.go swallows the original error."

**Switch diff view**
> "Split" / "Unified"

**Amend the plan**
> "Add a task to write integration tests for the login endpoint."
> "Cancel task T-5."
> "Split task T-3 into two smaller tasks."

**Respond to escalations**
> The Orchestrating Agent will ask for your input when CI fails beyond the retry
> limit, a reviewer requests changes, a merge conflict needs resolution, or an
> agent appears to have stalled.
