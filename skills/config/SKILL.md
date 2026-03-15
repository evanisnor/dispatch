---
name: config
description: "Document the full .agent-workflow.json configuration schema and help the user configure the plugin. Invoke with /config."
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

Walk the user through creating or updating `.agent-workflow.json`, then ensure `.claude/settings.json` is configured:

1. Check if `.agent-workflow.json` already exists. If so, warn and confirm before overwriting.
2. For each required field (`plan_storage.repo_path`), prompt for a value. Show the default and instruct the user to type it if they want to accept it — do not say "press Enter", as Claude Code requires non-empty input.
3. For optional fields, ask whether the user wants to configure them (yes/no). Skip if they decline.
4. Write the resulting JSON to `.agent-workflow.json` in the current working directory.
5. Confirm the file was written and show a summary of the values set.
6. Create or update `.claude/settings.json` to pre-authorize Task Agent tools. Merge with any existing content — do not overwrite keys not related to agent-workflow. The required permissions block is:

```json
{
  "permissions": {
    "allow": [
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

Explain to the user: these permissions allow Task Agents spawned by the Orchestrating Agent to read and write files in their worktrees. Without this, Task Agents will be blocked from writing code.
