#!/usr/bin/env python3
"""Offline integrity checks for the nine-dossier visual review."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'ShopFeedSummer26/DossierReviewMedia'
SOURCE = ROOT / 'ReviewSources/DossierLibrary'
records = json.loads((MEDIA / 'dossier-review-library.json').read_text())
catalog = json.loads((MEDIA / 'dossier-review-merchants.json').read_text())
mappings = json.loads((SOURCE / 'product-mappings.json').read_text())
hashes = json.loads((SOURCE / 'asset-hashes.json').read_text())
products = {(m['id'], int(p['id'])): p for m in catalog['merchants'] for p in m['products']}
assert len(records) == 9 and len({r['key'] for r in records}) == 9
assert sum(r['defaultVisible'] for r in records) == 6
assert len(products) == len(mappings) == 31
assert len({(v['merchantID'], v['productID']) for v in mappings.values()}) == len(mappings), 'Surrogate collision'
for item in hashes:
    path = MEDIA / item['file']
    assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], f'Asset changed: {path}'
for r in records:
    assert r['objects'], f'No anchor: {r["key"]}'
    for o in r['objects']:
        ref=o['reference'];product=products[(ref['merchantID'], ref['productID'])]
        assert product['price']=='Check merchant for price', 'Do not infer a currency from an export amount'
        for filename in [o['image']+'.jpg', o['image']+'.png', o['originalImage']+'.jpg']:
            assert (MEDIA/filename).is_file(), f'Missing {filename}'
    for filename in [*r['images'].values(), *r['videos'].values()]:
        assert (MEDIA/filename).is_file(), f'Missing {filename}'
    if r['family']=='gift':
        assert [o['role'] for o in r['objects']]==['Anchor','Kids desk organizer'], 'Do not bundle an alternative phone or an access point as required accessories'
print(f'Validated {len(records)} dossiers, 6 default cards, {len(products)} source product mappings, {len(hashes)} asset hashes')
