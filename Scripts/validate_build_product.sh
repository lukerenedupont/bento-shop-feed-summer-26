#!/bin/bash
set -euo pipefail

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FEED_BUNDLE="${APP_PATH}/bundle"

[[ -d "${APP_PATH}" ]] || { echo "error: Missing built app at ${APP_PATH}"; exit 1; }
[[ -f "${FEED_BUNDLE}/media-manifest.tsv" ]] || {
  echo "error: Optimized feed media manifest is missing"
  exit 1
}

APP_KB="$(du -sk "${APP_PATH}" | awk '{print $1}')"
FEED_KB="$(du -sk "${FEED_BUNDLE}" | awk '{print $1}')"
MAX_APP_KB=184320
MAX_FEED_KB=102400

if (( APP_KB > MAX_APP_KB )); then
  echo "error: App is ${APP_KB} KB; budget is ${MAX_APP_KB} KB"
  exit 1
fi
if (( FEED_KB > MAX_FEED_KB )); then
  echo "error: Feed bundle is ${FEED_KB} KB; budget is ${MAX_FEED_KB} KB"
  exit 1
fi

MANIFEST_FILES="$(tail -n +2 "${FEED_BUNDLE}/media-manifest.tsv" | wc -l | tr -d ' ')"
ACTUAL_FILES="$(find "${FEED_BUNDLE}/media" -type f | wc -l | tr -d ' ')"
if [[ "${MANIFEST_FILES}" != "${ACTUAL_FILES}" ]]; then
  echo "error: Media manifest lists ${MANIFEST_FILES} files but bundle has ${ACTUAL_FILES}"
  exit 1
fi

echo "Validated product budgets: app ${APP_KB} KB, feed ${FEED_KB} KB, ${ACTUAL_FILES} media files"
