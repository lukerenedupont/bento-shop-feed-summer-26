#!/usr/bin/env python3
"""Publish the explicitly reviewed native cover edit, never auto-approve branding.
Selections below were visually reviewed on 2026-09-17. This writes only to our
native snapshot and downloads higher-resolution copies of selected product art.
"""
import concurrent.futures
import hashlib
import json
import pathlib
import subprocess
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1] / 'ShopFeedSummer26/LibraryAssets'
reviewed_snapshot = ROOT / 'snapshot.json'
assert hashlib.sha256(reviewed_snapshot.read_bytes()).hexdigest() == '7768500df6cd602b20a414b203e2c154861f7e57e67ac878e143931976dd0d30', 'The catalog changed; review the cover selections again before publishing'
snapshot = json.loads(reviewed_snapshot.read_text())
products = {p['id']: p for p in snapshot['products']}
merchants = {m['id']: m for m in snapshot['merchants']}

# group index: (product position OR exact merchant ID, reviewed role, rationale)
SELECTIONS = {
    0: ('gid://shopify/Shop/60704260314', 'inContext', 'PORTA breakfast table: hosting context, distinct from the lead apron tile.'),
    1: ('gid://shopify/Shop/29035626574', 'editorial', 'Mast Books interior: a considered gift-shopping context, not another knife thumbnail.'),
    2: ('gid://shopify/Shop/6917057', 'editorial', 'Eckhaus street/editorial portrait, distinct from the studio product rail.'),
    3: (3, 'inContext', 'Savanna rug photographed in a dining room.'),
    4: (1, 'inContext', 'Brass bookends in use with books on a tiled shelf.'),
    5: (6, 'wornOrUsed', 'Travel knitwear worn as a complete comfortable outfit.'),
    7: (1, 'inContext', 'Obsidian lamp in a lit, styled tabletop scene.'),
    8: (0, 'wornOrUsed', 'Scarf worn in a portrait, not an isolated accessory packshot.'),
    9: (2, 'wornOrUsed', 'Activewear worn as a complete outfit.'),
    10: ('gid://shopify/Shop/1964605539', 'wornOrUsed', 'Veark kitchen-use photography: hands preparing bread.'),
    11: (2, 'inContext', 'Snow Peak shelter in use at a campsite at sunset.'),
    13: (2, 'wornOrUsed', 'Balenciaga tailoring worn as a complete look.'),
    14: (1, 'wornOrUsed', 'Warm, close-up jewelry styling for the fall edit.'),
    15: (2, 'wornOrUsed', 'Gold cuff worn against orange occasionwear.'),
    17: (0, 'wornOrUsed', 'Jil Sander bag carried on the body.'),
    18: (1, 'wornOrUsed', 'Dries clutch worn with a complete look.'),
    19: (2, 'inContext', 'Bellevue lamp in a room with a work cabinet and chair.'),
    20: (0, 'editorial', 'Hokusai volume staged against its illustrated print.'),
    21: (2, 'wornOrUsed', 'Graphic tee worn in a skate setting.'),
    22: ('gid://shopify/Shop/83980288319', 'inContext', 'FRAMA furnished interior, rather than an isolated furniture cutout.'),
    23: (1, 'wornOrUsed', 'On runners in an outdoor running scene beside a yellow car.'),
    24: ('gid://shopify/Shop/43179540638', 'editorial', 'Lemaire street portrait and architecture.'),
    25: (2, 'wornOrUsed', 'Derby shoes worn with tailoring.'),
    26: (1, 'inContext', 'White bed linen photographed on a made bed.'),
    27: ('domain:sohohome.com', 'inContext', 'Soho Home lounge interior with warm upholstered seating.'),
    28: (2, 'wornOrUsed', 'JW Anderson bag worn against a vivid red top.'),
    29: (1, 'wornOrUsed', 'Our Legacy coat worn as a complete look.'),
    30: (2, 'inContext', 'Peach lamps illuminating a dark room.'),
    31: (1, 'inContext', 'Carabiners in use with keys on a wooden surface.'),
}


def publish(entry):
    index, (selection, role, note) = entry
    group = snapshot['groups'][index]
    result = {'group': group['title'], 'role': role, 'note': note, 'reviewedAt': '2026-09-17'}
    if index == 2:
        result['portraitOffsetRatio'] = -0.5  # Keep the face inside a portrait viewport.
    if isinstance(selection, str):
        assert any(selection in products[pid]['merchantIDs'] for pid in group['productIDs'])
        asset = merchants[selection]['cover']
        assert asset and asset.startswith('./') and 'merchant-review/' not in asset
        result.update(sourceMerchantID=selection, path=asset, sourcePath=asset)
        image = ROOT / asset[2:]
    else:
        product = products[group['productIDs'][selection]]
        assert product['curated']
        url = product['originalImage']
        request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(request, timeout=25) as response:
            data = response.read()
        stem = hashlib.sha256(data).hexdigest()
        relative = f'catalog/editorial/{stem}.jpg'
        image = ROOT / relative
        image.parent.mkdir(parents=True, exist_ok=True)
        if not image.exists():
            with tempfile.TemporaryDirectory() as temp:
                source = pathlib.Path(temp) / 'image'
                source.write_bytes(data)
                subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '88', '-Z', '1600',
                                str(source), '--out', str(image)], check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        result.update(sourceProductID=product['id'], path='./' + relative, sourceURL=url)
    result['sha256'] = hashlib.sha256(image.read_bytes()).hexdigest()
    print(group['title'], flush=True)
    return index, result


with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    entries = dict(executor.map(publish, SELECTIONS.items()))
results = [entries[index] for index in sorted(entries)]
# The complete collection also has an explicitly selected cover; this does not
# alter the All Finds product ordering or assign approval to any other asset.
results.append({**results[0], 'group': '__all__', 'note': 'Selected table scene for the complete library overview.'})
(ROOT / 'editorial-covers.json').write_text(json.dumps(results, indent=2) + '\n')
print(f'Published {len(results)} explicit cover decisions to the native snapshot.')
