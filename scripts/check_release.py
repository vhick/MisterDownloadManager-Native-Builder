#!/usr/bin/env python3
"""Check published builder release identity; treat 404 as absent, other HTTP errors as fatal."""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

identity = json.loads(Path('build-identity.json').read_text(encoding='utf-8'))
repo = os.environ['GITHUB_REPOSITORY']
url = f"https://api.github.com/repos/{repo}/releases/tags/{urllib.parse.quote(identity['release_tag'])}"
request = urllib.request.Request(url, headers={
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'mdm-native-builder-b1r2',
    'Authorization': f"Bearer {os.environ['GITHUB_TOKEN']}",
})
try:
    with urllib.request.urlopen(request, timeout=30) as response:
        record = json.load(response)
    exists = True
    if record.get('draft'):
        raise RuntimeError('Same-tag draft exists: refusing duplicate release')
    if '<!-- portable-release-publisher:managed:v2 -->' not in (record.get('body') or ''):
        raise RuntimeError('Same-tag release is not owned by pinned publisher: refusing collision')
    asset_names = {a.get('name', '') for a in record.get('assets', [])}
    expect = {
        f"MisterDownloadManager-{identity['version']}-NativePortable-{identity['builder_revision']}.zip",
        f"MisterDownloadManager-{identity['version']}-NativePortable-SOURCE-{identity['builder_revision']}.zip",
        'SHA256SUMS.txt',
    }
    if asset_names != expect:
        raise RuntimeError(f'Same-tag release assets mismatch/incomplete: {sorted(asset_names)}')
except urllib.error.HTTPError as exc:
    if exc.code == 404:
        exists = False
    else:
        raise RuntimeError(f'Cannot check release identity (HTTP {exc.code})') from exc
print(f"Release already exists: {exists}")
with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8', newline='\n') as out:
    out.write(f"exists={'true' if exists else 'false'}\n")
