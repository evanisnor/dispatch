# Agent Workflow

```mermaid
sequenceDiagram
    participant Human as Human
    participant PrimaryAgent as Primary Claude Agent
    participant TaskAgent as Task Agent
    participant Worktree as Agent Worktree
    participant PR as Pull Request (Draft → Ready)
    participant GitHubCI as GitHub / CI
    participant LocalMain as Local Main
    participant OriginMain as Origin Main

    Note over TaskAgent: Each Task Agent is responsible for shepherding<br/>a single Pull Request from implementation through to merge

    rect rgb(30, 30, 60)
        Note over Human,PrimaryAgent: Planning Phase — may occur at any time for new or existing projects
        Human->>PrimaryAgent: Assign projects / tasks
        Note over Human,PrimaryAgent: Human may send new commands or tasks to Primary Agent at any time
        PrimaryAgent->>PrimaryAgent: Break work into atomic tasks
        PrimaryAgent->>PrimaryAgent: Identify task dependencies and potential worktree conflicts
        PrimaryAgent->>PrimaryAgent: Build full task dependency tree
        PrimaryAgent->>Human: Present task dependency tree for approval
        Human->>PrimaryAgent: Approve or revise task dependency tree
    end

    loop For each batch of tasks ready to execute per dependency tree
        PrimaryAgent->>Human: Request approval to spawn Task Agents for ready tasks
        Human->>PrimaryAgent: Approve Task Agent spawning
        PrimaryAgent->>TaskAgent: Spawn Task Agent with assigned task and worktree
        Note over PrimaryAgent,TaskAgent: Tasks with unresolved dependencies or worktree conflicts remain deferred in the tree

        TaskAgent->>Worktree: Create worktree and implement initial changes
        TaskAgent->>PrimaryAgent: Request approval to open PR
        PrimaryAgent->>PrimaryAgent: Open tmux pane "review-{task}" showing full diff
        PrimaryAgent->>Human: Present full diff for review
        alt Human approves
            Human->>PrimaryAgent: Approval granted
            PrimaryAgent->>PrimaryAgent: Close tmux pane
            PrimaryAgent-->>TaskAgent: Approval granted
        else Human rejects with reason
            Human->>PrimaryAgent: Rejection with specific reason
            PrimaryAgent->>PrimaryAgent: Close tmux pane
            PrimaryAgent-->>TaskAgent: Forward rejection reason as change requests
            TaskAgent->>Worktree: Apply requested changes
            TaskAgent->>PrimaryAgent: Request approval to open PR
            PrimaryAgent->>PrimaryAgent: Open tmux pane "review-{task}" showing full diff
            PrimaryAgent->>Human: Present full diff for review
            Note over Human,PrimaryAgent: Repeat until approved
        end

        TaskAgent->>PR: Open draft pull request
        PR->>PrimaryAgent: Notify PR opened (include URL)
        PR-->>GitHubCI: Trigger CI checks on draft

        alt CI checks fail
            GitHubCI-->>PR: Report CI failures
            PR-->>TaskAgent: Notify CI failures
            TaskAgent->>PR: Fix issues and push updates (no approval needed)
            PR-->>GitHubCI: Re-run CI checks
        else CI checks pass
            GitHubCI-->>PR: Report CI success
            TaskAgent->>PR: Mark as Ready for Review
            PR->>PrimaryAgent: Notify PR marked Ready for Review
        end

        loop Monitor review and CI feedback
            GitHubCI-->>PR: Send review comments / CI feedback
            alt Clear change requests
                PR-->>TaskAgent: Notify changes requested
                TaskAgent->>Worktree: Apply requested modifications
                TaskAgent->>PrimaryAgent: Notify updated change for approval
                PrimaryAgent->>PrimaryAgent: Open tmux pane "review-update-{task}" showing full diff
                PrimaryAgent->>Human: Present full diff for review
                alt Human approves
                    Human->>PrimaryAgent: Approval granted
                    PrimaryAgent->>PrimaryAgent: Close tmux pane
                    PrimaryAgent-->>TaskAgent: Approves updated change
                    TaskAgent->>PR: Push approved change
                    PR-->>GitHubCI: Trigger CI checks
                    alt CI checks fail
                        GitHubCI-->>PR: Report CI failures
                        PR-->>TaskAgent: Notify CI failures
                        TaskAgent->>PR: Fix issues and push updates (no approval needed)
                        PR-->>GitHubCI: Re-run CI checks
                    else CI checks pass
                        GitHubCI-->>PR: Report CI success
                    end
                else Human rejects with reason
                    Human->>PrimaryAgent: Rejection with specific reason
                    PrimaryAgent->>PrimaryAgent: Close tmux pane
                    PrimaryAgent-->>TaskAgent: Forward rejection reason as change requests
                    TaskAgent->>Worktree: Apply requested modifications
                    TaskAgent->>PrimaryAgent: Notify updated change for approval
                    PrimaryAgent->>PrimaryAgent: Open tmux pane "review-update-{task}" showing full diff
                    PrimaryAgent->>Human: Present full diff for review
                    Note over Human,PrimaryAgent: Repeat until approved
                end
            else Ambiguous comments
                PR-->>TaskAgent: Notify feedback unclear
                TaskAgent->>PR: Comment asking clarifying questions
            else All approvals & CI pass
                PR-->>TaskAgent: Ready to Merge
                TaskAgent->>PR: Add PR to Merge Queue
                PR->>PrimaryAgent: Notify PR added to Merge Queue
                alt Merge queue succeeds
                    PR-->>LocalMain: Merge queue merges PR automatically
                    par
                        LocalMain->>OriginMain: Rebase local main onto origin main (remove duplicates)
                        OriginMain-->>LocalMain: Local main synced with origin main
                    and
                        PrimaryAgent->>Worktree: Remove merged task worktree
                    end
                    LocalMain->>PrimaryAgent: Notify local main updated
                    PrimaryAgent->>Worktree: Rebase all remaining agent worktrees onto local main
                    PrimaryAgent->>PrimaryAgent: Unblock tasks in dependency tree that depended on this merge
                    PrimaryAgent->>Human: Present updated task dependency tree (if remaining tasks exist)
                else Merge fails with conflicts
                    PR-->>TaskAgent: Notify merge conflicts
                    TaskAgent->>Worktree: Resolve conflicts
                    TaskAgent->>PrimaryAgent: Notify conflict resolution for approval
                    PrimaryAgent->>PrimaryAgent: Open tmux pane "review-conflict-{task}" showing full diff
                    PrimaryAgent->>Human: Present full diff for review
                    alt Human approves
                        Human->>PrimaryAgent: Approval granted
                        PrimaryAgent->>PrimaryAgent: Close tmux pane
                        PrimaryAgent-->>TaskAgent: Approval granted
                        TaskAgent->>PR: Push conflict resolution
                        PR-->>GitHubCI: Trigger CI checks
                        alt CI checks fail
                            GitHubCI-->>PR: Report CI failures
                            PR-->>TaskAgent: Notify CI failures
                            TaskAgent->>PR: Fix issues and push updates (no approval needed)
                            PR-->>GitHubCI: Re-run CI checks
                        else CI checks pass
                            GitHubCI-->>PR: Report CI success
                        end
                    else Human rejects with reason
                        Human->>PrimaryAgent: Rejection with specific reason
                        PrimaryAgent->>PrimaryAgent: Close tmux pane
                        PrimaryAgent-->>TaskAgent: Forward rejection reason as change requests
                        TaskAgent->>Worktree: Apply requested modifications
                        Note over TaskAgent,Worktree: Worktree persists until merge succeeds
                    end
                else Merge fails with unrelated CI errors
                    PR-->>PrimaryAgent: Notify merge failure due to CI errors
                    PrimaryAgent->>Human: Notify merge failure with CI error details
                    Human->>PrimaryAgent: Provide instructions
                    PrimaryAgent-->>TaskAgent: Forward instructions
                    Note over TaskAgent,Worktree: Worktree persists until merge succeeds
                end
            end
        end
    end

    Note over PrimaryAgent,Worktree: Primary Agent ensures all agent worktrees are rebased onto local main after each merge
```

