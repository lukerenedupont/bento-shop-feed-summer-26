#!/bin/bash
set -euo pipefail

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
FEED_BUNDLE="${APP_PATH}/bundle"

[[ -d "${APP_PATH}" ]] || { echo "error: Missing built app at ${APP_PATH}"; exit 1; }

if [[ "${CONFIGURATION:-}" != "Debug" ]]; then
  ENV_RESOURCES="$(find "${APP_PATH}" -type f \( -name 'ShopServer.env' -o -name '.env' -o -name '.env.*' \) -print)"
  if [[ -n "${ENV_RESOURCES}" ]]; then
    echo "error: Non-Debug app contains a local environment file; refusing a shareable product"
    exit 1
  fi
fi
if [[ "${SHOP_CANVAS_LIBRARY_PREVIEW:-NO}" == "YES" ]]; then
  FEED_BUNDLE="${APP_PATH}/LibraryAssets"
  python3 "${SRCROOT}/Scripts/validate_shop_canvas_snapshot.py" "${FEED_BUNDLE}"
else
  [[ -f "${FEED_BUNDLE}/media-manifest.tsv" ]] || {
    echo "error: Optimized feed media manifest is missing"
    exit 1
  }
fi

FONT_COUNT="$(python3 - "${APP_PATH}" <<'PY'
import pathlib
import plistlib
import sys
app = pathlib.Path(sys.argv[1])
with (app / 'Info.plist').open('rb') as stream:
    declared = set(plistlib.load(stream).get('UIAppFonts', []))
actual = {path.name for path in app.glob('*.otf')}
if not declared or actual != declared:
    print('error: Bundled fonts must exactly match UIAppFonts', file=sys.stderr)
    print(f'  Missing: {sorted(declared - actual)}; undeclared: {sorted(actual - declared)}', file=sys.stderr)
    raise SystemExit(1)
print(len(actual))
PY
)"

APP_KB="$(du -sk "${APP_PATH}" | awk '{print $1}')"
# Xcode injects its test runner into a hosted Debug test product. Those Apple
# frameworks are not shipped. Keep the real app budget unchanged, and reject
# test runtimes entirely in a distribution product.
TEST_RUNTIME_KB=0
for name in Testing.framework XCTest.framework XCTestCore.framework XCTestSupport.framework \
  XCTAutomationSupport.framework XCUIAutomation.framework XCUnit.framework \
  libXCTestBundleInject.dylib libXCTestSwiftSupport.dylib; do
  runtime="${APP_PATH}/Frameworks/${name}"
  if [[ -e "${runtime}" ]]; then
    if [[ "${CONFIGURATION:-}" != "Debug" ]]; then
      echo "error: Non-Debug product contains a test runtime: ${name}"
      exit 1
    fi
    TEST_RUNTIME_KB=$((TEST_RUNTIME_KB + $(du -sk "${runtime}" | awk '{print $1}')))
  fi
done
if (( TEST_RUNTIME_KB > 0 )); then
  APP_KB=$((APP_KB - TEST_RUNTIME_KB))
  echo "Debug test-host overhead: ${TEST_RUNTIME_KB} KB (excluded from shipping app budget)"
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

if [[ "${SHOP_CANVAS_LIBRARY_PREVIEW:-NO}" == "YES" ]]; then
  ACTUAL_FILES="$(find "${FEED_BUNDLE}" -type f | wc -l | tr -d ' ')"
else
  MANIFEST_FILES="$(tail -n +2 "${FEED_BUNDLE}/media-manifest.tsv" | wc -l | tr -d ' ')"
  ACTUAL_FILES="$(find "${FEED_BUNDLE}/media" -type f | wc -l | tr -d ' ')"
  if [[ "${MANIFEST_FILES}" != "${ACTUAL_FILES}" ]]; then
    echo "error: Media manifest lists ${MANIFEST_FILES} files but bundle has ${ACTUAL_FILES}"
    exit 1
  fi
fi

echo "Validated product budgets: app ${APP_KB} KB, feed ${FEED_KB} KB, ${ACTUAL_FILES} media files, ${FONT_COUNT} fonts"
