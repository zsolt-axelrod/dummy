#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Axelrod AI wrapper repo.
# Cursor runs this from the repository root during environment install / builds.
#
# Always clones (or fast-forwards) Axelrod-AI/core into ./core using GH_TOKEN.
# Do not use `gh repo clone`: Cloud Agent VMs authenticate git as the generated
# `cursor` GitHub App identity, which cannot see Axelrod-AI/core when the
# launching user is only a collaborator (not an org admin).
set -euo pipefail
set +x

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Do not enable tracing: GH_TOKEN must never appear in logs.
unset GIT_TRACE GIT_TRACE_PACKET GIT_TRACE_PERFORMANCE GIT_CURL_VERBOSE \
  GIT_TRACE2 GIT_TRACE2_EVENT GIT_TRACE2_PERF 2>/dev/null || true

STAMP_DIR="${HOME:-/tmp}/.axelrod-ai"
STAMP_FILE="${STAMP_DIR}/install.stamp"
MARKER="${ROOT}/.cursor/.axelrod-install-complete"
HELPER="${STAMP_DIR}/git-credential-gh-token"
CORE_DIR="${ROOT}/core"
CORE_REPO="${AXELROD_CORE_REPO:-Axelrod-AI/core}"
CORE_URL="https://github.com/${CORE_REPO}.git"
CORE_URL_NO_GIT="https://github.com/${CORE_REPO}"

mkdir -p "$STAMP_DIR"

log() {
  printf '[install-axelrod-ai] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required command: $1"
    exit 1
  fi
}

require_token() {
  if [[ -z "${GH_TOKEN:-}" ]]; then
    log "GH_TOKEN is not set; cannot clone ${CORE_REPO}"
    exit 1
  fi
}

# Authenticate git HTTPS with GH_TOKEN without putting the token on argv or in remotes.
write_askpass() {
  local path="$1"
  cat >"$path" <<'ASKPASS'
#!/usr/bin/env bash
case "${1:-}" in
  *[Uu]sername*) printf '%s\n' "x-access-token" ;;
  *) printf '%s\n' "${GH_TOKEN}" ;;
esac
ASKPASS
  chmod 700 "$path"
}

# Persist a git credential helper so later `git -C core` uses GH_TOKEN too.
write_credential_helper() {
  cat >"$HELPER" <<'HELPER'
#!/usr/bin/env bash
set +x
case "${1:-}" in
  get)
    if [[ -z "${GH_TOKEN:-}" ]]; then
      exit 1
    fi
    printf 'username=%s\n' "x-access-token"
    printf 'password=%s\n' "${GH_TOKEN}"
    ;;
  store|erase)
    ;;
esac
HELPER
  chmod 700 "$HELPER"
}

# Run git against GitHub using only GH_TOKEN.
# Isolates the process from Cloud Agent global url.insteadOf rewrites and
# credential helpers, which embed the `cursor` app token for github.com.
git_github() {
  local askpass empty_cfg rc=0
  askpass="$(mktemp)"
  empty_cfg="$(mktemp)"
  write_askpass "$askpass"
  : >"$empty_cfg"
  set +x
  GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS="$askpass" \
    GIT_USERNAME="x-access-token" \
    GIT_CONFIG_GLOBAL="$empty_cfg" \
    GIT_CONFIG_SYSTEM="$empty_cfg" \
    GIT_CONFIG_NOSYSTEM=1 \
    git -c credential.helper= -c 'credential.https://github.com.helper=' "$@" || rc=$?
  rm -f "$askpass" "$empty_cfg"
  return "$rc"
}

# Cursor's configure-git writes a short github.com/ insteadOf that injects the
# generated app token. A longer no-op insteadOf on ./core wins for this repo
# so later git commands use GH_TOKEN via the local credential helper.
configure_core_local_git() {
  write_credential_helper

  git -C "$CORE_DIR" remote set-url origin "$CORE_URL"

  git -C "$CORE_DIR" config --local --unset-all "url.${CORE_URL}.insteadof" 2>/dev/null || true
  git -C "$CORE_DIR" config --local --unset-all "url.${CORE_URL_NO_GIT}.insteadof" 2>/dev/null || true
  git -C "$CORE_DIR" config --local "url.${CORE_URL}.insteadof" "$CORE_URL"
  git -C "$CORE_DIR" config --local "url.${CORE_URL_NO_GIT}.insteadof" "$CORE_URL_NO_GIT"

  git -C "$CORE_DIR" config --local --unset-all credential.helper 2>/dev/null || true
  git -C "$CORE_DIR" config --local credential.helper ""
  git -C "$CORE_DIR" config --local --add credential.helper "$HELPER"
}

clone_core() {
  log "cloning ${CORE_REPO} into ./core with GH_TOKEN"
  git_github clone "$CORE_URL" "$CORE_DIR"
}

update_core() {
  log "updating ./core from ${CORE_REPO} with GH_TOKEN"
  git -C "$CORE_DIR" remote set-url origin "$CORE_URL"
  git_github -C "$CORE_DIR" fetch --prune origin
  git_github -C "$CORE_DIR" remote set-head origin -a >/dev/null 2>&1 || true
  local branch
  branch="$(git -C "$CORE_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  branch="${branch#origin/}"
  if [[ -z "$branch" ]]; then
    branch="main"
  fi
  git_github -C "$CORE_DIR" checkout -B "$branch" "origin/${branch}"
}

clone_or_update_core() {
  require_token

  if [[ -d "${CORE_DIR}/.git" ]]; then
    update_core
  elif [[ -e "$CORE_DIR" ]]; then
    log "./core exists but is not a git clone; refusing to overwrite"
    exit 1
  else
    clone_core
  fi

  if [[ ! -d "${CORE_DIR}/.git" ]]; then
    log "clone failed: ${CORE_DIR} is not a git checkout"
    exit 1
  fi

  configure_core_local_git
  log "core $(git -C "$CORE_DIR" rev-parse --short HEAD) from ${CORE_REPO}"
}

log "starting install in ${ROOT}"

require_cmd bash
require_cmd git
require_cmd mktemp

clone_or_update_core

{
  echo "axelrod-ai-cloud-agent-wrapper"
  echo "installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "hostname=$(hostname 2>/dev/null || echo unknown)"
  echo "user=$(id -un 2>/dev/null || echo unknown)"
  echo "pwd=${ROOT}"
  echo "core_repo=${CORE_REPO}"
  echo "core_head=$(git -C "$CORE_DIR" rev-parse HEAD)"
  echo "git=$(git --version 2>/dev/null || echo missing)"
  echo "bash=${BASH_VERSION}"
  command -v python3 >/dev/null 2>&1 && python3 --version
  command -v node >/dev/null 2>&1 && node --version
  command -v npm >/dev/null 2>&1 && npm --version
} >"$STAMP_FILE"

cp "$STAMP_FILE" "$MARKER"

log "wrote stamp ${STAMP_FILE}"
log "install complete"
