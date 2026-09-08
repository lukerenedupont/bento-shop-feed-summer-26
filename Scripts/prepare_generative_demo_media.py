#!/usr/bin/env python3
"""PROTOTYPE: freeze exact catalog packshots for reliable simulator reviews.
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
    'standards-manual': [1424479363, 5842516163, 9539848971, 3933686169669],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    merchants = {m['id']: m for m in json.loads(CATALOG.read_text())['merchants']}
    # The merchant job uses the first four canonical products, not made-up releases.
    PRODUCTS['standards-manual'] = [int(p['id']) for p in merchants['standards-manual']['products'][:4]]
    if not args.check:
        from PIL import Image, ImageOps
        DEST.mkdir(exist_ok=True)
    existing = {r['filename']: r for r in json.loads((DEST / 'SOURCES.json').read_text())} if args.check else {}
    records = []
    for merchant_id, ids in PRODUCTS.items():
        inventory = {int(p['id']): p for p in merchants[merchant_id]['products']}
        for product_id in ids:
            product = inventory[product_id]
            urls = list(dict.fromkeys([product['imageUrl']] + product.get('allImageUrls', [])))
            filename = f'prototype-product-{merchant_id}-{product_id}.jpg'
            target = DEST / filename
            if args.check:
                assert target.is_file(), f'Missing exact product media: {filename}'
                url = existing[filename]['sourceURL']
                assert url in urls, f'Non-canonical image for {product_id}'
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
                image.thumbnail((840, 840))
                canvas = Image.new('RGB', image.size, 'white')
                canvas.paste(image, mask=image.getchannel('A'))
                canvas.save(target, quality=84, optimize=True)
                print(filename, target.stat().st_size)
            records.append(dict(merchantID=merchant_id, productID=product_id, title=product['title'],
                                sourceURL=url, filename=filename, sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    if args.check:
        assert records == json.loads((DEST / 'SOURCES.json').read_text()), 'Media provenance mismatch'
    else:
        (DEST / 'SOURCES.json').write_text(json.dumps(records, indent=2) + '\n')
    print(f'Validated {len(records)} exact catalog images and provenance')


if __name__ == '__main__':
    main()
