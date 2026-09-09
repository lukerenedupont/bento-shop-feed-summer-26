#!/usr/bin/env python3
"""Validate model-output structure, distinct compositions, assets, and inventory grounding."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/'ShopFeedSummer26'
payload=json.loads((APP/'NextGeneration20/ng20-compositions.json').read_text())
assert payload['schema']=='shop-composition/1'
cards=payload['cards'];assets=payload['assets']
assert len(cards)==20 and len({c['id'] for c in cards})==20
products=set()
for path in [APP/'Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json',APP/'QuietReviewMedia/quiet-review-catalog.json',APP/'DossierReviewMedia/dossier-review-merchants.json']:
 for m in json.loads(path.read_text())['merchants']:
  products.update((m['id'],int(p['id'])) for p in m['products'])
files={p.name:p for p in APP.rglob('*') if p.is_file()}
def exists(path):
 assert '..' not in path and ':' not in path, path
 if path.startswith('bundle/media/'):
  return (ROOT.parent/'dossier-feed-bundle'/path).is_file()
 return path in files
for key,a in assets.items():
 assert exists(a['image']), (key,a['image'])
 if a.get('video'):assert exists(a['video']), (key,a['video'])
KINDS={'spacer','row','column','media','product','grid','choice','compare','steps','pager','merchant','canvas'}
used=set()
def validate(n,c,ids,depth=0):
 assert depth<9 and len(ids)<80
 assert n['id'] not in ids,n['id'];ids.add(n['id'])
 k=n['kind'];assert k in KINDS;used.add(k)
 roles=set(c['entities'])
 if n.get('role'):assert n['role'] in roles|{'$selected'}
 if n.get('asset'):assert n['asset'] in assets
 for r in n.get('roles',[]):assert r in roles|{'$group'}
 if k in ['row','column']:
  assert 1<=len(n['children'])<=6
  assert len(n['weights'])==len(n['children']) and all(1<=w<=8 for w in n['weights'])
 if k=='product':
  assert n.get('role')
  for r in n.get('alternatives',[]):assert r in roles
  if n.get('alternatives'):assert n['role'] in n['alternatives']
 if k=='choice':
  assert 2<=len(n['options'])<=3 and n.get('response')
  for o in n['options']:
   assert o['roles'] and all(r in roles for r in o['roles'])
   validate(o['preview'],c,ids,depth+1)
 if k=='grid':assert 1<=n.get('columns',2)<=4 and n.get('roles')
 if k=='steps':assert len(n['labels'])==len(n['roles'])
 for child in n.get('children',[]):validate(child,c,ids,depth+1)
 if n.get('response'):validate(n['response'],c,ids,depth+1)
def shape(n):
 return (n['kind'],n.get('axis'),tuple(n.get('weights',[])),n.get('columns'),len(n.get('roles',[])),
         bool(n.get('alternatives')),tuple(shape(c) for c in n.get('children',[])),
         tuple(shape(o['preview']) for o in n.get('options',[])),shape(n['response']) if n.get('response') else None)
shapes=set();merchants=set();references=set()
for c in cards:
 assert set(c['order'])==set(c['entities']) and len(c['order'])==len(c['entities'])
 assert len(c['title'])<=70 and len(c['cta'])<=32
 for e in c['entities'].values():
  ref=(e['merchantID'],e['productID']);assert ref in products,(c['id'],ref)
  assert e['art'] in assets
  art=assets[e['art']]
  assert (art.get('merchantID'),art.get('productID'))==ref, ('Wrong image subject',c['id'],e['art'])
  merchants.add(e['merchantID']);references.add(ref)
 for slot in c.get('slots',[]):
  assert slot['role'] in c['entities'] and slot['role'] in slot['alternatives']
  assert all(r in c['entities'] for r in slot['alternatives'])
 for n in [c['root']]+c['alternates']:validate(n,c,set())
 shapes.add(shape(c['root']))
assert len(shapes)==20,f'Only {len(shapes)} distinct structural compositions'
assert len(used)>=10
leon=next(c for c in cards if c['id']=='ng20-leon')
assert assets[leon['entities']['one']['art']]['image'].endswith('object3.png'), 'Organizer must not become the Gabb phone image'
for item in json.loads((ROOT/'ReviewSources/ng20-media.json').read_text()):
 assert hashlib.sha256((APP/'NextGeneration20'/item['file']).read_bytes()).hexdigest()==item['sha256']
print(f'Validated 20 distinct composition trees, {len(used)} primitives, {len(references)} real product references, {len(merchants)} merchants, {len(assets)} asset bindings')
