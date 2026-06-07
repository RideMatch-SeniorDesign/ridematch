#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_PATH="${REPO_ROOT}/.venv"

ensure_repo() {
  if [[ ! -d "${REPO_ROOT}/AdminWebpage" || ! -d "${REPO_ROOT}/RiderWebpage" || ! -d "${REPO_ROOT}/DriverWebpage" ]]; then
    echo "Could not find repo at: ${REPO_ROOT}"
    echo "Expected layout:"
    echo "  ridematch/"
    echo "  ├── scripts/"
    echo "  ├── AdminWebpage/"
    echo "  ├── RiderWebpage/"
    echo "  └── DriverWebpage/"
    exit 1
  fi
}

ensure_venv() {
  if [[ ! -d "${VENV_PATH}" ]]; then
    echo "No virtual environment found at ${VENV_PATH}"
    echo "Run ./scripts/setup_env.sh first."
    exit 1
  fi
  # shellcheck disable=SC1091
  source "${VENV_PATH}/bin/activate"
}

find_lan_ip() {
  local ip=""
  ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
  if [[ -z "$ip" ]]; then
    ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "$ip" ]]; then
    echo "Could not find a LAN IP on en0 or en1." >&2
    exit 1
  fi
  printf "%s" "$ip"
}

ensure_repo
ensure_venv
cd "${REPO_ROOT}"
exec python RiderWebpage/app.py
