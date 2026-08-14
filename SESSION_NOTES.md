# Session notes — working state handoff

Living scratchpad for in-flight work. Read this first when picking up the
prototype; delete sections as they land. Long-term truth lives in
`ARCHITECTURE.md` / `README.md` — this file is only the "what was I doing"
layer.

## DONE: bentos on all 10 topics (commit `799f9c1`)

Every topic now leads with a bento; all `productRail` blocks are gone.
Landed: `kit-bento`, `mirror-bento`, `brew-bento`, plus `type-bento`
(The reading stack), `nursery-bento` (The kids' room — "The nursery"
collided with the subtopic pill), `table-bento` (The table, set),
`trail-bento` (The trailhead — owned XT-6 GTX auto-wides mid-box between
two trios), `city-bento` (The city archive), `ritual-bento` (The Sunday
ritual — pulled Guava shampoo `8178693210276` + hair oil `15464228749681`
from the wider ceremonia catalog to reach trio+pair), `material-bento`
(The material library). All screenshotted on-device; validator passes.

**The recipe, if new topics appear:**
1. In `personalized-feed.json`, for each topic: remove the `productRail`
   block and prepend a `bento` block (id `<something>-bento`, kind `bento`,
   title = a place-name like "The reading stack", not a CTA).
2. Items: first = `size: hero` product (or rely on cart signal), then 5–6
   standard products with paired `role`s, last = `kind: merchant` +
   `size: wide` + role "Shop the world".
3. Every item needs `role` (validator-enforced). Product IDs must come from
   the topic's stories — dump inventory with a small python script against
   `personalized-feed.json` + `prototype-merchants.json`.
4. Rhythm engine handles layout (trio/pair/banner clustering — never a
   plain grid). 5 standards → trio+pair; 6 → trio+trio; avoid runs of 4
   (trio + orphan banner directly above the merchant banner looks stacked).
5. `python3 Scripts/validate_personalized_feed.py` must pass.
6. Build → install → screenshot each bento → commit → push.

## Fast iteration loop

```bash
xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
  -destination 'id=286EAAB0-C6BC-41CB-A40C-B84318D400D8' \
  -derivedDataPath /tmp/sfs26-dd build
xcrun simctl install 286EAAB0-C6BC-41CB-A40C-B84318D400D8 \
  /tmp/sfs26-dd/Build/Products/Debug-iphonesimulator/ShopFeedSummer26.app
xcrun simctl launch 286EAAB0-C6BC-41CB-A40C-B84318D400D8 \
  com.shopify.purl.prototype.shop.feed.summer.26 \
  -openTopic <topic-id> -scrollTo <block-id>   # also: -openStory, -openProduct m/id
sleep 8 && xcrun simctl io 286EAAB0-C6BC-41CB-A40C-B84318D400D8 screenshot /tmp/x.png
```

Known warts: deep-link launch args occasionally don't fire on cold launch —
terminate, sleep 1–2s, relaunch. Simulator screenshots can't demo scroll.

## Standing constraints (user-stated, don't regress)

- Bentos must never read as a plain grid — rhythm engine guarantees it, but
  authored order still controls shape; always include a hero.
- Roles are data-side only (sizing + validator); they don't render.
- One back affordance per page: top floating chip only, never bottom.
- Product taps always land on the real PDP unless a dossier has actual
  content (payload or films).
- Topic surface colors are sampled from covers (`extract_cover_color.swift`,
  hue-bucket sampler) — resample if covers change.
- Ambient videos: muted, autoplaying, looping, never destinations. Films
  from Andreas's dossier-lab drop into `ShopFeedSummer26/Dossiers/`
  (still 0 dossiers, 0 films — visuals arriving "shortly").
- Feed cards: 40pt heavy / -1.4 tracking, short scannable hooks; topics are
  place-names.
- User iterates in small loops: change → build → screenshot → react → commit.

## Backlog (not started)

- Different retargeting card to replace the removed "Still on your mind".
- Bento hero typography/height tightening (420pt) — candidate.
- StoryTopicPage polish beyond compact header (user called them "sloppy";
  compact header + eyebrow shipped, may want more).
- Films restart on push (known wart); `ExplorePage` unreachable; Cart/
  Favorites tabs are stubs.
