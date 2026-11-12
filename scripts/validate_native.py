#!/usr/bin/env python3
"""Validate the zipped, source-built application, independent of publisher."""
import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path
from package_native import BINARIES, ROOT_NAME


def is_x64_pe_bytes(blob):
    if len(blob) < 256 or blob[:2] != b'MZ':
        return False
    offset = int.from_bytes(blob[0x3c:0x40], 'little')
    if offset < 64 or offset > len(blob) - 24:
        return False
    return blob[offset:offset+4] == b'PE\x00\x00' and int.from_bytes(blob[offset+4:offset+6], 'little') == 0x8664


def validate(path):
    path = Path(path)
    if path.suffix.lower() != '.zip' or not zipfile.is_zipfile(path):
        raise RuntimeError('ZIP missing/invalid')
    with zipfile.ZipFile(path) as z:
        members = z.namelist()
        if z.testzip() is not None: raise RuntimeError('ZIP CRC check failed')
        if len(members) != len(set(members)): raise RuntimeError('Duplicate names inside ZIP')
        for name in members:
            if not name.startswith(ROOT_NAME + '/') or '\\' in name or '..' in name.split('/'):
                raise RuntimeError(f'Unexpected archive name: {name}')
            if any(x in name.lower() for x in ('appinfo.ini','launcher.ini','traceguard', '.paf.exe')):
                raise RuntimeError(f'Wrong-mode component included: {name}')
        required = [f'{ROOT_NAME}/{name}' for name in BINARIES] + [
            f'{ROOT_NAME}/data/README.txt',
            f'{ROOT_NAME}/BUILD-IDENTITY.json',
            f'{ROOT_NAME}/SOURCE-ACCESS.txt',
            f'{ROOT_NAME}/Manager.ps1',
            f'{ROOT_NAME}/Mister-Manager.cmd',
            f'{ROOT_NAME}/LICENSE.txt',
            f'{ROOT_NAME}/ATTRIBUTION.txt',
            f'{ROOT_NAME}/extension/chromium/manifest.json',
            f'{ROOT_NAME}/extension/mdm-firefox.xpi',
        ]
        missing = sorted(set(required) - set(members))
        if missing: raise RuntimeError(f'Missing packaged files: {missing}')
        identity = json.loads(z.read(f'{ROOT_NAME}/BUILD-IDENTITY.json'))
        if identity.get('build_mode') != 'NATIVE': raise RuntimeError('Wrong build mode')
        if not identity.get('upstream_sha') or len(identity['upstream_sha']) != 40:
            raise RuntimeError('Missing verified source SHA')
        if identity.get('source_distribution', '').startswith('Exact upstream source') is False:
            raise RuntimeError('Missing corresponding-source distribution identity')
        source_info = z.read(f'{ROOT_NAME}/SOURCE-ACCESS.txt').decode('utf-8')
        if identity['source_archive_url'] not in source_info or identity['source_patch_sha256'] not in source_info:
            raise RuntimeError('Corresponding-source link or patch identity missing')
        for name in BINARIES:
            content = z.read(f'{ROOT_NAME}/{name}')
            if not is_x64_pe_bytes(content): raise RuntimeError(f'Invalid x64 PE binary: {name}')
            actual = hashlib.sha256(content).hexdigest()
            if actual != identity.get('binary_sha256', {}).get(name):
                raise RuntimeError(f'Binary SHA256 mismatch: {name}')
        chromium = json.loads(z.read(f'{ROOT_NAME}/extension/chromium/manifest.json'))
        if chromium.get('name') == 'com.misterdownloadmanager.host':
            raise RuntimeError('Packaged Chromium browser extension appears to be host manifest')
        with zipfile.ZipFile(__import__('io').BytesIO(z.read(f'{ROOT_NAME}/extension/mdm-firefox.xpi'))) as xpi:
            if xpi.testzip() or 'manifest.json' not in xpi.namelist():
                raise RuntimeError('Firefox XPI integrity failed')
        manager = z.read(f'{ROOT_NAME}/Manager.ps1').decode('utf-8')
        launcher = z.read(f'{ROOT_NAME}/Mister-Manager.cmd').decode('ascii')
        for must in ('HKEY_CURRENT_USER', 'browser-registration.json', 'Get-KeyDefault',
                     'Remove-VerifiedLegacy', 'Legacy-Registry-Backups', 'BACKUP-INDEX.json',
                     'Browser-Menu', 'Startup-Menu', 'Register-Portable', 'Unregister-Portable'):
            if must not in manager: raise RuntimeError(f'Missing unified manager feature/safeguard: {must}')
        if 'misterdownloadmanager-nmhost.exe --register' in manager:
            raise RuntimeError('Unsafe upstream portable host registration invoked')
        if '-AppRoot' in launcher or '-PortableRoot' in launcher:
            raise RuntimeError('Unsafe CMD root argument; previous Windows 5.1 regression')
        for legacy in ('BrowserIntegration.ps1', 'Mister-Browser-Integration.cmd',
                       'MDM-Legacy-Browser-Cleanup.ps1', 'MDM-Legacy-Browser-Cleanup.cmd'):
            if f'{ROOT_NAME}/{legacy}' in members:
                raise RuntimeError(f'Duplicate legacy console included: {legacy}')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f'STATIC-VALIDATED: NATIVE ZIP {path.name} ({path.stat().st_size:,} bytes)')
    print(f'SHA256 {digest}')
    print('No interactive GUI, registry, browser or actual data migration test performed by this validator.')
    return digest


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--zip', required=True)
    try:
        validate(ap.parse_args().zip)
    except Exception as ex:
        print(f'VALIDATION FAILED: {ex}', file=sys.stderr)
        sys.exit(1)
