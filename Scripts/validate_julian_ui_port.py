#!/usr/bin/env python3
"""Validate the local source port against its recorded source/extraction manifest."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1] / 'Vendor/JulianAgentUI'
manifest = json.loads((root / 'source-manifest.json').read_text())
assert manifest['commit'] == '79849f634b495df011aeefc0c4ef04a7180e633d'
for record in manifest['files'] + manifest['supportingFiles']:
    path = (root / record['destination']).resolve()
    assert path.is_relative_to(root), path
    expected = record.get('portedSha256', record['sha256'])
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, f'Unrecorded port change: {path}'
for path in root.rglob('*.swift'):
    assert '[JPORT]' not in path.read_text(), f'Diagnostic logging remains in {path}'
print(f"Validated Julian UI port: {len(manifest['files'])} source files, "
      f"{len(manifest['supportingFiles'])} supporting files; adapters separately identified")
