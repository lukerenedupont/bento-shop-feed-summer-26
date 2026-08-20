#!/usr/bin/env python3
"""Merge privacy-safe ranking signals from one Hypothesis user export.

The app bundle keeps public shelf and product presentation plus compact ranking
metadata. Hypotheses, queries, activity, suppressed items, and provenance are
used only to calculate relationships and are never written to the output.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path


STOP_WORDS = set(
    """
    a an and are around as at be because by current design designed elevated
    for from high in include including interest into is item items modern
    multiple new of on ongoing or product products shelf should show shows
    surface that the their them these they this through to with you your
    """.split()
)

DISPLAY_NAME_ALIASES = {
    "katrina": "katarina",
}

# Featured collections should explain a clear intent relationship. Lower
# similarities are useful for retrieval exploration, but too weak to publish
# as a shopper-facing recommendation.
RELATED_SHELF_MINIMUM = 0.095


def tokens(shelf: dict) -> Counter[str]:
    text = " ".join(
        [
            shelf.get("title", ""),
            shelf.get("subtitle", ""),
            shelf.get("belief", ""),
            shelf.get("hypothesis", ""),
            " ".join(shelf.get("queries", [])),
        ]
    ).lower()
    return Counter(
        token
        for token in re.findall(r"[a-z0-9]+", text)
        if len(token) > 2 and token not in STOP_WORDS
    )


def vectors(shelves: list[dict]) -> list[dict[str, float]]:
    documents = [tokens(shelf) for shelf in shelves]
    frequency = Counter(token for document in documents for token in document)
    document_count = len(documents)
    return [
        {
            token: (1 + math.log(count))
            * math.log((1 + document_count) / (1 + frequency[token]))
            for token, count in document.items()
        }
        for document in documents
    ]


def cosine(lhs: dict[str, float], rhs: dict[str, float]) -> float:
    magnitude_lhs = math.sqrt(sum(value * value for value in lhs.values()))
    magnitude_rhs = math.sqrt(sum(value * value for value in rhs.values()))
    if not magnitude_lhs or not magnitude_rhs:
        return 0
    overlap = sum(value * rhs.get(token, 0) for token, value in lhs.items())
    return overlap / (magnitude_lhs * magnitude_rhs)


def related_titles(shelves: list[dict]) -> dict[str, list[str]]:
    shelf_vectors = vectors(shelves)
    result: dict[str, list[str]] = {}
    for index, shelf in enumerate(shelves):
        candidates = []
        for candidate_index, candidate in enumerate(shelves):
            if candidate_index == index:
                continue
            score = cosine(shelf_vectors[index], shelf_vectors[candidate_index])
            same_persona = shelf.get("persona") == candidate.get("persona")
            if same_persona and score >= RELATED_SHELF_MINIMUM:
                candidates.append((score, candidate["title"]))
        candidates.sort(reverse=True)
        result[shelf["title"]] = [title for _, title in candidates[:3]]
    return result


def refined_topic(shelf: dict, current: str) -> str:
    """Repair narrow public-copy misses without exporting private text."""
    public_copy = f"{shelf.get('title', '')} {shelf.get('subtitle', '')}".lower()
    footwear_terms = ("footwear", "sneaker", "trainer", "runner", "dunk", "samba")
    if current == "design" and any(term in public_copy for term in footwear_terms):
        return "style"
    return current


def merge(dataset: dict, export: dict) -> dict:
    display_name = export["buyer"]["display_name"]
    bundled_name = DISPLAY_NAME_ALIASES.get(
        display_name.casefold(), display_name.casefold()
    )
    user = next(
        (
            candidate
            for candidate in dataset["users"]
            if candidate["name"].casefold() == bundled_name
        ),
        None,
    )
    if user is None:
        raise ValueError(f"No bundled user matches {display_name!r}")

    exported_by_title = {shelf["title"]: shelf for shelf in export["shelves"]}
    bundled_titles = {shelf["title"] for shelf in user["shelves"]}
    if bundled_titles != set(exported_by_title):
        missing = sorted(bundled_titles - set(exported_by_title))
        extra = sorted(set(exported_by_title) - bundled_titles)
        raise ValueError(f"Shelf mismatch; missing={missing}, extra={extra}")

    bundled_id_by_title = {shelf["title"]: shelf["id"] for shelf in user["shelves"]}
    relationships = related_titles(export["shelves"])
    for shelf in user["shelves"]:
        source = exported_by_title[shelf["title"]]
        shelf["topic"] = refined_topic(source, shelf["topic"])
        shelf["signals"] = {
            "kind": source.get("type", "exploit"),
            "persona": source.get("persona", "self"),
            "priceBandUSD": source.get("price_band_usd"),
            "qualityScore": (source.get("verify") or {}).get("score"),
            "relatedShelfIDs": [
                bundled_id_by_title[title]
                for title in relationships[shelf["title"]]
            ],
        }

    dataset["version"] = max(dataset.get("version", 1), 2)
    return dataset


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", type=Path)
    parser.add_argument("exports", type=Path, nargs="+")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    dataset = json.loads(args.dataset.read_text())
    for export_path in args.exports:
        dataset = merge(dataset, json.loads(export_path.read_text()))
    output = args.output or args.dataset
    output.write_text(
        json.dumps(dataset, ensure_ascii=False, separators=(",", ":")) + "\n"
    )


if __name__ == "__main__":
    main()
