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

# Apple Silicon refuses to run unsigned bundles ("is damaged and can't be opened").
#
# A local self-signed identity (default name "Flyby Local", override with
# FLYBY_SIGN_IDENTITY) is used when it is in the keychain: its signature keeps the
# same identity across builds, so the Accessibility grant survives rebuilds.
# Without it (CI, other machines) the bundle is ad-hoc signed, whose identity is
# the build hash, so every build is a new app to macOS privacy settings.
# Neither is a Developer ID signature, so Gatekeeper still asks for a one-time
# confirmation on downloaded copies.
SIGN_IDENTITY_NAME="${FLYBY_SIGN_IDENTITY:-Flyby Local}"
SIGN_IDENTITY=$(security find-identity -p codesigning 2>/dev/null \
  | awk -v name="\"${SIGN_IDENTITY_NAME}\"" 'index($0, name) { print $2; exit }')

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "Signing ${APP_NAME}.app (${SIGN_IDENTITY_NAME})..."
  codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
else
  echo "Signing ${APP_NAME}.app (ad-hoc)..."
  codesign --force --deep --sign - "${APP_BUNDLE}"
fi
codesign --verify --deep --strict "${APP_BUNDLE}"

echo "Created ${APP_BUNDLE}"
