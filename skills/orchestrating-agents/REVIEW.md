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
2. Call `open-review-pane.sh "<window-name>" "." "<diff-range>" "<new-mode>"` to re-open it in the requested mode.
3. Store the new window ID and continue the review loop from the same step.

The chosen mode applies only to the current review session and does not write back to config.

## Open in Editor

At any point during a diff review, if `EDITOR_APP` is configured, the human can respond with `open editor`. When this happens:

1. Call `open-in-editor.sh "."`.
2. Confirm to the human: "Project opened in `<EDITOR_APP>`."
3. Continue the review loop from the same step — the diff window stays open.

## Initial Diff Review Loop

Triggered when a Task Agent signals "Implementation committed, ready for review."

1. **Receive signal** from the Task Agent.
2. Call `open-review-pane.sh "review-<task-id>" "." "<pre-task-sha>...HEAD"` — opens a new tmux window showing the diff of all commits since the pre-task SHA. Store the returned window ID.
3. Present the diff to the human:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > Diff open in **review-`<task-id>`** — approve, request changes, or type a command:
   >
   > | T-{id}: {title} |
   > |---|
   > | **Status:** in_progress |
   >
   > - `split` / `unified` — switch diff display mode
   > - `open editor` — open the project in `<EDITOR_APP>`  ← only if `EDITOR_APP` is configured
   >
   > ---
4. **On approval:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Run the **Verification Gate** (see below) before sending the approval message to the Task Agent via SendMessage.
5. **On rejection:**
   a. Call `close-pane.sh "<window-id>"`.
   b. Look up the Task Agent's `agent_id` from the plan, then `SendMessage to: '<agent_id>'` with a structured rejection containing:
      - Which files are affected.
      - What specific change is expected.
      - Acceptance criteria the change must satisfy.
6. **Repeat** from step 1 when the Task Agent notifies that it has addressed the feedback. Use the same `<pre-task-sha>...HEAD` range — it captures all commits including fixes.

## Verification Gate

Runs after diff approval and before sending the approval `SendMessage` to the Task Agent. Read `verification.prompt` and `verification.manual_gate` from config (via `config.sh`).

**Step 1 — Delegate prompt (if `VERIFICATION_PROMPT` is set):**

1. Spawn a sub-agent via the Agent tool (`subagent_type: general-purpose`) using `VERIFICATION_PROMPT` as the task instructions, with these values appended:
   - `PROJECT_DIR=.`
   - `TASK_ID=<task-id>`
2. Present the sub-agent's output to the human.

**Step 2 — Manual gate (if `VERIFICATION_MANUAL_GATE=true`):**

1. Call `open-verification-pane.sh "verify-<task-id>" "." ["<startup-command>"]`. Store the returned window ID.
2. Tell the human:
   > ---
   >
   > **>>> ACTION REQUIRED**
   >
   > Verification window open — use the **verify-`<task-id>`** tmux window to test the build. Confirm here when ready to proceed.
   >
   > | T-{id}: {title} |
   > |---|
   > | **Status:** in_progress |
   >
   > ---
3. Await explicit human confirmation.
4. Call `close-pane.sh "<window-id>"`.

**Step 3 — Send approval message to Task Agent:**

After both steps complete (or if neither is configured, immediately after diff approval), look up the Task Agent's `agent_id` from the plan, then `SendMessage to: '<agent_id>'`: "approved".

If both `VERIFICATION_PROMPT` and `VERIFICATION_MANUAL_GATE` are set, the sub-agent runs first, then the manual gate opens.
