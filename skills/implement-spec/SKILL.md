---
name: implement-spec
description: "Implement the result of /to-spec and /to-tickets in code."
disable-model-invocation: true
---

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

The goal is the entire spec implemented on a single **integration branch**, with every ticket resolved the way the issue tracker closes work.
History shape is a user-visible decision: main stays **linear by default** (rebase ticket branches, land with fast-forward, merge the PR with `--rebase`). Merge-commit topologies are an explicit opt-in - confirm with the user before building one.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed. Track which tickets have landed on the integration branch yourself (a checklist in your orchestration notes): the tracker's blocked-by counts go stale mid-run, so never compute the frontier from the tracker alone.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

Start every subagent with a fresh context window.

**Implementer subagents** should be run in the background where possible for maximum concurrency.

## Steps

1. Read the spec and tickets to understand the task graph.

2. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

3. Create the integration branch, named `integration/<spec-slug>`, from the repo's main branch. If the issue tracker closes work through PRs, or the user asks for one, open a draft PR after the first merge in step 5 (a branch with no commits ahead of main can't open one), marked as closing the spec and tickets.

4. Use a fresh **implementer subagent** for each ticket, each in its own worktree on its own branch. Name the branch `<type>/<ticket-id>-<short-slug>` following the repo's branch-naming rules, and create it with `--no-track` if it will ever be pushed. Each implementer subagent:
   - confirms its worktree is based on the integration branch before starting, and resets onto it if not;
   - calls the Skill tool with `tdd` to build the ticket;
   - rebases its own branch onto the integration branch tip before reporting done (the worktree branch is local-only, so rebasing it is safe);
   - reports the exact verification command it ran, so the merger can re-run it.

5. Once an **implementer subagent** completes, land its work on the integration branch with a **merger subagent**. Run mergers strictly one at a time - two merger subagents must never integrate concurrently. The merger rebases the ticket branch onto the integration branch if the integration branch has moved, resolves conflicts (sending the ticket back to a fresh implementer when the conflict needs implementation judgment), **re-runs the ticket's verification command**, and only then lands the ticket branch on the integration branch. **Default to linear history**: after the mandatory rebase the ticket tip already sits on the integration tip, so land it with `git merge --ff-only` (no merge commit) and record ticket boundaries in your orchestration notes (ticket -> commit range) instead of in the graph. A merge-commit topology (`git merge --no-ff`, revert-whole via `git revert -m 1`) is an explicit opt-in - use it only when the user asked for it, because it piles merge commits onto main and strands already-published per-ticket PRs. Rebasing first is mandatory, not optional: the landing is then conflict-free, its tree is identical to the verified branch tip, and history stays linear. Never land a branch that has not been rebased onto the tip - a plain `git merge` from an unrebased branch creates divergent history. Worktrees contain only git-tracked files, so anything that depends on gitignored files (fixtures, credentials, native build outputs) is silently skipped there - re-verify such checks in the main checkout.

6. If this changes the **frontier** of tickets, kick off more **implementer subagents** to work on the new tickets. This allows for maximum concurrency.

7. Once all tickets are complete, call the Skill tool with `code-review` on the integration branch. Fix all issues raised by the code review in a single fresh **implementer subagent**, then re-run the code review once. If issues remain after the second review, stop and report to the user instead of looping.

8. Land the work through a PR: push the integration branch and mark the draft PR ready (for repos with a fork → upstream workflow, push the integration branch to the fork and merge the PR keeping main linear - default `gh pr merge <pr> --rebase`; squash or merge-commit only when the user explicitly asks). If the tickets were already implemented and PR'd before this run started, do not stack merge commits on top of them: rebase each ticket branch onto the latest upstream main and land them in order with fast-forward, and tell the user which history shape you are building before you build it. Never push directly to main. If the project has no PR workflow at all, stop and ask the user how to close out. Resolve tickets the way the issue tracker closes work only after the PR is merged.

9. Clean up all **implementer subagent** worktrees and their branches. First list what will be deleted and confirm each branch is merged (`git merge-base --is-ancestor <branch> <integration>`), then `git worktree remove`, `git branch -d` (never `-D` an unmerged branch), and `git worktree prune`. After the integration PR merges, delete the integration branch locally and on the remote.
