# stak

Tiny, no-deps CLI to keep a stack of single-commit PR branches in sync.

```
BASE -> b1 -> b2 -> ... -> TOP
```

stak rebases each branch onto its parent (in order) and force-pushes with lease.

## Why

- You already have branches + PRs.
- Each branch is one commit on top of the previous.
- You want a single, fast command that:
  - validates the stack,
  - rebases bottom → top,
  - pushes updates to your remote (so PRs refresh).

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

```bash
stak restack --branches A,B,C,D --base <BASE> --remote origin
```

3) If a conflict occurs, resolve and continue, then rerun the same command:

```bash
git add -A
git rebase --continue
# then
stak sync --top <TOP_BRANCH>
# or
stak restack --branches A,B,C,D --base <BASE>
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
   - `git rebase <parent>`
   - `git push --force-with-lease <remote> HEAD:refs/heads/<branch>`

You can skip auto-detection by providing an explicit branch list via `restack`.

If a rebase conflicts, Git stops; you fix & continue, then rerun `stak sync`.

## Usage

```text
stak sync --top <top-branch>
          [--base <base-branch>] [--remote <name>] [--dry-run]
          [-h|--help]

stak restack --branches <b1,b2,...>
             [--base <base-branch>] [--remote <name>] [--dry-run]
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

Restack when parents were updated and children need to be rebased onto them:

```bash
stak restack --branches A,B,C,D --base main --remote origin
```

Conflict flow:

```bash
stak sync --top feat/audit

# Git stops on conflict
# ... resolve files ...
git add -A
git rebase --continue
# finish the rest of the stack
stak sync --top feat/audit
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

Up to you. stak only rebases/pushes branches; it doesn’t touch PR bases.

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

A full integration test spins up a bare remote, builds a sample stack, and checks rebases, dry-run, and validation errors.

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