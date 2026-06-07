#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

if ! command -v code >/dev/null 2>&1; then
  echo "VS Code 'code' command is not in PATH."
  echo "Open VS Code and run: Shell Command: Install 'code' command in PATH"
  exit 1
fi

ensure_repo
cd "${REPO_ROOT}"

exec code .
