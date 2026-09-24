#!/usr/bin/env python3
"""Validate the packaged native library without changing its source."""
import hashlib
import json
import pathlib
import sys
from datetime import datetime
from decimal import Decimal
from urllib.parse import urlparse, parse_qs

root = pathlib.Path(sys.argv[1]).resolve()
snapshot = json.loads((root / 'snapshot.json').read_text())
manifest = json.loads((root / 'asset-manifest.json').read_text())
selected = snapshot['selectedIds']
products = snapshot['products']
assert len(selected) == len(set(selected)) == 328, 'Expected 328 unique editorial IDs'
assert [p['id'] for p in products if p['curated']] == selected, 'Editorial order changed'
assert len({p['nativeID'] for p in products}) == len(products), 'Native product ID collision'
merchant_records = snapshot['merchants']
merchants = {m['id'] for m in merchant_records}
confirmed_merchants = {
    m['id'] for m in merchant_records
    if m.get('platformOutcome') == 'confirmed_shopify'
    and m['id'].startswith('gid://shopify/Shop/')
}
published_products = [
    p for p in products
    if p['id'] in selected and set(p['merchantIDs']) & confirmed_merchants
]
assert len(confirmed_merchants) == 79, 'Confirmed Shopify merchant set changed'
assert len(published_products) == 213, 'Shopify-publishable product set changed'
assert all(p['merchantIDs'] and set(p['merchantIDs']) <= merchants for p in products), 'Missing exact merchant join'
assert all(p['price'] or not p['currency'] for p in products), 'Unknown price acquired a currency'
for relative, digest in manifest.items():
    path = (root / relative).resolve()
    assert path.is_relative_to(root) and 'merchant-review' not in path.parts, 'Unsafe asset path'
    assert path.is_file(), f'Missing asset: {relative}'
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, f'Changed source asset: {relative}'
for value in snapshot['nativeAssets'].values():
    path = (root / value.removeprefix('./')).resolve()
    assert path.is_relative_to(root) and path.is_file(), f'Missing native raster: {value}'
assert not list(root.rglob('merchant-review')), 'Review assets must not ship'
cover_file = root / 'editorial-covers.json'
if cover_file.exists():
    groups = {g['title']: set(g['productIDs']) for g in snapshot['groups']}
    groups['__all__'] = set(selected)
    by_id = {p['id']: p for p in products}
    for cover in json.loads(cover_file.read_text()):
        assert cover['note'] and cover['role'] in {'inContext', 'wornOrUsed', 'editorial', 'merchantPost'}
        path = (root / cover['path'].removeprefix('./')).resolve()
        assert path.is_relative_to(root) and 'merchant-review' not in path.parts
        assert hashlib.sha256(path.read_bytes()).hexdigest() == cover['sha256'], 'Reviewed cover changed'
        members = groups[cover['group']]
        if cover.get('sourceProductID'):
            assert cover['sourceProductID'] in members, 'Cover product is outside this edit'
        if cover.get('sourceMerchantID'):
            assert any(cover['sourceMerchantID'] in by_id[pid]['merchantIDs'] for pid in members), 'Cover merchant is outside this edit'
wordmark_file = root / 'wordmarks.json'
if wordmark_file.exists():
    marks = json.loads(wordmark_file.read_text())
    for asset in marks['assets'].values():
        assert 'pending' not in asset['review'].lower(), 'Unreviewed wordmark must not ship'
        assert asset['tier'] in {'launch-approved', 'approved', 'cosmos-brands'}
        for kind in ['white', 'original']:
            if kind not in asset:
                continue
            variant = asset[kind]
            for field, digest in [('path', variant['nativeSha256']), ('originalPath', variant['sha256'])]:
                path = (root / variant[field].removeprefix('./')).resolve()
                assert path.is_relative_to(root) and 'sweep-generated' not in path.parts
                assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, 'Wordmark checksum mismatch'
    assert set(marks['merchantKeys']) <= merchants, 'Wordmark has an unknown merchant mapping'
    assert set(marks['merchantKeys'].values()) | set(marks['groupKeys'].values()) <= set(marks['assets'])
research = json.loads((root / 'running-research.json').read_text())
research_merchants = {m['id']: m for m in research['merchants']}
assert all(m['platformOutcome'] == 'confirmed_shopify' and mid.startswith('gid://shopify/Shop/')
           for mid, m in research_merchants.items()), 'Unconfirmed research merchant'
film = json.loads((root / 'catalog/research-media/cover-film.json').read_text())
film_merchant = research_merchants[film['sourceMerchantID']]
assert any(o['merchantID'] == film['sourceMerchantID'] for o in research['offers'])
assert urlparse(film['sourcePage']).scheme == 'https'
assert urlparse(film['sourcePage']).hostname == urlparse(film_merchant['url']).hostname
assert urlparse(film['videoURL']).scheme == 'https' and urlparse(film['videoURL']).hostname == 'player.vimeo.com'
assert 0 < film['loopDuration'] <= 10 < film['sourceDuration'], 'Cover must remain a short excerpt'
assert film['sourceWidth'] > 0 and film['sourceHeight'] > 0
assert film['rightsStatus'] and film['credit'] and datetime.fromisoformat(film['checkedAt']).tzinfo
poster = (root / film['posterPath']).resolve()
assert poster.is_relative_to(root) and poster.is_file(), 'Unsafe or missing film poster'
assert hashlib.sha256(poster.read_bytes()).hexdigest() == film['posterSHA256'], 'Film poster changed'
ids = {p['id'] for p in products}
native_ids = {p['nativeID'] for p in products}
for offer in research['offers']:
    assert offer['id'] not in ids and offer['nativeID'] not in native_ids, 'Research product collision'
    ids.add(offer['id'])
    native_ids.add(offer['nativeID'])
    merchant = research_merchants[offer['merchantID']]
    source = urlparse(offer['sourceURL'])
    assert source.scheme == 'https' and source.hostname == urlparse(merchant['url']).hostname
    assert int(parse_qs(source.query)['variant'][0]) in offer['variantIDs'], 'Wrong source variant'
    amount = Decimal(offer['price'])
    assert amount.is_finite() and amount > 0 and offer['currency'] == 'USD'
    if offer['section'] == 'shoes':
        assert offer['color'] and len(offer['usMensSizes']) == len(offer['variantIDs'])
        assert all(Decimal(size) > 0 for size in offer['usMensSizes'])
    if offer['referencePrice'] is not None:
        reference = Decimal(offer['referencePrice'])
        assert reference.is_finite() and reference > amount, 'Invalid markdown reference'
    assert offer['availableVariants'] and len(offer['variantIDs']) == len(offer['availableVariants'])
    assert offer['observedImageID'] > 0 and offer['image'] == offer['images'][0]
    assert datetime.fromisoformat(offer['observedAt']).tzinfo is not None
for policy in research['shippingPolicies']:
    merchant = research_merchants[policy['merchantID']]
    assert urlparse(policy['sourceURL']).hostname == urlparse(merchant['url']).hostname
    assert policy['summary'] and policy['detail'] and datetime.fromisoformat(policy['observedAt']).tzinfo
print(f'Validated research supplement: {len(research["offers"])} offers; '
      f'combined publication: {len(published_products) + len(research["offers"])} products / '
      f'{len(confirmed_merchants | set(research_merchants))} confirmed Shopify merchants')
print(
    f'Validated library source: {len(selected)} curated products, {len(merchants)} merchants; '
    f'published Shopify set: {len(published_products)} products, {len(confirmed_merchants)} merchants; '
    f'{len(manifest)} original local assets'
)
