#!/bin/zsh

# Builds dist/Flyby-macos-arm64.dmg: a styled disk image that opens with the Flyby background art,
# Flyby.app on the left and an Applications shortcut on the right ("drag to install").
# Expects dist/Flyby.app and the built binary (run ./scripts/package-app.sh first).
#
# Styling uses dmgbuild (pip install dmgbuild), which writes the Finder layout directly instead of
# scripting Finder, so it works headless in CI. Without dmgbuild this falls back to a plain DMG.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="Flyby"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
BINARY="${ROOT_DIR}/.build/${BUILD_CONFIGURATION}/${APP_NAME}"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-macos-arm64.dmg"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "${WORK_DIR}"' EXIT

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "${APP_BUNDLE} not found. Run ./scripts/package-app.sh first."
  exit 1
fi

rm -f "${DMG_PATH}"

if command -v dmgbuild >/dev/null 2>&1 && [[ -x "${BINARY}" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")
  MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "${INFO_PLIST}")
  MIN_OS=${MIN_OS%.0}   # "13.0" -> "13"

  echo "Rendering installer background (v${VERSION}, macOS ${MIN_OS}+)..."
  "${BINARY}" --export-dmg-background "${WORK_DIR}/bg" "${VERSION}" "${MIN_OS}"

  echo "Creating ${DMG_PATH}..."
  VOLUME_ICON_ARGS=()
  if [[ -f "${ROOT_DIR}/Resources/App/${APP_NAME}.icns" ]]; then
    VOLUME_ICON_ARGS=(-D "volume_icon=${ROOT_DIR}/Resources/App/${APP_NAME}.icns")
  fi
  dmgbuild \
    -s "${ROOT_DIR}/scripts/dmg-settings.py" \
    -D "app=${APP_BUNDLE}" \
    -D "background=${WORK_DIR}/bg/background.png" \
    "${VOLUME_ICON_ARGS[@]}" \
    "${APP_NAME}" "${DMG_PATH}"
else
  echo "dmgbuild not found (pip install dmgbuild): creating a plain DMG without the installer artwork."
  STAGING_DIR="${WORK_DIR}/staging"
  mkdir -p "${STAGING_DIR}"
  # ditto preserves the code signature and bundle metadata.
  ditto "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
  ln -s /Applications "${STAGING_DIR}/Applications"
  hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -fs HFS+ -format UDZO -ov "${DMG_PATH}"
fi

echo "Created ${DMG_PATH}"
