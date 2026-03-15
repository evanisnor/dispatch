---
name: config
description: "Document the full .dispatch.yaml configuration schema and help the user configure the plugin. Invoke with /config."
---

# Dispatch Configuration

## Modes

- **View mode** (default, or pass "show"): Print the full configuration reference, then annotate the current `.dispatch.yaml` against the schema.
- **Setup mode** (pass "setup"): Walk through creating or updating `.dispatch.yaml` interactively.

---

## View Mode

Print the schema reference below. Then check whether `.dispatch.yaml` exists in the current working directory:

- If it exists: read it with `yq` and display each key's current value. For keys not present in the file, show the default value and mark it as `(default)`.
- If it does not exist: note that no project config is found and all values are using plugin defaults.

---

## Full Configuration Reference

### `plan_storage.repo_path`

| | |
|---|---|
| Type | `string` (path) |
| Default | `~/plans` |

The local path to your plan storage git repository. This repo holds plan YAML files and is shared across projects. Tilde expansion is applied.

---

### `git.protected_branches`

| | |
|---|---|
| Type | `array of strings` |
| Default | `["main", "master"]` |

Branches that Task Agents are sandbox-denied from pushing to directly.

---

### `issue_tracking.tool`

| | |
|---|---|
| Type | `string` |
| Default | `""` (disabled) |

Name of the issue tracker to connect (`"jira"`, `"linear"`, `"github"`, etc.). Leave empty to disable issue tracking entirely. When set, Claude uses whatever MCP tools are available for the named tool (e.g. `jira_create_issue`, `linear_create_issue`).

---

### `issue_tracking.read_only`

| | |
|---|---|
| Type | `boolean` |
| Default | `false` |

Controls how the Planning Agent interacts with the tracker. `false` = autonomous issue creation (write-enabled mode). `true` = generate a companion document for manual creation, then backfill real IDs after the human provides the root ID (read-only mode).

---

### `issue_tracking.skill`

| | |
|---|---|
| Type | `string` |
| Default | `""` (built-in tracker integration) |

Name of a delegate skill for all tracker operations. When set, the Planning Agent and Task Agent spawn this skill via the Agent tool instead of using built-in integration. The skill receives a structured prompt with the operation type (`create_issues`, `generate_companion`, `backfill_ids`, or `close_issue`) and relevant context, and returns structured output (JSON for ID operations, markdown for companion doc generation, a confirmation string for close). Leave empty to use the built-in integration.

---

### `diff.mode`

| | |
|---|---|
| Type | `string` — `"split"` or `"unified"` |
| Default | `"split"` |

Default diff display mode in review panes. `"split"` uses `delta --side-by-side`; `"unified"` uses standard `delta` output. Has no effect if `delta` is not installed.

---

### `pr.description_skill`

| | |
|---|---|
| Type | `string` |
| Default | `""` (built-in `pr-description.sh`) |

Name of a delegate skill to invoke for authoring PR descriptions. When set, the Task Agent spawns this skill via the Agent tool instead of calling `pr-description.sh`. The skill receives the full task context (task ID, title, description, context, epic title, branch) and must return the PR body as its output. Leave empty to use the built-in template.

---

### `pr.template_path`

| | |
|---|---|
| Type | `string` (path) |
| Default | `""` (built-in template) |

Path to a custom PR description template file. Leave empty to use the built-in default. Supports variables: `{task_id}`, `{task_title}`, `{task_description}`, `{task_context}`, `{epic_title}`, `{branch}`, `{plan_path}`, `{worktree}`.

---

### `verification.manual_gate`

| | |
|---|---|
| Type | `boolean` |
| Default | `false` |

When `true`, the Orchestrating Agent opens a tmux window pointed at the task's worktree after diff approval, and waits for explicit human confirmation before the PR opens. Gives you a shell in the exact state the Task Agent left — use it for runtime testing, smoke tests, or anything that requires the app to actually run.

---

### `verification.startup_command`

| | |
|---|---|
| Type | `string` |
| Default | `""` |

Shell command to run automatically in the verification tmux window when `verification.manual_gate` is `true`. Useful for booting a dev server (e.g. `"npm run dev"`, `"./gradlew bootRun"`). Leave empty to open an idle shell.

---

### `verification.skill`

| | |
|---|---|
| Type | `string` |
| Default | `""` |

Name of a delegate skill to spawn for automated pre-PR verification. The skill receives `WORKTREE`, `BRANCH`, and `TASK_ID` as context. Its output is presented to the human before they confirm. Useful for running integration test suites, deploying to a staging environment, or any project-specific verification logic. Independent of `verification.manual_gate` — both can be set and will run in sequence (skill first, then manual gate).

---

### `sandbox.network.allowed_domains`

| | |
|---|---|
| Type | `array of strings` |
| Default | `["github.com", "api.github.com", "registry.npmjs.org"]` |

Domains Task Agents are permitted to reach over the network.

---

### `sandbox.filesystem.extra_deny_read`

| | |
|---|---|
| Type | `array of glob strings` |
| Default | `[]` |

Additional filesystem paths to block Task Agents from reading. Merged with the hardcoded base deny list: `~/.ssh/**`, `~/.gnupg/**`, `**/.env`, `**/*.pem`, `**/*.key`.

---

### `defaults.max_ci_fix_attempts`

| | |
|---|---|
| Type | `integer` |
| Default | `3` |

How many times a Task Agent may attempt to fix a CI failure before escalating to the human.

---

### `defaults.max_agent_restarts`

| | |
|---|---|
| Type | `integer` |
| Default | `2` |

How many times the Orchestrating Agent may restart a dead Task Agent before escalating.

---

### `defaults.polling_timeout_minutes`

| | |
|---|---|
| Type | `integer` |
| Default | `60` |

How long (in minutes) watch scripts and liveness checks poll before timing out and escalating.

---

## Setup Mode

Walk the user through creating or updating `.dispatch.yaml`, then ensure `.claude/settings.json` is configured:

1. Check if `.dispatch.yaml` already exists. If so, warn and confirm before overwriting.
2. For each required field (`plan_storage.repo_path`), prompt for a value. Show the default and instruct the user to type it if they want to accept it — do not say "press Enter", as Claude Code requires non-empty input.
3. For optional fields, ask whether the user wants to configure them (yes/no). Skip if they decline. Optional fields to prompt for (in addition to those above):
   - `issue_tracking.tool` — "Do you want to connect an issue tracker? (yes/no)"
     - If yes, prompt for the tool name — "Enter your issue tracker name (e.g. jira, linear, github):"
     - Then prompt for `issue_tracking.read_only` — "Should the agent create issues autonomously, or generate a companion document for manual creation? (autonomous/manual)"
     - Then prompt for `issue_tracking.skill` — "Do you have a Claude skill for your issue tracker? (yes/no)"
       - If yes, prompt for the skill name — "Enter the skill name (e.g. jira-issues, linear-workflow):"
   - `verification.manual_gate` — "Do you want to enable a manual verification gate after diff review? (yes/no)"
     - If yes, also prompt for `verification.startup_command` — "Enter a startup command to run in the verification window, or leave blank for an idle shell:"
   - `verification.skill` — "Do you want to configure a delegate skill for automated pre-PR verification? (yes/no)"
     - If yes, prompt for the skill name.
4. Write the resulting YAML to `.dispatch.yaml` in the current working directory.
5. Confirm the file was written and show a summary of the values set.
6. Determine the Dispatch plugin installation path:
   - Check `~/.claude/plugins/installed_plugins.json` for an entry named `"dispatch"` and read its path.
   - If not found there, check whether `~/.claude/plugins/dispatch/` exists.
   - If still not found, ask the user: "Where is the Dispatch plugin installed? (e.g. ~/.claude/plugins/dispatch)"
   - Expand tildes to absolute paths.
7. Determine the plan storage repo path:
   - Use the value provided for `plan_storage.repo_path` in step 2 (or its default `~/plans`).
   - Expand tildes to absolute paths.
8. Create or update `.claude/settings.json` to pre-authorize tools. Merge with any existing content — do not overwrite keys not related to Dispatch. The required permissions block is:

```json
{
  "permissions": {
    "allow": [
      "Read(<plugin-path>/**)",
      "Read(<plan-storage-path>/**)",
      "Read(**)",
      "Write(**)",
      "Edit(**)",
      "Glob(**)",
      "Grep(**)",
      "Bash(**)",
      "WebFetch(domain:*)"
    ]
  }
}
```

Where `<plugin-path>` is the absolute path from step 6 and `<plan-storage-path>` is the absolute path from step 7 (e.g. `Read(/home/user/.claude/plugins/dispatch/**)`, `Read(/home/user/plans/**)`).

Explain to the user:
- The `Read(<plugin-path>/...)` entry allows the Orchestrating Agent to read Dispatch skill files without prompting. Without this, every skill file access will trigger an approval dialog.
- The `Read(<plan-storage-path>/...)` entry allows agents to read plan YAML files from the plan storage repo without prompting.
- The remaining permissions allow Task Agents spawned by the Orchestrating Agent to read and write files in their worktrees. Without this, Task Agents will be blocked from writing code.
