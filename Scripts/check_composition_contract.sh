#!/bin/bash
# Reproducibility, provenance and the actual Swift structural contract.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/build_next_generation_20.py --check-spec
python3 Scripts/validate_next_generation_20.py
PACKAGE="$PWD/Packages/ShopCompositionCore"
if [[ "${1:-}" == "--simulator" && -n "${2:-}" ]]; then
    # Optional runner for Macs whose security policy blocks locally built CLI
    # executables. No app host, UI automation or security-policy changes.
    WORK="$PWD/.build/composition-contract"
    mkdir -p "$WORK"
    python3 - "$PACKAGE" "$WORK" <<'PY'
import sys
from pathlib import Path
package, work = map(Path, sys.argv[1:])
source = (package/'Sources/CompositionCheck/main.swift').read_text()
(work/'main.swift').write_text(source.replace('import ShopCompositionCore\n', ''))
PY
    xcrun swiftc -target arm64-apple-ios26.0-simulator \
        -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        "$PACKAGE"/Sources/ShopCompositionCore/*.swift "$WORK/main.swift" -o "$WORK/composition-check"
    export COMPOSITION_CHECK_COMMAND="$(python3 - "$2" "$WORK/composition-check" <<'PY'
import json,sys
print(json.dumps(['xcrun','simctl','spawn',sys.argv[1],sys.argv[2]]))
PY
)"
elif [[ $# == 0 ]]; then
    swift build --package-path "$PACKAGE" --product composition-check
else
    echo 'Usage: check_composition_contract.sh [--simulator <booted UDID>]' >&2
    exit 2
fi
python3 Scripts/test_composition_contract.py
