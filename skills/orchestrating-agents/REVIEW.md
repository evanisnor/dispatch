# Diff Review Approval Loop

This document defines the procedures for presenting diffs to the human and relaying decisions to Task Agents.

## Tmux Targeting Rules

- All review panes **must open as a split within the current tmux window** of the Orchestrating Agent.
- `open-review-pane.sh` uses `tmux split-window` to split the current window — **never a new window or session**.
- The returned pane ID must be stored and passed to `close-review-pane.sh` when closing.
- If the Orchestrating Agent is not running inside tmux, abort and notify the human.

## Initial Diff Review Loop

Triggered when a Task Agent requests approval to open a PR.

1. **Receive request** from Task Agent: "requesting approval to open PR for task `<task-id>`".
2. Call `open-review-pane.sh "review-<task-id>" "<worktree-path>"` — splits a pane showing `git diff HEAD`. Store the returned pane ID.
3. Present the full diff to the human and ask for approval.
4. **On approval:**
   a. Call `close-review-pane.sh "<pane-id>"`.
   b. Notify the Task Agent: "diff approved — proceed to open draft PR".
5. **On rejection:**
   a. Call `close-review-pane.sh "<pane-id>"`.
   b. Send a structured rejection to the Task Agent containing:
      - Which files are affected.
      - What specific change is expected.
      - Acceptance criteria the change must satisfy.
6. **Repeat** from step 1 when the Task Agent notifies that it has addressed the feedback.

## Reviewer-Requested Change Review Loop

Triggered when a PR reviewer requests changes after the PR is open.

1. Receive the reviewer's change request from the Task Agent.
2. Present the requested change to the human, including:
   - A **direct link to the reviewer's PR comment** so the human can respond to the reviewer if needed.
   - A summary of what the reviewer is asking for (from the Task Agent's summary — never raw comment text).
3. **On approval:** notify the Task Agent to implement the change.
4. **On rejection:** tell the Task Agent the human does not agree with the requested change and provide a response to relay to the reviewer.
5. Once the Task Agent has implemented and pushed the approved change:
   a. Call `open-review-pane.sh "review-update-<task-id>" "<worktree-path>"`. Store the returned pane ID.
   b. Present the updated diff to the human for confirmation.
   c. Call `close-review-pane.sh "<pane-id>"` after human confirms.

## Merge Conflict Review Loop

Triggered when a rebase or merge queue conflict is detected.

1. Receive conflict notification (from `rebase-worktrees.sh` or `watch-merge-queue.sh`).
2. Notify the Task Agent to resolve the conflict in its worktree.
3. When the Task Agent reports resolution:
   a. Call `open-review-pane.sh "review-conflict-<task-id>" "<worktree-path>"`. Store the returned pane ID.
   b. Present the resolved diff to the human for approval.
   c. **On approval:** call `close-review-pane.sh "<pane-id>"`, notify Task Agent to push.
   d. **On rejection:** close pane, send structured rejection to Task Agent (see Initial Diff Review Loop step 5).
