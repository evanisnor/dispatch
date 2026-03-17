# Plan Storage

## Configuration

Resolve `PLAN_REPO` in priority order:
1. `.dispatch.yaml` → `plan_storage.repo_path`
2. `settings.yaml` → `defaults.plan_storage.repo_path`
3. Fallback: `~/plans`

Plan files live directly in `PLAN_REPO` with the naming convention `<plan-id>.yaml`.

If `PLAN_REPO` is not a git repo, initialize it: `git -C "$PLAN_REPO" init --quiet`.

---

## Loading (read-only)

```bash
cat "$PLAN_REPO/<plan-id>.yaml"
```

No lock needed. Loading is read-only.

---

## Saving (write-with-lock)

Never pipe a reconstructed full document to the plan file. Always patch in-place with `yq e -i`.

### Steps

1. **Pull latest** (if a remote exists):
   ```bash
   git -C "$PLAN_REPO" pull --rebase --quiet origin main
   ```
   If no remote: warn (`WARNING: plan storage has no remote — plans are saved locally only`) but continue.

2. **Acquire lock** — write `.lock`, commit, and push:
   ```bash
   echo "locked by agent $$ at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PLAN_REPO/.lock"
   git -C "$PLAN_REPO" add .lock
   git -C "$PLAN_REPO" commit -m "lock: acquire" --quiet
   git -C "$PLAN_REPO" push origin main --quiet   # skip if no remote
   ```

   **On push failure (contention):** another agent holds the lock.
   - `git -C "$PLAN_REPO" reset --soft HEAD~1 --quiet`
   - `git -C "$PLAN_REPO" restore --staged .lock 2>/dev/null || true`
   - `rm -f "$PLAN_REPO/.lock"`
   - Wait and retry: delays of 2s, 4s, 8s — up to 4 total attempts.
   - After 4 failures: stop and escalate to the Orchestrating Agent.

3. **Apply patch(es) in-place** using the `TASKS_PATH` discovered at session start:
   ```bash
   yq e -i '(<expression>)' "$PLAN_REPO/<plan-id>.yaml"
   ```
   Never pipe the full document. One `yq e -i` call per field group is fine.

   For single-task field updates, prefer `plan-update.sh` which handles discovery, patching, and read-back validation in one call:
   ```bash
   <plugin-root>/scripts/plan-update.sh "$PLAN_REPO/<plan-id>.yaml" <task-id> <field> <value>
   ```

3.5. **Validate mutation.** After every `yq e -i` patch, read back the written value and verify it matches the intended value:
   ```bash
   ACTUAL=$(yq e "($TASKS_PATH[] | select(.id == \"<task-id>\")).<field>" "$PLAN_REPO/<plan-id>.yaml")
   ```
   If `ACTUAL` does not match the expected value, the `select()` filter likely did not match any task — `yq e -i` with a non-matching `select()` exits 0 silently. Investigate the task ID before proceeding. Do **not** commit a plan file where a mutation was not verified.

4. **Commit and push** the plan file:
   ```bash
   git -C "$PLAN_REPO" add <plan-id>.yaml
   git -C "$PLAN_REPO" commit -m "plan: update <plan-id>" --quiet
   git -C "$PLAN_REPO" push origin main --quiet   # skip if no remote
   ```

5. **Release lock**:
   ```bash
   git -C "$PLAN_REPO" rm -f .lock --quiet
   git -C "$PLAN_REPO" commit -m "lock: release" --quiet
   git -C "$PLAN_REPO" push origin main --quiet   # skip if no remote
   ```

---

## Structure Inspection

The path to the task list varies by issue tracker. Before any `yq` query against a plan file, discover the structure.

**Step 1 — inspect top-level keys:**
```bash
yq e 'keys' "$PLAN_REPO/<plan-id>.yaml"
```

**Step 2 — find the tasks sequence:** identify the first key whose value is a sequence and whose items contain both `id` and `status` fields. That key (or dotted path) is `TASKS_PATH`.

Examples by tracker:
- Jira → `.epic.tasks`
- Linear → `.project.issues`
- GitHub Issues → `.milestone.issues`
- No tracker → `.tasks`

**Step 3 — cache `TASKS_PATH` for the session.** Do not re-inspect on every query.

**Example discovery for a two-level structure:**
```bash
# Check if tasks are nested under an envelope key
TOP_KEY=$(yq e 'keys | .[0]' "$PLAN_REPO/<plan-id>.yaml")
# Probe for a nested tasks-like sequence
TASKS_PATH=$(yq e ".$TOP_KEY | keys | .[]" "$PLAN_REPO/<plan-id>.yaml" \
  | while read key; do
      has_id=$(yq e ".$TOP_KEY.$key[0].id" "$PLAN_REPO/<plan-id>.yaml")
      has_status=$(yq e ".$TOP_KEY.$key[0].status" "$PLAN_REPO/<plan-id>.yaml")
      if [[ "$has_id" != "null" && "$has_status" != "null" ]]; then
        echo ".$TOP_KEY.$key"
        break
      fi
    done)
# Fallback: flat root
if [[ -z "$TASKS_PATH" ]]; then
  TASKS_PATH=".tasks"
fi
```

Once `TASKS_PATH` is known, use it for all subsequent queries:
```bash
yq e -i "($TASKS_PATH[] | select(.id == \"<task-id>\")).status = \"done\"" "$PLAN_REPO/<plan-id>.yaml"
```
