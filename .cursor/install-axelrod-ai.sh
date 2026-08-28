#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Axelrod AI wrapper repo.
# Cursor runs this from the repository root during environment install / builds.
#
# Always clones (or fast-forwards) Axelrod-AI/core into ./core.
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
CORE_DIR="${ROOT}/core"
CORE_REPO="${AXELROD_CORE_REPO:-Axelrod-AI/core}"
CORE_URL="https://github.com/${CORE_REPO}.git"

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

git_github() {
  local askpass rc=0
  askpass="$(mktemp)"
  write_askpass "$askpass"
  set +x
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS="$askpass" GIT_USERNAME="x-access-token" \
    git -c credential.helper= "$@" || rc=$?
  rm -f "$askpass"
  return "$rc"
}

# Prefer `gh` (uses GH_TOKEN from the environment). Fall back to git + ASKPASS.
clone_core() {
  log "cloning ${CORE_REPO} into ./core"
  if command -v gh >/dev/null 2>&1; then
    GH_TOKEN="${GH_TOKEN}" gh repo clone "${CORE_REPO}" "${CORE_DIR}"
  else
    git_github clone "$CORE_URL" "$CORE_DIR"
  fi
}

update_core() {
  log "updating ./core from ${CORE_REPO}"
  git -C "$CORE_DIR" remote set-url origin "$CORE_URL"
  if command -v gh >/dev/null 2>&1; then
    gh repo sync "${CORE_DIR}"
  else
    git_github -C "$CORE_DIR" fetch --prune origin
    git_github -C "$CORE_DIR" remote set-head origin -a >/dev/null
    local branch
    branch="$(git -C "$CORE_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    branch="${branch#origin/}"
    if [[ -z "$branch" ]]; then
      branch="main"
    fi
    git_github -C "$CORE_DIR" checkout -B "$branch" "origin/${branch}"
  fi
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

  # Ensure the stored remote never contains credentials.
  git -C "$CORE_DIR" remote set-url origin "$CORE_URL"
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
