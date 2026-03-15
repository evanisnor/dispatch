---
name: status
description: "Display a status table of all active Task Agents, their current activity, and PR state. Invoke with /status."
---

Render the agent status table immediately using the rules below. Do not read any external files. Do not summarise in prose instead of or in addition to the table.

## Status Table Template

```
| Task | Title | Status | Activity | PR | Branch |
|------|-------|--------|----------|----|--------|
| {id} | {title} | {status} | {activity} | {pr} | {branch} |
```

**Columns:**

| Column | Source | Notes |
|--------|--------|-------|
| Task | `task.id` from plan YAML | |
| Title | `task.title` from plan YAML | Truncate to 30 chars if needed |
| Status | `task.status` from plan YAML | See values below |
| Activity | Derived from live state | See values below |
| PR | `task.pr_url` — render as `#N` linked if available, `—` if none | |
| Branch | `task.branch` — render as code, `—` if not yet created | |

## Status Values

| Value | Meaning |
|-------|---------|
| `pending` | Not yet started |
| `in_progress` | A Task Agent is actively working on this |
| `done` | Merged |
| `blocked` | Cannot proceed — dependency failed or conflict unresolved |
| `failed` | Task Agent hit an unrecoverable error |
| `cancelled` | Abandoned by human instruction |

## Activity Values

| Activity | When to use |
|----------|-------------|
| `waiting to start` | `pending`, all dependencies met — ready to spawn |
| `implementing` | `in_progress`, no PR open yet |
| `pre-PR checklist` | `in_progress`, Task Agent has signalled checklist underway |
| `awaiting diff review` | `in_progress`, Task Agent has requested diff approval |
| `CI running` | PR open, CI checks in progress |
| `fixing CI (attempt N/M)` | Task Agent is applying a CI fix; N = current attempt, M = max |
| `awaiting review` | PR marked ready, no review decision yet |
| `reviewer requested changes` | PR reviewer has requested changes, awaiting human approval |
| `in merge queue` | PR approved and added to merge queue |
| `merged` | PR merged successfully |
| `blocked on <task-id>` | Waiting for a dependency that is not yet done |
| `failed — escalation required` | CI fix limit exceeded or unrecoverable error |

## Rendering Rules

1. **Row inclusion:**
   - Always include: all `in_progress`, `blocked`, and `failed` tasks.
   - Include `pending` tasks only if all their `depends_on` entries are `done` (ready to start).
   - Include `done` tasks only if they completed during the current session.
   - Omit `pending` tasks with unmet dependencies and `cancelled` tasks unless the human asks for a full plan view.

2. **Sort order:** `in_progress` → `blocked`/`failed` → `pending` (ready) → `done`.

3. **No active plan:** if no plan is loaded, display exactly:
   > No active plan. Here's what you can do:
   > - **Plan** — invoke `/orchestrating-agents` and describe what you'd like to build
   > - **Implement** — invoke `/orchestrating-agents` and point it at an existing plan file
   > - **Config** — run `/config` to view or update your setup
   > - **Help** — run `/help` for a full command reference

4. **Single task:** if only one task is active, still render the table (do not switch to prose).
