#!/bin/bash
# PROTOTYPE — build and open the product-specific card review gallery.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${GENERATIVE_FEED_SIMULATOR:-A2AA7E39-93E3-47FE-8599-B523E3358700}"
DERIVED="/tmp/pi-product-specific-feed-derived"
BUNDLE="com.shopify.purl.prototype.shop.feed.summer.26"
INDEX="${1:-0}"
mkdir -p .build/product-specific-review
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b
xcodegen generate
if ! xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
    -configuration Debug -destination "platform=iOS Simulator,id=$SIM" \
    -derivedDataPath "$DERIVED" build > .build/product-specific-review/build.log 2>&1; then
    tail -80 .build/product-specific-review/build.log
    exit 1
fi
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/ShopFeedSummer26.app"
xcrun simctl launch "$SIM" "$BUNDLE" -productSpecificFeedGallery -productSpecificCard "$INDEX"
printf 'Ready: product-specific card %s\n' "$INDEX"
