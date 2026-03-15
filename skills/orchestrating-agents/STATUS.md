---
name: status
description: "Canonical template and rendering rules for the agent status table."
---

# Agent Status Display

## Trigger Conditions

Render the status table whenever:

- The human asks anything resembling a status query: "what are the agents doing", "status update", "show me agent status", "how is the work going", "what's in progress", etc.
- The `/status` skill is invoked.

Always respond with the table. Do not summarise in prose instead of or in addition to the table.

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

Drawn directly from `task.status` in the plan YAML:

| Value | Meaning |
|-------|---------|
| `pending` | Not yet started |
| `in_progress` | A Task Agent is actively working on this |
| `done` | Merged |
| `blocked` | Cannot proceed — dependency failed or conflict unresolved |
| `failed` | Task Agent hit an unrecoverable error |
| `cancelled` | Abandoned by human instruction |

## Activity Values

Derived by the Orchestrating Agent from plan state and live PR/CI context. Use the most specific value that applies:

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

## Pending Reviews Table

Render this section **below the task table** when there are entries in the pending reviews list. If there are no pending reviews, omit the section entirely.

```
## Pending Reviews

| PR | Title | Author | Status |
|----|-------|--------|--------|
| #N | Title | @author | status |
```

**Columns:**

| Column | Source | Notes |
|--------|--------|-------|
| PR | `pr_number` — render as `#N` linked to `pr_url` | |
| Title | `title` | Truncate to 30 chars if needed |
| Author | `author` — render as `@author` | |
| Status | `status` from pending reviews list | See values below |

**Status values:**

| Value | Meaning |
|-------|---------|
| `preliminary` | Review Agent running; analysis not yet ready |
| `ready` | Analysis complete; awaiting human |
| `reviewing` | Diff pane open; human is actively reviewing |
| `approved` | Human approved; PR left for author to merge |

---

## Rendering Rules

1. **Row inclusion:**
   - Always include: all `in_progress`, `blocked`, and `failed` tasks.
   - Include `pending` tasks only if all their `depends_on` entries are `done` (ready to start).
   - Include `done` tasks only if they completed during the current session.
   - Omit `pending` tasks with unmet dependencies and `cancelled` tasks unless the human asks for a full plan view.

2. **Sort order:** `in_progress` → `blocked`/`failed` → `pending` (ready) → `done`.

3. **No active plan:** if no plan is loaded, display exactly:
   > No active plan. Give me an assignment to get started.

4. **Single task:** if only one task is active, still render the table (do not switch to prose).
