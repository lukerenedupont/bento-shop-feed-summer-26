#!/usr/bin/env python3
"""Prepare/verify canonical imagery for the authored generative-output review."""
import concurrent.futures, hashlib, io, json, sys, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'ShopFeedSummer26/PrototypeCardMedia'
CATALOG = ROOT / 'ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json'
plans = json.loads((MEDIA / 'EDITORIAL_PLANS.json').read_text())
merchants = {m['id']: m for m in json.loads(CATALOG.read_text())['merchants']}

def urls(p):
    return list(dict.fromkeys('https:' + u if u.startswith('//') else u for u in [p['imageUrl']] + p.get('allImageUrls', []) if u))

def references():
    found = {}
    for plan in plans:
        m = merchants[plan['merchant']]
        for pid in plan['products']:
            p = next(p for p in m['products'] if str(p['id']) == str(pid))
            found[(m['id'], pid)] = p
    return found

if '--check' in sys.argv:
    refs = references()
    records = json.loads((MEDIA / 'EDITORIAL_SOURCES.json').read_text())
    for r in records:
        p = refs[(r['merchant'], r['product'])]
        assert r['url'] in urls(p), r
        assert hashlib.sha256((MEDIA / r['file']).read_bytes()).hexdigest() == r['sha256'], r['file']
    assert len(plans) == 20 and len({p['id'] for p in plans}) == 20
    assert len({r['file'] for r in records}) == len(records)
    for plan in plans:
        assert len(plan['products']) == len(plan['labels'])
        for pid in plan['products']:
            assert any(r['merchant'] == plan['merchant'] and r['product'] == pid and r['index'] == 0 for r in records)
    print(f'Validated 20 plans, {len(refs)} canonical products and {len(records)} exact images')
    sys.exit()

from PIL import Image, ImageOps, ImageDraw, ImageChops
cache = ROOT / '.build/editorial-source'
cache.mkdir(parents=True, exist_ok=True)
refs = references()
research = '--research' in sys.argv
jobs = []
for (mid, pid), p in refs.items():
    primary = any(pl['merchant'] == mid and pl['products'][0] == pid for pl in plans)
    indices = range(len(urls(p))) if research and primary else [0]
    if not research:
        indices = sorted(set([0] + [pl.get('photoIndex', 0) for pl in plans if pl['merchant'] == mid and pl['products'][0] == pid]))
    for index in indices:
        jobs.append((mid, pid, p, index, urls(p)[index]))

def prepare(job):
    mid, pid, p, index, url = job
    source = cache / (hashlib.sha256(url.encode()).hexdigest() + '.source')
    try:
        if not source.exists():
            req = urllib.request.Request(url, headers={'User-Agent': 'ShopFeedPrototype/1.0'})
            source.write_bytes(urllib.request.urlopen(req, timeout=25).read())
        rgba = ImageOps.exif_transpose(Image.open(source)).convert('RGBA')
        crop = None
        if not research:
            alpha = rgba.getchannel('A')
            if alpha.getextrema()[0] == 0:
                crop = alpha.getbbox()
        background = Image.new('RGBA', rgba.size, 'white')
        im = Image.alpha_composite(background, rgba).convert('RGB')
        if not research and crop is None:
            # Only trim near-uniform pale studio margins, never room scenes.
            corners = [im.getpixel(pt) for pt in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)]]
            base = corners[0]
            if min(base) >= 235 and all(max(abs(c[k]-base[k]) for k in range(3)) <= 8 for c in corners):
                difference = ImageChops.difference(im, Image.new('RGB', im.size, base)).convert('L')
                crop = difference.point(lambda x: 255 if x > 8 else 0).getbbox()
        if crop:
            pad = int(max(im.size) * 0.04)
            crop = (max(0,crop[0]-pad), max(0,crop[1]-pad), min(im.width,crop[2]+pad), min(im.height,crop[3]+pad))
            im = im.crop(crop)
        im.thumbnail((640, 640))
        file = f'editorial-{mid}-{pid}-{index}.jpg'
        dest = cache / file if research else MEDIA / file
        im.save(dest, quality=66, optimize=True)
        return dict(merchant=mid, product=pid, index=index, url=url, file=file, crop=crop, sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    except Exception as e:
        print('Unavailable:', mid, pid, index, str(e)[:80])
        if not research: raise

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    records = [r for r in pool.map(prepare, jobs) if r]
if research:
    rows = []
    for plan in plans:
        mid, pid = plan['merchant'], plan['products'][0]
        images = [r for r in records if r['merchant'] == mid and r['product'] == pid]
        row = Image.new('RGB', (1200, 185), 'white'); draw = ImageDraw.Draw(row)
        for i, r in enumerate(images[:8]):
            im = ImageOps.contain(Image.open(cache / r['file']), (148, 155))
            row.paste(im, (i * 150, 0)); draw.text((i * 150, 157), str(r['index']) + ' ' + mid[:15], fill='black')
        rows.append(row)
    for start in range(0, len(rows), 5):
        sheet = Image.new('RGB', (1200, 185 * len(rows[start:start+5])), 'white')
        for i, row in enumerate(rows[start:start+5]): sheet.paste(row, (0, i * 185))
        sheet.save(cache / f'review-{start//5}.jpg')
else:
    (MEDIA / 'EDITORIAL_SOURCES.json').write_text(json.dumps(records, indent=2) + '\n')
    print('Prepared', len(records), 'images;', sum((MEDIA/r['file']).stat().st_size for r in records)//1024, 'KB')
