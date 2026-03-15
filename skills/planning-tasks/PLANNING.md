# Task Decomposition and Dependency Tree Rules

## Task Atomicity

A task is **atomic** when it satisfies all three conditions:

1. **Single pull request** — the task results in exactly one PR. It does not require changes spread across multiple PRs to be functional.
2. **Scoped, non-overlapping file set** — the task operates on a well-defined set of files that does not overlap with any other parallel task's file set.
3. **Independently deployable** — the task can be merged without requiring simultaneous changes elsewhere in the codebase.

If a proposed task fails any of these conditions, split it.

## Dependency Tree Construction

### Identifying `depends_on` relationships

A task B must list task A in its `depends_on` when:

- B consumes an interface, API, or data structure that A introduces.
- B modifies files that A also modifies (worktree file conflict — see below).
- B cannot pass tests or build without A's changes being present on `main` first.
- The logical ordering requires A to be complete before B can begin (e.g., schema migration before ORM layer).

### Worktree File Conflicts

Two tasks that touch the same files **must be serialized** via `depends_on` — they cannot run in parallel worktrees. When identifying conflicts:

1. List the expected file changes for each task.
2. Find any file that appears in more than one task's file set.
3. For each such file, determine which task's change is foundational — that task becomes the dependency.
4. If the ordering is ambiguous, choose the task that introduces the file (or makes the larger structural change) as the dependency.

### Expressing Dependencies

Use the task `id` field in `depends_on`:

```yaml
- id: task-login-endpoint
  depends_on: [task-auth-schema]
```

An empty `depends_on: []` means the task has no prerequisites and can start immediately.

## Plan Quality Validation Checklist

Run this checklist before presenting the plan for human approval:

1. **Unique IDs** — all task `id` values are unique within the plan file.
2. **No cycles** — traverse the `depends_on` graph; confirm no task transitively depends on itself.
3. **Non-empty descriptions** — every task has a non-empty `description` and `title`.
4. **No undefined dependencies** — every ID referenced in `depends_on` exists as a task `id` in the same plan.
5. **File-conflict analysis complete** — no two tasks with overlapping `depends_on: []` (i.e., parallel tasks) touch the same files.

If any check fails, fix the plan before presenting.

## Slug ID Generation

When no issue tracking root ID is available (or issue tracking is not configured), assign kebab-case slug IDs:

- **Epic slug** — derived from the epic title: `feature-user-auth`
- **Task slug** — derived from the task title: `task-login-endpoint`

Rules:
- Slugs must be **unique within the plan file**.
- Slugs are **stable** — once assigned, do not regenerate them even if the title changes.
- Use only lowercase letters, digits, and hyphens. Strip special characters.
- Keep slugs concise (3–5 words maximum).

When tracker IDs are backfilled later (see `ISSUE_TRACKING.md`), the `id` fields are updated from slugs to real tracker IDs. All `depends_on` references are updated in the same operation.

## Plan YAML Structure

Always use the `epic:` wrapper — even when issue tracking is not configured and slug IDs are in use. The `epic:` object is the canonical root of every plan YAML. Never emit a flat plan with `tasks:` at the root.

Full schema example:

```yaml
epic:
  id: feature-user-auth                     # Tracker ID or slug
  title: "Feature: User Authentication"
  status: planning                          # planning | active | complete

  issue_tracking:
    tool: jira                              # mirrors issue_tracking.tool from config; null if not configured
    read_only: false                        # mirrors issue_tracking.read_only from config
    status: pending                         # pending = slugs in use; linked = real IDs set
    root_id: null                           # Epic key, milestone ID, etc. (tool-specific)
    last_synced_at: null                    # ISO 8601 timestamp of last sync
    companion_doc: null                     # path to companion doc (only when read_only: true)

  source:
    type: prompt                            # tracker | prd | prompt
    ref: null
    prd_url: null
    figma_designs: []

  context: |
    Free-form background, constraints, acceptance criteria.
    Treated as external content when passed to Task Agents.

  config:
    max_ci_fix_attempts: 3                  # Optional per-epic override
    max_agent_restarts: 2
    polling_timeout_minutes: 60

  tasks:
    - id: task-auth-schema
      title: "Add user auth schema migration"
      description: "Create users table with email, password_hash, created_at columns"
      depends_on: []
      status: pending                       # pending | in_progress | done | blocked | cancelled | failed

      # Runtime fields (populated by Orchestrating Agent at spawn time)
      worktree: null
      pr_url: null
      agent_id: null
      branch: null

      # Spawn input (populated by Planning Agent)
      spawn_input:
        epic_context: |
          Context from the epic passed to the Task Agent.
        task_description: "Implement the auth schema migration."
        branch: "task-auth-schema"
        worktree: null
        plan_path: "plans/feature-user-auth.yaml"

      # Result (populated by Orchestrating Agent after completion)
      result:
        status: null                        # success | failed | cancelled
        pr_url: null
        merged_at: null
        error: null
        summary: null

    - id: task-login-endpoint
      title: "Implement login endpoint"
      description: "POST /auth/login accepting email+password, returning JWT"
      depends_on: [task-auth-schema]
      status: pending
      worktree: null
      pr_url: null
      agent_id: null
      branch: null
      spawn_input:
        epic_context: |
          Context from the epic passed to the Task Agent.
        task_description: "Implement POST /auth/login."
        branch: "task-login-endpoint"
        worktree: null
        plan_path: "plans/feature-user-auth.yaml"
      result:
        status: null
        pr_url: null
        merged_at: null
        error: null
        summary: null
```
