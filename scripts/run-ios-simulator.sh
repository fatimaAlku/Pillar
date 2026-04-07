#!/usr/bin/env bash
set -euo pipefail

SIMULATOR_NAME="${1:-iPhone 16 Pro}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/../apps/study_coach" && pwd)"

DEVICE_LINE="$(xcrun simctl list devices available | awk -v name="${SIMULATOR_NAME}" '$0 ~ ("^[[:space:]]*" name " \\(") {print; exit}')"
if [[ -z "${DEVICE_LINE}" ]]; then
  echo "Simulator device not found: ${SIMULATOR_NAME}"
  echo "Run: xcrun simctl list devices available"
  exit 1
fi

UDID="$(echo "${DEVICE_LINE}" | awk -F '[()]' '{print $2}')"

echo "Starting Simulator: ${SIMULATOR_NAME} (${UDID})"
xcrun simctl shutdown all || true
xcrun simctl boot "${UDID}" || true
open -a Simulator --args -CurrentDeviceUDID "${UDID}"

echo "Running Flutter app on ${SIMULATOR_NAME}..."
cd "${APP_DIR}"
flutter run -d "${UDID}"
