#!/bin/zsh

# Regenerates Resources/App/Flyby.icns (the Finder / Launchpad icon, "Vácuo" variation)
# from the SwiftUI artwork in Sources/Flyby/Utilities/AppIcon.swift.
# The Finder icon is static; the other variations are chosen at runtime in the app.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ICONSET_DIR=$(mktemp -d)/Flyby.iconset
trap 'rm -rf "$(dirname "${ICONSET_DIR}")"' EXIT

cd "${ROOT_DIR}"
swift build
.build/debug/Flyby --export-icons "${ICONSET_DIR}"
iconutil -c icns "${ICONSET_DIR}" -o "${ROOT_DIR}/Resources/App/Flyby.icns"
echo "Wrote Resources/App/Flyby.icns"
