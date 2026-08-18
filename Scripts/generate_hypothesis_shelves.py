#!/usr/bin/env python3
"""Generate public Shop feed fixtures from the Hypothesis Shelves export.

Only user names, shelf copy, and public product presentation fields are emitted.
Buyer activity, hypotheses, prompts, and provenance never enter the app bundle.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from collections import OrderedDict
from pathlib import Path


TOPICS = OrderedDict(
    [
        ("living", ("Living", ["bath", "home", "living", "furniture", "lamp", "lighting", "mirror", "decor", "vase", "chair", "sofa", "table", "bedding", "rug", "kids", "dog", "pet"])),
        ("style", ("Style", ["style", "fashion", "apparel", "shoe", "sneaker", "trainer", "tee", "hoodie", "knit", "jewelry", "watch", "bag", "cap", "swim", "wardrobe", "denim", "jacket", "dress", "accessor"])),
        ("wellness", ("Wellness", ["skin", "hair", "beauty", "groom", "fragrance", "shave", "wellness", "supplement", "fitness", "training", "activewear", "body care", "recovery"])),
        ("morning", ("Food & drink", ["coffee", "tea", "cocktail", "wine", "drink", "glassware", "cook", "kitchen", "dining", "snack", "pantry", "hydration", "brewer", "cup"])),
        ("outdoors", ("Outdoors", ["outdoor", "trail", "running", "race", "ski", "golf", "cycling", "hiking", "travel", "camp", "sport", "snow"])),
        ("design", ("Design & tech", ["design", "graphic", "typography", "book", "art", "print", "tech", "audio", "camera", "gaming", "computer", "desk", "clock", "paint", "music", "vinyl"])),
    ]
)

ACCENTS = {
    "living": "#8B7867",
    "style": "#5F5A61",
    "wellness": "#776D66",
    "morning": "#8A6F58",
    "outdoors": "#61705E",
    "design": "#626A70",
}

PROFILE_ACCENTS = ["#6657E8", "#596B67", "#6F5E73", "#7A654F", "#536B78", "#6D6656"]

# Source name, then the shopper-facing display name requested for the prototype.
COHORT = [
    ("Luke", "Luke"),
    ("Mikhail", "Mikhail"),
    ("Tobi", "Tobi"),
    ("Katrina", "Katarina"),
    ("Kenny", "Kenny"),
    ("Archie", "Archie"),
]


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False).replace("\\/", "/")


def slug(value: str) -> str:
    ascii_value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", ascii_value.lower()).strip("-") or "item"


def stable_int(value: str) -> int:
    digest = hashlib.sha256(value.encode()).digest()
    return int.from_bytes(digest[:8], "big") & ((1 << 63) - 1)


def classify(shelf: dict) -> str:
    text = f"{shelf['title']} {shelf['subtitle']}".lower()
    scores = {
        topic: sum(1 for keyword in keywords if keyword in text)
        for topic, (_, keywords) in TOPICS.items()
    }
    best = max(scores, key=scores.get)
    return best if scores[best] else "design"


def render(source: dict) -> str:
    raw_users = source["users"]
    users = OrderedDict(
        (display_name, raw_users[source_name])
        for source_name, display_name in COHORT
        if source_name in raw_users
    )
    stories = []
    profiles = []
    merchants: OrderedDict[str, dict] = OrderedDict()

    for profile_index, (user_name, user) in enumerate(users.items()):
        user_id = slug(user_name)
        story_ids = []
        stories_by_topic = {topic: [] for topic in TOPICS}

        for shelf_index, shelf in enumerate(user["shelves"]):
            story_id = f"shelf-{user_id}-{shelf_index + 1}-{slug(shelf['title'])}"
            topic = classify(shelf)
            references = []

            for item in shelf["items"]:
                shop = item["shop"] if item["shop"].strip() else "Shop"
                merchant_id = f"shelf-shop-{slug(shop)}-{hashlib.sha1(shop.encode()).hexdigest()[:7]}"
                merchant = merchants.setdefault(merchant_id, {"name": shop, "products": OrderedDict()})
                price = str(item["price"])
                product_key = (item["title"], price, item["image"])
                if product_key not in merchant["products"]:
                    product_id = stable_int("\0".join((shop, *product_key)))
                    merchant["products"][product_key] = {
                        "id": product_id,
                        "title": item["title"],
                        "price": price,
                        "image": item["image"],
                    }
                references.append((merchant_id, merchant["products"][product_key]["id"]))

            stories.append(
                {
                    "id": story_id,
                    "title": shelf["title"],
                    "subtitle": shelf["subtitle"],
                    "topic": topic,
                    "references": references,
                }
            )
            story_ids.append(story_id)
            stories_by_topic[topic].append(story_id)

        topics = [("for-you", "For you", "for-you", story_ids)]
        topics.extend(
            (topic, label, topic, ids)
            for topic, (label, _) in TOPICS.items()
            if (ids := stories_by_topic[topic])
        )
        profiles.append(
            {
                "id": user_id,
                "name": user_name,
                "symbol": user.get("emoji") or user_name[:1],
                "accent": PROFILE_ACCENTS[profile_index % len(PROFILE_ACCENTS)],
                "topics": topics,
            }
        )

    lines = [
        "// Generated by Scripts/generate_hypothesis_shelves.py. Do not hand-edit.",
        "// Contains only public shelf copy and product presentation fields.",
        "import SwiftUI",
        "",
        "enum HypothesisShelfCatalog {",
        "    static let stories: [FeedStory] = [",
    ]
    for story in stories:
        refs = ", ".join(f'ref({swift_string(mid)}, {pid})' for mid, pid in story["references"])
        lines.extend(
            [
                "        FeedStory(",
                f"            id: {swift_string(story['id'])}, eyebrow: \"\",",
                f"            title: {swift_string(story['title'])},",
                f"            subtitle: {swift_string(story['subtitle'])},",
                f"            format: .world, topicKeys: [{swift_string(story['topic'])}, \"catalog-only-media\"],",
                f"            accentHex: {swift_string(ACCENTS[story['topic']])}, coverImageName: nil,",
                f"            destinationLabel: \"Explore\", products: [{refs}]",
                "        ),",
            ]
        )
    lines.extend(["    ]", "", "    static let merchants: [SampleMerchant] = ["])
    for merchant_id, merchant in merchants.items():
        lines.extend(
            [
                "        SampleMerchant(",
                f"            id: {swift_string(merchant_id)}, name: {swift_string(merchant['name'])}, description: \"\",",
                "            rating: 0, totalRatings: 0, totalReviews: 0,",
                "            primaryColor: Color(hex: \"#706B66\"), secondaryColor: Color(hex: \"#706B66\"),",
                "            collections: [], products: [",
            ]
        )
        for product in merchant["products"].values():
            lines.extend(
                [
                    "                SampleMerchant.Product(",
                    f"                    id: {product['id']}, title: {swift_string(product['title'])}, price: {swift_string(product['price'])},",
                    f"                    handle: \"\", productType: nil, vendor: {swift_string(merchant['name'])},",
                    f"                    imageURL: {swift_string(product['image'])}, shopURL: nil,",
                    f"                    tags: [\"canonical-catalog\", \"hypothesis-shelf\"], allImageURLs: [{swift_string(product['image'])}]",
                    "                ),",
                ]
            )
        first_image = next(iter(merchant["products"].values()))["image"]
        lines.extend(
            [
                "            ],",
                f"            featuredImageURLs: [{swift_string(first_image)}], logoImageURL: nil, wordmarkImageURL: nil,",
                f"            coverImageURL: {swift_string(first_image)}, videoURL: nil, coverDominantColor: \"#706B66\", productCategory: nil",
                "        ),",
            ]
        )
    lines.extend(["    ]", "", "    static let profiles: [BuyerPreviewProfile] = ["])
    for profile in profiles:
        lines.extend(
            [
                "        BuyerPreviewProfile(",
                f"            id: {swift_string(profile['id'])}, name: {swift_string(profile['name'])}, symbol: {swift_string(profile['symbol'])},",
                f"            accentHex: {swift_string(profile['accent'])}, avatarAssetName: nil, topics: [",
            ]
        )
        for topic_id, label, source_id, ids in profile["topics"]:
            story_list = ", ".join(swift_string(item) for item in ids)
            lines.append(
                f"                .init(id: {swift_string(topic_id)}, label: {swift_string(label)}, sourceCategoryID: {swift_string(source_id)}, storyIDs: [{story_list}], evidence: .observed),"
            )
        lines.extend(["            ], utility: .none", "        ),"])
    lines.extend(
        [
            "    ]",
            "",
            "    private static func ref(_ merchantID: String, _ productID: Int) -> FeedStory.ProductReference {",
            "        .init(merchantID: merchantID, productID: productID)",
            "    }",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def sanitized_payload(source: dict) -> dict:
    """Return only fields that are safe and necessary for the prototype."""
    raw_users = source["users"]
    users = []
    available_cohort = [entry for entry in COHORT if entry[0] in raw_users]
    for profile_index, (source_name, display_name) in enumerate(available_cohort):
        user = raw_users[source_name]
        shelves = []
        for shelf_index, shelf in enumerate(user["shelves"]):
            shelf_id = f"shelf-{slug(display_name)}-{shelf_index + 1}-{slug(shelf['title'])}"
            items = []
            for item in shelf["items"]:
                shop = item["shop"] if item["shop"].strip() else "Shop"
                price = str(item["price"])
                image = item["image"]
                title = item["title"]
                buy_again = bool(item.get("buy_again"))
                saved = bool(item.get("saved"))
                open_loop = bool(item.get("open_loop"))
                items.append(
                    {
                        "merchantID": f"shelf-shop-{slug(shop)}-{hashlib.sha1(shop.encode()).hexdigest()[:7]}",
                        "productID": stable_int(
                            "\0".join(
                                (
                                    shop,
                                    title,
                                    price,
                                    image,
                                    str(buy_again),
                                    str(saved),
                                    str(open_loop),
                                )
                            )
                        ),
                        "title": title,
                        "shop": shop,
                        "price": price,
                        "image": image,
                        "buyAgain": buy_again,
                        "saved": saved,
                        "openLoop": open_loop,
                    }
                )
            shelves.append(
                {
                    "id": shelf_id,
                    "title": shelf["title"],
                    "subtitle": shelf["subtitle"],
                    "topic": classify(shelf),
                    "items": items,
                }
            )
        users.append(
            {
                "id": slug(display_name),
                "name": display_name,
                "symbol": user.get("emoji") or display_name[:1],
                "accent": PROFILE_ACCENTS[profile_index % len(PROFILE_ACCENTS)],
                "shelves": shelves,
            }
        )
    return {"version": 1, "users": users}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source = json.loads(args.source.read_text())
    if args.output.suffix == ".json":
        args.output.write_text(
            json.dumps(sanitized_payload(source), ensure_ascii=False, separators=(",", ":"))
        )
    else:
        args.output.write_text(render(source))


if __name__ == "__main__":
    main()
