#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
INFO_PLIST="${PROJECT_DIRECTORY}/Resources/Info.plist"
OUTPUT_DIRECTORY="${PROJECT_DIRECTORY}/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")"

if [[ ! "${VERSION}" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Invalid release version: ${VERSION}"
    exit 1
fi

ARCHIVE_NAME="ShiftGrid-${VERSION}-macOS-universal.zip"
ARCHIVE_PATH="${OUTPUT_DIRECTORY}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${OUTPUT_DIRECTORY}/SHA256SUMS.txt"

export SHIFTGRID_ARCHS="${SHIFTGRID_ARCHS:-arm64 x86_64}"
export CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

"${SCRIPT_DIRECTORY}/build-app.sh"

BINARY_PATH="${OUTPUT_DIRECTORY}/ShiftGrid.app/Contents/MacOS/ShiftGrid"
ARCHITECTURES="$(lipo -archs "${BINARY_PATH}")"
if [[ " ${ARCHITECTURES} " != *" arm64 "* || " ${ARCHITECTURES} " != *" x86_64 "* ]]; then
    print -u2 "Release binary is not Universal 2: ${ARCHITECTURES}"
    exit 1
fi

plutil -lint "${OUTPUT_DIRECTORY}/ShiftGrid.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "${OUTPUT_DIRECTORY}/ShiftGrid.app"

rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"
ditto -c -k --sequesterRsrc --keepParent \
    "${OUTPUT_DIRECTORY}/ShiftGrid.app" \
    "${ARCHIVE_PATH}"

(
    cd "${OUTPUT_DIRECTORY}"
    shasum -a 256 "${ARCHIVE_NAME}" > "${CHECKSUM_PATH:t}"
)

TEMPORARY_DIRECTORY="$(mktemp -d)"
trap 'rm -rf "${TEMPORARY_DIRECTORY}"' EXIT
ditto -x -k "${ARCHIVE_PATH}" "${TEMPORARY_DIRECTORY}"
codesign --verify --deep --strict --verbose=2 \
    "${TEMPORARY_DIRECTORY}/ShiftGrid.app"
lipo -archs "${TEMPORARY_DIRECTORY}/ShiftGrid.app/Contents/MacOS/ShiftGrid"

print "Created ${ARCHIVE_PATH}"
print "Created ${CHECKSUM_PATH}"
