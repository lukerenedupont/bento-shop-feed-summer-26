#!/usr/bin/env python3
"""Reject abrupt motion/cuts and a visible reset seam in the selected jacket loop.
Optionally pass another clip to verify the check catches the original fast edit.
"""
from pathlib import Path
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'ShopFeedSummer26/DossierReviewMedia/dossier-6d91ee4227655be2-calm.mp4'
raw = subprocess.check_output(['ffmpeg','-nostdin','-loglevel','error','-i',str(path),
    '-vf','fps=12,scale=48:84','-pix_fmt','rgb24','-f','rawvideo','-'])
size = 48 * 84 * 3
assert len(raw) % size == 0
frames = [raw[i:i+size] for i in range(0,len(raw),size)]
assert len(frames) >= 24, 'Loop should last at least two seconds'
def difference(a,b):
    return sum(abs(x-y) for x,y in zip(a,b)) / size
changes = [difference(a,b) for a,b in zip(frames,frames[1:])]
peak = max(changes)
seam = difference(frames[0],frames[-1])
print(f'{path.name}: mean frame change={statistics.mean(changes):.2f}, peak={peak:.2f}, loop seam={seam:.2f}')
assert peak < 5, 'Fast camera motion or cut in the jacket loop'
assert seam < 5, 'Visible reset jump in the jacket loop'
print('Calm jacket loop check passed')
