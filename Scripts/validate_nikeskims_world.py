#!/usr/bin/env python3
"""Validate the isolated NikeSKIMS internal-reference media bundle."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "ShopFeedSummer26" / "LibraryAssets"
MANIFEST = ASSET_ROOT / "nikeskims-world" / "manifest.json"


def main() -> None:
    data = json.loads(MANIFEST.read_text())
    assert data["permission"] == "not_established"
    assert data["usage"] == "internal_reference_only_editorial_non_linking"
    assert data["brown"] == "#241C19"
    assert len(data["collections"]) == 7
    assert len(data["assets"]) == 48
    assert sum(asset["kind"] == "video" for asset in data["assets"]) == 9
    assert sum(asset["kind"] == "image" for asset in data["assets"]) == 39
    assert all(asset["kind"] != "wordmark" for asset in data["assets"])
    paths = set()
    for asset in data["assets"]:
        assert asset["permission"] == "not_established_internal_reference_only"
        assert asset["path"] not in paths
        paths.add(asset["path"])
        path = ASSET_ROOT / asset["path"]
        assert path.is_file(), path
        assert hashlib.sha256(path.read_bytes()).hexdigest() == asset["sha256"], path
        source = asset.get("sourceURL") or asset.get("sourceManifestURL")
        assert source and (source.startswith("https://static.nike.com/") or source.startswith("https://api.nike.com/"))
    print("Validated NikeSKIMS World: 48 assets, 9 films, 39 stills, no Nike lockup, 7 fabric collections")


if __name__ == "__main__":
    main()
