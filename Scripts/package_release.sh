#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
OUTPUT_DIR="${ROOT_DIR}/Build"
APP_PATH="${OUTPUT_DIR}/LitePaste.app"
ARCHIVE_BASENAME="LitePaste-${VERSION}-${BUILD}"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

cd "${ROOT_DIR}"

Scripts/build_app_bundle.sh

rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
shasum -a 256 "${ARCHIVE_PATH}" > "${CHECKSUM_PATH}"

echo "Packaged ${ARCHIVE_PATH}"
echo "Checksum ${CHECKSUM_PATH}"
