#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="Flyby"
PACKAGE_SCRIPT="${ROOT_DIR}/scripts/package-app.sh"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

if [[ ! -w "${INSTALL_DIR}" ]]; then
  INSTALL_DIR="${HOME}/Applications"
fi

APP_SOURCE="${ROOT_DIR}/dist/${APP_NAME}.app"
APP_DESTINATION="${INSTALL_DIR}/${APP_NAME}.app"
LEGACY_BINARY_PATH="${INSTALL_DIR}/${APP_NAME}"

"${PACKAGE_SCRIPT}"

mkdir -p "${INSTALL_DIR}"
rm -rf "${APP_DESTINATION}"
ditto "${APP_SOURCE}" "${APP_DESTINATION}"

if [[ -f "${LEGACY_BINARY_PATH}" ]]; then
  echo "Legacy executable found at ${LEGACY_BINARY_PATH}."
  echo "You can remove it manually after confirming ${APP_DESTINATION} works."
fi

if command -v mdimport >/dev/null 2>&1; then
  mdimport "${APP_DESTINATION}" >/dev/null 2>&1 || true
fi

open "${APP_DESTINATION}"

echo "Installed ${APP_DESTINATION}"
echo "You can now open ${APP_NAME} from Finder, Spotlight, or Raycast."
