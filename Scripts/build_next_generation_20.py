#!/usr/bin/env python3
"""Materialize twenty agent-authored composition specifications and verified media.
The renderer consumes a layout tree, not a twenty-case template enum.
uv run --with pillow python Scripts/build_next_generation_20.py
"""
from pathlib import Path
import concurrent.futures
import copy
import hashlib
import io
import json
import subprocess
import shutil
import urllib.request
import argparse
import difflib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'ShopFeedSummer26/NextGeneration20'
FROZEN=ROOT.parent/'dossier-feed-bundle/bundle'
BASE=json.loads((ROOT/'ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json').read_text())
QUIET=json.loads((ROOT/'ShopFeedSummer26/QuietReviewMedia/quiet-review-catalog.json').read_text())
DOSSIERS=json.loads((ROOT/'ShopFeedSummer26/DossierReviewMedia/dossier-review-library.json').read_text())
D_MERCHANTS=json.loads((ROOT/'ShopFeedSummer26/DossierReviewMedia/dossier-review-merchants.json').read_text())
F_MERCHANTS=json.loads((FROZEN/'merchants.json').read_text())
PRODUCTS={}
for source in [BASE,QUIET,D_MERCHANTS]:
 for m in source['merchants']:
  for p in m['products']:PRODUCTS[(m['id'],int(p['id']))]=(m,p)
F_PRODUCTS={(m['id'],int(p['id'])):p for m in F_MERCHANTS['merchants'] for p in m['products']}
D={d['key']:d for d in DOSSIERS}
ASSETS={};DOWNLOADS={};CARDS=[];CUTOUTS={};DOWNLOAD_PRODUCTS={}


def asset(name,image,video=None,generated=False,subject=None):
 ASSETS[name]=dict(image=image,video=video,generated=generated)
 if subject:ASSETS[name].update(subject)
 return name


def still(key):
 a=ASSETS[key]
 subject=dict(merchantID=a['merchantID'],productID=a['productID']) if 'productID' in a else None
 return asset(key+'-still',a['image'],generated=a['generated'],subject=subject)


def product(mid,pid):
 key=(mid,int(pid));assert key in PRODUCTS,key
 m,p=PRODUCTS[key];name=f'{mid}-{pid}'
 local=ROOT/f'ShopFeedSummer26/QuietReviewMedia/quiet-product-{name}.jpg'
 if local.exists(): image=local.name
 elif (ROOT/f'ShopFeedSummer26/PrototypeCardMedia/prototype-product-{name}.jpg').exists():image=f'prototype-product-{name}.jpg'
 elif (ROOT/f'ShopFeedSummer26/DossierReviewMedia/dossier-product-{pid}.jpg').exists():image=f'dossier-product-{pid}.jpg'
 else:
  image='ng20-product-'+name+'.jpg';DOWNLOADS[image]=[p['imageUrl']]+p.get('allImageUrls',[]);DOWNLOAD_PRODUCTS[image]=p
 subject=dict(merchantID=mid,productID=int(pid))
 asset(name+'-product',image,subject=subject)
 art=name+'-product'
 if mid in ['fellow','kinto','nocs','ceremonia','moma','house-of-leon','forom','feature-salomon','extra-butter-salomon']:
  cutout='ng20-art-'+name+'.png';CUTOUTS[cutout]=image
  art=asset(name+'-art',cutout,subject=subject)
 result=dict(merchantID=mid,productID=int(pid),art=art,label=p['title'])
 if key in F_PRODUCTS:
  f=F_PRODUCTS[key];stills=[u for u in f.get('allImageUrls',[]) if not Path(u).name.startswith('remote-')]
  for kind,index in [('contact',0),('pair',1),('scene',2)]:
   if len(stills)>index:
    video=(f.get('allVideoUrls') or [None])[0] if kind=='scene' else None
    result[kind]=asset(name+'-'+kind,'bundle/'+stills[index],'bundle/'+video if video else None,True,subject)
 return result


def dossier(key):
 r=D[key];entities={}
 for i,o in enumerate(r['objects']):
  ref=o['reference'];e=product(ref['merchantID'],ref['productID'])
  e['art']=asset(key+'-art'+str(i),o['image']+'.png',generated=True,subject=ref)
  e['label']=o['role'] if i else PRODUCTS[(ref['merchantID'],ref['productID'])][1]['title']
  entities[['anchor','one','two','three'][i]]=e
 for variant,image in r['images'].items():
  if not variant.startswith('object'):asset(key+'-'+variant,image,r['videos'].get(variant),True,r['objects'][0]['reference'])
 return entities


def n(kind,**kw):return dict(kind=kind,**kw)
def col(*children,weights=None):return n('column',children=list(children),weights=weights or [1]*len(children))
def row(*children,weights=None):return n('row',children=list(children),weights=weights or [1]*len(children))
def media(asset=None,role=None,fit=False):return n('media',asset=asset,role=role,mediaFit='contain' if fit else 'cover')
def obj(role,mode='object',options=None):return n('product',role=role,productPresentation=mode,alternatives=options or [])
def grid(roles,columns=2):return n('grid',roles=roles,columns=columns)
def choices(options,response,axis='row'):return n('choice',options=options,response=response,layout=axis)
def option(id,title,roles,preview):return dict(id=id,title=title,roles=roles,preview=preview)
def steps(roles,labels):return n('steps',roles=roles,labels=labels)


def card(id,title,job,theme,entities,root,action='review',cta='View the selection',background=None,footer=None,reason='',alternates=None,destination=None,slots=None,presentation=None):
 c=dict(id='ng20-'+id,title=title,job=job,theme=theme,entities=entities,order=list(entities),root=root,action=action,cta=cta,
        background=background,footer=footer or [],reason=reason,
        alternates=alternates or [],destination=destination,slots=slots or [],presentation=presentation or dict(actionStyle='prominent',disclosure='none'),generation='agent-authored composition fixture; no live model call')
 CARDS.append(c)
 return c


def build():
 # 01 — established cinematic control case; all other arrangements vary the body.
 e=dossier('6d91ee4227655be2');e['shale']=product('sneaker-politics',8925922951356);e['cord']=product('sneaker-politics',9459028754620)
 card('jacket','Style this jacket','complete','ink',e,n('spacer'),background='6d91ee4227655be2-calm',footer=['anchor','one','two','three'],cta='View the look',
      reason='The anchor jacket and supporting garments remain individually shoppable over the supplied styling film.',
      slots=[dict(role='one',alternatives=['one','shale','cord'])])
 # 02 — full-width room inspiration, with three equally weighted companions.
 # The hero retains the lamp role in the review; chair swaps do not alter the scene.
 e=dossier('9d5f7d2f25a037ac');e['camel']=product('house-of-leon',7873592688813);e['black']=product('house-of-leon',7873592721581)
 room=col(media('9d5f7d2f25a037ac-look1',role='anchor'),row(obj('one',options=['one','camel','black']),obj('two'),obj('three')),weights=[4,1])
 card('woven-room','Around this lamp','complete','sand',e,
      room,presentation=dict(actionStyle='link',disclosure='none'),
      cta='Review the room',destination='spatial',reason='Natural fibers anchor a room study. A chair changes in its own compartment; the scene stays labelled as inspiration.')
 # 03 — immersive styling study with a consistent, shoppable outfit strip.
 e=dossier('4b42878d497ca473');e['denim']=product('sneaker-politics',9007369158844);e['cord']=product('sneaker-politics',9459028754620)
 outfit=col(n('spacer'),row(obj('anchor',mode='tile'),obj('one',mode='tile',options=['one','denim','cord']),obj('three',mode='tile'),obj('two',mode='tile')),weights=[4,1])
 card('vomero-kit','With these Vomeros','complete','ink',e,
      outfit,background='4b42878d497ca473-look1',presentation=dict(actionStyle='link',disclosure='stylingStudy'),
      cta='View the look',reason='The outdoor image is a fixed styling study, not a render of current selections. The shoe, swappable pants, jacket and socks remain individually grounded in the review.')
 # 04 — asymmetric outfit assembly, with styling as a supporting insert.
 e=dossier('8ccc0ca672d0d77f');e['cord']=product('sneaker-politics',9459028754620)
 card('bode-pair','Start with this tee','complete','sand',e,
      row(col(obj('anchor'),media('8ccc0ca672d0d77f-look0'),weights=[3,2]),col(obj('one',options=['one','cord']),obj('two'),weights=[4,1]),weights=[3,2]),
      cta='Keep the combination',action='save',reason='The tee stays fixed while a companion changes; saving records the exact pair, not a render.')
 # 05 — product inspection instead of an infinite generic recommendation rail.
 e=dossier('98979f976a7a42f3')
 card('watch-close','A closer look','inspect','ink',{'anchor':e['anchor']},
      col(n('pager',children=[media('98979f976a7a42f3-lookbook'),obj('anchor'),media('98979f976a7a42f3-look1')]),n('merchant',role='anchor'),weights=[6,1]),
      action='detail',cta='View watch',reason='Inspect the source watch and its styling details. No unsupported strap compatibility or authenticity claims.')
 # 06 — recipient-specific keep/dismiss feedback, with no misleading router bundle.
 e=dossier('7263898de0dd5a28')
 card('leon','For Leon','gift','paper',e,
      col(media('7263898de0dd5a28-gift'),row(obj('anchor'),obj('one')),weights=[3,2]),
      action='save',cta='Keep for Leon',reason='A recipient-scoped gift idea. Only the phone and desk organizer are retained, not the alternative smartphone/router.')
 # 07 — miniature storefront: identity, campaign pair, and one actual merchant item.
 e=dossier('5527c8904c1155d7')
 card('hat-trick','From Hat Trick NYC','discover','ink',{'anchor':e['anchor']},
      col(n('merchant',role='anchor'),n('spacer'),grid(['anchor'],1),weights=[1,3,2]),
      background='5527c8904c1155d7-look0',footer=[],action='merchant',cta='Visit Hat Trick NYC',reason='The hat merchant stays primary. Related styling objects are not presented as that merchant’s inventory.')
 # 08 — a tall photographic compartment and a three-piece outfit column.
 e=dossier('601abf8c7dca97ce')
 card('little-adventures','For little adventures','complete','rose',e,
      row(media('601abf8c7dca97ce-look1'),col(obj('anchor'),obj('one'),obj('two')),weights=[3,2]),
      cta='Review the outfit',reason='A child-focused outfit study. No adult alternatives or unverified fit/age claims.')
 # 09 — a modular studio board, using the corrected original source device.
 e=dossier('519234f72b73ffaa')
 card('studio','Your portable studio','complete','paper',e,
      col(row(obj('anchor'),obj('one'),weights=[3,2]),row(obj('two'),obj('three'),weights=[4,1]),weights=[3,2]),
      action='save',cta='Keep this setup',reason='A sampler, headphones, keyboard and cable are separate choices. The original green device replaces the erroneous generated K.O. II image.')
 # 10 — visual steering reconstructs the same area from a hard-gated group.
 e={'trail':product('extra-butter-salomon',8349773922487),'city':product('feature-salomon',6753846919239),'quest':product('extra-butter-salomon',8151144530103),'white':product('feature-salomon',7029064368199)}
 opts=[option('trail','On the trail',['trail','quest'],media(e['trail']['scene'])),option('city','In the city',['city','white'],media(e['city']['scene']))]
 card('salomon-directions','City or trail?','narrow','ink',e,
      choices(opts,col(media(role='$selected'),grid(['$group'],2),weights=[3,2])),
      cta='Explore your direction',footer=[],reason='Two real Salomon assortments. Choosing a direction excludes the other group from the response.')
 # 11 — simultaneous comparison; information appears only after two explicit choices.
 e={'camel':product('house-of-leon',7873592688813),'black':product('house-of-leon',7873592721581),'boucle':product('house-of-leon',8590788591789)}
 card('chairs','Still considering these?','compare','paper',e,n('compare',roles=list(e)),action='compare',cta='Compare chairs',
      reason='Two selected chairs reveal canonical titles, merchants and prices. No dimensions or reviews are invented.')
 # 12 — an interactive brewing sequence with a changing visual stage.
 e={'brew':product('fellow',7507479003236),'pour':product('fellow',2055410221171),'serve':product('fellow',2055409762419)}
 card('fellow-routine','Your Fellow setup','complete','sage',e,
      col(media(role='$selected'),steps(list(e),['Brew','Pour','Serve']),weights=[4,2]),action='save',cta='Keep the setup',
      reason='The selected workflow step changes the stage; a separate explicit save keeps the kit.')
 # 13 — close-up glass study, with a quiet browsable pair.
 e={'server':product('kinto',2214011961392),'cup':product('kinto',2214023331888),'cast':product('kinto',2214022053936)}
 card('kinto','Pour with KINTO','inspect','paper',e,
      row(n('pager',children=[media(e['cup']['scene']),media(e['cup']['contact'])]),col(obj('server'),obj('cup'),obj('cast')),weights=[3,2]),
      action='detail',cta='View the selected piece',reason='A material study anchored in actual KINTO products and supplied scenes.')
 # 14 — a four-step ritual with vertical rhythm, not another carousel.
 e={'scalp':product('ceremonia',7219216580772),'cleanse':product('ceremonia',8178693210276),'finish':product('ceremonia',6060165300388),'dry':product('ceremonia',15369056321905)}
 card('ceremonia','Your Ceremonia routine','complete','rose',e,
      row(col(media(e['finish']['scene']),obj('$selected'),weights=[3,2]),n('steps',roles=list(e),labels=['Scalp','Cleanse','Finish','Dry'],layout='column'),weights=[3,2]),
      action='save',cta='Keep the routine',reason='Product roles come from the catalog. This is not a claim about the shopper’s hair or treatment outcomes.')
 # 15 — reuse the actual extracted canvas engine for a real finite library.
 m=next(m for m in BASE['merchants'] if m['id']=='standards-manual');e={f'book{i}':product(m['id'],p['id']) for i,p in enumerate(m['products'])}
 card('standards-library','From the bookshelf','discover','paper',e,n('canvas'),action='canvas',cta='Explore the library',
      reason='Twenty real Standards Manual items in the existing native fisheye canvas. The finite assortment is not represented as infinite stock.')
 # 16 — a different steering form: two wide visual worlds stacked vertically.
 e={'jelly':product('coming-soon',9908030275890),'gemini':product('coming-soon',9603148841266)}
 opts=[option('playful','Playful',['jelly'],media(e['jelly']['scene'])),option('sculptural','Sculptural',['gemini'],media(e['gemini']['scene']))]
 card('mirror-directions','Pick a direction','narrow','sand',e,
      choices(opts,row(media(role='$selected'),obj('$selected'),weights=[3,2]),axis='column'),
      cta='View your choice',reason='Direction is communicated by the mirrors and rooms, not by large text buttons.')
 # 17 — a merchandised room feature with an uneven product strip.
 e={'mirror':product('forom',9080102322307),'table':product('forom',8817998889091),'ecru':product('forom',8774121619587),'vase':product('forom',9082606649475)}
 card('forom','A FOROM corner','complete','sand',e,
      col(media(e['mirror']['scene']),row(obj('mirror'),obj('table',options=['table','ecru']),obj('vase'),weights=[2,2,1]),weights=[3,2]),
      cta='Review the corner',destination='spatial',reason='A material-led FOROM composition with an independently swappable table.')
 # 18 — bold merchant color, restrained native type, and a three-object arrangement.
 e={'espresso':product('moma',9787655160038),'watch':product('moma',9604489248998),'flatware':product('moma',8909829603558)}
 card('moma','From MoMA','discover','blue',e,
      row(col(media(e['espresso']['scene']),obj('flatware'),weights=[4,1]),col(obj('watch'),media(e['watch']['contact']),weights=[2,3]),weights=[3,2]),
      action='merchant',cta='Visit MoMA',reason='Color comes from the merchant’s actual design objects; controls and typography stay native.')
 # 19 — field context plus a dense, useful equipment board.
 e={'pro':product('nocs',10432692846871),'tube':product('nocs',6591770722382),'strap':product('nocs',10139738243351),'pouch':product('nocs',10186761011479)}
 card('nocs','Nocs field kit','complete','ink',e,
      col(row(obj('pro'),obj('tube'),weights=[3,2]),grid(['strap','pouch'],2),weights=[3,1]),
      background=still(e['pro']['scene']),action='save',cta='Keep the field kit',reason='Optics and accessories from Nocs. Selecting equipment changes the stage; saves remain explicit.')
 # 20 — merchant discovery driven by category, with a shoppable reconstructed wall.
 e={'chair':product('lichen',12462683128126),'wassily':product('lichen',12567030169918),'shelf':product('lichen',12518383059262),'rack':product('lichen',12374848700734),'book':product('lichen',11009838154046),'table':product('lichen',12567031087422)}
 opts=[option('storage','Storage',['shelf','rack'],media(e['shelf']['art'])),option('seating','Seating',['chair','wassily'],media(e['chair']['art'])),option('objects','Objects',['book','table'],media(e['book']['art']))]
 storefront=col(n('merchant',role='book'),choices(opts,col(obj('$selected'),grid(['$group'],2),weights=[3,2]),axis='featured'),weights=[1,8])
 card('lichen','Found at Lichen','discover','paper',e,
      storefront,presentation=dict(actionStyle='link',disclosure='none'),
      action='merchant',cta='Visit Lichen',reason='The merchant remains the primary entity; category selection gates actual inventory rather than inventing a collection.')


def stamp(node,path):
 node['id']=path
 for i,c in enumerate(node.get('children',[])):stamp(c,f'{path}.{i}')
 for i,o in enumerate(node.get('options',[])):
  if isinstance(o,dict) and 'preview' in o:stamp(o['preview'],f'{path}.option{i}')
 if isinstance(node.get('response'),dict):stamp(node['response'],f'{path}.response')


def download(entry):
 from PIL import Image, ImageOps
 filename,urls=entry;target=OUT/filename
 cache=ROOT/'.build/ng20-download-sources';cache.mkdir(exist_ok=True)
 proof=cache/(filename+'.json')
 if target.exists():
  if proof.exists():urls.append(json.loads(proof.read_text())['sourceURL'])
  return
 def get(url):return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=35).read()
 def store(url):
  url='https:'+url if url.startswith('//') else url
  im=ImageOps.exif_transpose(Image.open(io.BytesIO(get(url)))).convert('RGBA');im.thumbnail((720,720))
  canvas=Image.new('RGB',im.size,'white');canvas.paste(im,mask=im.getchannel('A'));canvas.save(target,quality=78,optimize=True)
  proof.write_text(json.dumps(dict(sourceURL=url,productID=DOWNLOAD_PRODUCTS[filename]['id'])))
  if url not in urls:urls.append(url)
 error=None
 for url in list(dict.fromkeys(urls)):
  try:store(url);return
  except Exception as e:error=e
 # CDN images change. Refresh only the exact canonical merchant product;
 # never substitute a similar item or an unrelated search result.
 p=DOWNLOAD_PRODUCTS[filename]
 if '/products/' in p.get('shopUrl',''):
  fresh=json.loads(get(p['shopUrl'].split('?')[0].rstrip('/')+'.js'))
  assert str(fresh['id'])==str(p['id']), 'Canonical refresh changed product identity'
  for url in fresh.get('images',[]):
   try:store(url);return
   except Exception as e:error=e
 raise RuntimeError(f'{filename}: {error}')


def prepare_cutouts():
 from PIL import Image, ImageOps
 cache=ROOT/'.build/ng20-cutouts';cache.mkdir(parents=True,exist_ok=True)
 binary=cache/'cutout-tool'
 subprocess.run(['swiftc',str(ROOT/'Scripts/prepare_review_cutouts.swift'),'-o',str(binary)],check=True)
 records=[]
 for filename,source_name in CUTOUTS.items():
  source=OUT/source_name
  if not source.exists():source=next((ROOT/'ShopFeedSummer26').rglob(source_name))
  digest=hashlib.sha256(source.read_bytes()).hexdigest()
  cached=cache/(digest+'.png');target=OUT/filename
  if not cached.exists():
   im=ImageOps.exif_transpose(Image.open(source)).convert('RGBA');im.thumbnail((720,720))
   white=Image.new('RGB',im.size,'white');white.paste(im,mask=im.getchannel('A'))
   prepared=cache/(digest+'.jpg');white.save(prepared,quality=92)
   result=subprocess.run([str(binary),str(prepared),str(cached)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   if result.returncode==0:
    im=Image.open(cached).convert('RGBA');bounds=im.getchannel('A').point(lambda a:255 if a>25 else 0).getbbox()
    if bounds:im=im.crop(bounds)
    else:im=white.convert('RGBA')
   else:im=white.convert('RGBA')
   im.thumbnail((640,640));im.save(cached,optimize=True)
   subprocess.run(['pngquant','--force','--strip','--speed','8','--quality','60-85','--output',str(cached),'--',str(cached)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  shutil.copy2(cached,target)
  records.append(dict(file=filename,sourceFile=source_name,sourceSHA256=digest,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),transform='Foreground mask/crop; original product pixels'))
 (ROOT/'ReviewSources/ng20-cutouts.json').write_text(json.dumps(records,indent=2)+'\n')


def specification():
 ASSETS.clear();DOWNLOADS.clear();CARDS.clear();CUTOUTS.clear();DOWNLOAD_PRODUCTS.clear()
 build();assert len(CARDS)==20
 for c in CARDS:
  # Only expose alternates whose visual form is intentional. Blindly
  # transposing every row/column creates narrow labels and tiny products.
  if not c['alternates'] and c['root']['kind']=='choice':
   alternative=copy.deepcopy(c['root'])
   alternative['layout']='column' if alternative.get('layout')!='column' else 'row'
   c['alternates']=[alternative]
  stamp(c['root'],c['id']+'.root')
  for i,root in enumerate(c['alternates']):stamp(root,c['id']+f'.alt{i}')
 templates={
  'roomComparison':dict(roles=['current','alternative1','alternative2'],root=n('compare',roles=['current','alternative1','alternative2'])),
  'footwearLook':dict(roles=['anchor','one','two','three','denim','cord'],root=col(
   obj('anchor'),row(obj('one',options=['one','denim','cord']),obj('three'),obj('two')),weights=[3,1]))
 }
 for key,template in templates.items():stamp(template['root'],'journey.'+key)
 return dict(schema='shop-composition/2',generationMode='agent-authored fixtures; no live model service',cards=CARDS,assets=ASSETS,journeyTemplates=templates)


def main():
 parser=argparse.ArgumentParser(description=__doc__)
 mode=parser.add_mutually_exclusive_group()
 mode.add_argument('--check-spec',action='store_true',help='Check deterministic fixture drift; no downloads, cutouts or writes')
 mode.add_argument('--write-spec',action='store_true',help='Write composition JSON only, retaining existing media')
 args=parser.parse_args()
 payload=specification();target=OUT/'ng20-compositions.json'
 if args.check_spec:
  existing=json.loads(target.read_text())
  if existing!=payload:
   before=json.dumps(existing,indent=2,sort_keys=True).splitlines()
   after=json.dumps(payload,indent=2,sort_keys=True).splitlines()
   print('\n'.join(list(difflib.unified_diff(before,after,fromfile='bundled',tofile='authored'))[:100]))
   raise SystemExit('Composition drift: edit the authoring source, then run --write-spec')
  print('Authored and bundled specifications match');return
 OUT.mkdir(exist_ok=True)
 if args.write_spec:
  target.write_text(json.dumps(payload,indent=2)+'\n');print('Wrote specification only; media untouched');return
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(download,DOWNLOADS.items()))
 prepare_cutouts()
 target.write_text(json.dumps(payload,indent=2)+'\n')
 provenance=ROOT/'ReviewSources/ng20-media.json'
 provenance.write_text(json.dumps([dict(file=f,sourceCandidates=urls,sha256=hashlib.sha256((OUT/f).read_bytes()).hexdigest()) for f,urls in DOWNLOADS.items()],indent=2)+'\n')
 print(f'Generated {len(CARDS)} scene specs, {len(ASSETS)} asset bindings, {len(DOWNLOADS)} additional canonical images')

if __name__=='__main__':main()
