#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
PRODUCT_NAME="ShiftGrid"
BUNDLE_IDENTIFIER="app.ivol.ShiftGrid"
OUTPUT_DIRECTORY="${PROJECT_DIRECTORY}/dist"
APPLICATION_PATH="${OUTPUT_DIRECTORY}/${PRODUCT_NAME}.app"
EXPECTED_PATH="${PROJECT_DIRECTORY}/dist/ShiftGrid.app"
LOCAL_SIGNING_IDENTITY_FILE="${PROJECT_DIRECTORY}/.local-signing-identity"
BUILD_ARCHITECTURES="${SHIFTGRID_ARCHS:-arm64 x86_64}"

if [[ "${APPLICATION_PATH}" != "${EXPECTED_PATH}" ]]; then
    print -u2 "Refusing to replace unexpected path: ${APPLICATION_PATH}"
    exit 1
fi

cd "${PROJECT_DIRECTORY}"
typeset -a SWIFT_BUILD_ARGUMENTS
SWIFT_BUILD_ARGUMENTS=(-c release --product "${PRODUCT_NAME}")

for architecture in ${(z)BUILD_ARCHITECTURES}; do
    case "${architecture}" in
        arm64|x86_64)
            SWIFT_BUILD_ARGUMENTS+=(--arch "${architecture}")
            ;;
        *)
            print -u2 "Unsupported architecture: ${architecture}"
            exit 1
            ;;
    esac
done

swift build "${SWIFT_BUILD_ARGUMENTS[@]}"
BINARY_DIRECTORY="$(swift build "${SWIFT_BUILD_ARGUMENTS[@]}" --show-bin-path)"

rm -rf "${APPLICATION_PATH}"
mkdir -p "${APPLICATION_PATH}/Contents/MacOS" "${APPLICATION_PATH}/Contents/Resources"

ditto "${BINARY_DIRECTORY}/${PRODUCT_NAME}" "${APPLICATION_PATH}/Contents/MacOS/${PRODUCT_NAME}"
ditto "${PROJECT_DIRECTORY}/Resources/Info.plist" "${APPLICATION_PATH}/Contents/Info.plist"
ditto "${PROJECT_DIRECTORY}/Resources/AppIcon.icns" "${APPLICATION_PATH}/Contents/Resources/AppIcon.icns"
chmod 755 "${APPLICATION_PATH}/Contents/MacOS/${PRODUCT_NAME}"

SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "${SIGNING_IDENTITY}" && -r "${LOCAL_SIGNING_IDENTITY_FILE}" ]]; then
    IFS= read -r SIGNING_IDENTITY < "${LOCAL_SIGNING_IDENTITY_FILE}"
fi

if [[ -z "${SIGNING_IDENTITY}" ]]; then
    SIGNING_IDENTITY="-"
    print "No signing identity configured; using an ad-hoc signature."
fi

typeset -a CODESIGN_ARGUMENTS
CODESIGN_ARGUMENTS=(--force --sign "${SIGNING_IDENTITY}")
if [[ "${SIGNING_IDENTITY}" == "-" || "${CODE_SIGN_TIMESTAMP:-no}" != "yes" ]]; then
    CODESIGN_ARGUMENTS+=(--timestamp=none)
else
    CODESIGN_ARGUMENTS+=(--timestamp --options runtime)
fi

codesign "${CODESIGN_ARGUMENTS[@]}" "${APPLICATION_PATH}"

print "Built ${APPLICATION_PATH}"
