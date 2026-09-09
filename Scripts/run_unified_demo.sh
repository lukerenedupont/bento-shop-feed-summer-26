#!/bin/bash
# One native feed, twenty available cards, three authored continuation paths.
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-room}" in
    room|footwear|books) export NEXT_GENERATION_JOURNEY="${1:-room}" ;;
    *) echo 'Usage: run_unified_demo.sh [room|footwear|books]' >&2; exit 2 ;;
esac
export NEXT_GENERATION_SIMULATOR="${NEXT_GENERATION_SIMULATOR:-3F187DB4-1903-4F9D-A567-9779113B8229}"
exec ./Scripts/run_next_generation_20.sh feed
