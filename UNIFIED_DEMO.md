# Unified shopping journey proof of concept

One native feed, twenty available cards, three connected paths, and device-local
memory of explicit choices. This is an authored proof of concept, not a live AI
service or an authenticated shopping account.

## Run

```sh
./Scripts/run_unified_demo.sh room
./Scripts/run_unified_demo.sh footwear
./Scripts/run_unified_demo.sh books
```

Defaults to **Next Generation QA** (`3F187DB4-1903-4F9D-A567-9779113B8229`).
`NEXT_GENERATION_SIMULATOR` and `NEXT_GENERATION_DERIVED` override the destination.
The launcher uses the actual feed, not the gallery. Accept the disclosure on
first consumer launch. Choices persist across launches; the explicit launch
argument chooses which journey to open without clearing those choices.

All twenty cards remain available by flicking. To jump between paths in-app:
card options → Inspect specification → Feed → Demo journeys.

## Three-minute walkthrough

### Finish a room

1. Open **Around this lamp** → **Review the room**.
2. Choose **Compare chairs for this room**. The comparison contains the room's
   actual three eligible chairs, including the original chair—not an unrelated
   shortlist. The current chair and one alternative are initially selected.
3. Choose candidates if needed, then **Compare chairs** → **Review the pair**.
4. Choose **Use … in the room**. The feed returns to the lamp card with that
   chair; the lamp, rug and table remain unchanged.
5. Review again and **Keep this selection**. The existing Spatial action starts
   with the chosen chair. Spatial remains a one-object visual prototype, not a
   whole-room render or a verified fit.
6. Browse or change the chair. Card options → **Kept selections** → **Continue
   this selection** restores the exact room you kept.

### Choose a shoe, then build around it

1. Open **City or trail?** and choose a direction.
2. Focus a shoe, inspect it if desired, then **Explore your direction**.
3. Choose **Build around [selected shoe]**.
4. The same feed slot becomes a product-led composition with that exact
   Salomon, pants, jacket and socks. No Vomero backdrop is reused; all foreground
   images retain their catalog bindings. This is styling, not a technical kit or
   compatibility claim.
5. Swap the pants and **Review this combination** → **Keep this selection**.
6. Relaunch, or use **Kept selections** → **Continue this selection**. The shoe,
   pants and original direction are restored. Card options → **Back to shoe
   selection** returns to the direction experience without deleting saved looks.

### Discover and keep a book

1. Open **From the bookshelf** → **Explore the library**.
2. Tap a book to focus it; tap the focused book again to inspect its exact source.
3. Choose **Keep this product** in the product review.
4. Return to **Kept selections** and continue. The saved book's focus and canvas
   position return; interactive exploration itself resets so it cannot trap feed
   scrolling.

This uses the existing library canvas. The separately approved three-cover
editorial introduction has **not** been ported or approximated in this pass.

## Shared memory and reset

Every NG20 card's options menu opens the same **Kept selections** sheet. Product
reviews can keep a single product; composition reviews keep exact combinations.
Saving again does not rewrite an existing snapshot. Removing a snapshot does not
change an account favorite. Invalid/unavailable selections cannot silently resume
as a different product.

**Reset demo** lives in Kept selections and requires confirmation. It removes
only this demo's memory (`unifiedFeedDemo.luke.v1`), not custom feeds, account
state, or existing World preferences. Saved selections are capped at 50.

## Implementation seams

- `FeedJourneyMemory`: Foundation-only, versioned snapshots and scoped
  continuation/checkpoint restoration. No renderer or catalog I/O.
- `GenerativeFeedPrototypeSession`: optional UserDefaults adapter and existing
  shared interaction state. Other prototypes can still use an ephemeral session.
- `DemoJourneyCatalog` / `DemoJourneyActions`: explicit room/footwear transitions
  and canonical entity binding. No merchant/card switch was added to the renderer.
- `build_next_generation_20.py`: the two continuation trees are authored once in
  `journeyTemplates`, alongside the existing twenty cards. Core validation checks
  templates; the runtime adapter checks their bound roles and artwork identities.
- `JourneySelectionViews`: continuations in the existing review flow, one shared
  saved destination, and explicit keep in canonical product details.
- `HomePage`: native scroll requests synchronize the actual row and position
  cache. Explicit destinations tolerate startup layout shifts, then release as
  soon as the shopper touches/scrolls the feed.

The native regression caught offscreen footers shifted over the current card's
hit targets. NG20 now relies on its reserved layout height, not scroll-relative
footer painting, and bounds hit testing to each card frame.

## Verification

- 12 hosted model tests: inventory, gating, comparison, immutable snapshots,
  room round trip, exact footwear/direction restoration, book relaunch,
  demo-scoped reset, corrupted archive handling, and bound-artwork rejection.
- 5 UI tests: room flow, footwear save/relaunch/resume, book inspect/keep,
  consumer relaunch/navigation clearance, and the actual native-feed room round
  trip with a subsequent ordinary flick to the next card.
- All 17 passed on the final code: `/tmp/unified-final-acceptance.log`. The native check also verifies that the next card becomes active after the flick.
- Ten CLI contract checks and deterministic authoring/provenance checks passed:
  `/tmp/unified-final-contract.log`.
- Normal build passed at **173220 / 184320 KB**; Home is **1848 / 1900 lines** (`/tmp/unified-final-build.log`). No new media was added.
- UI tests use a separate defaults suite; they do not clear the presenter's saves.

Full twenty-card visual approval, physical-device AR, the approved editorial book
entry, broader FOROM/Lichen journey links, live generation, backend persistence,
and production-scale delivery remain outside this first connected slice.
