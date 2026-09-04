#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
INFO_PLIST="${PROJECT_DIRECTORY}/Resources/Info.plist"
OUTPUT_DIRECTORY="${PROJECT_DIRECTORY}/dist"
DMG_SETTINGS="${PROJECT_DIRECTORY}/Scripts/dmg-settings.py"
APP_ICON="${PROJECT_DIRECTORY}/Resources/AppIcon.icns"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")"

if [[ ! "${VERSION}" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Invalid release version: ${VERSION}"
    exit 1
fi

ZIP_NAME="ShiftGrid-${VERSION}-macOS-universal.zip"
ZIP_PATH="${OUTPUT_DIRECTORY}/${ZIP_NAME}"
DMG_NAME="ShiftGrid-${VERSION}-macOS-universal.dmg"
DMG_PATH="${OUTPUT_DIRECTORY}/${DMG_NAME}"
CHECKSUM_PATH="${OUTPUT_DIRECTORY}/SHA256SUMS.txt"

export SHIFTGRID_ARCHS="${SHIFTGRID_ARCHS:-arm64 x86_64}"
export CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

"${SCRIPT_DIRECTORY}/build-app.sh"

BINARY_PATH="${OUTPUT_DIRECTORY}/ShiftGrid.app/Contents/MacOS/ShiftGrid"

verify_universal_binary() {
    local binary_path="$1"
    local architectures
    architectures="$(lipo -archs "${binary_path}")"
    if [[ " ${architectures} " != *" arm64 "* || " ${architectures} " != *" x86_64 "* ]]; then
        print -u2 "Release binary is not Universal 2: ${architectures}"
        exit 1
    fi
    print "Verified architectures: ${architectures}"
}

verify_universal_binary "${BINARY_PATH}"

plutil -lint "${OUTPUT_DIRECTORY}/ShiftGrid.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "${OUTPUT_DIRECTORY}/ShiftGrid.app"

DMGBUILD_EXECUTABLE="${DMGBUILD_EXECUTABLE:-}"
if [[ -z "${DMGBUILD_EXECUTABLE}" && -x "${PROJECT_DIRECTORY}/.build/release-venv/bin/dmgbuild" ]]; then
    DMGBUILD_EXECUTABLE="${PROJECT_DIRECTORY}/.build/release-venv/bin/dmgbuild"
fi
if [[ -z "${DMGBUILD_EXECUTABLE}" && -x "${PROJECT_DIRECTORY}/.build/dmgbuild-venv/bin/dmgbuild" ]]; then
    DMGBUILD_EXECUTABLE="${PROJECT_DIRECTORY}/.build/dmgbuild-venv/bin/dmgbuild"
fi
if [[ -z "${DMGBUILD_EXECUTABLE}" ]]; then
    DMGBUILD_EXECUTABLE="$(command -v dmgbuild || true)"
fi
if [[ -z "${DMGBUILD_EXECUTABLE}" ]]; then
    print -u2 "dmgbuild is required for release packaging."
    print -u2 "Install Scripts/requirements-release.txt in a Python 3.10+ environment."
    exit 1
fi

DMGBUILD_BINARY_DIRECTORY="${DMGBUILD_EXECUTABLE:A:h}"
RELEASE_PYTHON=""
for python_candidate in \
    "${DMGBUILD_BINARY_DIRECTORY}/python3" \
    "${DMGBUILD_BINARY_DIRECTORY}/python"; do
    if [[ -x "${python_candidate}" ]]; then
        RELEASE_PYTHON="${python_candidate}"
        break
    fi
done
if [[ -z "${RELEASE_PYTHON}" ]]; then
    RELEASE_PYTHON="$(command -v python3 || true)"
fi
if [[ -z "${RELEASE_PYTHON}" ]]; then
    print -u2 "Python 3 is required to verify the DMG Finder layout."
    exit 1
fi

rm -f "${ZIP_PATH}" "${DMG_PATH}" "${CHECKSUM_PATH}"
ditto -c -k --sequesterRsrc --keepParent \
    "${OUTPUT_DIRECTORY}/ShiftGrid.app" \
    "${ZIP_PATH}"

"${DMGBUILD_EXECUTABLE}" \
    -s "${DMG_SETTINGS}" \
    -D "app=${OUTPUT_DIRECTORY}/ShiftGrid.app" \
    -D "icon=${APP_ICON}" \
    "ShiftGrid" \
    "${DMG_PATH}"

hdiutil verify "${DMG_PATH}"

DMG_IMAGE_INFO="$(hdiutil imageinfo -plist "${DMG_PATH}")"
DMG_FORMAT="$(print -r -- "${DMG_IMAGE_INFO}" | plutil -extract Format raw -o - -)"
if [[ "${DMG_FORMAT}" != "UDZO" || "${DMG_IMAGE_INFO}" != *"<key>HFS+</key>"* ]]; then
    print -u2 "The DMG must be a read-only compressed HFS+ image."
    exit 1
fi

(
    cd "${OUTPUT_DIRECTORY}"
    shasum -a 256 "${DMG_NAME}" "${ZIP_NAME}" > "${CHECKSUM_PATH:t}"
)

ZIP_VERIFY_DIRECTORY="$(mktemp -d)"
DMG_MOUNT_DIRECTORY="$(mktemp -d)"
DMG_IS_MOUNTED=false

cleanup() {
    local exit_status=$?
    if [[ "${DMG_IS_MOUNTED}" == true ]]; then
        hdiutil detach "${DMG_MOUNT_DIRECTORY}" -quiet || {
            sleep 1
            hdiutil detach "${DMG_MOUNT_DIRECTORY}" -quiet || \
                print -u2 "Warning: could not detach ${DMG_MOUNT_DIRECTORY}"
        }
    fi
    rm -rf "${ZIP_VERIFY_DIRECTORY}"
    rmdir "${DMG_MOUNT_DIRECTORY}" 2>/dev/null || true
    return "${exit_status}"
}
trap cleanup EXIT

ditto -x -k "${ZIP_PATH}" "${ZIP_VERIFY_DIRECTORY}"
codesign --verify --deep --strict --verbose=2 \
    "${ZIP_VERIFY_DIRECTORY}/ShiftGrid.app"
verify_universal_binary \
    "${ZIP_VERIFY_DIRECTORY}/ShiftGrid.app/Contents/MacOS/ShiftGrid"

hdiutil attach \
    -readonly \
    -nobrowse \
    -noautoopen \
    -mountpoint "${DMG_MOUNT_DIRECTORY}" \
    "${DMG_PATH}" >/dev/null
DMG_IS_MOUNTED=true

if [[ ! -d "${DMG_MOUNT_DIRECTORY}/ShiftGrid.app" ]]; then
    print -u2 "ShiftGrid.app is missing from the DMG."
    exit 1
fi
if [[ ! -L "${DMG_MOUNT_DIRECTORY}/Applications" || \
      "$(readlink "${DMG_MOUNT_DIRECTORY}/Applications")" != "/Applications" ]]; then
    print -u2 "The DMG Applications link is missing or invalid."
    exit 1
fi
if [[ ! -f "${DMG_MOUNT_DIRECTORY}/.DS_Store" ]]; then
    print -u2 "The DMG Finder layout is missing."
    exit 1
fi
"${RELEASE_PYTHON}" "${SCRIPT_DIRECTORY}/verify-dmg-layout.py" \
    "${DMG_MOUNT_DIRECTORY}/.DS_Store"

VISIBLE_ENTRIES=("${DMG_MOUNT_DIRECTORY}"/*(N))
if (( ${#VISIBLE_ENTRIES[@]} != 2 )); then
    print -u2 "The DMG must contain exactly ShiftGrid.app and Applications."
    exit 1
fi

codesign --verify --deep --strict --verbose=2 \
    "${DMG_MOUNT_DIRECTORY}/ShiftGrid.app"
verify_universal_binary \
    "${DMG_MOUNT_DIRECTORY}/ShiftGrid.app/Contents/MacOS/ShiftGrid"

hdiutil detach "${DMG_MOUNT_DIRECTORY}" -quiet
DMG_IS_MOUNTED=false

(
    cd "${OUTPUT_DIRECTORY}"
    shasum -a 256 -c "${CHECKSUM_PATH:t}"
)

print "Created ${DMG_PATH}"
print "Created ${ZIP_PATH}"
print "Created ${CHECKSUM_PATH}"
