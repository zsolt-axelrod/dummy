# Axelrod AI Cloud Agent wrapper

Thin repository that gives Cursor Cloud Agents a committed environment on [`zsolt-axelrod/dummy`](https://github.com/zsolt-axelrod/dummy).

Launch a Cloud Agent against this repo (branch `main`) to pick up `.cursor/environment.json`. The machine then runs `.cursor/install-axelrod-ai.sh` after checkout.

## Files

- `.cursor/environment.json` — repo-managed Cloud Agent environment (`install` only).
- `.cursor/install-axelrod-ai.sh` — idempotent bootstrap. Writes a stamp under `$HOME/.axelrod-ai/` and `.cursor/.axelrod-install-complete`.
- `AGENTS.md` — operating notes for Cloud Agents.

There is no application server, database, or deployable web UI.

## Run the install script locally

From the repository root:

```bash
bash .cursor/install-axelrod-ai.sh
```

The script is safe to run more than once. Success looks like:

```text
[install-axelrod-ai] starting install in ...
[install-axelrod-ai] wrote stamp ...
[install-axelrod-ai] install complete
```

## Push updates to GitHub

This wrapper lives on GitHub as `zsolt-axelrod/dummy`. Authenticate with `GH_TOKEN` (a GitHub PAT) and push `main`:

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
