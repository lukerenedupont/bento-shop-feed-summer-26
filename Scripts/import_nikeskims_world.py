#!/usr/bin/env python3
"""Import the pinned NikeSKIMS internal-reference media used by the rich World.

The source pages are first-party Nike pages. Their public availability is not a
license: generated manifest entries remain permission-not-established and the
app keeps this media editorial/non-linking. Requires ffmpeg and sips.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ShopFeedSummer26" / "LibraryAssets" / "nikeskims-world"
LANDING = "https://www.nike.com/nikeskims"
GUIDE = "https://www.nike.com/nikeskims-collection-guide"
USER_AGENT = "Mozilla/5.0 (Shop internal reference importer)"

LANDING_CARDS = {
    "film-opening": "d44614cc-a932-43fb-82b8-237c66e6abb0",
    "film-closing": "d58b2e47-dd30-493a-9ff9-6ff6467b2fad",
    "feature-accessories": "93f36036-a5c6-4cc6-89f1-9f394766d86a",
    "feature-rift": "548e3e2b-68fb-498e-85fb-363e555a8d98",
    "editorial-light-1": "656e3a2f-7f9d-457e-8275-ff34e1ec4322",
    "editorial-light-2": "01e16c86-8949-402b-b429-c4eba026e02f",
    "editorial-dark-1": "8d13f366-05a3-4de4-be24-a179c58e7c8f",
    "editorial-dark-2": "6be9d94f-c31e-485c-a1eb-9251f794469f",
}
LANDING_FILMSTRIPS = {
    "collection": "036a45c0-b769-4150-85ea-6b64c117caee",
    "color": "77d07c63-1b67-42ac-a0b3-e06887c27044",
    "build": "d6604352-d359-4dc4-a9b5-c595866200cc",
    "movement": "0f7b1a3f-b650-47e1-9eb7-fbc2d7119254",
}
GUIDE_VIDEOS = {
    "studio-stretch": "c13b91ed-2b27-4d45-97b2-253d6631fd45",
    "matte": "b94afcf6-47d4-4014-8299-9c74641d5d28",
    "airy": "b929b272-f5f1-4f19-b946-5f82c596be27",
    "satin-shine": "3905519e-5f6f-4f1f-a96f-9338e31be860",
    "weightless": "5832320f-4789-409d-96d3-807ffeeaf443",
    "ribbed-seamless": "f7ac111a-6ed5-480f-b053-abb9bc3dc32f",
    "stretch-knit": "e7652fd8-e7cd-4307-8ab4-7c68f0a4642f",
}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def page_data(url: str) -> dict:
    html = fetch(url).decode("utf-8")
    match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html)
    if not match:
        raise RuntimeError(f"Missing __NEXT_DATA__ on {url}")
    return json.loads(match.group(1))["props"]["pageProps"]["initialState"]["appData"]


def checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dimensions(path: Path) -> tuple[int, int]:
    output = subprocess.check_output(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)], text=True
    )
    width = int(re.search(r"pixelWidth: (\d+)", output).group(1))
    height = int(re.search(r"pixelHeight: (\d+)", output).group(1))
    return width, height


def save_image(name: str, source: str, role: str, entries: list[dict], preserve_png: bool = False) -> None:
    suffix = ".png" if preserve_png else ".jpg"
    target = DEST / f"{name}{suffix}"
    raw = DEST / f".{name}.download"
    raw.write_bytes(fetch(source))
    if preserve_png:
        # The supplied transparent lockup has very wide presentation margins.
        # Crop to its visible artwork so the native left-aligned treatment can
        # render large without scaling an empty canvas.
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw),
             "-vf", "crop=780:270:235:70", str(target)],
            check=True,
        )
        raw.unlink(missing_ok=True)
    else:
        subprocess.run(
            ["sips", "-s", "format", "jpeg", "-s", "formatOptions", "60", "-Z", "720", str(raw), "--out", str(target)],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        raw.unlink(missing_ok=True)
    width, height = dimensions(target)
    entries.append({
        "id": name,
        "kind": "wordmark" if preserve_png else "image",
        "role": role,
        "path": f"nikeskims-world/{target.name}",
        "sourceURL": source,
        "sha256": checksum(target),
        "width": width,
        "height": height,
        "permission": "not_established_internal_reference_only",
    })


def stream_url(video_id: str) -> str:
    master_url = f"https://api.nike.com/content/asset_video_manifest/v1/{video_id}"
    master = fetch(master_url).decode("utf-8")
    variants: list[tuple[int, str]] = []
    lines = [line.strip() for line in master.splitlines() if line.strip()]
    for index, line in enumerate(lines):
        if line.startswith("#EXT-X-STREAM-INF") and index + 1 < len(lines):
            match = re.search(r"RESOLUTION=(\d+)x", line)
            if match:
                variants.append((int(match.group(1)), lines[index + 1]))
    eligible = [variant for variant in variants if variant[0] <= 828]
    if not eligible:
        raise RuntimeError(f"No suitable stream in {master_url}")
    return max(eligible)[1]


def save_video(name: str, video_id: str, source_page: str, entries: list[dict]) -> None:
    target = DEST / f"{name}.mp4"
    stream = stream_url(video_id)
    width = "640" if name in {"film-opening", "film-closing"} else "480"
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-i", stream, "-an",
            "-vf", f"scale={width}:-2", "-c:v", "libx265", "-crf", "31",
            "-preset", "medium", "-tag:v", "hvc1", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", "-x265-params", "log-level=error", str(target),
        ],
        check=True,
    )
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height:format=duration", "-of", "json", str(target)
    ]))
    stream_info = probe["streams"][0]
    entries.append({
        "id": name,
        "kind": "video",
        "role": "editorial-film",
        "path": f"nikeskims-world/{target.name}",
        "sourcePage": source_page,
        "sourceVideoID": video_id,
        "sourceManifestURL": f"https://api.nike.com/content/asset_video_manifest/v1/{video_id}",
        "sourceStreamURL": stream,
        "sha256": checksum(target),
        "width": stream_info["width"],
        "height": stream_info["height"],
        "duration": round(float(probe["format"]["duration"]), 3),
        "permission": "not_established_internal_reference_only",
    })


def main() -> None:
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True, exist_ok=True)
    landing = page_data(LANDING)
    guide = page_data(GUIDE)
    entries: list[dict] = []

    for name, card_id in LANDING_CARDS.items():
        card = landing["cards"][card_id]
        if card.get("containerType") == "video":
            video_id = card.get("portraitVideoId") or card["videoId"]
            save_video(name, video_id, LANDING, entries)
            save_image(f"{name}-poster", card["portraitPosterUrl"], "video-poster", entries)
        else:
            source = card.get("portraitURL") or card.get("landscapeURL")
            save_image(name, source, "identity" if name == "wordmark" else "editorial-still", entries, name == "wordmark")

    for group, card_id in LANDING_FILMSTRIPS.items():
        for index, slide in enumerate(landing["cards"][card_id]["slides"], start=1):
            source = slide.get("portraitURL") or slide.get("landscapeURL")
            save_image(f"{group}-{index:02d}", source, f"{group}-gallery", entries)

    collections: list[dict] = []
    for name, card_id in GUIDE_VIDEOS.items():
        card = guide["cards"][card_id]
        video_id = card.get("portraitVideoId") or card["videoId"]
        save_video(f"fabric-{name}", video_id, GUIDE, entries)
        save_image(f"fabric-{name}-poster", card["portraitPosterUrl"], "fabric-poster", entries)
        collections.append({
            "id": name,
            "title": re.sub(r"<br>\s*", " ", card["titleProps"]["text"], flags=re.I).strip(),
            "description": card["bodyProps"]["text"],
            "video": f"nikeskims-world/fabric-{name}.mp4",
            "poster": f"nikeskims-world/fabric-{name}-poster.jpg",
        })

    manifest = {
        "version": 1,
        "observedAt": "2026-09-19",
        "usage": "internal_reference_only_editorial_non_linking",
        "permission": "not_established",
        "sourcePages": [LANDING, GUIDE],
        "brown": "#241C19",
        "assets": entries,
        "collections": collections,
    }
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Imported {len(entries)} NikeSKIMS reference assets to {DEST}")


if __name__ == "__main__":
    main()
