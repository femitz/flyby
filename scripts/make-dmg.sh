#!/bin/zsh

# Builds dist/Flyby-macos-arm64.dmg: a disk image that opens with Flyby.app next to an
# Applications shortcut, so installing is just "drag the app onto Applications".
# Expects dist/Flyby.app to exist (run ./scripts/package-app.sh first).

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="Flyby"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-macos-arm64.dmg"
STAGING_DIR=$(mktemp -d)

trap 'rm -rf "${STAGING_DIR}"' EXIT

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "${APP_BUNDLE} not found. Run ./scripts/package-app.sh first."
  exit 1
fi

echo "Creating ${DMG_PATH}..."
# ditto preserves the code signature and bundle metadata.
ditto "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "${DMG_PATH}"

echo "Created ${DMG_PATH}"
