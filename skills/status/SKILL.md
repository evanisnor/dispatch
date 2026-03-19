---
name: status
description: "Display a status table of plan tasks, independent worktrees, and pending reviews. Invoke with /status."
---

Render the status display immediately using the rules below. Do not summarise in prose instead of or in addition to tables. Never use bulleted lists, numbered lists, or any non-table format — every piece of status data must appear inside a table row. Always respond with tables.

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
| Status | Derived from task state | `done`, `in_progress`, `ready` (all deps met), `blocked on T-{id}` (first unmet dep), `cancelled`, `failed` |
| Commit | `task.result.commit_sha` | Abbreviated SHA (7 chars). Blank if not yet committed. |

## Worktrees Table

Only shown when non-main worktrees exist.

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
| Branch | Worktree ref | Rendered as inline code. Strip `refs/heads/` prefix. |
| Activity | PR status | See Activity Values below. |
| PR | Discovered PR | `#{number} [N]` footnote. Blank when no PR. |

**Footnotes:** Numbered per-section starting at `[1]`. Full URL list immediately below the table, one per line: `[N]: <url>`.

**Activity Values:**

| Activity | When to use |
|----------|-------------|
| `no PR` | Worktree with no associated PR |
| `CI running` | PR exists; CI in progress |
| `awaiting review` | PR exists; waiting for reviewer |
| `approved` | PR approved + CI passing |
| `changes requested` | Reviewer requested changes |
| `CI failed` | CI failed |
| `in merge queue` | In merge queue |
| `merged` | Merged (briefly, before cleanup) |

**Independent worktrees:** Worktrees from `git worktree list` that are not the main worktree appear as rows in the Worktrees Table. PR discovered via `gh pr list --head <branch>`. See STATUS.md § Independent Worktrees for full column definitions.

## Pending Reviews Table

Render below the other sections when there are entries in the pending reviews list. Omit if no pending reviews exist.

```
## Pending Reviews

| PR | Author | Status |
|----|--------|--------|
| #50 -- Fix auth redirect [1] | @alice | ready |

[1]: https://github.com/org/repo/pull/50
```

**Footnotes:** Numbered per-section starting at `[1]`. Full URL list immediately below the table.

## Data Extraction

When plan data is not already in memory, extract task summaries from the plan YAML file.

**Discover the tasks path** using `discover-tasks-path.sh`:

```bash
TASKS_PATH=$(bash "$DISPATCH_PLUGIN_DIR/scripts/discover-tasks-path.sh" "$PLAN_FILE")
```

**Extract task data** as YAML objects — never use `@csv` (it fails on nested fields like `depends_on`):

```bash
yq e '<TASKS_PATH>[] | {"id": .id, "title": .title, "status": .status, "depends_on": (.depends_on // [] | join(",")), "result_commit_sha": .result.commit_sha}' "$PLAN_FILE"
```

Replace `<TASKS_PATH>` with the literal value from `discover-tasks-path.sh` (e.g. `.epic.tasks`).

## Rendering Rules

1. **Tasks Table row inclusion:** All tasks in the plan. Omit `cancelled` tasks unless human asks for full view. Sort: `in_progress` → `ready` → `blocked` → `done` → `failed` → `cancelled`.

2. **Worktrees Table row inclusion:** All non-main worktrees from `git worktree list --porcelain`. Sort: worktrees with active PRs first, then `no PR`. Omit if no non-main worktrees exist.

3. **Pending Reviews:** Render when entries exist. Omit entirely when empty.

4. **No active plan:** If independent worktrees exist, render the Worktrees Table (independent only) above the no-plan text. Then display:
   > No active plan. Here's what you can do:
   > - **Plan** — describe what you'd like to build and I'll decompose it into tasks
   > - **Implement** — point me at an existing plan file to start executing
   >
   > Also available: `/status`, `/config`, `/help`

5. **Single entity:** still render it as a table row (do not switch to prose).
