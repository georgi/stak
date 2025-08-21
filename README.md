# stak

Tiny, no-deps CLI to keep a stack of single-commit PR branches in sync.

```
BASE -> b1 -> b2 -> ... -> TOP
```

stak cherry-picks each branch's single commit onto its parent (in order) and force-pushes with lease.

## Why

- You already have branches + PRs.
- Each branch is one commit on top of the previous.
- You want a single, fast command that:
  - validates the stack,
  - cherry-picks bottom → top,
  - pushes updates to your remote (so PRs refresh).

## How it works

At a high level, stak keeps a chain of single-commit feature branches rebased onto each other by recreating each tip with a cherry-pick:

- Stack model: `BASE -> b1 -> b2 -> ... -> TOP`, where each `bN` is exactly one commit on top of its parent.
- Auto-detection: given `--top`, stak walks parent commits from `TOP` downward until it reaches a commit contained in `BASE`. It maps commit tips to branch names across local and remote heads to reconstruct the chain bottom→top.
- Validation: before changing anything, stak checks that every link has exactly one commit ahead using `git rev-list --count parent..child`.
- Sync algorithm (bottom→top): for each branch `b` with parent `p`:
  - `git checkout b`
  - if `parent_of_tip(b) == tip(p)`, skip (already up-to-date)
  - `git reset --hard p`
  - `git cherry-pick <original tip of b>` (recreates `b` on top of `p`)
  - `git push --force-with-lease origin HEAD:refs/heads/b`
- Conflicts & resume: if a cherry-pick stops, stak writes progress to `.git/stak-state` and exits with instructions. `stak continue` runs `git cherry-pick --continue` (or `git rebase --continue` if applicable) and proceeds with the remaining branches.
- Safety: requires a clean worktree, prints `--dry-run` plans without changing anything, and always uses `--force-with-lease`.
- Scope: stak moves branches only. It does not open PRs or change their metadata.

## Install

```bash
# put stak on your PATH (example)
curl -fsSL https://raw.githubusercontent.com/georgi/stak/refs/heads/main/stak > /usr/local/bin/stak
chmod +x /usr/local/bin/stak
```

### Requirements

- bash ≥ 4
- git ≥ 2.20

## Quick start

Auto-detect the stack from the top branch:

```bash
stak sync --top feat/audit
```

Be verbose without doing anything:

```bash
stak sync --top feat/audit --dry-run
```

## Resume after conflicts

### Conflicts and `stak continue`

If a cherry-pick stops due to conflicts, stak records progress in `.git/stak-state`, prints next steps, and exits. Resolve files, stage changes, then run:

```bash
git add -A
stak continue
```

`stak continue` executes `git cherry-pick --continue` (falls back to `git rebase --continue` if applicable), pushes the resolved branch with `--force-with-lease`, and proceeds with the remaining branches in the stack. Repeat if further conflicts appear.

### Saved stack state

After a successful `sync`/`restack`, stak writes the stack information to `.git/stak-state` (base, remote, ordered branches). On the next run, you can omit `--top` and stak will reuse the saved stack:

```bash
# once:
stak sync --top feat/audit

# later, no need to pass --top:
stak sync
```

Notes:
- Passing `--top/--base/--remote` overrides saved values.
- The state file also stores progress during conflicts; `stak continue` uses it to resume.

## Normal workflow

After you change a file on any branch in the stack:

1) Amend the branch's single commit (keep one-commit invariant):

```bash
git add -A
git commit --amend --no-edit
```

2) Update the whole stack on the remote so PRs refresh:

- If auto-detection can walk the chain from the top:

```bash
stak sync --top <TOP_BRANCH>
```

- If you already pushed updated parents (e.g., A and B) and need to rebase children (C, D) onto them, explicitly restack:
  
  # Note: with cherry-pick semantics this is still called "restack"

```bash
stak restack --branches A,B,C,D --base <BASE> --remote origin
```

3) If a conflict occurs, resolve and continue with `stak continue`:

```bash
git add -A
stak continue
```

## Terms

- Remote: your Git host remote (default: origin).
- Base: branch the stack sits on (auto: remote HEAD, else main|trunk|master|develop).
- Stack: ordered branches; each child is exactly one commit on top of its parent.
- Top: highest branch in the stack.

## What stak does

1. Ensures a clean working tree.
2. Resolves remote and base.
3. Determines the stack by walking parents from the top branch until reaching base history.
4. Validates the single-commit rule at every link.
5. For each branch (bottom → top):
   - `git checkout <branch>`
   - `git reset --hard <parent>`
   - `git cherry-pick <branch@{tip}>`
   - `git push --force-with-lease <remote> HEAD:refs/heads/<branch>`

On conflicts, stak saves state and instructs you to run `stak continue` after resolving.

You can skip auto-detection by providing an explicit branch list via `restack`.

If a cherry-pick conflicts, Git stops; you fix & continue, then rerun `stak sync`.

## Usage

```text
stak sync --top <top-branch>
          [--base <base-branch>] [--remote <name>] [--dry-run]
          [-h|--help]

stak restack --branches <b1,b2,...>
             [--base <base-branch>] [--remote <name>] [--dry-run]
             [-h|--help]

stak continue
  [-h|--help]
```

### Options

- `--top <branch>`: auto-detect chain by walking parents from `<branch>`.
- `--base <branch>`: override base branch.
- `--remote <name>`: remote name (default: `origin`).
- `--dry-run`: print actions; make no changes.
- `--branches <csv>`: for `restack`, explicit chain in bottom→top order (e.g., `A,B,C,D`).
- `-h|--help`: show help.

### Exit codes

- 0: success
- ≠0: error (dirty tree, validation failed, etc.)

## Assumptions (read this)

- Each stack branch is exactly one commit on top of its parent.
- History is linear between links (no merge commits at the tip).
- Branches exist locally or on the remote.
- You can force-push with lease to the remote.
- stak does not create PRs or change PR metadata; your host updates PRs when branches move.

## Examples

Auto-detect chain from the top branch:

```bash
stak sync --top feat/audit --remote origin
```

Dry run before doing it live:

```bash
stak sync --top feat/audit --dry-run
```

Restack when parents were updated and children need to be restacked onto them:

```bash
stak restack --branches A,B,C,D --base main --remote origin
```

Conflict flow:

```bash
stak sync --top feat/audit

# Git stops on conflict
# ... resolve files ...
git add -A
stak continue
```

## Safety

- Uses `--force-with-lease` (won’t clobber unexpected remote changes).
- Refuses to run with a dirty worktree.
- Stops on conflicts; you stay in control.

## FAQ

**Does it open PRs?**

No. It moves branches. Your PR UI updates automatically.

**Can a branch have multiple commits?**

No. stak enforces exactly one. Split your change or squash locally.

**Can PRs target their parent branch instead of main?**

Up to you. stak only moves/pushes branches; it doesn’t touch PR bases.

**Multiple remotes?**

Use `--remote`. Default is `origin`.

**Windows?**

Use Git Bash or WSL.

## Troubleshooting

- “Working tree not clean” — Commit or stash before running.
- “Could not determine base branch” — Pass `--base <branch>` or set the remote HEAD.
- Auto-detect can’t find the next branch — Ensure each child’s parent commit equals its parent branch’s tip, and that branch exists (locally or remote).
- Validation failed: not exactly one commit — Inspect with:

```bash
git rev-list --count parent..child
```

## Testing

A full integration test spins up a bare remote, builds a sample stack, and checks cherry-pick syncs, dry-run, and validation errors.

```bash
./test
```

## Design choices

- No metadata: only Git topology.
- Predictable defaults: remote HEAD → base branch.
- Fast failure: strict validation before rewriting history.
- Small surface: two subcommands (`sync`, `restack`) with a few flags.


## License

Public Domain / CC0. Use at your own risk.