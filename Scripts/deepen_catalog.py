#!/usr/bin/env python3
"""Deepen the bundled merchant catalog with each shop's real inventory.

Fetches every merchant's public Shopify `/products.json` endpoint and appends
real products to prototype-merchants.json. Existing curated products (the ones
stories and merchandising blocks reference) are left untouched and stay first
in each merchant's list; fetched products are appended after them, deduped by
product ID and slug.

Usage: python3 Scripts/deepen_catalog.py [--max-per-merchant N]
"""

import argparse
import html
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json"

TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"\s+")

SKIP_TITLE_WORDS = ("gift card", "e-gift", "giftcard")


def strip_html(text: str) -> str:
    return WS_RE.sub(" ", html.unescape(TAG_RE.sub(" ", text or ""))).strip()


def fetch_products(base_url: str) -> list[dict]:
    url = base_url.rstrip("/") + "/products.json?limit=250"
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (prototype-fixture-builder)"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)["products"]


def convert(product: dict, base_url: str) -> dict | None:
    images = [img.get("src") for img in product.get("images", []) if img.get("src")]
    variants = product.get("variants") or []
    if not images or not variants:
        return None
    if any(word in product["title"].lower() for word in SKIP_TITLE_WORDS):
        return None
    available = any(v.get("available", True) for v in variants)
    if not available:
        return None
    description = strip_html(product.get("body_html", ""))
    return {
        "id": str(product["id"]),
        "title": product["title"].strip(),
        "slug": product["handle"],
        "description": description[:600],
        "price": variants[0].get("price", "0.00"),
        "currencyCode": "USD",
        "imageUrl": images[0],
        "allImageUrls": images[:6],
        "productType": (product.get("product_type") or None),
        "vendor": (product.get("vendor") or None),
        "tags": product.get("tags") or [],
        "shopUrl": base_url.rstrip("/") + "/products/" + product["handle"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-per-merchant", type=int, default=20)
    args = parser.parse_args()

    catalog = json.loads(CATALOG_PATH.read_text())
    total_added = 0

    for merchant in catalog["merchants"]:
        base_url = merchant.get("websiteUrl")
        if not base_url:
            print(f"  {merchant['id']:24s} SKIP (no websiteUrl)")
            continue
        try:
            fetched = fetch_products(base_url)
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"  {merchant['id']:24s} FAILED ({exc})")
            continue

        existing_ids = {p.get("id") for p in merchant["products"]}
        existing_slugs = {p.get("slug") for p in merchant["products"]}
        added = 0
        for raw in fetched:
            if len(merchant["products"]) >= args.max_per_merchant:
                break
            entry = convert(raw, base_url)
            if entry is None:
                continue
            if entry["id"] in existing_ids or entry["slug"] in existing_slugs:
                continue
            merchant["products"].append(entry)
            existing_ids.add(entry["id"])
            existing_slugs.add(entry["slug"])
            added += 1
        total_added += added
        print(f"  {merchant['id']:24s} +{added:2d} -> {len(merchant['products'])} products")

    CATALOG_PATH.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    print(f"Added {total_added} products.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
