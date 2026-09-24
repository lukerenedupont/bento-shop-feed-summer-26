#!/bin/bash
# Rebuild and open the local Shop Library Preview after a machine restart.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${SIMULATOR_ID:-A802FE07-B2DD-4AE9-9B6F-8D99335BD1D8}"
DESTINATION="${1:-host}"
DERIVED="${DERIVED_DATA_PATH:-${ROOT}/.build/PreviewDerived}"
PACKAGES="${SOURCE_PACKAGES_DIR:-${ROOT}/.build/SourcePackages}"
BUNDLE_ID="com.shopify.purl.prototype.shop.feed.library.preview"

if [[ -d /Applications/Xcode_26.5.app ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode_26.5.app/Contents/Developer}"
fi

if ! xcrun simctl list devices available | grep -q "${DEVICE_ID}"; then
  echo "error: Simulator ${DEVICE_ID} is not available."
  echo "Set SIMULATOR_ID to an exact UUID from: xcrun simctl list devices available"
  exit 1
fi

xcrun simctl boot "${DEVICE_ID}" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "${DEVICE_ID}" -b

mkdir -p "${DERIVED}" "${PACKAGES}"
cd "${ROOT}"
python3 Scripts/validate_shop_canvas_snapshot.py ShopFeedSummer26/LibraryAssets

xcodebuild \
  -project ShopFeedSummer26.xcodeproj \
  -scheme ShopFeedSummer26 \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${DEVICE_ID}" \
  -derivedDataPath "${DERIVED}" \
  -clonedSourcePackagesDirPath "${PACKAGES}" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  SWIFT_OPTIMIZATION_LEVEL=-O \
  build

APP="${DERIVED}/Build/Products/Debug-iphonesimulator/ShopFeedSummer26.app"
xcrun simctl install "${DEVICE_ID}" "${APP}"
xcrun simctl terminate "${DEVICE_ID}" "${BUNDLE_ID}" 2>/dev/null || true

case "${DESTINATION}" in
  host)
    xcrun simctl launch "${DEVICE_ID}" "${BUNDLE_ID}" -previewStory library-edit-0
    ;;
  self-care)
    xcrun simctl launch "${DEVICE_ID}" "${BUNDLE_ID}" -previewStory library-edit-9
    ;;
  reading-corner)
    xcrun simctl launch "${DEVICE_ID}" "${BUNDLE_ID}" -previewStory library-edit-oblist-reading-corner
    ;;
  home)
    xcrun simctl launch "${DEVICE_ID}" "${BUNDLE_ID}"
    ;;
  *)
    echo "error: Unknown destination '${DESTINATION}'. Use: host, self-care, reading-corner, or home."
    exit 2
    ;;
esac

echo "Opened ${DESTINATION} in Shop Library Preview on simulator ${DEVICE_ID}."
