#!/bin/bash
# Reproducible, credential-free Release artifacts. Does not upload or provision.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
OUTPUT="${ROOT}/DemoArtifacts"
DERIVED="${DERIVED_DATA_PATH:-${ROOT}/.build/DemoDerived}"
PACKAGES="${SOURCE_PACKAGES_DIR:-${ROOT}/.build/SourcePackages}"

if [[ "${MODE}" != "simulator" && "${MODE}" != "archive-unsigned" ]]; then
  echo "Usage: $0 simulator <exact-simulator-UUID> | archive-unsigned"
  echo "archive-unsigned is for validation/handoff; it cannot be installed until signed."
  exit 2
fi
if [[ "${MODE}" == "simulator" && -z "${2:-}" ]]; then
  echo "error: Supply the exact simulator UUID from xcrun simctl list devices"
  exit 2
fi
if [[ ! -f "${ROOT}/ShopFeedSummer26/LibraryAssets/snapshot.json" ]]; then
  echo "error: Import the read-only Shop Canvas library before building this preview"
  exit 1
fi
mkdir -p "${OUTPUT}"
cd "${ROOT}"
python3 Scripts/validate_shop_canvas_snapshot.py ShopFeedSummer26/LibraryAssets

args=(-project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26
  -configuration Release -derivedDataPath "${DERIVED}"
  -clonedSourcePackagesDirPath "${PACKAGES}" CODE_SIGNING_ALLOWED=NO)
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  args+=("CURRENT_PROJECT_VERSION=${BUILD_NUMBER}")
fi

if [[ "${MODE}" == "simulator" ]]; then
  xcodebuild "${args[@]}" -destination "platform=iOS Simulator,id=$2" ONLY_ACTIVE_ARCH=YES build
  PRODUCT="${DERIVED}/Build/Products/Release-iphonesimulator/ShopFeedSummer26.app"
  DEST="${OUTPUT}/ShopLibraryPreview-Simulator.app"
  rm -rf "${DEST}"
  ditto "${PRODUCT}" "${DEST}"
  echo "Release simulator app: ${DEST}"
else
  ARCHIVE="${OUTPUT}/ShopLibraryPreview-Unsigned.xcarchive"
  xcodebuild "${args[@]}" -destination 'generic/platform=iOS' -archivePath "${ARCHIVE}" archive
  echo "Unsigned iPhone archive: ${ARCHIVE}"
  echo "Not installable yet. Select the intended Apple team/distribution method before signing."
fi
