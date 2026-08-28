# Axelrod AI Cloud Agent wrapper

Thin repository that gives Cursor Cloud Agents a committed environment on [`zsolt-axelrod/dummy`](https://github.com/zsolt-axelrod/dummy).

Launch a Cloud Agent against this repo (branch `main`) to pick up `.cursor/environment.json`. After checkout, `.cursor/install-axelrod-ai.sh` clones [`Axelrod-AI/core`](https://github.com/Axelrod-AI/core) into `./core` using `GH_TOKEN` (`gh repo clone`, with git HTTPS as fallback).

## Files

- `.cursor/environment.json` — repo-managed Cloud Agent environment (`install` plus `repositoryDependencies`).
- `.cursor/install-axelrod-ai.sh` — idempotent bootstrap. Clones or updates `./core` from `Axelrod-AI/core` (override with `AXELROD_CORE_REPO`). Writes a stamp under `$HOME/.axelrod-ai/` and `.cursor/.axelrod-install-complete`.
- `AGENTS.md` — operating notes for Cloud Agents.
- `core/` — git checkout created at install time; gitignored.

There is no application server, database, or deployable web UI.

## Secrets

Set `GH_TOKEN` (a GitHub PAT that can read `Axelrod-AI/core`) before running install. Do not print the token.

## Run the install script locally

From the repository root:

```bash
export GH_TOKEN  # do not print this
bash .cursor/install-axelrod-ai.sh
```

The script is safe to run more than once. A successful run clones or fast-forwards `./core` and prints:

```text
[install-axelrod-ai] starting install in ...
[install-axelrod-ai] cloning Axelrod-AI/core into ./core
[install-axelrod-ai] core <sha> from Axelrod-AI/core
[install-axelrod-ai] wrote stamp ...
[install-axelrod-ai] install complete
```

## Push updates to GitHub

This wrapper lives on GitHub as `zsolt-axelrod/dummy`. Authenticate with `GH_TOKEN` and push `main`:

```bash
export GH_TOKEN  # do not print this
git push "https://x-access-token:${GH_TOKEN}@github.com/zsolt-axelrod/dummy.git" HEAD:main
```

Or, with GitHub CLI already using `GH_TOKEN`:

```bash
gh auth setup-git
git remote add github https://github.com/zsolt-axelrod/dummy.git  # once
git push -u github main
```
