#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="Flyby"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
PRODUCT_PATH="${ROOT_DIR}/.build/${BUILD_CONFIGURATION}/${APP_NAME}"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_SOURCE="${ROOT_DIR}/Resources/App/Info.plist"
INFO_PLIST_DEST="${CONTENTS_DIR}/Info.plist"
ICON_SOURCE="${ROOT_DIR}/Resources/App/${APP_NAME}.icns"

echo "Building ${APP_NAME} (${BUILD_CONFIGURATION})..."
swift build -c "${BUILD_CONFIGURATION}"

if [[ ! -x "${PRODUCT_PATH}" ]]; then
  echo "Expected built executable at ${PRODUCT_PATH}, but it was not found."
  exit 1
fi

echo "Creating app bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${PRODUCT_PATH}" "${MACOS_DIR}/${APP_NAME}"
cp "${INFO_PLIST_SOURCE}" "${INFO_PLIST_DEST}"

if [[ -f "${ICON_SOURCE}" ]]; then
  cp "${ICON_SOURCE}" "${RESOURCES_DIR}/${APP_NAME}.icns"
fi

chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "Created ${APP_BUNDLE}"
