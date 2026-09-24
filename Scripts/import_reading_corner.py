#!/usr/bin/env python3
"""Deliberate first-party USD snapshot; never changes the base library.
Run only when refreshing the reviewed Oblist set, then review prices and images.
"""
import datetime
import hashlib
import json
import pathlib
import re
from decimal import Decimal
from html import unescape
from import_running_research import fetch

ROOT = pathlib.Path(__file__).resolve().parents[1] / 'ShopFeedSummer26/LibraryAssets'
MERCHANT = 'gid://shopify/Shop/67152904457'
SELECTION = [
    ('chair', '594146-sedia-tonda', 'Wood', 'Stained birch plywood. A sculptural, unupholstered seat; comfort has not been tested.'),
    ('table', '635658-cubo', None, 'Stained birch plywood, with an adjustable height of 32–55 cm.'),
    ('light', 'floor-lamp-1', None, 'Brushed stainless steel. 140 cm tall, 35 cm wide; E27-compatible. Bulb not verified.'),
    ('chair', '161659-small-palma', None, 'An open, slatted back and a slimmer profile. A different silhouette, not a tested comfort upgrade.'),
    ('light', 'la-lampe-bien-faite-taupe', None, 'A compact table lamp instead of a floor light. Uses table space; G9 LED bulb not included.'),
    ('table', '633555-figure-side-table-4', None, 'A rounded top and sculptural legs. Check the chosen size and finish at The Oblist; the source photo shows more than one table.'),
    ('chair', 'melides-chair', None, 'Hand-crafted solid oak, formed from slotted elements. Made to order; confirm the production lead time at the shop.'),
    ('chair', '382442-vaga-chair', None, 'Solid walnut and oak with a matte finish. Made to order in Portugal; comfort has not been tested.'),
    ('chair', '447110-fish-chair', None, 'A metal chair with fishing-net buoys. An experimental direction, not a comfort-tested reading chair.'),
]


def main():
    merchant = next(m for m in json.loads((ROOT / 'snapshot.json').read_text())['merchants'] if m['id'] == MERCHANT)
    assert merchant['platformOutcome'] == 'confirmed_shopify'
    pieces = []
    for role, handle, variant_title, note in SELECTION:
        source = 'https://oblist.com/products/' + handle
        page = fetch(source + '?currency=USD')
        assert re.search(r'"shopId"\s*:\s*67152904457', page)
        assert re.search(r'Shopify\.currency\s*=\s*\{\s*"active":"USD"', page)
        product = json.loads(fetch(source + '.json?currency=USD'))['product']
        ajax = json.loads(fetch(source + '.js?currency=USD'))
        available = {v['id']: v for v in ajax['variants'] if v.get('available')}
        variants = [v for v in product['variants'] if v['id'] in available and (variant_title is None or v['title'] == variant_title)]
        assert variants, (handle, 'No available reviewed variant')
        lead = variants[0]  # Preserve authored variant order; do not silently pick a cheaper finish.
        assert lead['price_currency'] == 'USD'
        amount = Decimal(lead['price'])
        assert amount.is_finite() and amount > 0 and amount * 100 == available[lead['id']]['price']
        image = next((i for i in product['images'] if i['id'] == lead.get('image_id')), product['images'][0])
        images = [image['src']] + [i['src'] for i in product['images'] if i['id'] != image['id']]
        observed = datetime.datetime.now(datetime.timezone.utc).isoformat()
        url = source + '?variant=' + str(lead['id']) + '&currency=USD'
        record = dict(id=f'oblist:{product["id"]}', nativeID=product['id'], curated=True,
                      merchantIDs=[MERCHANT], title=product['title'], brand=product['vendor'],
                      group='Reading corner', image=images[0], originalImage=images[0], url=url,
                      price=lead['price'], currency='USD', description=unescape(re.sub('<[^>]+>', ' ', product['body_html'])),
                      commerceCheck='USD snapshot · Recheck price, availability and delivery at The Oblist.',
                      checkedAt=observed, images=images)
        pieces.append(dict(role=role, handle=handle, variantID=lead['id'], variantTitle=lead['title'],
                           observedImageID=image['id'], imageAspectRatio=image['width'] / image['height'],
                           amountCents=int(amount * 100), note=note, product=record))
        print(product['title'], lead['title'], lead['price'], image['src'])
    cover_path = 'catalog/reading-corner/living-room.jpg'
    cover = dict(group='Reading corner', path=cover_path, role='editorial',
                 note='The Oblist Living Room Edit collection image. Inspiration, not the selected products or a generated room.',
                 sha256=hashlib.sha256((ROOT / cover_path).read_bytes()).hexdigest(), sourceMerchantID=MERCHANT)
    payload = dict(pieces=pieces, cover=cover,
                   coverSource='https://oblist.com/collections/mid-century-modern-living-room',
                   coverImageSource='https://cdn.shopify.com/s/files/1/0671/5290/4457/collections/Capture_d_ecran_2024-02-08_a_15.14.35.png?v=1726065948',
                   rightsStatus='Internal-reference media; production redistribution clearance outstanding.')
    (ROOT / 'reading-corner.json').write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
