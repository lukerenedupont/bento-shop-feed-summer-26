#!/bin/bash
# Isolated review build. Does not modify the original branch or its simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${QUIET_REVIEW_SIMULATOR:-9D696736-11E8-447A-A09D-8F63738786C5}"
DERIVED="${QUIET_REVIEW_DERIVED:-/tmp/shop-quiet-review-derived}"
BUNDLE="com.shopify.purl.prototype.shop.feed.summer.26"
MODE="${1:-feed}"
INDEX="${2:-0}"
case "$MODE" in feed|gallery|design) ;; *) echo "Usage: $0 [feed|gallery|design] [0...4]"; exit 2 ;; esac
case "$INDEX" in 0|1|2|3|4) ;; *) echo "Card index must be 0...4"; exit 2 ;; esac
mkdir -p .build/quiet-review
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b
python3 Scripts/validate_quiet_review.py
xcodegen generate
if ! xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
    -configuration Debug -destination "platform=iOS Simulator,id=$SIM" \
    -derivedDataPath "$DERIVED" build > .build/quiet-review/build.log 2>&1; then
    tail -60 .build/quiet-review/build.log
    exit 1
fi
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/ShopFeedSummer26.app"
if [ "$MODE" = gallery ]; then
    xcrun simctl launch "$SIM" "$BUNDLE" -quietFeedReview -nextGenerationGallery "$INDEX"
elif [ "$MODE" = design ]; then
    xcrun simctl launch "$SIM" "$BUNDLE" -quietFeedReview -nextGenerationGallery "$INDEX" -feedDesignMode
else
    xcrun simctl launch "$SIM" "$BUNDLE" -quietFeedReview -openNextGenerationCard "$INDEX"
fi
open -a Simulator --args -CurrentDeviceUDID "$SIM"
echo "Ready: Shop Quiet Feed Review. Activity and recommendations are authored. State is session-only."
