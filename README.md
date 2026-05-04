# Rico's Hermes Fork — Curated Stable Mirror

**Fork of:** [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)  
**Owner:** Rico (Fengzhuoyang) Zhu — `RicoZhu@ricozhu.com`  
**Purpose:** A stable, company-curated distribution of Hermes Agent for internal deployment.

---

## What This Fork Is

This repository is a **curated, stable buffer** between the fast-moving upstream Hermes Agent project and your internal users. The upstream repository receives frequent updates — some stable, some experimental. This fork ensures that **only changes you have personally reviewed and approved** reach your users.

### Key Principle

> Your users run `hermes update` and receive changes from **this fork only**. They never pull directly from the upstream repository. You are the gatekeeper.

---

## Repository Setup

### Remotes

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `git@github.com:Rico0319/hermes-rico.git` | Your fork — what users install from |
| `upstream` | `https://github.com/NousResearch/hermes-agent.git` | Original repo — you review from here |

### One-Liner Install (for your users)

```bash
curl -fsSL https://raw.githubusercontent.com/Rico0319/hermes-rico/main/scripts/install.sh | bash
```

### One-Liner Install (with options)

```bash
# Skip the interactive setup wizard (good for demos)
curl -fsSL ... | bash -s -- --skip-setup

# Install a specific branch
curl -fsSL ... | bash -s -- --branch stable

# Install to a custom directory
curl -fsSL ... | bash -s -- --dir ~/hermes-custom
```

---

## Your Workflow as Fork Owner

### Daily / Weekly: Check for Upstream Updates

```bash
cd ~/hermes-rico                    # your local clone
./scripts/check-upstream.sh         # see what's new
```

This shows you:
- How many commits upstream is ahead of your fork
- A summary of what changed
- Options to preview diffs, read detailed logs, or start a merge

### When You Find a Good Update: Merge & Push

```bash
# 1. Review what's new
./scripts/check-upstream.sh --diff

# 2. Start the interactive merge workflow
./scripts/check-upstream.sh --merge
```

The merge workflow will:
1. Show you the commits to be merged
2. Ask for confirmation
3. Merge upstream into your `main`
4. Prompt you to test before pushing
5. Push to `origin` (your fork) when you're ready

### Manual Merge (if you prefer)

```bash
cd ~/hermes-rico
git fetch upstream

# See what's new
git log --oneline main..upstream/main

# Merge
git checkout main
git merge upstream/main --no-ff -m "Merge upstream: [description]"

# Test locally
source .venv/bin/activate
python -m pytest tests/ -q

# Push to your fork — this is what users receive
git push origin main
```

### Cherry-Picking a Single Fix

If upstream has one specific fix you want, without taking everything:

```bash
cd ~/hermes-rico
git fetch upstream
git checkout main
git cherry-pick abc1234   # specific upstream commit hash
git push origin main
```

---

## What Your Users Experience

### Installation

Your boss or team member runs the one-liner. It:

1. Downloads the install script from **your fork**
2. Clones **your fork** into `~/.hermes/hermes-agent`
3. Installs dependencies, creates venv, links the `hermes` command
4. Runs the setup wizard (unless `--skip-setup`)

### Updating

When you push an update to your fork, users get it by running:

```bash
hermes update
```

Or re-running the install script.

Under the hood, `hermes update` does:

```bash
cd ~/.hermes/hermes-agent
git fetch origin              # checks YOUR fork, not upstream
git pull --ff-only origin main
```

**Your users never see upstream directly.** They only receive what you've pushed to your fork.

---

## Update Policy

### What to Merge

- Security patches
- Bug fixes affecting features you use
- Stable new features you've tested
- Documentation improvements

### What to Skip

- Experimental or "beta" features
- Large architectural refactors (unless you've tested thoroughly)
- Updates that break your custom configurations
- Commits with failing CI/tests upstream

### Merge Commit Message Convention

```
Merge upstream: sync <short-hash> into fork

- Security fix for tool execution sandbox
- New feature: web search skill improvements
- Tested locally: pytest passes, manual CLI check OK
```

---

## File Reference

| File | Purpose |
|------|---------|
| `scripts/install.sh` | The one-liner install script your users run. Points to this fork. |
| `scripts/check-upstream.sh` | Your personal tool to review upstream changes. |
| `README.md` | This file. |

---

## Important Notes

### Your Fork Must Stay Public (or users need SSH keys)

The one-liner uses `git clone` over HTTPS. If you make this fork private, the install script will fail unless your users have SSH keys configured for GitHub.

If you need a private fork:
- Option A: Host an internal GitLab/Bitbucket mirror
- Option B: Distribute the install script internally, pointing to a private repo with SSH
- Option C: Build a tarball release and distribute that instead of `git clone`

### Pinning Dependencies

The upstream `pyproject.toml` or `requirements.txt` may have loose version constraints. If you want stricter stability:

1. Generate a lockfile after a known-good install:
   ```bash
   cd ~/.hermes/hermes-agent
   source .venv/bin/activate
   pip freeze > requirements-lock.txt
   ```

2. Commit the lockfile to your fork

3. Modify the install script to install from the lockfile instead of `[all]`

### Testing Before Pushing

Always test merged upstream changes before pushing to your fork:

```bash
cd ~/hermes-rico
source .venv/bin/activate
python -m pytest tests/ -q          # quick smoke test
hermes --version                    # CLI loads
hermes --tui                        # TUI loads (smoke test)
```

If tests fail, **do not push**. Fix or skip that upstream update.

---

## Quick Command Cheat Sheet

| Task | Command |
|------|---------|
| Check upstream status | `./scripts/check-upstream.sh` |
| Preview upstream diff | `./scripts/check-upstream.sh --diff` |
| Detailed upstream log | `./scripts/check-upstream.sh --log` |
| Interactive merge | `./scripts/check-upstream.sh --merge` |
| Manual fetch upstream | `git fetch upstream` |
| See upstream commits | `git log --oneline main..upstream/main` |
| Merge upstream | `git merge upstream/main --no-ff` |
| Cherry-pick one commit | `git cherry-pick <hash>` |
| Push to your fork | `git push origin main` |
| Check fork status | `git status && git log --oneline -3` |

---

## Contact

**Rico (Fengzhuoyang) Zhu**  
Email: `RicoZhu@ricozhu.com`  
GitHub: [@Rico0319](https://github.com/Rico0319)

---

*Last updated: 2025-05-04*
