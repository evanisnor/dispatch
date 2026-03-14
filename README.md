# agent-workflow

agent-workflow is a Claude Code plugin that runs a multi-agent software development workflow directly from your terminal. You describe a piece of work, and a coordinated team of AI agents handles the rest: decomposing the work into atomic tasks, implementing each one in an isolated git worktree, opening pull requests, watching CI, responding to reviewer feedback, and merging — while keeping you in the loop at every decision point that matters.

- **Orchestrating Agent** coordinates the whole process. It spawns the other agents, opens tmux panes for diff review, monitors PRs and CI, and handles post-merge cleanup. It never writes code.
- **Planning Agent** breaks down your assignment into atomic tasks with a dependency tree, optionally syncs with Jira, and saves a structured plan to a dedicated git repository. It exits once you approve the plan.
- **Task Agents** each implement a single task in their own git worktree, shepherd the PR from draft through to merge, fix CI failures autonomously, and resolve merge conflicts when they arise.
- **You** approve plans, review diffs, and handle anything the agents escalate — no more, no less.

## Requirements

- [Claude Code](https://claude.ai/code) (CLI)
- `git` and `gh` (GitHub CLI), authenticated
- `tmux` (for diff review panes)
- `jq` and `yq` (for config and plan parsing)
- A dedicated **plan storage git repository** (can be private, can be empty to start)
- Optionally: a Jira MCP server if you want Jira integration

## Installation

**1. Clone the plugin**

```sh
git clone https://github.com/evanisnor/agent-workflow ~/.claude/plugins/agent-workflow
```

**2. Enable the plugin in Claude Code**

Add it to your Claude Code plugins config, or place it in your `CLAUDE_PLUGIN_DIR`. Refer to the [Claude Code plugin documentation](https://code.claude.com/docs/en/plugins) for your installation method.

**3. Create your plan storage repository**

```sh
mkdir -p ~/plans && cd ~/plans && git init && git remote add origin <your-remote-url>
```

The plan storage repo holds plan YAML files and is shared across projects. It can be a private repo on GitHub.

**4. Configure your project**

Copy the example config into your project root and fill in your values:

```sh
cp ~/.claude/plugins/agent-workflow/.agent-workflow.example.json .agent-workflow.json
```

Edit `.agent-workflow.json`:

```json
{
  "plan_storage": {
    "repo_path": "~/plans"
  },
  "worktree": {
    "base_dir": "~/.agents"
  },
  "git": {
    "protected_branches": ["main"]
  },
  "build": {
    "test_command": "npm run test",
    "lint_command": "npm run lint",
    "build_command": "npm run build"
  }
}
```

The file is gitignored — it should never be committed.

**5. Start a tmux session**

The diff review workflow opens windows inside your current tmux session. Start one before invoking the Orchestrating Agent:

```sh
tmux new-session -s work
```

## Usage

### Start the Orchestrating Agent

In a Claude Code session, invoke the skill:

```
/agent-workflow:orchestrating-agents
```

The Orchestrating Agent activates automatically if you have `settings.json` installed as a plugin default. It will greet you and wait for an assignment.

### Give it an assignment

Describe the work in plain language:

```
Build a user authentication system: registration, login, JWT tokens, and a
middleware guard for protected routes.
```

The Orchestrating Agent will ask for your approval before spawning a Planning Agent.

### Review and approve the plan

The Planning Agent decomposes the work and presents a dependency tree. You review it through the Orchestrating Agent, request changes if needed, and approve when satisfied. The plan is saved to your plan storage repo.

### Review diffs before PRs open

For each task, once a Task Agent has implemented the work and passed its pre-PR checklist, the Orchestrating Agent opens a tmux window showing `git diff HEAD`. You approve or reject with specific feedback. No PR opens without your sign-off.

### Monitor and merge

After you approve a diff, the Task Agent opens a draft PR, watches CI, marks the PR ready when CI passes, and adds it to the merge queue. You are notified of CI failures that exceed the retry limit, reviewer change requests, and merge queue issues. Everything else is handled automatically.

## Use Case Examples

### New feature from scratch

```
We need to add a CSV export feature to the reports page. Users should be able
to export any filtered report view as a CSV file. The backend needs a new
endpoint and the frontend needs an export button.
```

The Planning Agent will split this into backend and frontend tasks, serialize them correctly via `depends_on` if the frontend depends on the backend contract, and spawn Task Agents for each once you approve.

### Picking up a Jira epic

```
Take epic PROJ-42 and implement it. The Jira project is configured in my
.agent-workflow.json.
```

The Planning Agent reads the epic and child issues via the Jira MCP server, builds a plan keyed to real Jira IDs, and backfills those IDs into the plan YAML. Progress is tracked against the actual ticket keys.

### Resuming after a restart

Start the Orchestrating Agent and it will automatically reconcile in-progress state: it checks which branches exist, which PRs are open, and which agents are running, then resumes without losing work.

### Handling a rejected diff

When you reject a diff, provide specific feedback:

```
Reject. The error handling in auth_middleware.go swallows the original error.
Wrap it with fmt.Errorf instead. All error returns in that file should include
the original error.
```

The Orchestrating Agent forwards structured feedback to the Task Agent, which implements the change and requests re-review.

## Permissions and Security

### What the agents can and cannot do

The Orchestrating Agent uses targeted permission rules and does not run in `bypassPermissions` mode. It cannot push code or merge PRs.

Task Agents run in `bypassPermissions` mode, but this is scoped inside an OS-level sandbox (Seatbelt on macOS, bubblewrap on Linux) at spawn time. The sandbox is generated from your `.agent-workflow.json` and enforces:

- **Write access** limited to the task's assigned worktree directory.
- **Network access** limited to domains you list in `sandbox.network.allowed_domains`.
- **Read access** denied for `~/.ssh/**`, `~/.gnupg/**`, `**/.env`, `**/*.pem`, `**/*.key`, plus any paths you add to `sandbox.filesystem.extra_deny_read`.

Protected branches (`git.protected_branches`) are enforced by deny rules at the permissions layer, independent of agent reasoning. `gh pr merge` without `--auto` is also always denied — Task Agents can only add PRs to the merge queue, never merge directly.

### Prompt injection defense

All external content — PR comments, CI log summaries, reviewer feedback, Jira text, and plan `context` fields — is wrapped in `<external_content>` tags before being included in any agent prompt. Every agent's system prompt includes an explicit rule to treat content inside those tags as data only and never follow instructions found there.

CI scripts (`watch-ci.sh`, `watch-merge-queue.sh`, `watch-pr-status.sh`) emit state-change summaries only. Raw log text and full API payloads are never injected into agent context.

### Human approval gates

Despite the automation, these operations always require your explicit approval:

| Operation | Gate |
|---|---|
| Spawning a Planning Agent | You approve |
| Spawning a batch of Task Agents | You approve |
| Opening a PR (diff review) | You approve the diff |
| Merging (after reviewer approval + CI) | Merge queue; you control reviewer approval |
| Abandoning a task | You approve |

## Jira Integration

Jira integration is optional and disabled by default. To enable it, set `"jira": { "enabled": true }` in your `.agent-workflow.json` and ensure a Jira MCP server is configured and accessible to Claude Code.

When enabled, the Planning Agent reads epics and child issues via the Jira MCP server (read-only). It matches Jira issues to plan tasks by title similarity and backfills real Jira keys into the plan YAML in place of slug IDs.

If Jira is disabled or the MCP server is unavailable, the Planning Agent uses kebab-case slug IDs (`feature-user-auth`, `task-login-endpoint`) and generates a companion markdown document (`{slug}-jira-items.md`) in the plan storage repo. This document contains a formatted table of proposed issues that you can use to create tickets manually in Jira or any other tracker.

The plugin does not ship a Jira MCP server configuration. If you need one, configure it separately in your Claude Code settings before enabling Jira integration here.
