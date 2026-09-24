#!/usr/bin/env python3
"""Refresh selected USD storefront observations. No agent-generated FX rates.
Prices, reference prices and stock must agree across Shopify's page/JSON/Ajax
surfaces. Reviewed men's shoe color/US-size joins are explicit below.
"""
import concurrent.futures
import datetime
import json
import pathlib
import re
import urllib.request
from decimal import Decimal
from html import unescape

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'ShopFeedSummer26/LibraryAssets/running-research.json'
# Regional path or currency query selects the merchant's own USD presentation.
SELECTION = [
    ('https://nordarun.com', 'norda', '?currency=USD', [
        ('003-m-cinder', '003', 'shoes', 'Cinder'),
        ('001a-m-cinder', '001A', 'shoes', 'Cinder'),
        ('001a-m-astral', '001A', 'shoes', 'Astral'),
        ('005-m-neve', '005', 'shoes', 'Neve'),
        ('055-m-strato', '055', 'shoes', 'Strato'),
    ]),
    ('https://renegade-running.com', 'Renegade Running', '', [
        ('norda-003-m-cinder', '003', 'shoes', 'Cinder'),
        ('mens-055-strato', '055', 'shoes', 'Strato'),
    ]),
    ('https://theexchange.run', 'The Exchange Running Collective', '', [
        ('mens-001a', '001A', 'shoes', 'Cinder'),
        ('mens-005', '005', 'shoes', 'Neve'),
    ]),
    ('https://districtvision.com', 'District Vision', '', [
        ('ultralight-nylon-zippered-shorts-obsidian', '', 'apparel', ''),
        ('ultralight-nylon-windbreaker-obsidian', '', 'apparel', ''),
        ('ultralight-nylon-trail-shorts-obsidian-umber', '', 'apparel', ''),
        ('dv-nb-1080-training-shoe-womens-linen', '', 'alternatives', ''),
    ]),
    ('https://www.soarrunning.com/en-us', 'SOAR', '', [
        ('marathon-shorts-black-and-white-dot', '', 'apparel', ''),
    ]),
    ('https://satisfyrunning.com', 'SATISFY', '?currency=USD', [
        ('mothtech-t-shirt-aged-black-men', '', 'apparel', ''),
        ('rippy-cordura-5-trail-shorts-black', '', 'apparel', ''),
        ('therocker-shadow', '', 'alternatives', ''),
    ]),
]


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode('utf-8')


def import_merchant(selection):
    base, name, query, products = selection
    offers, shop_id = [], None
    for handle, model, section, reviewed_color in products:
        source = base + '/products/' + handle
        page = fetch(source + query)
        shop = re.search(r'"shopId"\s*:\s*(\d+)', page)
        active = re.search(r'Shopify\.currency\s*=\s*\{\s*"active":"([A-Z]{3})"', page)
        assert shop and active and active[1] == 'USD', (source, 'USD storefront evidence missing')
        shop_id = shop_id or shop[1]
        assert shop[1] == shop_id
        product = json.loads(fetch(source + '.json' + query))['product']
        ajax = json.loads(fetch(source + '.js' + query))
        available_ids = {v['id'] for v in ajax['variants'] if v.get('available')}
        variants = [v for v in product['variants'] if v['id'] in available_ids]
        assert variants, (source, 'No available variant')
        lead = min(variants, key=lambda v: Decimal(v['price']))
        assert lead.get('price_currency') == 'USD', (source, 'JSON currency mismatch')
        amount = lead['price']
        reference = lead.get('compare_at_price')
        reference = reference if reference and Decimal(reference) > Decimal(amount) else None
        color_options = ['option' + str(o['position']) for o in product['options']
                         if o['name'].lower() in ['color', 'colour', 'couleur']]
        same_offer = [v for v in variants if v['price'] == amount
                      and v.get('compare_at_price') == lead.get('compare_at_price')
                      and all(v[k] == lead[k] for k in color_options)]
        color = ' / '.join(lead[k] for k in color_options)
        if reviewed_color:
            if color:
                assert color.casefold() == reviewed_color.casefold(), (source, 'Color mismatch')
            else:
                assert product['title'].casefold().endswith(reviewed_color.casefold())
            color = reviewed_color
        lead_image = next((i for i in product['images'] if i['id'] == lead.get('image_id')), None)
        if lead_image is None and color_options:
            same_color_ids = {v['image_id'] for v in product['variants'] if v.get('image_id')
                              and all(v[k] == lead[k] for k in color_options)}
            if len(same_color_ids) == 1:
                lead_image = next((i for i in product['images'] if i['id'] in same_color_ids), None)
        if len({v.get('image_id') for v in product['variants']} - {None}) > 1:
            assert lead_image, (source, 'Ambiguous variant image')
            images = [lead_image]
        else:
            images = ([lead_image] if lead_image else []) + [i for i in product['images'] if i != lead_image]
        urls = [i['src'] + ('&' if '?' in i['src'] else '?') + 'width=900' for i in images[:5]]
        for variant in same_offer:
            js_variant = next(v for v in ajax['variants'] if v['id'] == variant['id'])
            assert Decimal(js_variant['price']) / 100 == Decimal(variant['price']), 'Price endpoints disagree'
        us_sizes = []
        if section == 'shoes':
            size_option = next(('option' + str(o['position']) for o in product['options']
                                if o['name'].lower() in ['size', 'shoe size', 'taille']), 'option1')
            for variant in same_offer:
                raw = variant[size_option]
                match = re.fullmatch(r'(?:US\s*)?M?\s*(\d+(?:\.\d+)?)', raw, re.I)
                assert match, (source, 'Unreviewed size syntax', raw)
                us_sizes.append(format(Decimal(match[1]).normalize(), 'f'))
        offers.append(dict(
            id='research:' + shop_id + ':' + str(product['id']), nativeID=product['id'],
            merchantID='gid://shopify/Shop/' + shop_id, merchantName=name,
            title=product['title'], brand=product['vendor'], model=model, section=section,
            color=color, usMensSizes=us_sizes, observedImageID=images[0]['id'],
            price=amount, referencePrice=reference, currency='USD',
            variantIDs=[v['id'] for v in same_offer], availableVariants=[v['title'] for v in same_offer],
            image=urls[0], images=urls, canonicalURL=source + query,
            sourceURL=source + query + ('&' if query else '?') + 'variant=' + str(lead['id']),
            observedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            description=unescape(re.sub('<[^>]+>', ' ', product.get('body_html') or '')).strip(),
        ))
        print(name, product['title'], '$' + amount, 'reference', reference, 'sizes', us_sizes)
    merchant = dict(id='gid://shopify/Shop/' + shop_id, name=name, url=base,
                    status='Source checked Shopify storefront', platformOutcome='confirmed_shopify',
                    logo=None, wordmark=None, wordmarkWhite=None, cover=None,
                    colors=dict(primary='#252C22', coverDominant='#252C22'))
    return merchant, offers


def shipping_policies():
    url = 'https://renegade-running.com/policies/shipping-policy'
    page = unescape(re.sub('<[^>]+>', ' ', fetch(url)))
    assert 'free shipping on orders over $180 in the US' in page
    assert 'processed within 2 business days' in page
    return [dict(merchantID='gid://shopify/Shop/27527348310',
                 summary='Free US shipping over $180',
                 detail='Processes within 2 business days. UPS Ground for domestic orders. This is not a delivery estimate.',
                 sourceURL=url, observedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())]


def main():
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        imported = list(executor.map(import_merchant, SELECTION))
    snapshot = dict(merchants=[m for m, _ in imported], offers=[o for _, offers in imported for o in offers],
                    shippingPolicies=shipping_policies())
    OUTPUT.write_text(json.dumps(snapshot, indent=2, ensure_ascii=False) + '\n')
    print('Wrote', OUTPUT)


if __name__ == '__main__':
    main()
