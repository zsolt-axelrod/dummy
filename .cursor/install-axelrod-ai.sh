#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Axelrod AI wrapper repo.
# Cursor runs this from the repository root during environment install / builds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STAMP_DIR="${HOME:-/tmp}/.axelrod-ai"
STAMP_FILE="${STAMP_DIR}/install.stamp"
MARKER="${ROOT}/.cursor/.axelrod-install-complete"

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

log "starting install in ${ROOT}"

require_cmd bash
require_cmd git

# Record a stable toolchain snapshot so later agents can confirm bootstrap ran.
{
  echo "axelrod-ai-cloud-agent-wrapper"
  echo "installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "hostname=$(hostname 2>/dev/null || echo unknown)"
  echo "user=$(id -un 2>/dev/null || echo unknown)"
  echo "pwd=${ROOT}"
  echo "git=$(git --version 2>/dev/null || echo missing)"
  echo "bash=${BASH_VERSION}"
  command -v python3 >/dev/null 2>&1 && python3 --version
  command -v node >/dev/null 2>&1 && node --version
  command -v npm >/dev/null 2>&1 && npm --version
} >"$STAMP_FILE"

cp "$STAMP_FILE" "$MARKER"

log "wrote stamp ${STAMP_FILE}"
log "install complete"

# Re-running must stay a no-op success.
if [[ -f "$STAMP_FILE" && -f "$MARKER" ]]; then
  exit 0
fi
