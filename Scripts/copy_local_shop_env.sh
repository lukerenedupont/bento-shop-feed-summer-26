#!/bin/bash
set -euo pipefail

DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
DEST_FILE="${DEST_DIR}/ShopServer.env"

# Never carry developer credentials into an archive or a shareable build.
# Remove a prior Debug copy too, including when reusing a build directory.
if [[ "${CONFIGURATION:-}" != "Debug" ]]; then
  rm -f "${DEST_FILE}"
  exit 0
fi

ENV_FILE="${SRCROOT}/.env.local"
if [[ -f "${ENV_FILE}" ]]; then
  mkdir -p "${DEST_DIR}"
  cp "${ENV_FILE}" "${DEST_FILE}"
else
  rm -f "${DEST_FILE}"
fi
