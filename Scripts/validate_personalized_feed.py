#!/usr/bin/env python3
"""Validate the bundled catalog and personalized feed fixtures."""

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json"
FEED_PATH = ROOT / "ShopFeedSummer26/Assets.xcassets/personalized-feed.dataset/personalized-feed.json"
ASSETS_PATH = ROOT / "ShopFeedSummer26/Assets.xcassets"

catalog = json.loads(CATALOG_PATH.read_text())
feed = json.loads(FEED_PATH.read_text())
errors: list[str] = []

# Keep the two live composition surfaces from turning back into monoliths.
# Supporting components can grow independently, but these orchestration files
# should remain readable and cheap for Swift's type checker.
SOURCE_LINE_BUDGETS = {
    ROOT / "ShopFeedSummer26/Pages/HomePage.swift": 1900,
    ROOT / "ShopFeedSummer26/Pages/TopicDetailPage.swift": 1200,
    ROOT / "ShopFeedSummer26/Pages/TopicPageBlocks.swift": 1100,
}
for source_path, line_budget in SOURCE_LINE_BUDGETS.items():
    line_count = len(source_path.read_text().splitlines()) if source_path.exists() else 0
    if not line_count:
        errors.append(f"Missing architecture source {source_path.relative_to(ROOT)}")
    elif line_count > line_budget:
        errors.append(
            f"{source_path.relative_to(ROOT)} has {line_count} lines; "
            f"extract a component before exceeding {line_budget}"
        )

# The frozen dossier bundle is optional for contributors, but when present it
# must be internally complete. Every shipped media file should be referenced,
# and every relative media reference must resolve, or the phone build carries
# dead weight/broken cards.
BUNDLE_PATH = ROOT.parent / "dossier-feed-bundle/bundle"
bundle_media_count = 0
if (BUNDLE_PATH / "feed.json").exists() and (BUNDLE_PATH / "merchants.json").exists():
    bundle_documents = [
        (BUNDLE_PATH / "feed.json").read_text(),
        (BUNDLE_PATH / "merchants.json").read_text(),
    ]
    referenced_media = {
        match
        for document in bundle_documents
        for match in re.findall(r'(?<![A-Za-z0-9_-])media/([^"?]+)', document)
    }
    media_files = {
        path.name for path in (BUNDLE_PATH / "media").iterdir() if path.is_file()
    }
    bundle_media_count = len(media_files)
    for missing in sorted(referenced_media - media_files):
        errors.append(f"Frozen feed references missing media/{missing}")
    for unused in sorted(media_files - referenced_media):
        errors.append(f"Frozen feed bundles unreferenced media/{unused}")

    frozen_feed = json.loads(bundle_documents[0])
    frozen_merchants = json.loads(bundle_documents[1])
    frozen_merchant_ids = [item.get("id") for item in frozen_merchants.get("merchants", [])]
    if len(frozen_merchant_ids) != len(set(frozen_merchant_ids)):
        errors.append("Frozen feed merchant IDs must be unique")
    for story in frozen_feed.get("stories", []):
        if len(story.get("products") or []) < 3:
            errors.append(f"Frozen story {story.get('id')!r} needs at least 3 products")

merchants = {merchant["id"]: merchant for merchant in catalog["merchants"]}
products = {
    (merchant["id"], int(product["id"])): product
    for merchant in catalog["merchants"]
    for product in merchant["products"]
}

story_ids = [story["id"] for story in feed["stories"]]
if len(story_ids) != len(set(story_ids)):
    errors.append("Story IDs must be unique")

topic_ids = [topic["id"] for topic in feed["topics"]]
if len(topic_ids) != len(set(topic_ids)):
    errors.append("Topic IDs must be unique")

story_id_set = set(story_ids)
for topic in feed["topics"]:
    explicit_story_ids = topic.get("storyIDs")
    if explicit_story_ids is not None:
        if not explicit_story_ids:
            errors.append(f"{topic['id']}: explicit topic feed must not be empty")
        missing = set(explicit_story_ids) - story_id_set
        if missing:
            errors.append(f"{topic['id']}: unknown story IDs {sorted(missing)}")
        if len(explicit_story_ids) != len(set(explicit_story_ids)):
            errors.append(f"{topic['id']}: story IDs must not repeat")

    for merchant_id in topic.get("relatedMerchantIDs", []) or []:
        if merchant_id not in merchants:
            errors.append(f"{topic['id']}: unknown related merchant {merchant_id!r}")

    block_ids: set[str] = set()
    for block in topic.get("merchandisingBlocks", []) or []:
        block_id = block.get("id")
        if not block_id or block_id in block_ids:
            errors.append(f"{topic['id']}: merchandising block IDs must be present and unique")
        block_ids.add(block_id)
        if block.get("kind") not in {"mediaCarousel", "merchantRail", "productRail", "masonry", "bento"}:
            errors.append(f"{topic['id']}: unsupported merchandising block kind {block.get('kind')!r}")
        for item in block.get("items", []) or []:
            kind = item.get("kind")
            if block.get("kind") == "bento":
                # Every bento compartment must state its purpose.
                if not item.get("role"):
                    errors.append(f"{topic['id']}/{block_id}: bento compartment missing role")
                if item.get("size") not in {None, "hero", "wide", "standard"}:
                    errors.append(f"{topic['id']}/{block_id}: unknown bento size {item.get('size')!r}")
            if kind == "story" and item.get("storyID") not in story_id_set:
                errors.append(f"{topic['id']}/{block_id}: unknown story item {item.get('storyID')!r}")
            elif kind == "merchant" and item.get("merchantID") not in merchants:
                errors.append(f"{topic['id']}/{block_id}: unknown merchant item {item.get('merchantID')!r}")
            elif kind == "product":
                key = (item.get("merchantID"), int(item.get("productID", -1)))
                if key not in products:
                    errors.append(f"{topic['id']}/{block_id}: unknown product item {key}")
            elif kind == "merchantSpotlight":
                # Bento-only tall brand card: a merchant plus exactly two
                # shoppable chips from that merchant's catalog.
                if block.get("kind") != "bento":
                    errors.append(f"{topic['id']}/{block_id}: merchantSpotlight is bento-only")
                if item.get("merchantID") not in merchants:
                    errors.append(f"{topic['id']}/{block_id}: unknown spotlight merchant {item.get('merchantID')!r}")
                chip_ids = item.get("productIDs") or []
                if len(chip_ids) != 2:
                    errors.append(f"{topic['id']}/{block_id}: merchantSpotlight needs exactly 2 productIDs")
                for product_id in chip_ids:
                    if (item.get("merchantID"), int(product_id)) not in products:
                        errors.append(f"{topic['id']}/{block_id}: unknown spotlight chip ({item.get('merchantID')!r}, {product_id})")
            elif kind == "avatarCluster":
                # Bento-only shop shelf: 4 discs fill a square cell, 6 a tall one.
                if block.get("kind") != "bento":
                    errors.append(f"{topic['id']}/{block_id}: avatarCluster is bento-only")
                cluster_ids = item.get("merchantIDs") or []
                if len(cluster_ids) not in {4, 6}:
                    errors.append(f"{topic['id']}/{block_id}: avatarCluster needs 4 or 6 merchantIDs")
                if len(cluster_ids) != len(set(cluster_ids)):
                    errors.append(f"{topic['id']}/{block_id}: avatarCluster merchants must not repeat")
                for merchant_id in cluster_ids:
                    if merchant_id not in merchants:
                        errors.append(f"{topic['id']}/{block_id}: unknown cluster merchant {merchant_id!r}")
            elif kind == "videoProductMosaic":
                # Bento-only generated film paired with the exact product set
                # authored on its source story.
                if block.get("kind") != "bento":
                    errors.append(f"{topic['id']}/{block_id}: videoProductMosaic is bento-only")
                if item.get("storyID") not in story_id_set:
                    errors.append(f"{topic['id']}/{block_id}: unknown mosaic story {item.get('storyID')!r}")
            elif kind not in {"story", "merchant", "product"}:
                errors.append(f"{topic['id']}/{block_id}: unsupported item kind {kind!r}")

    for subtopic in topic.get("subtopics", []) or []:
        if not subtopic.get("label"):
            errors.append(f"{topic['id']}: subtopic missing label")
        if subtopic.get("storyID") not in story_id_set:
            errors.append(f"{topic['id']}: subtopic {subtopic.get('label')!r} references unknown story {subtopic.get('storyID')!r}")
        elif explicit_story_ids and subtopic["storyID"] not in explicit_story_ids:
            errors.append(f"{topic['id']}: subtopic {subtopic['label']!r} references story outside the topic feed")

        anchor_merchant = subtopic.get("anchorMerchantID")
        anchor_product = subtopic.get("anchorProductID")
        if (anchor_merchant is None) != (anchor_product is None):
            errors.append(f"{topic['id']}: subtopic {subtopic.get('label')!r} must set both anchorMerchantID and anchorProductID or neither")
        elif anchor_merchant is not None and (anchor_merchant, int(anchor_product)) not in products:
            errors.append(f"{topic['id']}: subtopic {subtopic.get('label')!r} references unknown anchor product {(anchor_merchant, anchor_product)}")

known_topic_keys = {
    topic["storyTopicKey"]
    for topic in feed["topics"]
    if topic.get("storyTopicKey")
}
used_topic_keys: set[str] = set()

for story in feed["stories"]:
    if not story.get("title"):
        errors.append(f"{story['id']}: missing title")
    if not story.get("products"):
        errors.append(f"{story['id']}: must reference at least one product")
    if story.get("format") not in {"world", "shortlist", "setup"}:
        errors.append(f"{story['id']}: unsupported format {story.get('format')!r}")

    cover = story.get("coverImageName")
    if cover is not None:
        if not (ASSETS_PATH / f"{cover}.imageset" / "Contents.json").exists():
            errors.append(f"{story['id']}: coverImageName {cover!r} has no imageset in Assets.xcassets")

    used_topic_keys.update(story.get("topicKeys", []))
    seen_refs: set[tuple[str, int]] = set()
    for reference in story.get("products", []):
        key = (reference["merchantID"], int(reference["productID"]))
        if reference["merchantID"] not in merchants:
            errors.append(f"{story['id']}: unknown merchant {reference['merchantID']}")
        elif key not in products:
            errors.append(f"{story['id']}: unknown product {key}")
        if key in seen_refs:
            errors.append(f"{story['id']}: duplicate product reference {key}")
        seen_refs.add(key)

# Cover imagesets that no story references are dead weight in the bundle.
used_covers = {story.get("coverImageName") for story in feed["stories"]} - {None}
bundled_covers = {path.name.removesuffix(".imageset") for path in ASSETS_PATH.glob("cover-*.imageset")}
for orphan in sorted(bundled_covers - used_covers):
    errors.append(f"Cover imageset {orphan!r} is bundled but referenced by no story")

for key in known_topic_keys:
    if key not in used_topic_keys:
        errors.append(f"Topic key {key!r} has no stories")

unknown_story_keys = used_topic_keys - known_topic_keys
if unknown_story_keys:
    errors.append(f"Stories use unknown topic keys: {sorted(unknown_story_keys)}")

# Shopper signal fixtures must reference real catalog products.
for group in ("cart", "owned", "viewed"):
    for ref in (feed.get("signals", {}) or {}).get(group, []) or []:
        key = (ref.get("merchantID"), int(ref.get("productID", -1)))
        if key not in products:
            errors.append(f"signals.{group}: unknown product {key}")

# Dossier drop zone: manifest entries must reference real catalog products,
# and dropped files must belong to a manifest entry.
DOSSIERS_PATH = ROOT / "ShopFeedSummer26/Dossiers"
dossier_count = film_count = 0
manifest_path = DOSSIERS_PATH / "dossier-manifest.json"
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text())
    entries = manifest.get("dossiers", [])
    keys = [e.get("key") for e in entries]
    if len(keys) != len(set(keys)):
        errors.append("Dossier manifest keys must be unique")
    listed_videos: set[str] = set()
    for entry in entries:
        ref = (entry.get("merchantID"), int(entry.get("productID", -1)))
        if ref not in products:
            errors.append(f"Dossier {entry.get('key')!r}: unknown product {ref}")
        listed_videos.update(entry.get("videoFiles") or [])
    key_set = set(keys)
    for path in sorted(DOSSIERS_PATH.glob("*.json")):
        if path.name == "dossier-manifest.json":
            continue
        dossier_count += 1
        if path.stem not in key_set:
            errors.append(f"Dossier payload {path.name!r} has no manifest entry")
    for path in sorted(DOSSIERS_PATH.glob("*.mp4")):
        film_count += 1
        if path.name not in listed_videos and not any(path.name.startswith(k) for k in key_set):
            errors.append(
                f"Film {path.name!r} matches no manifest entry "
                "(rename to '<dossierKey>-*.mp4' or list it under videoFiles)"
            )

if errors:
    print("Personalized feed validation failed:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    raise SystemExit(1)

print(
    f"Validated feed v{feed['version']}: "
    f"{len(feed['topics'])} topics, {len(feed['stories'])} stories, "
    f"{len(products)} catalog products, {len(used_covers)} covers, "
    f"{dossier_count} dossiers, {film_count} films, "
    f"{bundle_media_count} frozen media files"
)
