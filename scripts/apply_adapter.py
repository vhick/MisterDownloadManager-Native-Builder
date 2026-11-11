#!/usr/bin/env python3
"""Source adapter: make pre-existing data directory fail closed on read-only media.

Upstream's portable_dir() falls back to AppData when Data exists but is read-only.
For NATIVE we require stable storage path even if writable storage becomes unavailable.
Changing the return value preserves the portable root and lets ordinary write failures
surface instead of migrating silently to the host profile.
"""
import argparse
from pathlib import Path

BEFORE = '''    let probe = dir.join(".write-test");
    let writable = std::fs::write(&probe, b"").is_ok();
    let _ = std::fs::remove_file(&probe);
    writable.then_some(dir)'''
AFTER = '''    // Native portable fail-closed: the presence of Data selects this folder even
    // when storage turns read-only. Never silently switch to %APPDATA%.
    // Actual writes still fail if Data is not writable; no host-state harvesting.
    Some(dir)'''


def adapt(source):
    if source.count(BEFORE) != 1:
        raise RuntimeError("Expected upstream portable_dir block not found exactly once; source drift")
    return source.replace(BEFORE, AFTER, 1)


def inspect(source):
    requirements = [
        'pub fn portable_dir()', 'std::env::current_exe()', 'join("data")',
        'pub fn data_dir()', 'if let Some(dir) = portable_dir()',
        'pub fn instance_lock()', 'pub fn endpoint_path()',
    ]
    for marker in requirements:
        if marker not in source:
            raise RuntimeError(f"Missing expected storage marker: {marker}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--upstream', required=True)
    args = p.parse_args()
    path = Path(args.upstream) / 'crates/ipc/src/lib.rs'
    src = path.read_text(encoding='utf-8')
    inspect(src)
    new = adapt(src)
    path.write_text(new, encoding='utf-8', newline='\n')
    # Guards: native host's CLI registration is rejected in portable mode, but serve isn't.
    host = (Path(args.upstream) / 'crates/nmhost/src/main.rs').read_text(encoding='utf-8')
    for marker in ('const HOST_NAME: &str = "com.misterdownloadmanager.host";',
                   'portable_refused()?;', '"--register" => register(all_users)',
                   '"--unregister" => unregister(all_users)', 'our_caller(&args)'):
        if marker not in host: raise RuntimeError(f"Unexpected host source: {marker}")
    # Prevent drift of browser ID constants used by the optional console.
    extension = (Path(args.upstream) / 'crates/ipc/src/extension.rs').read_text(encoding='utf-8')
    for marker in ('oogbclbbninliongijffeeggalppliok',
                   'ejoleppdfgjdndddcjoehopknmlglojp',
                   'integration@misterdownloadmanager.com'):
        if marker not in extension: raise RuntimeError(f"Extension identity changed: {marker}")
    print('SOURCE-INSPECTED: fail-closed intrinsic data folder adapter applied, host ID guarded')


if __name__ == '__main__':
    main()
