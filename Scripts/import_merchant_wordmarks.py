#!/usr/bin/env python3
"""Import reviewed wordmarks from a user-supplied archive into our native copy.
Never extracts the entire archive, guesses merchant IDs from names, or changes
seller associations. The source archive and Shop Canvas library stay read-only.
"""
import argparse
import hashlib
import json
import pathlib
import stat
import subprocess
import zipfile

TIER_PRIORITY = {'launch-approved': 0, 'approved': 1, 'cosmos-brands': 2}
# Explicit branding of existing, uniformly branded edits. These are brand
# identities, not assertions that the brand is the seller for every product.
BRAND_EDITS = {
    'Eckhaus Latta': 'cosmos-profile:1784728528',
    'Nordic Knots': 'cosmos-profile:125685194',
    'Snow Peak': 'gid://shopify/Shop/33032994860',
    'Balenciaga': 'cosmos-profile:1058078761',
    'Jil Sander': 'cosmos-profile:1829324199',
    'Dries Van Noten': 'gid://shopify/Shop/58974732484',
    'On': 'cosmos-profile:890734513',
    'Lemaire': 'gid://shopify/Shop/43179540638',
    'JW Anderson': 'gid://shopify/Shop/67459383396',
    'Our Legacy': 'cosmos-profile:473159284',
}


def reviewed(row):
    review = row.get('review', '')
    return (row.get('tier') in TIER_PRIORITY and 'pending' not in review.lower()
            and (review == 'approved' or review.startswith('approved_')
                 or review == 'cosmos_native_capture_visually_reviewed'))


def key(row):
    identifier = row['merchant_id']
    if row['tier'] == 'cosmos-brands':
        if type(identifier) is not int:
            raise ValueError('Cosmos identity must be an exact profile ID')
        return f'cosmos-profile:{identifier}'
    if not isinstance(identifier, str) or not identifier.startswith(('gid://shopify/Shop/', 'domain:')):
        raise ValueError('Missing exact merchant ID')
    return identifier


def extract_asset(archive, descriptor, destination):
    name = descriptor['file']
    path = pathlib.PurePosixPath(name)
    if (path.is_absolute() or '..' in path.parts or len(path.parts) < 3
            or path.parts[0] != 'wordmarks' or path.parts[1] not in TIER_PRIORITY):
        raise ValueError(f'Unsafe archive path: {name}')
    info = archive.getinfo(name)
    if stat.S_ISLNK(info.external_attr >> 16) or info.file_size > 12 * 1024 * 1024:
        raise ValueError(f'Unsafe archive member: {name}')
    data = archive.read(info)
    digest = hashlib.sha256(data).hexdigest()
    if digest != descriptor['sha256']:
        raise ValueError(f'Checksum mismatch: {name}')
    relative = pathlib.Path('merchant-assets/imported-wordmarks') / pathlib.Path(*path.parts[1:])
    output = destination / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    native = output
    if output.suffix.lower() == '.svg':
        native = output.with_suffix('.svg.png')
        subprocess.run(['sips', '-s', 'format', 'png', '-Z', '1000', str(output), '--out', str(native)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    return {'path': './' + native.relative_to(destination).as_posix(),
            'originalPath': './' + relative.as_posix(), 'sha256': digest,
            'nativeSha256': hashlib.sha256(native.read_bytes()).hexdigest()}


def import_marks(archive_path, directory_path, destination):
    destination = destination.resolve()
    source_root = directory_path.resolve().parent.parent
    if destination == source_root or destination.is_relative_to(source_root):
        raise ValueError('The source library must remain read-only')
    snapshot = json.loads((destination / 'snapshot.json').read_text())
    directory = {m['id']: m for m in json.loads(directory_path.read_text())['merchants']}
    with zipfile.ZipFile(archive_path) as archive:
        if len(archive.infolist()) != len(set(archive.namelist())):
            raise ValueError('Archive has duplicate member names')
        manifest = json.loads(archive.read('wordmarks/manifest.json'))
        candidates = {}
        for row in sorted(manifest['wordmarks'], key=lambda r: TIER_PRIORITY.get(r['tier'], 99)):
            if reviewed(row):
                candidates.setdefault(key(row), row)
        merchant_keys = {}
        for merchant in snapshot['merchants']:
            mid = merchant['id']
            if mid in candidates:
                merchant_keys[mid] = mid
            else:
                # Explicit metadata bridge, not slug/name matching. Numeric
                # Cosmos archive IDs refer to sourceProfileId, not Shopify IDs.
                profile = directory.get(mid, {}).get('curatedBranding', {}).get('sourceProfileId')
                profile_key = f'cosmos-profile:{profile}'
                if profile_key in candidates:
                    merchant_keys[mid] = profile_key
        products = {p['id']: p for p in snapshot['products']}
        group_keys = {}
        for group in snapshot['groups']:
            name = group['title']
            if name not in BRAND_EDITS:
                continue
            if not all(products[pid]['brand'] == name for pid in group['productIDs']):
                raise ValueError(f'{name}: mixed branding requires an editorial title, not a wordmark')
            if BRAND_EDITS[name] not in candidates:
                raise ValueError(f'{name}: missing reviewed mark')
            group_keys[name] = BRAND_EDITS[name]
        assets = {}
        for identifier in sorted(set(merchant_keys.values()) | set(group_keys.values())):
            row = candidates[identifier]
            variants = {kind: extract_asset(archive, row[kind], destination)
                        for kind in ['white', 'original'] if row.get(kind)}
            assets[identifier] = {'tier': row['tier'], 'review': row['review'],
                                  'source': row.get('source'), **variants}
        result = {'archiveSha256': hashlib.sha256(archive_path.read_bytes()).hexdigest(),
                  'reusePermission': manifest['reuse_permission'], 'merchantKeys': merchant_keys,
                  'groupKeys': group_keys, 'assets': assets,
                  'excludedPendingRows': sum(not reviewed(r) for r in manifest['wordmarks'])}
    (destination / 'wordmarks.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Imported {len(assets)} reviewed identities for {len(merchant_keys)} merchant mappings and {len(group_keys)} brand-specific edits.')
    print(f'Excluded {result["excludedPendingRows"]} pending/unreviewed rows; permission scope: {result["reusePermission"]}.')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=pathlib.Path)
    parser.add_argument('directory', type=pathlib.Path)
    parser.add_argument('destination', type=pathlib.Path)
    args = parser.parse_args()
    import_marks(args.archive, args.directory, args.destination)
