#!/usr/bin/env python3
"""Import the six supplied Dossiers as a bounded, offline visual review library.
uv run --with pillow python Scripts/import_dossier_review.py
Original ZIPs remain unchanged. Generated imagery is never commerce evidence.
"""
from pathlib import Path
import concurrent.futures
import hashlib
import io
import json
import subprocess
import urllib.request
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / '.build/dossier-imports'
OUT = ROOT / 'ShopFeedSummer26/DossierReviewMedia'
PROVENANCE = ROOT / 'ReviewSources/DossierLibrary'
ORDER = ['6d91ee4227655be2', '9d5f7d2f25a037ac', '4b42878d497ca473', '98979f976a7a42f3', '7263898de0dd5a28', '5527c8904c1155d7', '8ccc0ca672d0d77f', '601abf8c7dca97ce', '519234f72b73ffaa']
CONFIG = {
 '4b42878d497ca473': ('outfit', 'Style these Vomeros', 'Sneaker Politics', None),
 '601abf8c7dca97ce': ('kids', 'For little adventures', 'The Spot Chicago', None),
 '519234f72b73ffaa': ('setup', 'A studio in the making', 'MoMA Design Store', None),
 '6d91ee4227655be2': ('outfit', 'Style this jacket', 'COMPLEX', 'https://www.complex.com/shop/products/reversible-valley-of-flowers-work-jacket'),
 '9d5f7d2f25a037ac': ('room', 'Build around this lamp', 'MESO', 'https://www.mesogoods.com/products/artefacto-ls-16-by-lordag-sondag'),
 '98979f976a7a42f3': ('watch', 'Still on your mind?', 'Reference in Time', None),
 '7263898de0dd5a28': ('gift', 'For Leon', 'Tin Can', 'https://tincan.kids/products/tin-can'),
 '5527c8904c1155d7': ('merchant', 'From Hat Trick NYC', 'Hat Trick NYC', 'https://hattrick.nyc/products/yankee-sitcom-hat-season-8'),
 '8ccc0ca672d0d77f': ('outfit', 'Start with your tee', 'BODE', 'https://bode.com/products/companion-tee-cream'),
}


def local_id(gid):
    # Explicit local surrogate, not a claimed merchant numeric ID.
    return int(hashlib.sha256(gid.encode()).hexdigest()[:12], 16)


def save_image(raw, path, side=960):
    im = ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert('RGBA')
    im.thumbnail((side, side))
    canvas = Image.new('RGB', im.size, 'white');canvas.paste(im, mask=im.getchannel('A'))
    canvas.save(path, quality=78, optimize=True)


def main():
    OUT.mkdir(exist_ok=True); PROVENANCE.mkdir(parents=True, exist_ok=True)
    records = []; merchants = {}; hashes = []; mappings = {}
    cutter = ROOT / '.build/dossier-product-downloads/cutout-tool'
    cutter.parent.mkdir(exist_ok=True)
    subprocess.run(['swiftc', str(ROOT/'Scripts/prepare_review_cutouts.swift'), '-o', str(cutter)], check=True)
    folders = {json.loads((p/'manifest.json').read_text())['key']: p for p in INPUT.iterdir() if (p/'manifest.json').exists()}
    for key in ORDER:
        folder = folders[key]
        d = json.loads((folder/'dossier.json').read_text()); source = json.loads((folder/'source.json').read_text())
        manifest = json.loads((folder/'manifest.json').read_text())
        assert not manifest['missing']
        family, title, merchant_name, canonical_url = CONFIG[key]
        (PROVENANCE / f'{key}-source.json').write_bytes((folder/'source.json').read_bytes())
        (PROVENANCE / f'{key}-manifest.json').write_bytes((folder/'manifest.json').read_bytes())
        objects = []
        candidates = [(source['product'], 'Anchor', 0, canonical_url)]
        # Tin Can's phone and access point are alternatives/context, not automatic complements.
        # Watch straps are NOT claimed compatible without lug-width verification.
        for p in source.get('pairingCatalog', {}).get('products', []):
            if family == 'gift' and p['category'] != 'organizer': continue
            candidates.append((p['product'], p['label'], p['slotIndex'] + 1, None))
        for item, role, index, link in candidates:
            pid = local_id(item['id']); mid = 'dossier-' + hashlib.sha256(item['brand'].lower().encode()).hexdigest()[:10]
            image_name = f'dossier-product-{pid}.jpg'
            if index == 0:
                raw = (folder / d['product']['image']).read_bytes()
            else:
                cache = ROOT / '.build/dossier-product-downloads' / f'{pid}.image';cache.parent.mkdir(exist_ok=True)
                if not cache.exists():
                    req=urllib.request.Request(item['image'],headers={'User-Agent':'Mozilla/5.0'})
                    cache.write_bytes(urllib.request.urlopen(req,timeout=45).read())
                raw=cache.read_bytes()
            save_image(raw, OUT/image_name, 760)
            m = merchants.setdefault(mid, dict(id=mid,name=item['brand'],rating=0,totalRatings=0,totalReviews=0,products=[]))
            if not any(p['id']==str(pid) for p in m['products']):
                m['products'].append(dict(id=str(pid),title=item['title'],price='Check merchant for price',slug='',vendor=item['brand'],
                    imageUrl=item['image'],shopUrl=link,description=None,productType=role))
            ref = dict(merchantID=mid,productID=pid)
            mappings[item['id']] = dict(**ref, identity='local surrogate for original global ID; not a merchant ID', sourcePrice=item.get('price'))
            objects.append(dict(reference=ref, role=role, image=f'dossier-{key}-object{index}', originalImage=image_name[:-4]))
        images={};videos={}
        for variant,path in d['imageUrls'].items():
            filename=f'dossier-{key}-{variant}.jpg'
            # This export's generated object0 depicts K.O. II, not the green source device.
            if key == '519234f72b73ffaa' and variant == 'object0':
                path = d['product']['image']
            save_image((folder/path).read_bytes(),OUT/filename)
            if variant.startswith('object'):
                # Separate objects need alpha, not another beige rectangle multiplied onto beige.
                alpha = OUT/(Path(filename).stem + '.png')
                subprocess.run([str(cutter), str(OUT/filename), str(alpha)], check=True)
                im = Image.open(alpha).convert('RGBA')
                bounds = im.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox()
                assert bounds, f'Empty foreground: {filename}'
                im = im.crop(bounds);im.thumbnail((560,560));im.save(alpha,optimize=True)
                subprocess.run(['pngquant','--force','--strip','--speed','8','--quality','60-85','--output',str(alpha),'--',str(alpha)],check=False)
            images[variant]=filename
        # Tin Can gets an image of the phone in use, not a fake router bundle.
        if family=='gift':
            im=Image.open(folder/d['imageUrls']['lookbook']);w,h=im.size
            im.crop((0,0,w//2,h//2)).convert('RGB').save(OUT/f'dossier-{key}-gift.jpg',quality=82,optimize=True)
            images['gift']=f'dossier-{key}-gift.jpg'
        # One muted clip per card. All exported clips remain available in the input archive.
        variant = 'look1' if family=='outfit' else 'look0'
        if variant in d['videoUrls'] and family != 'gift':
            filename=f'dossier-{key}-{variant}.mp4'
            subprocess.run(['ffmpeg','-nostdin','-loglevel','error','-y','-i',str(folder/d['videoUrls'][variant]),
                '-an','-vf','scale=540:-2,fps=24','-c:v','libx264','-preset','fast','-crf','28','-pix_fmt','yuv420p',
                '-movflags','+faststart',str(OUT/filename)],check=True)
            videos[variant]=filename
        colors=d.get('imageColors',{})
        records.append(dict(key=key,family=family,title=title,merchant=merchant_name,objects=objects,images=images,videos=videos,
            defaultVisible=key not in ['8ccc0ca672d0d77f','601abf8c7dca97ce','519234f72b73ffaa'],
            surface=colors.get('pairSquare',{}).get('hex','#F4EEE5'),
            note='Generated styling studies, not exact renders of changed selections. Export prices have no currency metadata and are not displayed as verified prices.'))
    (OUT/'dossier-review-library.json').write_text(json.dumps(records,indent=2)+'\n')
    (OUT/'dossier-review-merchants.json').write_text(json.dumps(dict(merchants=list(merchants.values())),indent=2)+'\n')
    from prepare_calm_jacket import prepare
    prepare()
    for path in sorted(OUT.iterdir()):
        hashes.append(dict(file=path.name,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (PROVENANCE/'asset-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
    (PROVENANCE/'product-mappings.json').write_text(json.dumps(mappings,indent=2)+'\n')
    print(f'Imported {len(records)} dossiers, {len(mappings)} unique product IDs, {sum(p.stat().st_size for p in OUT.iterdir())//1024} KB')

if __name__=='__main__':main()
