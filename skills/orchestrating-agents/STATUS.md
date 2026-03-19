---
name: status
description: "Canonical template and rendering rules for the task-centric status display."
---

# Agent Status Display

## Trigger Conditions

Render the status display whenever:

- The human asks anything resembling a status query: "what are the agents doing", "status update", "show me agent status", "how is the work going", "what's in progress", etc.
- The `/status` skill is invoked.

Always respond with tables. Do not summarise in prose instead of or in addition to tables. Never use bulleted lists, numbered lists, or any non-table format — every piece of status data must appear inside a table row.

## Table Format

Each status section is a **multi-column markdown table** — one row per entity. This lets the eye scan rows horizontally and spot patterns across tasks at a glance.

URLs do not render well in table cells, so all PR links use a **footnote stub** (`[N]`) in-line, with the full URL listed below the table.

## Tasks Table

Primary view. Always shown when a plan is loaded.

```
## Tasks

| Task | Status | Commit |
|------|--------|--------|
| T-1: Add auth flow | done | a1b2c3d |
| T-2: API client | in_progress | |
| T-3: Cache layer | ready | |
| T-4: Dashboard | blocked on T-2 | |
```

**Columns:**

| Column | Source | Notes |
|--------|--------|-------|
| Task | `task.id` + `task.title` | Format: `T-{id}: {title}`. Truncate title to 30 chars if needed. |
| Status | Derived from task state | See Status Values below. |
| Commit | `task.result.commit_sha` | Abbreviated SHA (7 chars). Blank if not yet committed. |

### Status Values

| Value | When to use |
|-------|-------------|
| `done` | Task status is `done` |
| `in_progress` | Task status is `in_progress` |
| `ready` | Task status is `pending` and all `depends_on` are `done` |
| `blocked on T-{id}` | Task status is `pending` or `blocked` with unmet dependencies (show the first unmet dependency) |
| `cancelled` | Task status is `cancelled` |
| `failed` | Task status is `failed` |

## Worktrees Table

Only shown when non-main worktrees exist (independent or prototype). These are worktrees outside the plan's task execution.

```
## Worktrees

| Branch | Activity | PR |
|--------|----------|----|
| `proto/experiment` | no PR | |
| `fix/typo` | approved | #44 [1] |

[1]: https://github.com/org/repo/pull/44
```

**Columns:**

| Column | Source | Notes |
|--------|--------|-------|
| Branch | Worktree ref | Rendered as inline code. Strip `refs/heads/` from the ref. |
| Activity | Derived from PR status | See Activity Values below. |
| PR | Discovered PR URL | Render as `#{number} [N]`. Footnote stub with numbered reference. Blank when no PR exists. |

**Footnotes:** Numbered per-section starting at `[1]`. Full URL list immediately below the table, one per line: `[N]: <url>`.

### Independent Worktrees

Worktrees that exist on disk (per `git worktree list --porcelain`) but are not the main worktree are shown in the Worktrees Table.

- **Branch:** from worktree ref (strip `refs/heads/`).
- **Activity:** derived from PR status per [PR_MONITORING.md](PR_MONITORING.md) § Independent PR Activity Derivation. Use `no PR` when no PR is found.
- **PR:** discovered via `gh pr list --head <branch> --json number,url --jq '.[0]'`. Blank if no PR found.

### Activity Values

| Activity | When to use |
|----------|-------------|
| `no PR` | Worktree with no associated PR |
| `CI running` | PR exists; CI in progress |
| `awaiting review` | PR exists; waiting for reviewer |
| `approved` | PR approved + CI passing |
| `changes requested` | Reviewer requested changes |
| `reviewer commented` | Reviewer left comments |
| `CI failed` | CI failed |
| `in merge queue` | In merge queue |
| `merge conflict` | Conflict in merge queue |
| `ejected` | Ejected from merge queue |
| `closed` | Closed without merging |
| `merged` | Merged (briefly, before cleanup) |

## Pending Reviews Table

Render one table below the other sections when there are entries in the pending reviews list. If there are no pending reviews, omit the section entirely.

```
## Pending Reviews

| PR | Author | Status |
|----|--------|--------|
| #50 -- Fix auth redirect [1] | @alice | ready |

[1]: https://github.com/org/repo/pull/50
```

**Columns:**

| Column | Source | Notes |
|--------|--------|-------|
| PR | `pr_number` + `title` | Format: `#{number} -- {title} [N]`. Truncate title to 30 chars if needed. Footnote stub for URL. |
| Author | `author` | Format: `@{author}` |
| Status | Review status | See status values below. |

**Footnotes:** Numbered per-section starting at `[1]`. Full URL list immediately below the table.

**Status values:**

| Value | Meaning |
|-------|---------|
| `preliminary` | Review Agent running; analysis not yet ready |
| `ready` | Analysis complete; awaiting human |
| `reviewing` | Diff pane open; human is actively reviewing |
| `approved` | Human approved; PR left for author to merge |

## Plan Card

Used in the startup greeting and completion summary when a plan summary is warranted:

```
| Plan: {plan_id} |
|---|
| **Project:** {title} |
| **Tasks:** {done}/{total} done ({queued} queued) |
```

---

## Rendering Rules

### Tasks Table

1. **Row inclusion:** All tasks in the plan. Omit `cancelled` tasks unless the human asks for a full plan view.
2. **Sort order:** `in_progress` → `ready` → `blocked` → `done` → `failed` → `cancelled`.
3. **Empty state:** If no plan is loaded, omit the Tasks section entirely.

### Worktrees Table

1. **Row inclusion:** All non-main worktrees from `git worktree list --porcelain`.
2. **Sort order:** Worktrees with active PRs first, then `no PR`.
3. **Empty state:** If no non-main worktrees exist, omit the section entirely.

### Pending Reviews

1. Render when there are entries in the pending reviews list. Omit entirely when empty.

### No active plan

If no plan is loaded and independent worktrees exist, render the Worktrees Table (independent only) followed by:

> No active plan. Give me an assignment to get started.

If no plan is loaded and no independent worktrees exist, display exactly:

> No active plan. Give me an assignment to get started.

### Single entity

If only one task or worktree exists, still render it as a table row (do not switch to prose).
