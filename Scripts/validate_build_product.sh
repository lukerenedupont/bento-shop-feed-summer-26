#!/bin/bash
set -euo pipefail

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FEED_BUNDLE="${APP_PATH}/bundle"

[[ -d "${APP_PATH}" ]] || { echo "error: Missing built app at ${APP_PATH}"; exit 1; }
[[ -f "${FEED_BUNDLE}/media-manifest.tsv" ]] || {
  echo "error: Optimized feed media manifest is missing"
  exit 1
}

FONT_COUNT="$(find "${APP_PATH}" -maxdepth 1 -type f -name '*.otf' | wc -l | tr -d ' ')"
EXPECTED_FONT_COUNT=22
if [[ "${FONT_COUNT}" != "${EXPECTED_FONT_COUNT}" ]]; then
  echo "error: App declares ${EXPECTED_FONT_COUNT} custom fonts but bundle has ${FONT_COUNT}"
  exit 1
fi

APP_KB="$(du -sk "${APP_PATH}" | awk '{print $1}')"
# Xcode injects Apple test runtimes into a hosted unit-test app. Exclude only
# those known runtimes when explicitly building the test host; normal review
# builds retain the unchanged total-app gate below.
if [[ "${COMPOSITION_TEST_HOST:-NO}" == YES ]]; then
  TEST_SUPPORT_KB=0
  for name in Testing.framework XCTestCore.framework XCUIAutomation.framework \
      XCTAutomationSupport.framework XCTestSupport.framework XCTest.framework \
      XCUnit.framework libXCTestSwiftSupport.dylib libXCTestBundleInject.dylib; do
    if [[ -e "${APP_PATH}/Frameworks/${name}" ]]; then
      SIZE="$(du -sk "${APP_PATH}/Frameworks/${name}" | awk '{print $1}')"
      TEST_SUPPORT_KB=$((TEST_SUPPORT_KB + SIZE))
    fi
  done
  APP_KB=$((APP_KB - TEST_SUPPORT_KB))
  echo "Hosted tests: ${TEST_SUPPORT_KB} KB of injected Apple XCTest runtimes excluded from app-only budget"
fi
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

echo "Validated product budgets: app ${APP_KB} KB, feed ${FEED_KB} KB, ${ACTUAL_FILES} media files, ${FONT_COUNT} fonts"
