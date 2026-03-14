---
name: config
description: "Document the full .agent-workflow.json configuration schema and help the user configure the plugin. Invoke with /agent-workflow:config."
---

# agent-workflow Configuration

## Modes

- **View mode** (default, or pass "show"): Print the full configuration reference, then annotate the current `.agent-workflow.json` against the schema.
- **Setup mode** (pass "setup"): Walk through creating or updating `.agent-workflow.json` interactively.

---

## View Mode

Print the schema reference below. Then check whether `.agent-workflow.json` exists in the current working directory:

- If it exists: read it with `jq` and display each key's current value. For keys not present in the file, show the default value and mark it as `(default)`.
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

### `worktree.base_dir`

| | |
|---|---|
| Type | `string` (path) |
| Default | `~/.agents` |

Directory where Task Agent worktrees are created. Structure: `{base_dir}/{repo-name}/{task-id}/`. Tilde expansion is applied.

---

### `git.protected_branches`

| | |
|---|---|
| Type | `array of strings` |
| Default | `["main", "master"]` |

Branches that Task Agents are sandbox-denied from pushing to directly.

---

### `jira.enabled`

| | |
|---|---|
| Type | `boolean` |
| Default | `false` |

Enable Jira MCP integration. Requires a Jira MCP server configured in Claude Code settings.

---

### `diff.mode`

| | |
|---|---|
| Type | `string` — `"split"` or `"unified"` |
| Default | `"split"` |

Default diff display mode in review panes. `"split"` uses `delta --side-by-side`; `"unified"` uses standard `delta` output. Has no effect if `delta` is not installed.

---

### `pr.template_path`

| | |
|---|---|
| Type | `string` (path) |
| Default | `""` (built-in template) |

Path to a custom PR description template file. Leave empty to use the built-in default. Supports variables: `{task_id}`, `{task_title}`, `{task_description}`, `{epic_title}`, `{branch}`, `{plan_path}`, `{worktree}`.

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

### `defaults.task_agent_mode`

| | |
|---|---|
| Type | `string` — `"bypassPermissions"` or `"acceptEdits"` |
| Default | `"bypassPermissions"` |

Permission mode for Task Agents. `"bypassPermissions"` lets the agent act freely within the OS sandbox; `"acceptEdits"` requires approval for every file edit.

---

## Setup Mode

Walk the user through creating or updating `.agent-workflow.json`:

1. Check if `.agent-workflow.json` already exists. If so, warn and confirm before overwriting.
2. For each required field (`plan_storage.repo_path`, `worktree.base_dir`), prompt for a value and show the default.
3. For optional fields, ask whether the user wants to configure them. Skip if they decline.
4. Write the resulting JSON to `.agent-workflow.json` in the current working directory.
5. Confirm the file was written and show a summary of the values set.
