#!/usr/bin/env python3
"""Validate the frozen review's catalog, dossier mapping, and asset provenance offline."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'ShopFeedSummer26/QuietReviewMedia'
SOURCE = ROOT / 'ReviewSources'
catalog = json.loads((MEDIA / 'quiet-review-catalog.json').read_text())
records = json.loads((SOURCE / 'quiet-review-assets.json').read_text())
products = {(m['id'], int(p['id'])): p for m in catalog['merchants'] for p in m['products']}
assert len(products) == sum(len(m['products']) for m in catalog['merchants']), 'Duplicate product references'
for record in records:
    asset = MEDIA / record['filename']
    assert asset.is_file(), f'Missing {asset}'
    assert hashlib.sha256(asset.read_bytes()).hexdigest() == record['sha256'], f'Changed asset: {asset}'
    if not record['generated'] and 'productID' in record:
        product = products[(record['merchantID'], record['productID'])]
        sources = ['https:' + u if u.startswith('//') else u for u in [product['imageUrl']] + product.get('allImageUrls', [])]
        assert record['sourceURL'] in sources, f'Unmapped product media: {asset}'
        assert product['shopUrl'].startswith('https://'), f'Missing canonical destination: {asset}'
        assert float(product['price']) > 0, f'Invalid price: {asset}'

mapping = json.loads((SOURCE / 'dossier-product-mappings.json').read_text())
for gid, ref in mapping['mappings'].items():
    assert (ref['merchantID'], ref['productID']) in products, f'Unresolved dossier mapping: {gid}'
assert len(mapping['unresolved']) == 2, 'Do not silently guess the sneaker/overshirt mappings'
print(f'Validated {len(products)} products, {len(records)} assets, and {len(mapping["mappings"])} exact Dossier mappings')
