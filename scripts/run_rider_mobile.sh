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

MODE="${1:-ios-simulator}"
TARGET_DEVICE="${2:-}"
BUILD_MODE="${3:-debug}"

ensure_repo
ensure_venv
cd "${REPO_ROOT}/ridermobile"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not in PATH."
  exit 1
fi

case "$MODE" in
  ios-simulator|ios-sim|simulator|ios)
    HOST_VALUE="127.0.0.1"
    ;;
  iphone|ios-device|ios-phone|ipad)
    HOST_VALUE="$(find_lan_ip)"
    ;;
  android-emulator|android-sim|emulator|avd)
    HOST_VALUE="10.0.2.2"
    ;;
  samsung|android-phone|android-device|galaxy|phone|device)
    HOST_VALUE="$(find_lan_ip)"
    ;;
  *)
    HOST_VALUE="$MODE"
    ;;
esac

case "$BUILD_MODE" in
  debug)
    FLUTTER_BUILD_FLAG=""
    ;;
  profile)
    FLUTTER_BUILD_FLAG="--profile"
    ;;
  release)
    FLUTTER_BUILD_FLAG="--release"
    ;;
  *)
    echo "Invalid build mode: $BUILD_MODE"
    echo "Use one of: debug, profile, release"
    exit 1
    ;;
esac

printf 'API_HOST=%s\n' "$HOST_VALUE" > device.env
echo "Wrote $(pwd)/device.env with API_HOST=$HOST_VALUE"
echo "Running Flutter in $BUILD_MODE mode"

flutter pub get

if [[ -d ios ]] && command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
fi

if [[ -n "$TARGET_DEVICE" ]]; then
  exec flutter run $FLUTTER_BUILD_FLAG -d "$TARGET_DEVICE" --dart-define-from-file=device.env
else
  exec flutter run $FLUTTER_BUILD_FLAG --dart-define-from-file=device.env
fi
