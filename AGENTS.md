# AGENTS.md

This repository is a Cursor Cloud Agent wrapper for Axelrod AI. It does not contain application source. Launch Cloud Agents against `zsolt-axelrod/dummy` so they boot with the committed environment instead of an empty machine.

## Layout

| Path | Role |
| --- | --- |
| `.cursor/environment.json` | Repo-managed Cloud Agent environment. Highest precedence over personal or team dashboard environments. |
| `.cursor/install-axelrod-ai.sh` | Idempotent install script. Clones `Axelrod-AI/core` into `./core` with `gh repo clone` using `GH_TOKEN`. |
| `core/` | Checkout of `Axelrod-AI/core` created at install time. Do not commit it. |
| `README.md` | Human setup and local-run notes. |

Do not add application code here unless the task is to extend the wrapper itself. Work in `./core` after install.

## Cursor Cloud specific instructions

- The environment is repository-managed. Do not create a competing dashboard environment for this repo.
- `install` is `bash .cursor/install-axelrod-ai.sh`. It must stay non-interactive, terminate, and succeed when run twice.
- The default clone source is `Axelrod-AI/core`. Override with `AXELROD_CORE_REPO` only when a task says to.
- `GH_TOKEN` must be present as an environment secret. Use it for git HTTPS. Never print, log, or commit the token. Never put it in a remote URL.
- There is no `start` command and no `terminals` entry. Do not start a dummy web server.
- After boot, confirm bootstrap by reading `.cursor/.axelrod-install-complete` or `$HOME/.axelrod-ai/install.stamp`, and by checking that `./core` is a git checkout.
- Put durable toolchain work in the install script. Put task-specific commands in this file, not in `install`.
- Do not commit secrets. Use Cloud Agent environment secrets if credentials are required later.
- Default branch is `main`. Keep wrapper changes on `main` unless a task asks for a branch.

## Working rules

1. Treat this repo as configuration, not a product. Application work belongs in `./core`.
2. Keep `environment.json` valid against the public schema. Do not add a `$schema` field.
3. After editing the install script, run `bash .cursor/install-axelrod-ai.sh` twice and confirm both exits are 0.
4. When pushing to GitHub, use `GH_TOKEN` for `zsolt-axelrod/dummy`. Never print the token.
