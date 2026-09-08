#!/usr/bin/env python3
"""PROTOTYPE: import one Dossier export and exact merchant media for the review.
Run: uv run --with pillow python Scripts/prepare_quiet_review.py <export-folder>
Only selected, compressed assets ship; source metadata remains outside the app.
"""
import concurrent.futures
import hashlib
import html
import io
import json
from pathlib import Path
import re
import sys
import subprocess
import urllib.request
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'ShopFeedSummer26/QuietReviewMedia'
ARCHIVE = ROOT / 'ReviewSources'
CACHE = Path('/tmp/quiet-review-downloads')


def fetch(url):
    CACHE.mkdir(exist_ok=True)
    target = CACHE / hashlib.sha256(url.encode()).hexdigest()
    if not target.exists():
        request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        target.write_bytes(urllib.request.urlopen(request, timeout=45).read())
    return target.read_bytes()


def normalize(url):
    return 'https:' + url if url.startswith('//') else url


def product(raw, domain, js=False):
    images = [normalize(i if isinstance(i, str) else i['src']) for i in raw['images']]
    price = f"{raw['price']/100:.2f}" if js else raw['variants'][0]['price']
    return dict(id=str(raw['id']), title=raw['title'], price=price, slug=raw['handle'],
                vendor=raw.get('vendor'), productType=raw.get('product_type'), currencyCode='USD',
                imageUrl=images[0], allImageUrls=images,
                shopUrl=f"https://{domain}/products/{raw['handle']}",
                description=html.unescape(re.sub('<[^>]+>', ' ', raw.get('body_html', raw.get('description', '')))).strip())


def main():
    export = Path(sys.argv[1])
    source = json.loads((export / 'source.json').read_text())
    manifest = json.loads((export / 'manifest.json').read_text())
    assert manifest['missing'] == [], 'Resolve missing export assets before importing'
    OUT.mkdir(exist_ok=True)
    # The full flat-lay is archived in the supplied export, not needed at runtime.
    (OUT / 'quiet-dossier-pair.jpg').unlink(missing_ok=True)
    ARCHIVE.mkdir(exist_ok=True)
    for name in ['source.json', 'dossier.json', 'manifest.json', 'image-colors.json']:
        (ARCHIVE / f"{source['key']}-{name}").write_bytes((export / name).read_bytes())
    merchants = {}
    def add(mid, name, p):
        m = merchants.setdefault(mid, dict(id=mid, name=name, rating=0, totalRatings=0, totalReviews=0,
            colors=dict(primary='#F5E9DA', secondary='#111111'), products=[]))
        if not any(x['id'] == p['id'] for x in m['products']): m['products'].append(p)

    requests = [
        ('bode', 'BODE', 'bode.com', 'companion-tee-cream'),
        ('sneaker-politics', 'Sneaker Politics', 'sneakerpolitics.com', 'carhartt-wip-single-knee-pant-shale'),
        ('sneaker-politics', 'Sneaker Politics', 'sneakerpolitics.com', 'levis-568-loose-straight-corduroy-carpenter-pants-perfect-storm'),
        ('sneaker-politics', 'Sneaker Politics', 'sneakerpolitics.com', 'marithe-francois-girbaud-brand-x-denim-pants-desert-blue'),
        ('house-of-leon', 'House of Leon', 'houseofleon.com', 'antwerp-sofa-cocoa'),
        ('house-of-leon', 'House of Leon', 'houseofleon.com', 'antwerp-sofa-bone'),
        ('house-of-leon', 'House of Leon', 'houseofleon.com', 'palazzo-sofa-frost'),
        ('goodr', 'goodr', 'goodr.com', 'black-tie-fabulous'),
        ('goodr', 'goodr', 'goodr.com', 'dapper-in-the-dark'),
        ('goodr', 'goodr', 'goodr.com', 'mahogany-martini-hour'),
        ('goodr', 'goodr', 'goodr.com', 'underwhelming-alien-abduction'),
        ('goodr', 'goodr', 'goodr.com', 'once-in-a-pink-moon'),
        ('goodr', 'goodr', 'goodr.com', 'fuchsia-fields-forever'),
    ]
    def load(args):
        mid, name, domain, handle = args
        raw = json.loads(fetch(f'https://{domain}/products/{handle}.js'))
        return mid, name, product(raw, domain, js=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for mid, name, p in pool.map(load, requests): add(mid, name, p)

    base = json.loads((ROOT / 'ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json').read_text())
    extra = {'extra-butter-salomon': [7919493251255,8151144530103,4643336060976],
             'house-of-leon': [7014265454765,7873592688813,7873592721581],
             'forom': [8817998889091,8774121619587,9082606649475]}
    for m in base['merchants']:
        for p in m['products']:
            if int(p['id']) in extra.get(m['id'], []): add(m['id'], m['name'], p)

    records = []
    def image_job(args):
        mid, p = args
        url = normalize(p['imageUrl'])
        filename = f"quiet-product-{mid}-{p['id']}.jpg"
        save_image(fetch(url), OUT / filename, 760)
        return dict(merchantID=mid, productID=int(p['id']), filename=filename, sourceURL=url,
                    generated=False, sha256=hashlib.sha256((OUT / filename).read_bytes()).hexdigest())
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        records.extend(pool.map(image_job, [(m['id'], p) for m in merchants.values() for p in m['products']]))

    # Use segmentation, not image generation, for furniture: preserve exact product pixels.
    cutout_ids = {8505646055597, 8505645662381, 8214794371245, 7873592688813, 7873592721581, 8817998889091, 8774121619587,
                  8925922951356, 9459028754620, 9007369158844}
    binary = CACHE / 'review-cutouts'
    subprocess.run(['swiftc', str(ROOT / 'Scripts/prepare_review_cutouts.swift'), '-o', str(binary)], check=True)
    for record in records:
        if record['productID'] not in cutout_ids: continue
        target = OUT / record['filename']
        masked = CACHE / (target.stem + '.png')
        subprocess.run([str(binary), str(target), str(masked)], check=True)
        image = Image.open(masked).convert('RGBA')
        bounds = image.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox()
        assert bounds, f'Empty foreground: {target.name}'
        image = image.crop(bounds)
        canvas = Image.new('RGB', image.size, 'white')
        canvas.paste(image, mask=image.getchannel('A'))
        canvas.save(target, quality=76, optimize=True)
        record['transformation'] = 'Vision foreground mask; tight crop; white backing. Original product pixels.'
        record['sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()

    # Dossier illustrations stay separate from canonical product media.
    for variant, relative in [('look0', 'media/images/look0.png'), ('tee', 'media/images/object0.png')]:
        filename = f"quiet-dossier-{variant}.jpg"
        save_image((export / relative).read_bytes(), OUT / filename, 760)
        if variant == 'tee':
            masked = CACHE / 'dossier-tee.png'
            subprocess.run([str(binary), str(OUT / filename), str(masked)], check=True)
            image = Image.open(masked).convert('RGBA')
            bounds = image.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox()
            assert bounds, 'Empty tee illustration'
            image = image.crop(bounds)
            canvas = Image.new('RGB', image.size, '#f5e9da')
            canvas.paste(image, mask=image.getchannel('A'))
            canvas.save(OUT / filename, quality=80, optimize=True)
        records.append(dict(filename=filename, exportKey=source['key'], sourcePath=relative, generated=True,
            sha256=hashlib.sha256((OUT / filename).read_bytes()).hexdigest()))
    campaign = 'https://cdn.shopify.com/s/files/1/0236/4333/files/Salomon_EB_Look3-3.jpg?v=1605817987'
    save_image(fetch(campaign), OUT / 'quiet-salomon-campaign.jpg', 1000)
    records.append(dict(filename='quiet-salomon-campaign.jpg', sourceURL=campaign, generated=False,
        sha256=hashlib.sha256((OUT / 'quiet-salomon-campaign.jpg').read_bytes()).hexdigest()))
    (OUT / 'quiet-review-catalog.json').write_text(json.dumps(dict(merchants=list(merchants.values())), indent=2)+'\n')
    (ARCHIVE / 'quiet-review-assets.json').write_text(json.dumps(records, indent=2)+'\n')
    mappings = {source['product']['id']: dict(merchantID='bode', productID=8229947965634),
        source['pairingCatalog']['products'][0]['product']['id']: dict(merchantID='sneaker-politics', productID=8925922951356)}
    (ARCHIVE / 'dossier-product-mappings.json').write_text(json.dumps(dict(
        mappings=mappings, unresolved=[x['product']['id'] for x in source['pairingCatalog']['products'][1:]],
        note='Only tee and pants mapped for this interaction. No guessed mappings for generated objects.'), indent=2)+'\n')
    print('Prepared', len(records), 'assets;', sum(p.stat().st_size for p in OUT.iterdir()), 'bytes')
    for m in merchants.values(): print(m['id'], [(p['id'],p['title']) for p in m['products']])


def save_image(raw, target, side):
    image = ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert('RGBA')
    image.thumbnail((side, side))
    canvas = Image.new('RGB', image.size, 'white')
    canvas.paste(image, mask=image.getchannel('A'))
    canvas.save(target, quality=76, optimize=True)


if __name__ == '__main__': main()
