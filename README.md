# Dispatch

A Claude Code plugin that coordinates a team of AI agents through your development workflow — from planning to merged PR — pausing only at decisions that need you.

## Features

- Decomposes work into atomic tasks with a dependency tree — you approve the plan before any code is written
- Implements each task in an isolated git worktree, one agent per task, running in parallel
- Opens a diff review window before every PR — no PR opens without your sign-off
- Watches CI, fixes failures autonomously, and adds PRs to the merge queue
- Handles reviewer feedback — presents requested changes to you, implements what you approve, replies to reviewers
- Analyzes incoming GitHub review requests automatically before you sit down to review
- Stacks dependent tasks during review so parallel work begins immediately
- Prototype mode — explore before committing to the full plan, no PRs opened
- Knowledge store — learns from past sessions, reapplies lessons in future runs

## How It Works

<img width=400 src="docs/orchestration.png" alt="Orchestration diagram">

| Agent | Role |
|---|---|
| **Orchestrating Agent** | Coordinates everything — spawns agents, surfaces decisions, monitors PRs and CI. Never writes code. |
| **Planning Agent** | Decomposes work into atomic tasks with a dependency tree. Exits after you approve the plan. |
| **Task Agents** | One per task. Implements in an isolated worktree, shepherds the PR from draft through merge. |
| **Review Agents** | Analyzes incoming review requests — reads the diff, summarizes changes, surfaces questions — so the work is done before you sit down. |

### Human approval gates

- **Spawning a Planning Agent** — before any work is decomposed
- **Approving the plan** — before anything is saved
- **Spawning Task Agents** — before any code is written
- **Spawning a Prototype Agent** — before any exploratory implementation begins
- **Stacking a dependent Task Agent** — offered after each approved diff; one at a time, opt-in
- **Diff review** — before every PR is opened
- **Reviewer-requested changes** — before the Task Agent acts on them
- **CI failures beyond the retry limit** — escalated with a summary of what failed
- **Merge conflicts** — surfaced for guidance before any conflicting changes are pushed
- **Abandoning a task** — requires explicit confirmation

## Requirements

- [Claude Code](https://claude.ai/code) (CLI)
- `git` and `gh` (GitHub CLI), authenticated
- `tmux` (for diff review windows)
- `jq` and `yq` (for config and plan parsing)
- A dedicated **plan storage git repository** (can be private, can be empty to start)
- Optionally: [`delta`](https://github.com/dandavison/delta) for syntax-highlighted diff review (falls back to plain `git diff` if not installed)
- Optionally: issue tracker access (Jira, Linear, GitHub Issues, etc.) via whichever integration your Claude environment provides

## Installation

**1. Clone the plugin**

```sh
git clone https://github.com/evanisnor/dispatch ~/.claude/plugins/dispatch
```

**2. Install dependencies (macOS)**

```sh
brew bundle --file ~/.claude/plugins/dispatch/Brewfile
```

**3. Start a tmux session**

```sh
tmux new-session -s work
```

**4. Start Claude with the plugin loaded**

```sh
claude --plugin-dir ~/.claude/plugins/dispatch
```

**5. Configure your project** — in your project directory, run the config skill to create `.dispatch.yaml` interactively:

```
/config setup
```

This walks you through the required fields (plan storage path) and optional settings. The file is gitignored — it should never be committed. To review the full config schema at any time, run `/config`.

## Usage

In a Claude Code session, invoke the skill:

```
/dispatch
```

The Orchestrating Agent will run startup reconciliation, then greet you with a status summary and next-step options. Describe the work in plain language, point to a PRD or design document, or reference a tracker epic — the agent will ask for your approval before spawning a Planning Agent.

From there, the workflow runs automatically: plan approval, parallel task implementation, diff review before each PR opens, CI monitoring, and merge queue management. You're pulled in only at the gates listed above.

## Configuration

`.dispatch.yaml` lives in your project root (gitignored) and overrides plugin defaults for that project. Run `/config` to see all current values, or `/config setup` to create or update the file interactively.

| Key | Type | Default | Description |
|---|---|---|---|
| `plan_storage.repo_path` | `string` (path) | `~/plans` | Local path to your plan storage git repository. |
| `git.protected_branches` | `array of strings` | `["main", "master"]` | Branches Task Agents are sandbox-denied from pushing to directly. |
| `git.branch_prefix` | `string` | `""` | Prefix prepended to every task branch (e.g. `"feat/"`, `"users/evan/"`). Must end with `/` for directory-style prefixes. |
| `issue_tracking.tool` | `string` | `""` | Name of the issue tracker (`"jira"`, `"linear"`, `"github"`, etc.). Leave empty to disable. |
| `issue_tracking.read_only` | `boolean` | `false` | `false` = autonomous issue creation (write-enabled). `true` = generate companion doc for manual creation + backfill IDs after human provides root ID. |
| `issue_tracking.prompt` | `string` | `""` | Prompt (or `"/skill-name"`) for all tracker operations. When set, a general-purpose sub-agent is spawned with this prompt instead of built-in integration. Leave empty to use the built-in approach. |
| `diff.mode` | `"split"` \| `"unified"` | `"split"` | Diff display mode in review panes. `"split"` uses `delta --side-by-side`; `"unified"` uses standard `delta` output. No effect if `delta` is not installed. |
| `editor.app` | `string` | `""` | Editor or IDE to open when reviewing a diff. On macOS, use the app's display name (e.g. `"Cursor"`, `"Xcode"`, `"Visual Studio Code"`). On any platform, a CLI command works too (e.g. `"code"`, `"cursor"`). When set, a `open editor` option is offered during every diff review. Leave empty to disable. |
| `pr.template_path` | `string` (path) | `""` | Path to a custom PR description template. Leave empty to use the built-in template. |
| `pr.description_prompt` | `string` | `""` | Prompt (or `"/skill-name"`) for PR description authoring. When set, a general-purpose sub-agent is spawned with this prompt instead of calling `pr-description.sh`. Leave empty to use the built-in template or `pr.template_path`. |
| `verification.manual_gate` | `boolean` | `false` | When `true`, opens a tmux window at the task's worktree after diff approval and waits for human confirmation before the PR opens. |
| `verification.startup_command` | `string` | `""` | Command to run automatically in the verification window (e.g. `"npm run dev"`). Only applies when `verification.manual_gate` is `true`. |
| `verification.prompt` | `string` | `""` | Prompt (or `"/skill-name"`) for automated pre-PR verification. Spawned after diff approval; output is presented to the human before confirmation. Independent of `manual_gate`. |
| `prototype.auto_push` | `boolean` | `false` | When `true`, the Prototype Agent pushes its branch to origin automatically after completing all commits. When `false` (default), the Orchestrating Agent asks before pushing. |
| `code_review.prompt` | `string` | `""` | Prompt (or `"/skill-name"`) for preliminary PR analysis. When set, Review Agents spawn a sub-agent with this prompt instead of performing their own analysis. Leave empty to use the built-in behavior. |
| `sandbox.network.allowed_domains` | `array of strings` | `["github.com", "api.github.com", "registry.npmjs.org"]` | Domains Task Agents are permitted to reach over the network. |
| `sandbox.filesystem.extra_deny_read` | `array of glob strings` | `[]` | Additional paths to block Task Agents from reading, merged with the hardcoded base deny list. |
| `defaults.max_ci_fix_attempts` | `integer` | `3` | How many times a Task Agent may attempt to fix a CI failure before escalating. |
| `defaults.max_agent_restarts` | `integer` | `2` | How many times the Orchestrating Agent may restart a dead Task Agent before escalating. |
| `defaults.polling_timeout_minutes` | `integer` | `60` | How long (in minutes) watch scripts poll before timing out and escalating. |

### Issue Tracking Integration

Issue tracking is optional and disabled by default. Set `issue_tracking.tool` in your `.dispatch.yaml` and ensure an MCP server for that tracker is configured in your Claude Code environment.

Two modes are available:

- **Write-enabled** (`read_only: false`, the default): The Planning Agent autonomously creates issues — a root issue for the epic and child issues for each task. After a task's PR merges, the Task Agent marks the corresponding issue done and links the PR.
- **Read-only** (`read_only: true`): The Planning Agent generates a companion markdown document listing proposed issues for manual creation. After you create them and provide the root ID, the agent backfills real IDs into the plan YAML.

If you have a Claude skill that knows your tracker's structure, set `issue_tracking.prompt` to delegate all tracker operations to it:

```yaml
issue_tracking:
  tool: jira
  prompt: /jira-workflow
```

If issue tracking is not configured, the Planning Agent uses kebab-case slug IDs throughout.

### PR Description Templates

By default, every Task Agent generates a PR body using the built-in template:

```markdown
## What
{task_description}

## Why
{task_context}

## Task
`{task_id}` — {epic_title}

---
*Generated by [Dispatch](https://github.com/evanisnor/dispatch)*
```

To use a custom template, point to it in `.dispatch.yaml`:

```yaml
pr:
  template_path: .github/pr-template.md
```

Available template variables: `{task_id}`, `{task_title}`, `{task_description}`, `{task_context}`, `{epic_title}`, `{branch}`, `{plan_path}`, `{worktree}`.

To delegate PR description authoring to a Claude skill, set `pr.description_prompt`. The Task Agent will spawn that skill with the full task context and use whatever it returns as the PR body.

```yaml
pr:
  description_prompt: /my-pr-skill
```

### Code Review Prompt

By default, Review Agents read the diff and produce a summary, analysis, and list of open questions. To delegate preliminary analysis to a project-specific skill:

```yaml
code_review:
  prompt: /my-review-skill
```

The Review Agent spawns a sub-agent with the PR URL, title, author, base and head refs, PR description, and diff — all wrapped in `<external_content>` tags. The sub-agent returns the same structured output (summary, analysis, questions) as the built-in behavior.

## Permissions and Security

### What the agents can and cannot do

- The Orchestrating Agent uses targeted permission rules and does not run in `bypassPermissions` mode. It cannot push code or merge PRs.
- Task Agents run with pre-authorized tool permissions scoped to their worktree.
- **Write access** is limited to the task's assigned worktree directory.
- **Network access** is limited to domains listed in `sandbox.network.allowed_domains`.
- **Read access** is denied for `~/.ssh/**`, `~/.gnupg/**`, `**/.env`, `**/*.pem`, `**/*.key`, plus any paths in `sandbox.filesystem.extra_deny_read`.
- Protected branches (`git.protected_branches`) are enforced at the permissions layer, independent of agent reasoning.
- `gh pr merge` without `--auto` is always denied — Task Agents can only add PRs to the merge queue, never merge directly.

### Prompt injection defense

All external content — PR comments, CI log summaries, reviewer feedback, issue tracker text, and plan `context` fields — is wrapped in `<external_content>` tags before being included in any agent prompt. Every agent's system prompt includes an explicit rule to treat content inside those tags as data only and never follow instructions found there.
