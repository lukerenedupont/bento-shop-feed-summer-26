#!/usr/bin/env python3
"""Read-only Shop Canvas library → native preview snapshot and referenced assets.

Editorial approval comes only from product.curated. Branding is joined by
exact merchant ID; neither branding availability nor merchant-depth adds
anything to the curated selection. Relative paths belong to public/, not
public/catalog/. No source files are changed and no review assets are copied.
"""
import argparse
import hashlib
import json
import math
import pathlib
import shutil
import subprocess
from collections import OrderedDict
from decimal import Decimal
from urllib.parse import unquote, urlsplit

ALLOWED_DIRECTORIES = {"catalog", "cosmos-brand-assets", "merchant-assets", "merchant-cover-assets"}
BRANDING_FIELDS = ("wordmarkWhite", "wordmark", "logo", "cover")


def read_json(path):
    return json.loads(path.read_text())


def indexed(rows, label):
    result = {}
    for row in rows:
        identifier = row.get("id")
        if not isinstance(identifier, str) or not identifier:
            raise ValueError(f"{label}: missing exact ID")
        if identifier in result:
            raise ValueError(f"{label}: duplicate ID {identifier}")
        result[identifier] = row
    return result


def asset_path(value, root):
    """Return a safe library-relative path, or None for an external URL."""
    if not value:
        return None
    parsed = urlsplit(value)
    path = pathlib.PurePosixPath(unquote(parsed.path))
    if "merchant-review" in path.parts:
        raise ValueError(f"Unapproved review asset: {value}")
    if parsed.scheme in {"http", "https"}:
        return None
    if value.startswith("//"):
        return None
    if parsed.scheme or parsed.netloc:
        raise ValueError(f"Unsupported asset URL: {value}")
    relative = pathlib.PurePosixPath(str(path).lstrip("/"))
    if not relative.parts or relative.parts[0] not in ALLOWED_DIRECTORIES or ".." in relative.parts:
        raise ValueError(f"Asset is outside the library's approved directories: {value}")
    resolved = (root / relative).resolve()
    if (not resolved.is_relative_to(root.resolve())
            or "merchant-review" in resolved.relative_to(root.resolve()).parts
            or not resolved.is_file()):
        raise ValueError(f"Missing or escaping local asset: {value}")
    return relative.as_posix()


def safe_asset(value, root, warnings):
    if not value:
        return None
    try:
        asset_path(value, root)
    except ValueError as error:
        warnings.append(str(error))
        return None
    return "https:" + value if value.startswith("//") else value


def native_id(identifier):
    value = 14_695_981_039_346_656_037
    for byte in identifier.encode():
        value = ((value ^ byte) * 1_099_511_628_211) & ((1 << 64) - 1)
    return value % ((1 << 63) - 1)


def price_value(price):
    if not isinstance(price, dict):
        return "", ""
    amount, currency = price.get("amount"), price.get("currency")
    if type(amount) not in (int, float) or not math.isfinite(amount) or amount < 0:
        return "", ""
    if not isinstance(currency, str) or len(currency) != 3 or not currency.isalpha() or not currency.isupper():
        return "", ""
    # Matches the asset library's catalog.js display contract (minor units / 100).
    return format(Decimal(str(amount)) / 100, ".2f"), currency


def merged_products(catalog, depth, include_depth=False):
    base = indexed(catalog["products"], "catalog products")
    selected = catalog["selectedIds"]
    if len(selected) != len(set(selected)):
        raise ValueError("selectedIds contains duplicates")
    curated = {identifier for identifier, row in base.items() if row.get("curated") is True}
    if set(selected) != curated:
        raise ValueError("selectedIds must exactly describe the explicitly curated products")
    if include_depth:
        for row in depth.get("products", []):
            # A depth record never replaces an existing curated/base record.
            if row["id"] not in base:
                base[row["id"]] = {**row, "curated": False}
    order = selected + ([identifier for identifier in base if identifier not in curated] if include_depth else [])
    enrichment = depth.get("enrichment", {})
    result = []
    for identifier in order:
        row = base[identifier]
        details = {**(row.get("details") or {}), **enrichment.get(identifier, {})}
        result.append({**row, "curated": identifier in curated, "details": details})
    return result


def make_snapshot(root, include_depth=False, expected_count=None):
    catalog = read_json(root / "catalog/catalog.json")
    directory = indexed(read_json(root / "catalog/merchants.json")["merchants"], "merchant directory")
    depth = read_json(root / "catalog/merchant-depth.json")
    rows = merged_products(catalog, depth, include_depth)
    if expected_count is not None and sum(row["curated"] for row in rows) != expected_count:
        raise ValueError(f"Expected {expected_count} curated products")
    warnings, products, merchant_ids, groups = [], [], OrderedDict(), OrderedDict()
    seen_native_ids = {}
    for row in rows:
        identifier = row["id"]
        product_id = native_id(identifier)
        if product_id in seen_native_ids and seen_native_ids[product_id] != identifier:
            raise ValueError("Native product ID collision; source IDs remain authoritative")
        seen_native_ids[product_id] = identifier
        associations = list(dict.fromkeys(ref["id"] for ref in row.get("merchants", [])))
        if not associations or any(mid not in directory for mid in associations):
            raise ValueError(f"{identifier}: missing exact merchant association")
        for mid in associations:
            merchant_ids[mid] = None
        amount, currency = price_value(row.get("price"))
        details = row["details"]
        image = safe_asset(row.get("image"), root, warnings)
        original = safe_asset(row.get("originalImage"), root, warnings)
        if row["curated"] and not image:
            raise ValueError(f"{identifier}: curated product has no publishable thumbnail")
        images = [safe_asset(value, root, warnings) for value in details.get("images", [])]
        products.append({
            "id": identifier, "nativeID": product_id, "curated": row["curated"],
            "merchantIDs": associations, "title": row["title"], "brand": row.get("brand", ""),
            "group": row.get("group") or "Curated finds", "image": image,
            "originalImage": original, "url": row.get("url"),
            "price": amount, "currency": currency,
            "description": details.get("description") or row.get("description") or "",
            "commerceCheck": row.get("commerceCheck") or "Reference only; availability not verified",
            "checkedAt": row.get("checkedAt"),
            "images": list(dict.fromkeys(value for value in [original, *images, image] if value)),
            "details": details,
        })
        if row["curated"]:
            groups.setdefault(row.get("group") or "Curated finds", []).append(identifier)
    merchants = []
    for identifier in merchant_ids:
        current = directory[identifier]
        # Embedded product.merchants branding and previousAssets are deliberately not read.
        merchants.append({
            "id": identifier, "name": current["name"], "url": current.get("url"),
            "status": current.get("status"), "platformOutcome": current.get("platformOutcome"),
            "colors": current.get("colors") or {},
            **{key: safe_asset(current.get(key), root, warnings) for key in BRANDING_FIELDS},
        })
    source_hashes = {name: hashlib.sha256((root / "catalog" / name).read_bytes()).hexdigest()
                     for name in ["catalog.json", "merchants.json", "merchant-depth.json"]}
    return {
        "version": 1, "selectedIds": catalog["selectedIds"], "products": products,
        "merchants": merchants,
        "groups": [{"title": title, "productIDs": ids} for title, ids in groups.items()],
        "approvedHeroes": [],  # Approval is separately authored, never inferred from branding.
        "sourceHashes": source_hashes, "warnings": warnings,
        "includesBroaderInventory": include_depth,
    }


def publish_snapshot(root, destination, snapshot):
    root, destination = root.resolve(), destination.resolve()
    if destination == root or destination.is_relative_to(root) or root.is_relative_to(destination):
        raise ValueError("Output must be separate from the read-only library")
    if destination.exists() and any(destination.iterdir()):
        raise ValueError("Use a new/empty output directory; refusing to overwrite an existing snapshot")
    destination.mkdir(parents=True, exist_ok=True)
    paths = set()
    for product in snapshot["products"]:
        for value in [product["image"], product["originalImage"], *product["images"]]:
            if value and (relative := asset_path(value, root)):
                paths.add(relative)
    for merchant in snapshot["merchants"]:
        for key in BRANDING_FIELDS:
            if merchant[key] and (relative := asset_path(merchant[key], root)):
                paths.add(relative)
    for relative in sorted(paths):
        output = destination / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / relative, output)
    # Native ImageIO cannot use SVG directly on iOS. Keep the original asset
    # path intact and add a raster sibling in our copy, never in the library.
    native_assets = {}
    for relative in sorted(paths):
        if pathlib.Path(relative).suffix.lower() == ".svg":
            raster = relative + ".png"
            subprocess.run(["sips", "-s", "format", "png", "-Z", "640",
                            str(destination / relative), "--out", str(destination / raster)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            native_assets["./" + relative] = "./" + raster
    snapshot["nativeAssets"] = native_assets
    (destination / "snapshot.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
    manifest = {relative: hashlib.sha256((destination / relative).read_bytes()).hexdigest() for relative in sorted(paths)}
    (destination / "asset-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return len(paths)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("destination", type=pathlib.Path)
    parser.add_argument("--include-depth", action="store_true")
    parser.add_argument("--expected-curated-count", type=int, default=328)
    args = parser.parse_args()
    snapshot = make_snapshot(args.source, args.include_depth, args.expected_curated_count)
    count = publish_snapshot(args.source, args.destination, snapshot)
    print(f"Imported {len(snapshot['selectedIds'])} curated products, {len(snapshot['merchants'])} exact-ID merchants, {count} referenced local assets")
    print(f"Broader inventory included: {snapshot['includesBroaderInventory']}; warnings: {len(snapshot['warnings'])}")


if __name__ == "__main__":
    main()
