#!/bin/bash
# Twenty composition-tree cards in the existing Shop flick-and-stick shell.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${NEXT_GENERATION_SIMULATOR:-9D696736-11E8-447A-A09D-8F63738786C5}"
DERIVED="${NEXT_GENERATION_DERIVED:-/tmp/shop-quiet-review-derived}"
BUNDLE=com.shopify.purl.prototype.shop.feed.summer.26
BASE_ARGS=(-quietFeedReview -bentoMediaReview -nextGeneration20 -buyerPreviewProfileID luke)
MODE="${1:-feed}"
INDEX="${2:-0}"
case "$MODE" in feed|gallery|design) ;; *) echo "Usage: $0 [feed|gallery|design] [0...19]"; exit 2 ;; esac
if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || (( INDEX > 19 )); then echo "Index must be 0...19"; exit 2; fi
mkdir -p .build/ng20-review
python3 Scripts/validate_next_generation_20.py
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b
xcodegen generate
if ! xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DERIVED" build > .build/ng20-review/build.log 2>&1; then
    tail -60 .build/ng20-review/build.log; exit 1
fi
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/ShopFeedSummer26.app"
if [ "$MODE" = feed ]; then
    xcrun simctl launch "$SIM" "$BUNDLE" "${BASE_ARGS[@]}" -openNextGenerationCard "$INDEX"
elif [ "$MODE" = design ]; then
    xcrun simctl launch "$SIM" "$BUNDLE" "${BASE_ARGS[@]}" -nextGenerationGallery "$INDEX" -feedDesignMode
else
    xcrun simctl launch "$SIM" "$BUNDLE" "${BASE_ARGS[@]}" -nextGenerationGallery "$INDEX"
fi
open -a Simulator --args -CurrentDeviceUDID "$SIM"
echo 'Next Generation Feed: twenty native composition-tree cards. Long-press/overflow for the specification.'
