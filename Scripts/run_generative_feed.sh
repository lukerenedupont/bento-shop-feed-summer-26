#!/bin/bash
# PROTOTYPE — one command to build, install and review; no desktop input injection.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${GENERATIVE_FEED_SIMULATOR:-A2AA7E39-93E3-47FE-8599-B523E3358700}"
DERIVED="/tmp/pi-feed-interactive-cards-derived"
BUNDLE="com.shopify.purl.prototype.shop.feed.summer.26"
MODE="${1:-feed}"
INDEX="${2:-0}"
case "$MODE" in feed|gallery|consumer) ;; *) echo "Usage: $0 [feed|gallery|consumer] [0...19]"; exit 2 ;; esac
case "$INDEX" in [0-9]|1[0-9]) ;; *) echo "Card index must be 0...19"; exit 2 ;; esac
mkdir -p .build/generative-review
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b
python3 Scripts/prepare_generative_demo_media.py --check
python3 Scripts/prepare_editorial_feed.py --check
xcodegen generate
if ! xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
    -configuration Debug -destination "platform=iOS Simulator,id=$SIM" \
    -derivedDataPath "$DERIVED" build > .build/generative-review/build.log 2>&1; then
    tail -60 .build/generative-review/build.log
    exit 1
fi
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/ShopFeedSummer26.app"
if [ "$MODE" = gallery ]; then
    xcrun simctl launch "$SIM" "$BUNDLE" -nextGenerationGallery "$INDEX" -feedDesignMode
elif [ "$MODE" = consumer ]; then
    xcrun simctl launch "$SIM" "$BUNDLE" -openNextGenerationCard "$INDEX"
else
    xcrun simctl launch "$SIM" "$BUNDLE" -openNextGenerationCard "$INDEX" -feedDesignMode
fi
echo "Ready in Feed Interactive Cards. Use the heading sliders or long-press a heading to direct a card."
