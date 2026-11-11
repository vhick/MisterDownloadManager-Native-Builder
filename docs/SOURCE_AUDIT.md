# Application-specific source audit — MDM v0.5.2

## Scope and provenance

The source was inspected as text from the official `anefzaoui/misterdownloadmanager` **v0.5.2** GitHub tag (stable release), not from an unverified main branch. On each GitHub build, the resolver discovers the newest suitable released stable semantic version or explicitly supplied stable version, resolves the tag to a full 40-hex Git commit SHA, validates the cloned HEAD against that value, and records `Cargo.lock` SHA-256, source patch hash, package revision and binary hashes. The actual upstream SHA is deliberately not hardcoded in documentation: it is resolved and checked at build time. No binary was downloaded or executed during this kit's local authoring.

**Upstream source citations (official raw tag URLs)**

- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/Cargo.toml — Rust 2024 workspace, `rust-version = 1.95`, `GPL-3.0-or-later`, pinned git dependencies.
- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/crates/ipc/src/lib.rs — `data_dir`, `portable_dir`, lock and IPC channel paths.
- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/crates/nmhost/src/main.rs — native messaging protocols, browser keys, CLI registration guard and independent `serve()`.
- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/crates/ipc/src/extension.rs — Chromium and Firefox identity and extension-seen file.
- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/tools/installer/build.ps1 — official portable `data` directory and Windows binary names.
- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/tools/extension/pack.ps1 — Chromium/Firefox extension resource build.
- https://raw.githubusercontent.com/anefzaoui/misterdownloadmanager/v0.5.2/ATTRIBUTION.md — redistribution notices.
- https://raw.githubusercontent.com/vhick/portable-release-publisher/v1.1.1/action.yml — shared publisher inputs / composite implementation.

The audit is **source-level**, not a Windows runtime ProcMon/registry trace. Source changes that invalidate guards cause CI to stop instead of blindly applying a patch to a different version.

## Mode-specific finding matrix

| Finding | Evidence status / source | Path or registry | Component | NATIVE remedy | PORTABLEAPPS remedy | Data safety | Tradeoff / test / limit |
|---|---|---|---|---|---|---|---|
| Local portable root | SOURCE-INSPECTED `crates/ipc/src/lib.rs:portable_dir()` | `<running EXE>/data/` | App shared IPC library | Maintain upstream `current_exe()` root and create `data/` before launch | Not applicable | Local direct save | Test arbitrary working directory, drive move and Unicode path |
| Read-only media fallback | SOURCE-INSPECTED same function, write probe and `writable.then_some(dir)` | `%APPDATA%/misterdownloadmanager` fallback | App | Fail-closed one-block source patch, never fall back if `data` exists | Not applicable | Prevents silent data-splitting | Writes correctly fail on unwritable media; Windows runtime still unverified |
| Env override | SOURCE-INSPECTED `data_dir()` | `MDM_DATA_DIR` | App | Respect supported override; document exceptions | Not applicable | Per-process override | An explicitly set environment variable overrides local data, so unset it for normal portable use |
| Legacy profile | SOURCE-INSPECTED `data_dir()` | `%APPDATA%/idmnext` to `%APPDATA%/misterdownloadmanager` when no portable root | App | `data/` ensures fallback migration branch not used | Not applicable | Protect existing installed profile | Audit first run under real Windows account |
| IPC and instance lock | SOURCE-INSPECTED shared IPC lib | `data/ipc.json`, `data/instance.lock` | App + CLI + nmhost | All binaries kept together, same root resolution | Not applicable | Token and single instance remain local | Test multiple launches, extension auto-start, relocated folder |
| Downloaded files | SOURCE-INSPECTED upstream portable guidance | Default Downloads folder (user-selected output) | App | Keep user-selected output path unchanged | Not applicable | Never move/delete downloads | Configure Save To folder manually for fully movable download destinations |
| Native-messaging registration | SOURCE-INSPECTED `crates/nmhost/src/main.rs:portable_refused()` | HKCU browser `NativeMessagingHosts` | Native host CLI | Optional ownership-aware `BrowserIntegration.ps1` builds same-form manifests without invoking refused `--register` | Not applicable | Fail on key collisions | OS registration is intentional; test browsers manually |
| Browser caller allowlist | SOURCE-INSPECTED `crates/ipc/src/extension.rs`, nmhost `our_caller()` | Browser native host manifests | Extension + native host | Restrict to exact unpacked/store Chromium IDs and Firefox ID | Not applicable | No arbitrary extension origins | New upstream store IDs require explicit script revision |
| Native host auto-start | SOURCE-INSPECTED `crates/nmhost/src/main.rs:deliver()` | Adjacent `misterdownloadmanager.exe` | Native host | Keep host and app beside each other | Not applicable | No wrapper or global PATH | Browsers can launch app on demand; test with app initially closed |
| Native extensions | SOURCE-INSPECTED `tools/extension/pack.ps1` | packaged Chromium folder / Firefox XPI | Browser | Package upstream-generated assets | Not applicable | Does not change browser profile | Firefox unsigned XPI not assumed permanently installable |
| Start at login | SOURCE-INSPECTED `Command.startup` and `/startup` | HKCU Run opt-in | App + optional manager | Optional journalled manager; never install by default | Not applicable | Never overwrite unowned Run value | Test login, relocation and remove, exact EXE ownership |
| Tray / notifications | SOURCE-INSPECTED app `tray-icon` dependency; Windows integration not traced | Windows notification area, OS caches | App + Windows | Keep upstream native behavior unmodified | Not applicable | No cleanup of Windows caches | GUI acceptance required |
| Auxiliary processes / helpers | SOURCE-INSPECTED upstream package crates and attribution | App data, optional external 7-Zip | App/dependencies | Preserve bins and local app data; do not bundle external program without verification | Not applicable | External dependencies unchanged | Test media/torrent/extraction workflows, close state |
| Self-update | NOT YET VERIFIED in Windows | App EXE and optional updater temp/state | App/update subsystem | Warn; use manual binary replacement and preserve `data` | Not applicable | Back up data; keep release ZIP | Do not assert internal auto-updater safely patches this unofficial build |
| Windows caches, jump lists | INFERRED Windows/framework behavior | Windows caches and user profile | Windows OS | Document unavoidable OS-managed traces, no post-exit harvesting | Not applicable | Protect host | Trace with ProcMon in real Windows; zero-trace promise impossible |

## Implementation architecture

- **EXE storage:** upstream in-process path selection is controlled in the IPC crate and reused by the GUI and native host. `data/` is created by the package. One minimal patch removes writable-probe-driven AppData fallback for an existing `data/` directory; preserving existing failure behavior when directory is absent. The running executable's location is used, never the current working directory.
- **Native messaging:** the host itself checks a browser-provided origin/add-on ID, and its normal `serve()` path is independent of the `--register` subcommand. Windows native messaging requires a manifest file and HKCU/HKLM registry pointer. The optional scripts create only per-user HKCU pointers, never HKLM. The manifest `path` points directly to the **native host EXE**, not PowerShell or a wrapper. The host then launches the adjacent main executable if needed. See `docs/PORTABLE_USAGE.md`.
- **Collision protection:** per-user Chrome, Chromium, Edge, Brave and Firefox registration keys AND system-wide HKLM equivalents are checked before any registration; the script never changes unowned keys. Ownership is journalled under local `data/Integration`; removed keys must still match the journal, preserving installed-app and user modifications. Optional HKCU Run autostart uses a unique key name, also only after explicit consent.
- **No PortableApps:** no AppNamePortable launcher, installer, PortableApps metadata, data harvesting, post-exit shell scraping, or shared package builder.

## Compatibility and audit limitations

We did not run static analysis over every dependency's Windows host-write behavior nor an actual ProcMon trace. Dependencies (Windows networking/crypto, tray and notification stacks, user-selected downloaded-file destinations and browser OS activity) can generate host-managed activity. App credentials may be tied to a Windows user via native encryption. `MDM_DATA_DIR` and `--data` are intended overrides. This kit specifically protects core app-owned data selection and opts into browser registry integration. It does **not** certify zero writes outside the folder. Audit on Windows before claiming complete runtime containment.

The source-built app is **not** a trivial repackaging of official release binaries; it compiles the real upstream four Rust programs from pinned source. No runnable binary is included in the **builder kit** before GitHub CI completes.
