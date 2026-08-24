# Performance baseline

Measured 2026-08-23 using the Debug simulator build on the Shop `azure-peak`
iPhone simulator. Device builds use the same optimized feed bundle.

| Metric | Observed | Guardrail |
|---|---:|---:|
| Optimized frozen feed | 75 MB | 100 MB |
| Debug simulator app | 160 MB | 180 MB |
| Resting physical footprint on For You | 125 MB | 175 MB |
| Resting peak during sample | 135 MB | 200 MB |
| Frozen media files | 287 | All referenced |
| Warm incremental build | ~5 seconds | 15 seconds |

The simulator's `ps` RSS includes large mapped framework regions and is not
the memory number to compare. Record `footprint`/Instruments physical footprint
for regressions. Release/device builds should be lower than this Debug baseline.

## Verification

1. Run `Scripts/validate_personalized_feed.py`.
2. Build the app; `Validate Build Product` checks app/feed sizes and manifest.
3. Launch For You and let the first video settle for ten seconds.
4. Record physical footprint and peak.
5. Open a topic, swipe every carousel type, then return to For You.
6. Confirm memory returns near baseline and no off-screen video keeps playing.
7. Repeat on the connected physical iPhone before handoff.
