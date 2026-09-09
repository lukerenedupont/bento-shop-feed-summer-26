#!/usr/bin/env python3
"""Make a calm loop from the steady ending of the supplied jacket film.
No new imagery is generated. Original export/video stays untouched.
"""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
KEY = '6d91ee4227655be2'
MEDIA = ROOT / 'ShopFeedSummer26/DossierReviewMedia'
PROVENANCE = ROOT / 'ReviewSources/DossierLibrary'


def prepare():
    source = ROOT / '.build/dossier-imports' / f'dossier-{KEY}/media/videos/look1.mp4'
    video = MEDIA / f'dossier-{KEY}-calm.mp4'
    poster = MEDIA / f'dossier-{KEY}-calm.jpg'
    # Cut AFTER the fast zoom/cut. A slowed forward/reverse sequence has no
    # reset jump; frame blending makes the original tiny movements gradual.
    graph = ('[0:v]trim=start=3.55:end=4.25,setpts=3*(PTS-STARTPTS),'
             'scale=540:-2,split[forward][reverse];'
             '[reverse]reverse,setpts=PTS-STARTPTS[back];'
             '[forward][back]concat=n=2:v=1:a=0,'
             'minterpolate=fps=24:mi_mode=blend,format=yuv420p[v]')
    subprocess.run(['ffmpeg','-nostdin','-loglevel','error','-y','-i',str(source),
        '-filter_complex',graph,'-map','[v]','-an','-c:v','libx264','-preset','fast',
        '-crf','24','-movflags','+faststart',str(video)],check=True)
    subprocess.run(['ffmpeg','-nostdin','-loglevel','error','-y','-ss','3.55','-i',str(source),
        '-frames:v','1','-vf','scale=720:-2','-q:v','2',str(poster)],check=True)
    path = MEDIA / 'dossier-review-library.json'
    records = json.loads(path.read_text())
    record = next(r for r in records if r['key']==KEY)
    record['videos']['calm'] = video.name
    record['images']['calm'] = poster.name
    path.write_text(json.dumps(records,indent=2)+'\n')
    (PROVENANCE/'calm-jacket-edit.json').write_text(json.dumps(dict(
        sourceExport=KEY,sourcePath='media/videos/look1.mp4',
        sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),
        sourceRangeSeconds=[3.55,4.25],timeScale=3,
        edit='Forward/reverse loop of stable full-body ending; frame blending to 24 fps; no audio',
        video=video.name,poster=poster.name),indent=2)+'\n')
    return video


def update_hashes():
    records = [dict(file=p.name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
               for p in sorted(MEDIA.iterdir()) if p.is_file()]
    (PROVENANCE/'asset-hashes.json').write_text(json.dumps(records,indent=2)+'\n')


if __name__=='__main__':
    print(prepare())
    update_hashes()
