# Notification Banner Styles

All human-facing notifications must use one of the four banner styles below. These styles make important events visually distinct from surrounding conversational text in the terminal.

## Styles

### ACTION REQUIRED — human must respond

Use for: diff review requests, plan review requests, approval gates, scheduling prompts, stacking prompts, verification gates, batch spawn approval, orphaned worktree decisions.

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

Use for: draft PR opened, review requested (incoming), preliminary review ready, review removed, startup greetings, stacking explanation, stalled reviewer comment.

```
**-- <Topic>:** <message>
```

Rendering rules:
- Single line. Bold leader `**-- <Topic>:**` followed by message text.
- No horizontal rules, no block structure.
- Topic is a short label describing the event (e.g., `Draft PR opened`, `Review requested`, `Preliminary review ready`).

### WARNING — something went wrong, usually needs a decision

Use for: CI fix exhausted, merge queue ejection, agent death, agent stall, timeout escalation, plan corruption, failed tasks warning.

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
| Batch spawn approval | ACTION REQUIRED | SKILL.md |
| Stacking prompt | ACTION REQUIRED | SKILL.md |
| Orphaned worktree decision | ACTION REQUIRED | SKILL.md |
| Plan review ready | ACTION REQUIRED | REVIEW.md |
| Amendment review ready | ACTION REQUIRED | REVIEW.md |
| Diff review (approve/reject) | ACTION REQUIRED | REVIEW.md |
| Verification gate | ACTION REQUIRED | REVIEW.md |
| Reviewer-requested change | ACTION REQUIRED | REVIEW.md |
| Conflict resolution review | ACTION REQUIRED | REVIEW.md |
| Diff open for incoming review | ACTION REQUIRED | CODE_REVIEW.md |
| CI passing — schedule readiness | ACTION REQUIRED | executing-tasks/SKILL.md |
| Approved — schedule merge | ACTION REQUIRED | executing-tasks/SKILL.md |
| Draft PR opened | INFORMATIONAL | PR_MONITORING.md |
| Draft PR opened (Task Agent) | INFORMATIONAL | executing-tasks/SKILL.md |
| Review requested (incoming) | INFORMATIONAL | CODE_REVIEW.md |
| Review request removed | INFORMATIONAL | CODE_REVIEW.md |
| Preliminary review ready | INFORMATIONAL | CODE_REVIEW.md |
| Startup greetings (Scenarios A–D) | INFORMATIONAL | SKILL.md |
| Stacking explanation | INFORMATIONAL | SKILL.md |
| Stalled reviewer comment | INFORMATIONAL | PR_MONITORING.md |
| PR auto-advanced (orphaned agent) | INFORMATIONAL | PR_MONITORING.md |
| CI fix exhausted | WARNING | PR_MONITORING.md |
| Merge queue ejection | WARNING | PR_MONITORING.md |
| Timeout escalation | WARNING | PR_MONITORING.md |
| Agent dead | WARNING | PR_MONITORING.md |
| Agent stalled | WARNING | PR_MONITORING.md |
| Plan corruption | WARNING | SKILL.md |
| Failed tasks warning | WARNING | SKILL.md |
| Startup Scenario C with failures | WARNING | SKILL.md |
| PR approved | SUCCESS | CODE_REVIEW.md |
| All tasks complete | SUCCESS | SKILL.md |
| Ready for new assignment | SUCCESS | SKILL.md |

## Agent-to-Agent Messages

Messages between agents (e.g., "diff approved — proceed to open draft PR") are **not** human-facing notifications. They do not use banner styles.
