#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script "cd '${SCRIPT_DIR}' && ./run_admin.sh" in front window
  delay 0.3
  tell application "System Events" to keystroke "t" using command down
  delay 0.3
  do script "cd '${SCRIPT_DIR}' && ./run_rider_web.sh" in front window
  delay 0.3
  tell application "System Events" to keystroke "t" using command down
  delay 0.3
  do script "cd '${SCRIPT_DIR}' && ./run_driver_web.sh" in front window
end tell
APPLESCRIPT
