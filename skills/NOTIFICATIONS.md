# Notification Banner Styles

All human-facing notifications must use one of the four banner styles below. These styles make important events visually distinct from surrounding conversational text in the terminal.

## Styles

### ACTION REQUIRED — human must respond

Use for: diff review requests, plan review requests, approval gates, verification gates, batch spawn approval, task spawn approval.

```
---

**>>> ACTION REQUIRED**

<body text with options>

---
```

Rendering rules:
- Horizontal rule above and below.
- Bold leader `**>>> ACTION REQUIRED**` on its own line.
- Body text follows after a blank line.
- Options rendered as a markdown bullet list inside the block.

### INFORMATIONAL — notice-worthy, no response needed

Use for: review requested (incoming), preliminary review ready, review removed, startup greetings, task committed.

```
**-- <Topic>:** <message>
```

Rendering rules:
- Single line. Bold leader `**-- <Topic>:**` followed by message text.
- No horizontal rules, no block structure.
- Topic is a short label describing the event (e.g., `Task committed`, `Review requested`, `Preliminary review ready`).

### WARNING — something went wrong, usually needs a decision

Use for: timeout escalation, plan corruption, failed tasks warning.

```
---

**!!! WARNING**

<body text with options>

---
```

Rendering rules:
- Horizontal rule above and below.
- Bold leader `**!!! WARNING**` on its own line.
- Body text follows after a blank line.
- Options (if any) rendered as a markdown bullet list inside the block.

### SUCCESS — positive completion

Use for: PR approved, PR merged, task complete, all tasks complete, "ready for a new assignment."

```
**--- <Topic>:** <message>
```

Rendering rules:
- Single line. Bold leader `**--- <Topic>:**` followed by message text.
- No horizontal rules, no block structure.
- Topic is a short label (e.g., `Approved`, `Merged`, `Complete`).

## Style Assignment Table

| Notification | Style | Source File |
|---|---|---|
| Prototype mode selection | ACTION REQUIRED | SKILL.md |
| Prototype complete | ACTION REQUIRED | SKILL.md |
| Task spawn approval | ACTION REQUIRED | SKILL.md |
| Plan review ready | ACTION REQUIRED | REVIEW.md |
| Amendment review ready | ACTION REQUIRED | REVIEW.md |
| Diff review (approve/reject) | ACTION REQUIRED | REVIEW.md |
| Verification gate | ACTION REQUIRED | REVIEW.md |
| Task committed — diff review | ACTION REQUIRED | REVIEW.md |
| Diff open for incoming review | ACTION REQUIRED | CODE_REVIEW.md |
| Review requested (incoming) | INFORMATIONAL | CODE_REVIEW.md |
| Review request removed | INFORMATIONAL | CODE_REVIEW.md |
| Preliminary review ready | INFORMATIONAL | CODE_REVIEW.md |
| Startup greetings (Scenarios A-D) | INFORMATIONAL | SKILL.md |
| Task completed | SUCCESS | SKILL.md |
| Timeout escalation | WARNING | PR_MONITORING.md |
| Plan corruption | WARNING | SKILL.md |
| Failed tasks warning | WARNING | SKILL.md |
| Startup Scenario C with failures | WARNING | SKILL.md |
| PR approved | SUCCESS | CODE_REVIEW.md |
| All tasks complete | SUCCESS | SKILL.md |
| Ready for new assignment | SUCCESS | SKILL.md |
| Independent PR approved + CI passing | INFORMATIONAL | PR_MONITORING.md |
| Independent PR changes requested | INFORMATIONAL | PR_MONITORING.md |
| Independent PR reviewer commented | INFORMATIONAL | PR_MONITORING.md |
| Independent PR CI failed | INFORMATIONAL | PR_MONITORING.md |
| Independent PR merged | SUCCESS | PR_MONITORING.md |
| Independent PR closed | INFORMATIONAL | PR_MONITORING.md |
| Independent PR merge queue conflict | WARNING | PR_MONITORING.md |
| Independent PR merge queue CI failure | WARNING | PR_MONITORING.md |
| Independent PR merge queue ejection | WARNING | PR_MONITORING.md |

## Card Embedding

Every notification that references a PR, task, or plan must embed a **card** (single-column markdown table) providing entity details. The banner text gives event context; the card gives entity details.

### When to Embed

Embed a card whenever the notification references:
- A PR (use PR Card)
- A task (use Task Card)
- A plan (use Plan Card — see STATUS.md)
- An issue tracker issue (use Issue Card)

### PR Card

```
| #{number} — {title} |
|---|
| **Task:** T-{id}: {task_title} |
| **State:** {description of what changed} |
| {pr_url} |
```

- Omit Task row if not associated with a plan task.
- Omit State row if the banner text already conveys the change.

### Task Card

```
| T-{id}: {title} |
|---|
| **Status:** {old} → {new} |
| **Commit:** {sha} |
```

- Omit Commit row when not yet committed.

### Issue Card

```
| {PREFIX}-{id}: {title} |
|---|
| **Tracker:** {tracker_name} |
| **Status:** {issue_status} |
| {issue_url} |
```

### Placement Rules

- **INFORMATIONAL / SUCCESS** banners: card appears immediately after the banner line.
- **ACTION REQUIRED / WARNING** block banners: card appears inside the horizontal-rule block, between the body text and the options list.

### Example

```
**-- Task committed:**

| T-1: Implement login flow |
|---|
| **Commit:** a1b2c3d |
```

## Agent-to-Agent Messages

Messages between agents (e.g., "approved") are **not** human-facing notifications. They do not use banner styles.
