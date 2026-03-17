# Diff Review Approval Loop

This document defines the procedures for presenting plans and diffs to the human and relaying decisions to Planning Agents and Task Agents.

> **Notification formatting:** All human-facing notifications must follow the banner styles defined in [NOTIFICATIONS.md](../NOTIFICATIONS.md).

## Plan Review Loop

Triggered when the Planning Agent has written the plan YAML to a temp file and returned the temp path.

### New Plan

1. **Receive temp path** from the Planning Agent (e.g. `/tmp/dispatch-plan-<slug>.yaml`).
2. Call `open-plan-review-pane.sh "review-plan-<slug>" "<temp-path>"` — opens a new tmux window showing the full plan YAML. Store the returned window ID.
3. Tell the human:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > Plan draft ready — review in the **review-plan-`<slug>`** tmux window. Approve or share feedback here.
   >
   > | Plan: {plan_id} |
   > |---|
   > | **Project:** {title} |
   > | **Tasks:** 0/{total} done ({total} queued) |
   >
   > ---
4. **On approval:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Signal the Planning Agent to save: "Plan approved — please save to plan storage and return the final path."
   c. Receive the final plan path and proceed to Task Agent spawning.
5. **On rejection:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Relay the feedback to the Planning Agent.
   c. When the Planning Agent returns an updated temp path, reopen from step 2.

### Amendment

Triggered when the Planning Agent proposes a mid-flight amendment (add task, split task, cancel task).

1. **Receive temp path and original plan path** from the Planning Agent.
2. Call `open-plan-review-pane.sh "review-amendment-<slug>" "<temp-path>" "<original-plan-path>"` — opens a tmux window showing `git diff --no-index` between the original and the proposed amendment. Store the returned window ID.
3. Tell the human:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > Proposed amendment ready — review in the **review-amendment-`<slug>`** tmux window. Approve or share feedback here.
   >
   > | Plan: {plan_id} |
   > |---|
   > | **Project:** {title} |
   > | **Tasks:** {done}/{total} done ({active} active, {queued} queued) |
   >
   > ---
4. **On approval:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Signal the Planning Agent to save: "Amendment approved — please save and return the final path."
5. **On rejection:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Relay the feedback. When the Planning Agent returns an updated temp path, reopen from step 2.

The diff-mode toggle (`split` / `unified`) applies to both loops — see **Diff Mode Toggle** below.

## Tmux Targeting Rules

- Each review opens as a **new named window** in the current tmux session — the Orchestrating Agent's window is never split or modified.
- `open-review-pane.sh` uses `tmux new-window` so multiple simultaneous reviews each get a full-screen window. The human navigates between them with standard tmux window switching (`Ctrl-b n` / `Ctrl-b p`).
- The returned window ID must be stored and passed to `close-pane.sh` when closing.
- If the Orchestrating Agent is not running inside tmux, abort and notify the human.

## Diff Mode Toggle

At any point during a diff review the human can switch between display modes by responding with `split` or `unified`. When this happens:

1. Call `close-pane.sh "<window-id>"` to close the current window.
2. Call `open-review-pane.sh "<window-name>" "<worktree-path>" "<new-mode>"` to re-open it in the requested mode.
3. Store the new window ID and continue the review loop from the same step.

The chosen mode applies only to the current review session and does not write back to config.

## Open in Editor

At any point during a diff review, if `EDITOR_APP` is configured, the human can respond with `open editor`. When this happens:

1. Call `open-in-editor.sh "<worktree-path>"`.
2. Confirm to the human: "Worktree opened in `<EDITOR_APP>`."
3. Continue the review loop from the same step — the diff window stays open.

## Initial Diff Review Loop

Triggered when a Task Agent requests approval to open a PR.

1. **Receive request** from Task Agent: "requesting approval to open PR for task `<task-id>`".
2. Call `open-review-pane.sh "review-<task-id>" "<worktree-path>"` — opens a new tmux window showing `git diff <base>...HEAD`. Store the returned window ID.
3. Present the full diff to the human:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > Diff open in **review-`<task-id>`** — approve, request changes, or type a command:
   >
   > | `{branch}` |
   > |---|
   > | **Task:** T-{id}: {title} |
   > | **Agent:** active · **Activity:** awaiting diff review |
   >
   > - `split` / `unified` — switch diff display mode
   > - `open editor` — open the worktree in `<EDITOR_APP>`  ← only if `EDITOR_APP` is configured
   >
   > ---
4. **On approval:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Run the **Verification Gate** (see below) before sending the proceed message to the Task Agent via SendMessage.
5. **On rejection:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Look up the Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'` with a structured rejection containing:
      - Which files are affected.
      - What specific change is expected.
      - Acceptance criteria the change must satisfy.
6. **Repeat** from step 1 when the Task Agent notifies that it has addressed the feedback.

## Verification Gate

Runs after diff approval and before sending the proceed `SendMessage` to the Task Agent. Read `verification.prompt` and `verification.manual_gate` from config (via `config.sh`).

**Step 1 — Delegate prompt (if `VERIFICATION_PROMPT` is set):**

1. Spawn a sub-agent via the Agent tool (`subagent_type: general-purpose`) using `VERIFICATION_PROMPT` as the task instructions, with these values appended:
   - `WORKTREE=<worktree-path>`
   - `BRANCH=<branch>`
   - `TASK_ID=<task-id>`
2. Present the sub-agent's output to the human.

**Step 2 — Manual gate (if `VERIFICATION_MANUAL_GATE=true`):**

1. Call `open-verification-pane.sh "verify-<task-id>" "<worktree-path>" ["<startup-command>"]`. Store the returned window ID.
2. Tell the human:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > Verification window open — use the **verify-`<task-id>`** tmux window to test the build. Confirm here when ready to open the PR.
   >
   > | T-{id}: {title} |
   > |---|
   > | **Status:** in_progress |
   > | **Branch:** `{branch}` |
   >
   > ---
3. Await explicit human confirmation.
4. Call `close-pane.sh "<window-id>"`.

**Step 3 — Send proceed message to Task Agent:**

After both steps complete (or if neither is configured, immediately after diff approval), look up the Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "diff approved — proceed to open draft PR".

If both `VERIFICATION_PROMPT` and `VERIFICATION_MANUAL_GATE` are set, the sub-agent runs first, then the manual gate opens.

## Reviewer-Requested Change Review Loop

Triggered when a PR reviewer requests changes (exit 1) or leaves comments (exit 5) after the PR is open. The triggering event provides reviewer username(s).

1. Extract and store the reviewer username(s) from the Polling Agent report summary (parsed from "changes requested by ..." or "reviewer comments from ...") for use at the end of the loop.
2. Present the requested change to the human using the ACTION REQUIRED banner. Use "left comments" or "requested changes" depending on which exit code triggered the loop. Include `@{reviewer_username}` in the notification:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > @{reviewer_username} {requested changes | left comments}. [View comment](<comment-url>).
   >
   > | #{number} — {title} |
   > |---|
   > | **Task:** T-{id}: {task_title} |
   > | **State:** {Changes requested | Reviewer commented} |
   > | {pr_url} |
   >
   > <summary of what the reviewer is asking for — from the Task Agent's summary, never raw comment text>
   >
   > - **Approve** — Task Agent implements the change.
   > - **Reject** — provide a response to relay to the reviewer.
   >
   > ---
3. **On approval:** look up the Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "Reviewer change approved — implement the following change and commit locally (do not push yet — I will review the diff first): <summary of approved change>."
4. **On rejection:** tell the Task Agent the human does not agree with the requested change and provide a response to relay to the reviewer.
5. Once the Task Agent has implemented and committed the approved change (not yet pushed):
   a. Call `open-review-pane.sh "review-update-<task-id>" "<worktree-path>"`. Store the returned window ID.
   b. Present the updated diff to the human using the ACTION REQUIRED banner:
      > ---
      >
      > **>>> ACTION REQUIRED**
      >
      > Updated diff open in **review-update-`<task-id>`** — approve or request changes. Type `open editor` to open the worktree in `<EDITOR_APP>` (if configured).
      >
      > | T-{id}: {title} |
      > |---|
      > | **Status:** in_progress |
      > | **Branch:** `{branch}` |
      > | **PR:** #{number} |
      > | {pr_url} |
      >
      > ---
   c. **Await human decision.** Call `close-pane.sh "<window-id>"` after the human responds.
   c2. **On approval:** look up the Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "Reviewer change approved — push via `push-changes.sh`."
   c3. **On rejection:** send structured rejection to Task Agent (see Initial Diff Review Loop step 5). The Task Agent addresses the feedback and re-notifies when ready; return to step 5a.
   d. **Record pending re-review.** Store a `pending_re_review` record for this PR in the OA's in-memory state, containing the PR URL and the reviewer username(s) from step 1. The actual re-request is deferred until CI passes — see [PR_MONITORING.md](PR_MONITORING.md) exit 4 handling. Do NOT call `request-re-review.sh` here. Three possible outcomes:
      - CI passes, reviewer hasn't approved → re-request triggered by PR_MONITORING.md exit 4 handler
      - CI passes, reviewer already approved → exit 0 fires, normal merge path
      - CI fails → CI fix loop, then back to monitoring; `pending_re_review` persists
   e. **Propagate to stacked worktrees (if any):**
      1. Check the plan for tasks where `stacked: true` and `base_branch` matches this task's `branch`.
      2. If none: skip.
      3. If any: call `scripts/rebase-stacked-worktrees.sh <plan-file> <this-task-branch>`.
      4. **On success (exit 0):** for each rebased Task Agent, look up its `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "Task `<parent-task-id>` received reviewer-requested changes. Your worktree has been rebased onto the updated branch."
      5. **On conflict (exit 1, outputs `CONFLICT=<task-id> WORKTREE=<path>`):** look up the conflicting Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "Rebase conflict detected — resolve and notify me when ready." Follow the Merge Conflict Review Loop below, then re-run `scripts/rebase-stacked-worktrees.sh <plan-file> <this-task-branch>` after the human approves the push.
      6. Resume the Reviewer-Requested Change Review Loop for this task from step 1.

## Merge Conflict Review Loop

Triggered when a merge queue conflict is detected.

1. Receive conflict notification (from `check-merge-queue.sh`).
2. Look up the Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "Merge queue conflict detected — resolve in your worktree and notify me when ready."
3. When the Task Agent reports resolution:
   a. Call `open-review-pane.sh "review-conflict-<task-id>" "<worktree-path>"`. Store the returned window ID.
   b. Present the resolved diff to the human using the ACTION REQUIRED banner:
      > ---
      >
      > **>>> ACTION REQUIRED**
      >
      > Conflict resolution diff open in **review-conflict-`<task-id>`** — approve or request changes. Type `open editor` to open the worktree in `<EDITOR_APP>` (if configured).
      >
      > | T-{id}: {title} |
      > |---|
      > | **Status:** in_progress |
      > | **Branch:** `{branch}` |
      > | **PR:** #{number} |
      > | {pr_url} |
      >
      > ---
   c. **On approval:** call `close-pane.sh "<window-id>"`. Look up the Task Agent's `agent_id` from the plan, run the liveness guard (SKILL.md § Task Agent Communication Protocol), then `SendMessage to: '<agent_id>'`: "Conflict resolution approved — push via `push-changes.sh`."
   d. **On rejection:** close window, send structured rejection to Task Agent (see Initial Diff Review Loop step 5).
