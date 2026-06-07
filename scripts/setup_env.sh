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

resolve_python_bin() {
  local pyenv_version=""

  if command -v pyenv >/dev/null 2>&1; then
    pyenv_version="$(pyenv versions --bare 2>/dev/null | awk '/^3\.11\./ { print; exit }')"
    if [[ -n "${pyenv_version}" ]]; then
      local pyenv_python="$(pyenv root)/versions/${pyenv_version}/bin/python3.11"
      if [[ -x "${pyenv_python}" ]]; then
        printf "%s" "${pyenv_python}"
        return 0
      fi
    fi
  fi

  for candidate in python3.11 python3.12 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf "%s" "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_repo

cd "${REPO_ROOT}"

PYTHON_BIN="$(resolve_python_bin || true)"

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "Could not find python3. Install Python first."
  exit 1
fi

if [[ ! -d "${VENV_PATH}" ]]; then
  echo "Creating virtual environment at ${VENV_PATH} with ${PYTHON_BIN}..."
  "${PYTHON_BIN}" -m venv "${VENV_PATH}"
fi

# shellcheck disable=SC1091
source "${VENV_PATH}/bin/activate"

python -m pip install --upgrade pip setuptools wheel

cd "${REPO_ROOT}"

if [[ -f requirements.txt ]]; then
  echo "Installing root requirements.txt..."
  pip install -r requirements.txt
fi

if [[ -f AdminWebpage/requirements.txt ]]; then
  echo "Installing AdminWebpage requirements..."
  pip install -r AdminWebpage/requirements.txt
fi

if [[ -f AdminWebpage/requirements-dev.txt ]]; then
  echo "Installing AdminWebpage dev requirements..."
  pip install -r AdminWebpage/requirements-dev.txt
fi

if command -v flutter >/dev/null 2>&1; then
  if [[ -d ridermobile ]]; then
    echo "Running flutter pub get for ridermobile..."
    (cd ridermobile && flutter pub get)
  fi
  if [[ -d drivermobile ]]; then
    echo "Running flutter pub get for drivermobile..."
    (cd drivermobile && flutter pub get)
  fi
else
  echo "Flutter not found in PATH. Skipping flutter pub get."
fi

if command -v pod >/dev/null 2>&1; then
  if [[ -d ridermobile/ios ]]; then
    echo "Running pod install for ridermobile..."
    (cd ridermobile/ios && pod install)
  fi
  if [[ -d drivermobile/ios ]]; then
    echo "Running pod install for drivermobile..."
    (cd drivermobile/ios && pod install)
  fi
else
  echo "CocoaPods not found in PATH. Skipping pod install."
fi

echo
echo "Setup complete."
echo "Virtual environment location: ${VENV_PATH}"
echo "Activate it anytime with:"
echo "  source \"${VENV_PATH}/bin/activate\""
