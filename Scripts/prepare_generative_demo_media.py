#!/usr/bin/env python3
"""PROTOTYPE: freeze exact catalog photography for simulator reviews.
Requires Pillow to prepare; --check uses only the standard library.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json'
DEST = ROOT / 'ShopFeedSummer26/PrototypeCardMedia'
PRODUCTS = {
    'feature-salomon': [6882429993031, 6882430025799, 6882429796423],
    'house-of-leon': [7873592688813, 7873592721581, 8590788591789, 7014265454765],
    'standards-manual': [1424479363, 5842516163, 92039479320, 3933686169669],
    'fellow': [7507479003236, 2055410221171, 4807420739684],
    'forom': [9080102322307, 8817998889091],
    'lichen': [12518383059262, 12462683128126],
}
# An exact alternate from this SKU's catalog gallery, not another chair's photo.
PRESENTATIONS = [
    ('house-of-leon', 7873592721581, 'comparison',
     'https://cdn.shopify.com/s/files/1/0593/2217/1565/files/chrome-leather-chair-house-of-leon.png?v=1775260744'),
]


def normalized(url):
    return 'https:' + url if url.startswith('//') else url


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    merchants = {m['id']: m for m in json.loads(CATALOG.read_text())['merchants']}
    PRODUCTS['standards-manual'] = [int(p['id']) for p in merchants['standards-manual']['products']]
    if not args.check:
        from PIL import Image, ImageOps
        DEST.mkdir(exist_ok=True)
    manifest = DEST / 'SOURCES.json'
    existing = {r['filename']: r for r in json.loads(manifest.read_text())} if manifest.exists() else {}
    requests = [(m, p, '', None) for m, ids in PRODUCTS.items() for p in ids] + PRESENTATIONS
    records = []
    for merchant_id, product_id, presentation, preferred in requests:
        product = next(p for p in merchants[merchant_id]['products'] if int(p['id']) == product_id)
        urls = list(dict.fromkeys(normalized(u) for u in [product['imageUrl']] + product.get('allImageUrls', [])))
        if preferred:
            assert preferred in urls, f'Non-canonical presentation image for {product_id}'
            urls = [preferred]
        suffix = f'-{presentation}' if presentation else ''
        filename = f'prototype-product-{merchant_id}-{product_id}{suffix}.jpg'
        target = DEST / filename
        cached = existing.get(filename)
        if args.check:
            assert target.is_file(), f'Missing exact product media: {filename}'
            assert cached and cached['sourceURL'] in urls, f'Non-canonical image for {product_id}'
            url = cached['sourceURL']
        elif cached and target.is_file() and cached['sourceURL'] in urls and hashlib.sha256(target.read_bytes()).hexdigest() == cached['sha256']:
            # Preserve the frozen bytes; only fetch new/missing/changed records.
            url = cached['sourceURL']
        else:
            raw = None
            for url in urls:
                request = urllib.request.Request(url, headers={'User-Agent': 'ShopFeedPrototype/1.0'})
                try:
                    with urllib.request.urlopen(request, timeout=40) as response:
                        raw = response.read()
                    break
                except urllib.error.HTTPError as error:
                    if error.code != 404:
                        raise
            assert raw is not None, f'No verified catalog image remains for {product_id}'
            image = ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert('RGBA')
            # Additional library tiles need 2x/3x tile resolution, not full
            # originals. Existing frozen review images retain their bytes.
            side = 600 if merchant_id == 'standards-manual' else 840
            image.thumbnail((side, side))
            canvas = Image.new('RGB', image.size, 'white')
            canvas.paste(image, mask=image.getchannel('A'))
            canvas.save(target, quality=84, optimize=True)
            print(filename, target.stat().st_size)
        records.append(dict(merchantID=merchant_id, productID=product_id, title=product['title'],
                            sourceURL=url, filename=filename, sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    if args.check:
        assert records == json.loads(manifest.read_text()), 'Media provenance mismatch'
    else:
        manifest.write_text(json.dumps(records, indent=2) + '\n')
    print(f'Validated {len(records)} exact catalog images and provenance')


if __name__ == '__main__':
    main()
