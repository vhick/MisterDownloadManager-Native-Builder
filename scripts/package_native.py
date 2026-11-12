#!/usr/bin/env python3
"""Package audited source-built MDM NATIVE binaries; no installers or wrappers."""
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import zipfile
from pathlib import Path

BINARIES = (
    "misterdownloadmanager.exe",
    "misterdownloadmanager-nmhost.exe",
    "misterdownloadmanager-cli.exe",
    "misterdownloadmanager-mcp.exe",
)
ROOT_NAME = "MisterDownloadManager-NativePortable"
PATCH_ROOT = "MisterDownloadManager-Source-Patch"
SOURCE_REPO = "https://github.com/anefzaoui/misterdownloadmanager"
MAX_PATCH_ARCHIVE_BYTES = 20 * 1024 * 1024


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_x64_pe(path):
    if not path.is_file() or path.stat().st_size < 256:
        return False
    with path.open('rb') as fh:
        header = fh.read(64)
        if header[:2] != b'MZ':
            return False
        pe_offset = struct.unpack_from('<I', header, 0x3c)[0]
        if pe_offset < 64 or pe_offset > path.stat().st_size - 24:
            return False
        fh.seek(pe_offset)
        coff = fh.read(6)
    return coff[:4] == b'PE\0\0' and struct.unpack('<H', coff[4:])[0] == 0x8664


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--upstream', required=True)
    parser.add_argument('--identity', default='build-identity.json')
    parser.add_argument('--output', default='dist')
    args = parser.parse_args()
    checkout = Path(args.upstream).resolve()
    here = Path(__file__).resolve().parents[1]
    identity = json.loads(Path(args.identity).read_text(encoding='utf-8'))
    actual_sha = subprocess.check_output(['git','-C',str(checkout),'rev-parse','HEAD'], text=True).strip()
    if actual_sha.lower() != identity['upstream_sha'].lower():
        raise RuntimeError('Checked-out upstream commit differs from verified stable tag')
    source = (checkout / 'crates/ipc/src/lib.rs').read_text(encoding='utf-8')
    if 'Native portable fail-closed:' not in source:
        raise RuntimeError('Mandatory source-level storage adapter not applied')
    if 'Some(dir)' not in source:
        raise RuntimeError('Source-level storage containment marker missing')
    version = identity['version']
    cargo = (checkout / 'Cargo.toml').read_text(encoding='utf-8')
    if f'version = "{version}"' not in cargo:
        raise RuntimeError('Cargo workspace version does not match stable release')
    bin_dir = checkout / 'target/release'
    for name in BINARIES:
        if not is_x64_pe(bin_dir / name):
            raise RuntimeError(f'Missing/not genuine 64-bit Windows application binary: {name}')
    pack = checkout / 'target/extension'
    if not (pack / 'chromium/manifest.json').is_file() or not (pack / 'mdm-firefox.xpi').is_file():
        raise RuntimeError('Official extension packaging output missing: run tools/extension/pack.ps1')
    firefox = pack / 'mdm-firefox.xpi'
    with zipfile.ZipFile(firefox) as xpi:
        if xpi.testzip() or 'manifest.json' not in xpi.namelist():
            raise RuntimeError('Firefox extension XPI corrupt')
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    stage = out / ROOT_NAME
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)
    for name in BINARIES:
        shutil.copy2(bin_dir / name, stage / name)
    shutil.copy2(checkout / 'LICENSE', stage / 'LICENSE.txt')
    shutil.copy2(checkout / 'ATTRIBUTION.md', stage / 'ATTRIBUTION.txt')
    shutil.copytree(pack / 'chromium', stage / 'extension/chromium')
    (stage / 'extension').mkdir(exist_ok=True)
    shutil.copy2(firefox, stage / 'extension/mdm-firefox.xpi')
    shutil.copy2(here / 'portable_integration/Manager.ps1', stage / 'Manager.ps1')
    shutil.copy2(here / 'portable_integration/Mister-Manager.cmd', stage / 'Mister-Manager.cmd')
    (stage / 'data').mkdir()
    (stage / 'data/README.txt').write_text(
        'This folder is the NATIVE application data root. NEVER delete it on upgrade.\n'
        'Optional browser/auto-start ownership journals are in data/Integration/.\n'
        'New legacy browser registry backups are in data/Integration/Legacy-Registry-Backups/.\n'
        'Do not run the application from a read-only location.\n', encoding='utf-8')
    shutil.copy2(here / 'docs/NATIVE_WINDOWS_ACCEPTANCE.md', stage / 'WINDOWS_ACCEPTANCE.txt')
    shutil.copy2(here / 'docs/PORTABLE_USAGE.md', stage / 'PORTABLE_USAGE.txt')
    identity['cargo_lock_sha256'] = sha256(checkout / 'Cargo.lock')
    identity['actual_rustc'] = subprocess.check_output(['rustc', '--version'], encoding='utf-8', text=True).strip()
    identity['actual_cargo'] = subprocess.check_output(['cargo', '--version'], encoding='utf-8', text=True).strip()
    identity['github_runner_os'] = os.getenv('RUNNER_OS', 'unknown')
    identity['github_run_id'] = os.getenv('GITHUB_RUN_ID', 'unknown')
    identity['source_adapter'] = 'scripts/apply_adapter.py fail-closed storage selection'
    identity['source_adapter_sha256'] = sha256(here / 'scripts/apply_adapter.py')
    identity['unified_manager_sha256'] = sha256(here / 'portable_integration/Manager.ps1')
    identity['unmodified_upstream_commit'] = actual_sha
    identity['binary_sha256'] = {name: sha256(stage / name) for name in BINARIES}
    (stage / 'BUILD-IDENTITY.json').write_text(json.dumps(identity, indent=2) + '\n', encoding='utf-8')
    zip_name = f'MisterDownloadManager-{version}-NativePortable-{identity["builder_revision"]}.zip'
    zip_path = out / zip_name
    if zip_path.exists():
        zip_path.unlink()
    # GPL-3.0 source availability: publish an exact commit URL and our modified
    # source as a small patch instead of recursively archiving the entire CI
    # working tree (which can include enormous generated/untracked resources).
    source_name = f'MisterDownloadManager-{version}-NativePortable-SOURCE-PATCH-{identity["builder_revision"]}.zip'
    source_zip = out / source_name
    if source_zip.exists():
        source_zip.unlink()
    changed_paths = subprocess.check_output(
        ['git', '-C', str(checkout), 'diff', '--name-only', 'HEAD', '--'],
        text=True, encoding='utf-8').splitlines()
    expected_path = 'crates/ipc/src/lib.rs'
    if changed_paths != [expected_path]:
        raise RuntimeError(f'Unexpected modified upstream files: {changed_paths}; only the audited storage patch is allowed')
    patch = subprocess.check_output(
        ['git', '-C', str(checkout), 'diff', '--binary', 'HEAD', '--', expected_path])
    if not patch.startswith(b'diff --git a/crates/ipc/src/lib.rs b/crates/ipc/src/lib.rs'):
        raise RuntimeError('The expected exact source patch was not generated')
    if len(patch) > 2 * 1024 * 1024:
        raise RuntimeError('Source patch unexpectedly exceeds 2 MiB')
    patch_sha = hashlib.sha256(patch).hexdigest()
    identity['source_patch_sha256'] = patch_sha
    identity['source_repository'] = SOURCE_REPO
    identity['source_archive_url'] = f'{SOURCE_REPO}/archive/{actual_sha}.zip'
    identity['source_distribution'] = 'Exact upstream source by commit URL + this published modified-source patch and builder'
    (stage / 'BUILD-IDENTITY.json').write_text(json.dumps(identity, indent=2) + '\n', encoding='utf-8')
    source_access = (f'Mister Download Manager modified corresponding-source access\n'
        f'Upstream: {SOURCE_REPO}\nTag: {identity["upstream_tag"]}\n'
        f'Exact commit: {actual_sha}\nSource archive: {SOURCE_REPO}/archive/{actual_sha}.zip\n'
        f'Applied source patch: {source_name} (PORTABILITY.patch)\n'
        f'Patch SHA-256: {patch_sha}\n'
        f'Builder revision: {identity["builder_revision"]}\n'
        'The runnable application ZIP intentionally contains no Rust checkout.\n'
        'To reconstruct the full modified source, obtain the exact upstream commit,\n'
        'then apply PORTABILITY.patch with git apply. The patch ZIP also includes\n'
        'Cargo.lock, the changed Rust source file, and build scripts.\n'
        'GPL-3.0-or-later: anyone distributing these binaries is responsible for\n'
        'ensuring that the complete Corresponding Source remains freely obtainable.\n'
        'If the upstream source link stops working, the distributor must provide\n'
        'equivalent complete source access; a patch alone is not sufficient.\n')
    (stage / 'SOURCE-ACCESS.txt').write_text(source_access, encoding='utf-8')
    # Create the application ZIP once, after build identity and source directions are final.
    with zipfile.ZipFile(zip_path, 'w', compression=zipfile.ZIP_DEFLATED,
                         compresslevel=7, allowZip64=True) as archive:
        for path in sorted(stage.rglob('*')):
            if path.is_symlink():
                raise RuntimeError(f'Unexpected symlink in staging: {path}')
            if path.is_file():
                archive.write(path, f'{ROOT_NAME}/{path.relative_to(stage).as_posix()}')
    with zipfile.ZipFile(source_zip, 'w', compression=zipfile.ZIP_DEFLATED,
                         compresslevel=7, allowZip64=True) as archive:
        archive.writestr(f'{PATCH_ROOT}/PORTABILITY.patch', patch)
        archive.writestr(f'{PATCH_ROOT}/UPSTREAM-SOURCE.txt', source_access)
        archive.writestr(f'{PATCH_ROOT}/BUILD-IDENTITY.json', json.dumps(identity, indent=2) + '\n')
        archive.write(checkout / 'Cargo.lock', f'{PATCH_ROOT}/Cargo.lock')
        archive.write(checkout / expected_path, f'{PATCH_ROOT}/patched/{expected_path}')
        for local_file in sorted(here.rglob('*')):
            rel = local_file.relative_to(here)
            if local_file.is_dir() or local_file.is_symlink():
                continue
            if any(part in ('__pycache__', '.git') for part in rel.parts):
                continue
            if rel.suffix in ('.pyc', '.zip'):
                continue
            archive.write(local_file, f'{PATCH_ROOT}/builder/{rel.as_posix()}')
    if source_zip.stat().st_size > MAX_PATCH_ARCHIVE_BYTES:
        raise RuntimeError('Source patch bundle unexpectedly large; refusing to publish')
    with zipfile.ZipFile(source_zip) as check:
        names = set(check.namelist())
        required = {f'{PATCH_ROOT}/PORTABILITY.patch',
                    f'{PATCH_ROOT}/UPSTREAM-SOURCE.txt',
                    f'{PATCH_ROOT}/Cargo.lock',
                    f'{PATCH_ROOT}/patched/{expected_path}',
                    f'{PATCH_ROOT}/builder/scripts/apply_adapter.py'}
        if check.testzip() or not required.issubset(names):
            raise RuntimeError('Source patch archive integrity check failed')
    print(f'Created NATIVE ZIP {zip_path} SHA256 {sha256(zip_path)}')
    print(f'Created compact SOURCE PATCH ZIP {source_zip} SHA256 {sha256(source_zip)}')
    print(f'Upstream tag {identity["upstream_tag"]}, commit {actual_sha}, lock {identity["cargo_lock_sha256"]}')


if __name__ == '__main__':
    main()
