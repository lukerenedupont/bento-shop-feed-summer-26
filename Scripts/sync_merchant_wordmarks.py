#!/usr/bin/env python3
"""Resolve official merchant wordmarks and optionally build white asset sets.

The public storefront is only used to discover merchant-owned assets. The
resulting SVG/PNG files are copied into Assets.xcassets so the prototype does
not depend on favicons or third-party logo services at runtime.
"""

from __future__ import annotations

import argparse
import copy
import concurrent.futures
import html
import io
import json
import re
import shutil
import ssl
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_CATALOG = ROOT / "ShopFeedSummer26" / "Assets.xcassets" / "MerchantWordmarks"


@dataclass(frozen=True)
class Merchant:
    id: str
    name: str
    storefront: str


MERCHANTS = [
    Merchant("standards-manual", "Standards Manual", "https://standardsmanual.com"),
    Merchant("draw-down", "Draw Down", "https://draw-down.com"),
    Merchant("moma-design-store", "MoMA Design Store", "https://store.moma.org"),
    Merchant("lichen", "Lichen", "https://lichennyc.com"),
    Merchant("forom", "Forom", "https://foromshop.com"),
    Merchant("coming-soon", "Coming Soon", "https://comingsoonnewyork.com"),
    Merchant("fellow", "Fellow", "https://fellowproducts.com"),
    Merchant("kinto", "KINTO", "https://kinto-usa.com"),
    Merchant("xbloom", "xBloom", "https://xbloom.com"),
    Merchant("promix", "PROMIX", "https://promixnutrition.com"),
    Merchant("manmade", "Manmade", "https://manmadebrand.com"),
    Merchant("henson-shaving", "Henson Shaving", "https://hensonshaving.com"),
    Merchant("moza-racing", "MOZA Racing", "https://mozaracing.com"),
    Merchant("sim-lab", "Sim-Lab", "https://sim-lab.eu"),
    Merchant("svrn", "SVRN", "https://svrn.com"),
    Merchant("vitaly", "Vitaly", "https://vitalydesign.com"),
    Merchant("matteau", "Matteau", "https://matteau-store.com"),
    Merchant("rhode", "Rhode", "https://www.rhodeskin.com"),
    Merchant("ssense", "SSENSE", "https://www.ssense.com"),
    Merchant("color-wow", "Color Wow", "https://colorwowhair.com"),
    Merchant("alfaparf-milano", "Alfaparf Milano", "https://shopalfaparfusa.com"),
    Merchant("lange-hair", "L'ange Hair", "https://langehair.com"),
    Merchant("youfromme", "youfromme", "https://youfromme.com"),
    Merchant("comfrt", "Comfrt", "https://comfrt.com"),
    Merchant("satechi", "Satechi", "https://satechi.net"),
    Merchant("tomtoc", "tomtoc", "https://tomtoc.com"),
    Merchant("caldigit", "CalDigit", "https://www.caldigit.com"),
    Merchant("kith", "Kith", "https://kith.com"),
    Merchant("gantri", "Gantri", "https://gantri.com"),
    Merchant("city-lights-sf", "City Lights SF", "https://citylightssf.com"),
    Merchant("birkenstock", "Birkenstock", "https://www.birkenstock.com/us"),
    Merchant("new-balance", "New Balance", "https://www.newbalance.com"),
    Merchant("stone-island", "Stone Island", "https://www.stoneisland.com"),
    Merchant("matisse-footwear", "Matisse Footwear", "https://www.matissefootwear.com"),
    Merchant("concepts", "Concepts", "https://cncpts.com"),
    Merchant("nocs-provisions", "Nocs Provisions", "https://nocsprovisions.com"),
    Merchant("feature", "Feature", "https://feature.com"),
    Merchant("extra-butter", "Extra Butter", "https://extrabutterny.com"),
    Merchant("house-of-leon", "House of Leon", "https://houseofleon.com"),
]


# Explicit merchant-owned assets win over scraping. Keep this small: it is an
# audit trail for storefronts whose themes hide the header mark in JavaScript.
OVERRIDES: dict[str, str] = {
    "moma-design-store": "https://store.moma.org/cdn/shop/t/1359/assets/sprite-icon-767e27ca.svg?v=76814305896351509361786638334",
    "nocs-provisions": "https://www.nocsprovisions.com/cdn/shop/t/33/assets/nocs-logo-white.svg?v=157140221280410772331688765178",
    "kinto": "https://kinto-usa.com/cdn/shop/t/129/assets/sprite.svg?v=67551792836678614101758819346",
    "forom": "https://www.foromshop.com/cdn/shop/files/Forom_Logo.svg?v=1784177732&width=600",
    "fellow": "https://fellowproducts.com/cdn/shop/files/Fellow_Wordmark.svg?v=1770319887&width=600",
    "xbloom": "https://xbloom.com/cdn/shop/files/xbloom_logo_2988e005-3aa0-4291-9b12-7b1d23307bbe.png?v=1684639959&width=500",
    "manmade": "https://manmadebrand.com/cdn/shop/files/manmade_logo_final_-logo-on_dark_red-full-color-rgb_logo-_gray-_rgb_copy.svg?v=1697047918&width=600",
    "henson-shaving": "https://hensonshaving.com/cdn/shop/files/Wordmark_Horizontal_blue.svg",
    "moza-racing": "https://mozaracing.com/cdn/shop/files/MOZA_Racing_White.svg?v=1749175348&width=600",
    "sim-lab": "https://sim-lab.eu/cdn/shop/files/SimLab-logo-black.png?v=1750932852&width=600",
    "svrn": "https://www.svrn.com/cdn/shop/t/55/assets/svrnlogo.svg?v=27612235397982744121767630209",
    "vitaly": "https://www.vitalydesign.com/cdn/shop/files/wordmark_1.png?v=1686880369&width=600",
    "matteau": "https://matteau-store.com/cdn/shop/t/36/assets/logo-black.svg?v=77362779901093983241781138080",
    "rhode": "https://www.rhodeskin.com/cdn/shop/files/rhode-footer-logo_640x.png?v=1775257872",
    "comfrt": "https://comfrt.com/fast-image/fl_progressive:steep/comfrt/files/Comfrt-new-logo-black.svg?v=1769094857",
    "satechi": "https://satechi.com/cdn/shop/files/logo_2.png?v=1769640076&width=600",
    "gantri": "https://gantri.com/logo-large.png",
    "city-lights-sf": "https://citylightssf.com/cdn/shop/files/logo.webp?v=1717758224&width=600",
    "birkenstock": "https://www.birkenstock.com/on/demandware.static/Sites-US-Site/-/default/dw383709d8/images/logo.svg",
    "new-balance": "https://www.newbalance.com/on/demandware.static/-/Library-Sites-NBUS-NBCA/default/dw3de6aa04/images/homepage/footer/logo.svg",
    "stone-island": "https://www.stoneisland.com/on/demandware.static/Sites-StoneNA-Site/-/default/dw93150bef/images/logo.png",
    "matisse-footwear": "https://www.matissefootwear.com/cdn/shop/files/Matisse_Web_Logo_f5bbd820-4b8e-4894-b899-23097a115777.svg?v=1703794352&width=600",
    "coming-soon": "https://comingsoonnewyork.com/cdn/shop/t/38/assets/logo@3x.png?v=39346900649826370461727886665",
    "lichen": "https://www.lichennyc.com/cdn/shop/files/Lichen_Logo_1.png?v=1656369429&width=600",
    "promix": "https://promixnutrition.com/cdn/shop/t/175/assets/promix-protein-powder-logo.png?v=171405470187072173881772815812",
    "house-of-leon": "https://houseofleon.com/cdn/shop/files/House_of_Leon_Logo_Dark_360x.png?v=1645092990",
    "caldigit": "https://www.caldigit.com/wp-content/uploads/2022/10/CalDigit-Logo.png",
}

# A small number of official theme assets are SVG symbol sheets. The exact
# header wordmark can be extracted losslessly instead of shipping the entire
# sprite or falling back to a padded social-share image.
SVG_SYMBOL_IDS = {
    "moma-design-store": "logo",
    "kinto": "logo-kinto",
}

# Some modern themes author their official header logo inline and publish a
# stale asset URL in metadata. Resolve the exact live SVG by class instead of
# letting nearby campaign photography win the generic URL scorer.
INLINE_SVG_CLASSES = {"kith": "icon--site-logo"}
INLINE_SVG_ATTRIBUTE_PATTERNS = {
    "feature": r'\bviewBox=["\']0\s+0\s+235\s+32["\']',
}

# Kith's live header SVG is authored as white letter-shaped knockouts inside
# a solid box. The collection treatment needs those exact letters as a white
# transparent mark, so invert the knockout without redrawing the brand.
NEGATIVE_SILHOUETTE_IDS = {"kith"}

# These storefronts expose payment sprites, icon sheets, or social-card art
# near the word "logo" but not a reusable brand wordmark. A native text
# fallback is more accurate than bundling the wrong asset.
TEXT_FALLBACK_ONLY = {
    "standards-manual",
}


USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
SSL_CONTEXT = ssl.create_default_context()
URL_PATTERN = re.compile(
    r"(?:https?:)?//[^\"'<>\\\s]+|/[^\"'<>\\\s]+\.(?:svg|png|webp)(?:\?[^\"'<>\\\s]*)?",
    re.IGNORECASE,
)


@dataclass
class Candidate:
    url: str
    score: int
    aspect_ratio: float | None = None
    content: bytes | None = None
    extension: str | None = None


def fetch(url: str, timeout: int = 25, max_bytes: int = 8_000_000) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"})
    with urllib.request.urlopen(request, timeout=timeout, context=SSL_CONTEXT) as response:
        return response.read(max_bytes), response.headers.get("Content-Type", "")


def normalized_html(raw: bytes) -> str:
    text = raw.decode("utf-8", "replace")
    return html.unescape(text).replace("\\/", "/").replace("\\u0026", "&")


def discover_urls(merchant: Merchant, document: str) -> list[tuple[str, str]]:
    discovered: list[tuple[str, str]] = []
    for match in re.finditer(r"(?is).{0,260}(?:wordmark|logo).{0,320}", document):
        context = match.group(0)
        for raw_url in URL_PATTERN.findall(context):
            discovered.append((urllib.parse.urljoin(merchant.storefront, raw_url), context))

    # Schema.org Organization logos are often cleaner than the responsive
    # header image because they omit width transforms.
    for match in re.finditer(
        r'"logo"\s*:\s*(?:"([^\"]+)"|\{[^{}]{0,500}?"url"\s*:\s*"([^\"]+)")',
        document,
        re.IGNORECASE,
    ):
        raw_url = next((value for value in match.groups() if value), None)
        if raw_url:
            discovered.append((urllib.parse.urljoin(merchant.storefront, raw_url), match.group(0)))

    unique: dict[str, str] = {}
    for url, context in discovered:
        # Theme JavaScript and CSS commonly leave closing punctuation next to
        # an otherwise valid asset URL. It must never become part of the CDN
        # request or the stored provenance URL.
        clean = url.replace("&amp;", "&").rstrip(")],;\\")
        unique.setdefault(clean, context)
    return list(unique.items())


def base_score(url: str, context: str, merchant: Merchant) -> int:
    value = f"{url} {context}".lower()
    score = 0
    if "wordmark" in value:
        score += 90
    if "header-logo" in value or "header__heading-logo" in value:
        score += 45
    if "logo" in value:
        score += 35
    if url.lower().split("?", 1)[0].endswith(".svg"):
        score += 45
    if any(token in value for token in ("desktop", "primary", "main-logo", "brand-logo")):
        score += 12
    if merchant.name.lower() in value:
        score += 10
    if any(token in value for token in ("favicon", "apple-touch", "icon", "mark-only", "symbol")):
        score -= 80
    if any(token in value for token in ("footer", "payment", "social", "review")):
        score -= 18
    return score


def svg_aspect_ratio(content: bytes) -> float | None:
    text = content.decode("utf-8", "replace")
    view_box = re.search(r'viewBox=["\']\s*[-.\d]+\s+[-.\d]+\s+([.\d]+)\s+([.\d]+)', text)
    if view_box and float(view_box.group(2)):
        return float(view_box.group(1)) / float(view_box.group(2))
    width = re.search(r'\bwidth=["\']([.\d]+)', text)
    height = re.search(r'\bheight=["\']([.\d]+)', text)
    if width and height and float(height.group(1)):
        return float(width.group(1)) / float(height.group(1))
    return None


def inspect_candidate(candidate: Candidate) -> Candidate | None:
    try:
        content, content_type = fetch(candidate.url)
    except Exception:
        return None
    if content.lstrip().startswith(b"<svg") or "svg" in content_type:
        candidate.extension = "svg"
        candidate.aspect_ratio = svg_aspect_ratio(content)
    else:
        try:
            image = Image.open(io.BytesIO(content))
            candidate.extension = "png"
            candidate.aspect_ratio = image.width / image.height if image.height else None
        except Exception:
            return None
    candidate.content = content
    if candidate.aspect_ratio is not None:
        if candidate.aspect_ratio >= 1.8:
            candidate.score += 35
        elif candidate.aspect_ratio < 1.15:
            candidate.score -= 55
    return candidate


def resolve(merchant: Merchant) -> tuple[Merchant, list[Candidate], str | None]:
    if merchant.id in TEXT_FALLBACK_ONLY:
        return merchant, [], "storefront has no verified reusable wordmark asset"
    if merchant.id in INLINE_SVG_CLASSES or merchant.id in INLINE_SVG_ATTRIBUTE_PATTERNS:
        try:
            raw, _ = fetch(merchant.storefront)
            document = normalized_html(raw)
            if merchant.id in INLINE_SVG_CLASSES:
                class_name = re.escape(INLINE_SVG_CLASSES[merchant.id])
                attribute_pattern = rf'\bclass=["\'][^"\']*\b{class_name}\b[^"\']*["\']'
                fragment = INLINE_SVG_CLASSES[merchant.id]
            else:
                attribute_pattern = INLINE_SVG_ATTRIBUTE_PATTERNS[merchant.id]
                fragment = "header-wordmark"
            match = re.search(
                rf'<svg\b(?=[^>]*{attribute_pattern})[^>]*>.*?</svg>',
                document,
                re.IGNORECASE | re.DOTALL,
            )
            if not match:
                return merchant, [], "official inline wordmark not found"
            content = match.group(0).encode("utf-8")
            candidate = Candidate(
                f"{merchant.storefront}#inline-{fragment}",
                1_000,
                svg_aspect_ratio(content),
                content,
                "svg",
            )
            return merchant, [candidate], None
        except Exception as error:
            return merchant, [], f"{type(error).__name__}: {error}"
    if merchant.id in OVERRIDES:
        inspected = inspect_candidate(Candidate(OVERRIDES[merchant.id], 1_000))
        return merchant, [inspected] if inspected else [], None if inspected else "override failed"
    try:
        raw, _ = fetch(merchant.storefront)
        document = normalized_html(raw)
        candidates = [Candidate(url, base_score(url, context, merchant)) for url, context in discover_urls(merchant, document)]
        candidates.sort(key=lambda item: item.score, reverse=True)
        inspected: list[Candidate] = []
        for candidate in candidates[:10]:
            resolved = inspect_candidate(candidate)
            if resolved:
                inspected.append(resolved)
        inspected.sort(key=lambda item: item.score, reverse=True)
        return merchant, inspected[:3], None
    except Exception as error:
        return merchant, [], f"{type(error).__name__}: {error}"


def white_svg(content: bytes) -> bytes:
    text = content.decode("utf-8", "replace")
    # Storefront assets can contain CRLFs and whitespace-only lines. Normalize
    # generated SVGs so rerunning the sync keeps the asset catalog diff-clean.
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = "\n".join(line.rstrip() for line in text.splitlines())
    # Preserve explicit transparency while making every painted vector white.
    text = re.sub(r'(?i)(fill|stroke)=(\"|\')(?!none|transparent|url\()[^\"\']+\2', r'\1=\2#FFFFFF\2', text)
    text = re.sub(r'(?i)(fill|stroke)\s*:\s*(?!none|transparent|url\()[^;}]+', r'\1:#FFFFFF', text)
    # Paths without their own paint use SVG's default black. Set a white root
    # fill so those shapes normalize too, while explicit `none` still wins.
    text = re.sub(r"<svg\b(?![^>]*\bfill=)", '<svg fill="#FFFFFF"', text, count=1, flags=re.IGNORECASE)
    return (text.rstrip() + "\n").encode("utf-8")


def extracted_svg_symbol(content: bytes, symbol_id: str) -> bytes:
    root = ElementTree.fromstring(content)
    symbol = next(
        (element for element in root.iter() if element.attrib.get("id") == symbol_id),
        None,
    )
    if symbol is None:
        raise ValueError(f"SVG symbol {symbol_id!r} not found")

    view_box = symbol.attrib.get("viewBox")
    if not view_box:
        width = re.sub(r"[^.\d]", "", symbol.attrib.get("width", ""))
        height = re.sub(r"[^.\d]", "", symbol.attrib.get("height", ""))
        if not width or not height:
            raise ValueError(f"SVG symbol {symbol_id!r} has no dimensions")
        view_box = f"0 0 {width} {height}"

    namespace = "http://www.w3.org/2000/svg"
    ElementTree.register_namespace("", namespace)
    isolated = ElementTree.Element(f"{{{namespace}}}svg", {"viewBox": view_box})
    for child in symbol:
        isolated.append(copy.deepcopy(child))
    return ElementTree.tostring(isolated, encoding="utf-8", xml_declaration=True)


def extracted_negative_wordmark(content: bytes) -> bytes:
    source = ElementTree.fromstring(content)
    view_box = source.attrib.get("viewBox")
    if not view_box:
        raise ValueError("negative wordmark SVG has no viewBox")
    min_x, min_y, width, height = view_box.split()

    namespace = "http://www.w3.org/2000/svg"
    ElementTree.register_namespace("", namespace)
    output = ElementTree.Element(f"{{{namespace}}}svg", {"viewBox": view_box})
    definitions = ElementTree.SubElement(output, f"{{{namespace}}}defs")
    mask = ElementTree.SubElement(
        definitions,
        f"{{{namespace}}}mask",
        {"id": "letter-knockout", "maskUnits": "userSpaceOnUse"},
    )
    ElementTree.SubElement(
        mask,
        f"{{{namespace}}}rect",
        {"x": min_x, "y": min_y, "width": width, "height": height, "fill": "#FFFFFF"},
    )
    for child in source:
        if child.tag.rsplit("}", 1)[-1] in {"title", "desc", "defs"}:
            continue
        knockout = copy.deepcopy(child)
        knockout.set("fill", "#000000")
        mask.append(knockout)
    ElementTree.SubElement(
        output,
        f"{{{namespace}}}rect",
        {
            "x": min_x,
            "y": min_y,
            "width": width,
            "height": height,
            "fill": "#FFFFFF",
            "mask": "url(#letter-knockout)",
        },
    )
    return ElementTree.tostring(output, encoding="utf-8", xml_declaration=True)


def white_png(content: bytes) -> bytes:
    image = Image.open(io.BytesIO(content)).convert("RGBA")
    source_pixels = list(image.getdata())
    has_transparency = any(alpha < 250 for _, _, _, alpha in source_pixels)

    # Opaque storefront files frequently place a dark wordmark on white (or a
    # white mark on black). Recover transparency from the border color before
    # whitening so the asset does not become a solid rectangle in the card.
    if not has_transparency:
        width, height = image.size
        border = []
        for x in range(width):
            border.append(source_pixels[x])
            border.append(source_pixels[(height - 1) * width + x])
        for y in range(height):
            border.append(source_pixels[y * width])
            border.append(source_pixels[y * width + width - 1])
        border_luminance = sum((r + g + b) / 3 for r, g, b, _ in border) / max(len(border), 1)

    pixels = []
    for red, green, blue, alpha in source_pixels:
        # Official transparent raster marks retain their authored antialiasing.
        luminance = (red + green + blue) / (3 * 255)
        if has_transparency:
            resolved_alpha = alpha
        elif border_luminance >= 128:
            resolved_alpha = int((1 - luminance) * 255)
        else:
            resolved_alpha = int(luminance * 255)
        pixels.append((255, 255, 255, resolved_alpha))
    image.putdata(pixels)

    # Remove compression haze and storefront-canvas padding. Without this,
    # an otherwise correct wordmark can occupy only a small fraction of its
    # UIImage frame (social share images are a common offender).
    alpha = image.getchannel("A").point(lambda value: 0 if value < 10 else value)
    image.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds:
        image = image.crop(bounds)
        padding = max(2, round(max(image.size) * 0.015))
        padded = Image.new(
            "RGBA",
            (image.width + padding * 2, image.height + padding * 2),
            (255, 255, 255, 0),
        )
        padded.paste(image, (padding, padding), image)
        image = padded

    output = io.BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def write_asset(merchant: Merchant, candidate: Candidate) -> None:
    assert candidate.content is not None and candidate.extension is not None
    asset_dir = ASSET_CATALOG / f"merchant-wordmark-{merchant.id}.imageset"
    if asset_dir.is_dir():
        shutil.rmtree(asset_dir)
    asset_dir.mkdir(parents=True, exist_ok=True)
    filename = f"merchant-wordmark-{merchant.id}.{candidate.extension}"
    source = candidate.content
    if candidate.extension == "svg" and merchant.id in SVG_SYMBOL_IDS:
        source = extracted_svg_symbol(source, SVG_SYMBOL_IDS[merchant.id])
    if candidate.extension == "svg" and merchant.id in NEGATIVE_SILHOUETTE_IDS:
        rendered = extracted_negative_wordmark(source)
    else:
        rendered = white_svg(source) if candidate.extension == "svg" else white_png(source)
    (asset_dir / filename).write_bytes(rendered)
    contents = {
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": candidate.extension == "svg"},
    }
    (asset_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_catalog_metadata(
    resolved: Iterable[tuple[Merchant, list[Candidate], str | None]],
    preserve_existing: bool = False,
) -> None:
    ASSET_CATALOG.mkdir(parents=True, exist_ok=True)
    (ASSET_CATALOG / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    resolved_manifest = {
        merchant.id: {
            "name": merchant.name,
            "asset": f"merchant-wordmark-{merchant.id}" if candidates else None,
            "source": candidates[0].url if candidates else None,
            "error": error,
        }
        for merchant, candidates, error in resolved
    }
    manifest_path = ASSET_CATALOG / "manifest.json"
    manifest = {}
    if preserve_existing and manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text())
        except (OSError, json.JSONDecodeError):
            manifest = {}
    manifest.update(resolved_manifest)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    for merchant, candidates, _ in resolved:
        if candidates:
            continue
        stale_asset = ASSET_CATALOG / f"merchant-wordmark-{merchant.id}.imageset"
        if stale_asset.is_dir():
            shutil.rmtree(stale_asset)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="write resolved white assets into Assets.xcassets")
    parser.add_argument("--only", help="comma-separated merchant ids to resolve")
    arguments = parser.parse_args()
    selected_ids = set(arguments.only.split(",")) if arguments.only else None
    selected_merchants = [merchant for merchant in MERCHANTS if selected_ids is None or merchant.id in selected_ids]

    # Some storefront homepages are multi-megabyte documents. Resolve them one
    # at a time so the sync works reliably on developer laptops and in CI.
    resolved: list[tuple[Merchant, list[Candidate], str | None]] = []
    for merchant in selected_merchants:
        merchant, candidates, error = resolve(merchant)
        if candidates:
            best = candidates[0]
            ratio = f"{best.aspect_ratio:.2f}" if best.aspect_ratio else "?"
            print(f"{merchant.id}\t{best.score}\t{ratio}\t{best.url}", flush=True)
            if arguments.write:
                write_asset(merchant, best)
            resolved.append((merchant, [Candidate(best.url, best.score, best.aspect_ratio)], error))
        else:
            print(f"{merchant.id}\tMISSING\t{error or 'no usable logo candidate'}", flush=True)
            resolved.append((merchant, [], error))

    if arguments.write:
        # A targeted audit must also remove an older, now-rejected asset. If
        # this cleanup only ran during a full sync, bad logos could survive a
        # precise `--only` correction and continue shipping from the catalog.
        for merchant, candidates, _ in resolved:
            if candidates:
                continue
            stale_asset = ASSET_CATALOG / f"merchant-wordmark-{merchant.id}.imageset"
            if stale_asset.is_dir():
                shutil.rmtree(stale_asset)

        write_catalog_metadata(resolved, preserve_existing=selected_ids is not None)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
