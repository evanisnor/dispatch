# Stacked Worktrees

## Definition and Use Case

A **stacked worktree** is a Task Agent worktree whose base branch is another task's feature branch rather than main. Stacking lets the Orchestrating Agent begin implementing task B while task A is still in review — B's changes build on A's. This eliminates idle time during review cycles for chains of dependent tasks.

Use stacking when:
- Task B has `depends_on: [A]` and A's diff has been approved but not yet merged.
- The human confirms they want B to start immediately rather than waiting for A to merge.

## Data Model

Two optional fields are written to a task entry in the plan YAML at runtime:

| Field | Type | Meaning |
|---|---|---|
| `base_branch` | string | The branch this worktree was rebased onto. Absent means main. Set when the stacked worktree is created. |
| `stacked` | bool | `true` marks this as a stacked worktree. Used as a filter by rebase scripts. |

These fields are **distinct from `depends_on`**. `depends_on` encodes logical ordering (B cannot be done before A). `base_branch` / `stacked` encode the physical git relationship (B's commits sit on top of A's branch). A task can have `depends_on` without being stacked, and in normal sequential execution it will not have these fields at all.

## Worktree Creation

Stacked worktrees are created using the standard `isolation: "worktree"` mechanism on the Agent tool — no special creation script is needed. The worktree starts from HEAD (main), so its branch tip is at the same commit as main at creation time.

Immediately after the Agent tool returns the worktree path (and before the Task Agent makes any commits), the Orchestrating Agent rebases the fresh worktree onto the parent's branch:

```bash
git -C <worktree-path> rebase <base-branch>
```

This is safe because the worktree contains no commits yet — the rebase simply moves the branch tip to the parent branch's HEAD.

The Task Agent's spawn prompt includes `base_branch: <branch>` so the Task Agent is aware it is stacked and should verify it is on the correct base before making commits (see Race Condition below).

## Stacking Prompt Flow

The Orchestrating Agent offers stacking interactively after the Verification Gate completes and before notifying the Task Agent to open its PR.

### When to Offer

After the Verification Gate for task A passes, identify tasks in the plan where:
- `depends_on` contains A's task ID, **and**
- `status: pending`

If any exist, ask the human before proceeding. Offer one dependent at a time; stop after the first "no".

### What to Tell the Human

> "Task `<dep-id>` (`<dep-name>`) depends directly on this one. Would you like me to start implementing it now as a stacked worktree on top of `<branch>`? B's changes will be based on A's — I'll rebase them automatically as A evolves."

On **yes**, explain the lifecycle implications before spawning:

> "I'll spawn a Task Agent for `<dep-id>` in a new worktree and immediately rebase it onto `<branch>`. While `<task-id>` is in review, `<dep-id>` will be implemented in parallel. If reviewers request changes to `<task-id>`, I'll rebase `<dep-id>` automatically and ask you to review any conflicts."

On **no**, proceed normally (notify Task Agent to open draft PR).

### Lifecycle Implications to Communicate

Make the human aware before they commit to stacking:
- Any reviewer-requested change on A triggers an automatic rebase of B (and deeper stacked tasks).
- Rebase conflicts in B require human review before implementation can continue.
- If a conflict is found mid-stack, deeper tasks cannot be rebased until the conflict is resolved.

## Change Propagation

When a reviewer requests changes to task A, and B is stacked on A's branch, B must be rebased onto A's updated branch after A's changes are pushed.

The Orchestrating Agent calls `rebase-stacked-worktrees.sh` after closing the updated-diff review pane (REVIEW.md § Reviewer-Requested Change Review Loop, step 5d):

```bash
scripts/rebase-stacked-worktrees.sh <plan-file> <task-a-branch>
```

The script rebases in stack-depth order (shallowest first) and recurses for deeper dependents. See [rebase-stacked-worktrees.sh](scripts/rebase-stacked-worktrees.sh) for full behavior.

**On success:** notify each rebased Task Agent:
> "Task `<parent-task-id>` received reviewer-requested changes. Your worktree has been rebased onto the updated branch."

**On conflict (script exits 1):** the script outputs `CONFLICT=<task-id> WORKTREE=<path>`. Follow the Merge Conflict Review Loop in [REVIEW.md](REVIEW.md): notify the conflicting Task Agent to resolve the conflict in its worktree, open a review pane for human approval, then re-run `rebase-stacked-worktrees.sh` to continue rebasing the remainder of the stack.

## Post-Merge Rebase

When task A merges into main, any tasks stacked on A's branch must be rebased onto main.

The Orchestrating Agent calls `rebase-stacked-worktrees.sh` after step 4 of the Merge Queue Monitoring success case (PR_MONITORING.md § Merge Queue Monitoring, step 4.5):

```bash
scripts/rebase-stacked-worktrees.sh <plan-file> <merged-branch>
```

**On success:** notify each rebased Task Agent:
> "Task `<parent-task-id>` has merged into main. Your worktree has been rebased onto main. GitHub will retarget your PR base automatically."

**On conflict:** same resolution flow as Change Propagation above.

### GitHub PR Base Auto-Update

When A merges and B's branch is rebased onto main, GitHub automatically retargets B's PR base from A's branch to main. No action is required by the Task Agent or Orchestrating Agent to update the PR base.

## Conflict Handling

Conflicts are handled the same way for both change propagation and post-merge rebase:

1. `rebase-stacked-worktrees.sh` aborts the rebase on first conflict and exits 1 with `CONFLICT=<task-id> WORKTREE=<path>`.
2. Notify the conflicting Task Agent to resolve the conflict in its worktree.
3. Follow the Merge Conflict Review Loop in [REVIEW.md](REVIEW.md).
4. After human-approved push, re-run `rebase-stacked-worktrees.sh <plan-file> <updated-branch>` to continue rebasing the remainder of the stack.

A conflict in task B blocks rebasing of task C (which is stacked on B). C cannot be rebased until B's conflict is resolved. This is intentional — partial stack rebase would leave C in an inconsistent state.

## Cleanup

Stacked worktrees are removed the same way as regular worktrees: call `remove-worktree.sh <worktree-path>` after the task's own PR merges. There is no special cleanup for stacked worktrees.

## Race Condition: Task Agent Commits Before Initial Rebase

Because the Agent tool spawns the Task Agent in the background and returns immediately, there is a window during which the Task Agent may begin work before the Orchestrating Agent runs `git rebase <base-branch>` on the fresh worktree.

**Mitigation:**
- The Task Agent's first steps are read-only (loading the plan, loading config, reading knowledge). This gives the Orchestrating Agent time to run the initial rebase before any commits are made.
- The Task Agent's spawn prompt includes `base_branch: <branch>`. Before making any commits, the Task Agent must verify it is on the correct base:
  ```bash
  git -C <worktree-path> log --oneline origin/<base-branch>..HEAD
  ```
  If commits exist that should not (the worktree has not yet been rebased), the Task Agent must wait and re-check before proceeding.
- If the Orchestrating Agent detects the Task Agent has already committed before the rebase could run, escalate to the human.
