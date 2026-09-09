# ShopCompositionCore

UI-independent native composition contract. The app and `composition-check` CLI
use the same decoder and structural validator. No catalog I/O, UIKit, SwiftUI,
network, or session dependencies live here.

## Interface

- `CompositionNode`: immutable, typed tree; unsupported keys and enum values fail decoding.
- `CompositionPresentation`: card-level action style and disclosure, separate from layout.
- `CompositionStructure.issues(in:roles:assets:)`: validate a tree against allowed IDs;
  returns field-specific `CompositionIssue` values rather than a bare Boolean.

The app's `CompositionValidation` adapter additionally checks local media paths,
asset/product identity and card-level invariants. Catalog resolution and session
state remain app responsibilities. Structural validity is not visual approval.

## Schema 2

- Node `layout`: `row`, `column`, `featured` (featured choices require three options).
- Node `productPresentation`: `object`, `tile`.
- Node `mediaFit`: `contain`, `cover`.
- Node `playback`: `still`, `video`.
- Card `presentation.actionStyle`: `prominent`, `link`.
- Card `presentation.disclosure`: `none`, `stylingStudy`.

Legacy node `mode`, `axis`, and Boolean `fit` fields are rejected. The bundled
fixtures migrated atomically to `shop-composition/2`; there is no silent fallback
adapter that could change a reviewed layout.

## Checks (from repository root)

```sh
./Scripts/check_composition_contract.sh
# For a Mac that blocks locally built executables, use a booted Simulator:
./Scripts/check_composition_contract.sh --simulator <UDID>
```

This checks authoring drift, provenance, and ten regression cases against the
actual Swift validator through its CLI. Python's standard-library unittest is
the harness; there is no app test host or third-party test dependency. The
Simulator option compiles the same core/CLI sources for the simulator runtime;
it does not drive UI or change machine security policy.

Direct usage:

```sh
swift run --package-path Packages/ShopCompositionCore composition-check \
  ShopFeedSummer26/NextGeneration20/ng20-compositions.json
```

The CLI checks structure and typed decoding, not live inventory or filesystem
provenance. Run the repository check script for those additional fixture gates.
