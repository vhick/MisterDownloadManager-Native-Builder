# Mister Download Manager — NATIVE portable builder b1r5

**Unofficial, independent GitHub Actions source builder and a single optional Windows manager.** Not an upstream fork and not an official installer.

- Upstream: https://github.com/anefzaoui/misterdownloadmanager
- Selected architecture: **NATIVE only**. The executable `misterdownloadmanager.exe` launches directly; the manager is not necessary for portability.
- Verified source audit reference: published upstream v0.5.2; the build resolves the latest published stable tag (or an explicitly selected stable version). Changed upstream Rust source must pass strict adapter matching.
- Compiler: GitHub-hosted Windows x64, Rust >= 1.95, locked Cargo dependencies.
- Publisher: `vhick/portable-release-publisher@cb64f86ac2d8c67506db5832de07f9ff58cbeaeb` (pinned v1.1.1). No PortableApps installer in NATIVE mode.

## Unified manager (retained from b1r3)

**Only ONE console is required: `Mister-Manager.cmd` with `Manager.ps1`.** It combines the earlier manager, the opt-in portable browser native-messaging registration, and the user-confirmed working standalone legacy browser-host cleanup. The generated native ZIP also contains only these two console files.

Launch `Mister-Manager.cmd` in a folder containing `misterdownloadmanager.exe`, `misterdownloadmanager-nmhost.exe`, and a writable `data/` folder. It provides:

| Main option | Action |
|---|---|
| 1 | Start MDM |
| 2 | Gracefully stop portable MDM |
| 3 | Application and autostart status |
| 4 | Browser registration, status, safe unregister, OLD installation cleanup |
| 5 | Optional per-user Windows autostart controls |
| 6 | Open portable data folder |
| 0 | Exit |

### Browser submenu

1. Read-only portable registration status **and** legacy scan.
2. Register or repair browser native messaging for the portable copy (HKCU only).
3. Unregister **only** portable keys owned by this manager (requires an ownership journal).
4. Clean **verified old-installation** per-user (`HKCU`) browser registrations. It inventories entries, requires the exact phrase `REMOVE LEGACY` and backs up verified keys before deletion.
5. Clean verified old system-wide (`HKLM`) browser registrations (administrator and confirmation `REMOVE SYSTEM LEGACY` required).
0. Back.

**Two distinct removal paths remain intentionally separate:** portable unregister *will never* remove old installation keys without its own journal. Legacy cleanup only targets recognized old MDM native-messaging registrations. This prevents accidental deletion of unrelated software registrations or current portable keys.

### Existing official portable version: no rebuild needed

1. Extract `portable_integration/Manager.ps1` and `portable_integration/Mister-Manager.cmd` beside your existing official **portable** MDM EXEs and `data/` folder.
2. Close existing consoles, replace the previous manager files (back them up first). Do not delete your `data/` directory or old `.reg` backups.
3. Double-click **Mister-Manager.cmd** normally, without elevation.
4. Open **4 — Browser integration** → **1 — Show status / scan**. Confirm any legacy registrations.
5. If your *installed* version has been uninstalled and old registrations are verified, use submenu **4** to clean old per-user entries (or submenu **5** for old system-wide entries, only if needed and authorized).
6. Use submenu **2** to register the portable browser host, restart the browsers, and test a download using the actual official extension.

The manager reads its own file location. It does NOT pass `%~dp0` as a native PowerShell argument, avoiding the earlier Windows PowerShell 5.1 `GetFullPath` and path-quoting failures.

## Builder kit layout

```text
.github/workflows/build-native.yml       Unattended Windows source build, tests, ZIPs, releases
portable_integration/Manager.ps1         ALL optional functions in one script
portable_integration/Mister-Manager.cmd   Single double-click Windows entry point
scripts/resolve_release.py              Stable released tag + verified commit SHA
scripts/check_release.py                Detect duplicate/publisher-owned releases
scripts/verify_publisher.py             Verify pinned v1.1.1 publisher action
scripts/apply_adapter.py                Fail-closed source patch for `data/` storage
scripts/package_native.py               Genuine EXE ZIP + GPL corresponding source patch ZIP
scripts/validate_native.py              Independent ZIP structure/hash validation
tests/test_builder.py                    Local stdlib-only regression tests
LICENSES/BUILD-KIT-LICENSE.txt           Builder and upstream licensing
docs/                                    Setup, source audit, acceptance, data safety
```

## Unattended GitHub workflow

The NATIVE pipeline resolves the actual upstream stable tag and SHA, refuses unverified main or prerelease, checks for duplicate managed releases, verifies pinned publisher inputs, checks out source, applies the exact fail-closed data adapter, builds Windows x64 Rust binaries, packages the upstream browser extension resources, and independently validates the NATIVE ZIP and the GPL source patch ZIP. The publisher dry-run is mandatory before publication. No upstream fork, local compiler, paid runner or installer is required.

**b1r5 addition:** Windows PowerShell 5.1 parses the combined `Manager.ps1`, runs a non-mutating `SelfTest`, and performs a read-only native-messaging registry scan on the hosted Windows runner. This checks console initialization but does not simulate interactive Explorer, browser extensions, actual registration, autostart, or GUI behavior.

Outputs after a *successful* hosted build:

```text
MisterDownloadManager-<version>-NativePortable-b1r5.zip
MisterDownloadManager-<version>-NativePortable-SOURCE-PATCH-b1r5.zip
SHA256SUMS.txt
```

The application ZIP contains actual source-built binaries, the only two manager files, upstream license and attribution, extension resources, build identity, and an initially empty native `data/` directory. The source patch ZIP contains the modified Rust file and patch plus this builder, a pinned original upstream source location, and exact reconstruction instructions. It is not a full upstream checkout; distributing GPL binaries requires making the full corresponding source obtainable for as long as required. No launcher, installer, PortableApps metadata or post-exit scavenger is used.

## Data protection and migration from b1r1/b1r2

- NEVER replace, wipe, or reset `data/`. Retain `data/Integration/browser-registration.json`, `autostart-ownership.json`, manifests and `.bak` files. The merged manager understands the existing b1r2 ownership journal format.
- New verified old-installation registry backups go into `data/Integration/Legacy-Registry-Backups/`. Backups created by the standalone cleaner b1r2 in `MDM-Legacy-Registry-Backups/` are **not** moved, overwritten, or deleted.
- The old `Mister-Browser-Integration.cmd` / `BrowserIntegration.ps1` and `MDM-Legacy-Browser-Cleanup.cmd` / `.ps1` are no longer required for operation; leave them alone if desired or archive the scripts only. Do not delete any backup folder.
- Native-browser integration intentionally creates HKCU registry entries. Optional autostart creates one ownership-verified HKCU Run value. Neither is an invisible host-free operation. On moving portable folders, use browser Repair and autostart Repair as needed.
- Never use upstream `misterdownloadmanager-nmhost.exe --unregister` as a shortcut: it has no knowledge of this console's ownership journal.

## Limitations and verification

- Python regression tests cover semver resolution, PE validation, correct NATIVE-only structure, a single console and registry safety guards.
- The user-provided b1r4 Actions run **successfully compiled** Windows Rust MDM and built extensions but failed source ZIP packaging; **b1r5 still needs its own CI run**. Interactive browser-extension communication, real Windows registry cleanup with the combined manager, and b1r5 publication remain unverified. The user previously confirmed the standalone b1r2 legacy cleanup works, but this does not prove the b1r5 integration has been runtime-verified.
- The upstream data-path patch is source-specific. If newer upstream versions change the exact Rust code, the build should **fail closed** until the adapter is reviewed.
- Do not use this package to remove applications, downloads, browser extensions, unrelated keys or files. Manual Windows acceptance and installed-app coexistence tests remain necessary.

Read `docs/GITHUB_DESKTOP_SETUP.md`, `docs/PORTABLE_USAGE.md`, `docs/TROUBLESHOOTING.md`, `docs/SOURCE_AUDIT.md`, and `docs/NATIVE_WINDOWS_ACCEPTANCE.md` before distributing.


## What changes in b1r5: compact source publication

The previous b1r2 release showed an 18.5 MB application ZIP and a separate 934 MB SOURCE ZIP. The SOURCE ZIP resulted from archiving the entire upstream build checkout, not from app files. **b1r5 removes that archive step.** Builds are still compiled from verified upstream Rust source; the runtime ZIP contains only compiled binaries, extension resources, manager and empty `data/`. The second release ZIP is a deliberately compact `SOURCE-PATCH` bundle containing `PORTABILITY.patch`, patched Rust source, Cargo.lock, builder scripts and instructions to fetch the full exact upstream commit. It is not the full source tree. Complete Corresponding Source must remain available under the GPL, and distributors must arrange equivalent access if the upstream source link ceases to work. The source patch ZIP has a 20 MiB maximum-size safeguard; a source tree is never recursively packed into a release asset.

## b1r5 fix — source patch ZIP builder-root recursion (Nov 12, 2026)

The real b1r4 Windows run compiled the MDM executables successfully but failed
at `scripts/package_native.py` while building the compact source ZIP. The
source packager accidentally scanned all files under the builder checkout, which
included the freshly cloned `upstream/`, compiled `upstream/target/`, and
untracked CI output. Its 20 MiB source-archive safeguard correctly stopped
publication but the recursive inclusion was a packaging defect.

b1r5 replaces that recursion with an **exact explicit manifest of 19 builder
source files**. No `upstream/`, `dist/`, `target/`, `.git/`, cache, or unknown
local file can enter the source-patch ZIP. The 20 MiB archive limit remains.
Two new regression tests create 25 MiB of synthetic Rust build output and
untracked/secret files adjacent to the builder and verify they are excluded.
The main application ZIP contents, Rust source adapter, and unified manager
are unchanged from b1r4. No need to rebuild or modify your existing portable
MDM installation. Run a new GitHub Actions dispatch with revision `b1r5`.

**GPL reminder:** The SOURCE-PATCH asset is not a complete source checkout.
Distribution requires continued access to the exact upstream source and all
corresponding source/build materials, not only the patch. See `SOURCE-ACCESS.txt`.
