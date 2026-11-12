# Troubleshooting — Unified NATIVE Manager b1r4

## Manager fails to open

Check `Manager.ps1` and `Mister-Manager.cmd` are **both** beside `misterdownloadmanager.exe` and `misterdownloadmanager-nmhost.exe`, not inside an extra nested directory. The CMD file does not pass `%~dp0` as a PowerShell argument, so it avoids the b1r1/b1r2 trailing-backslash `GetFullPath` and `Illegal characters in path` startup errors. Do not use the older browser/legacy CMD files for this build.

## Browser extension disconnected

1. Run `Mister-Manager.cmd` → main **4** → browser **1** (read-only scan).
2. Check if a previous normal installation owns any HKCU or HKLM registration. The manager does not overwrite it.
3. If the normal installation is no longer needed, uninstall it through Windows Settings and retain your download data. Scan again. Browser submenu **4** can remove only verified old current-user registrations after backup and confirmation. Submenu **5** is only for deliberate, authorized old system-wide cleanup (administrator required); check no other Windows user still needs it.
4. After old registrations are absent, browser submenu **2** registers the portable host. Close/reopen Chrome, Chromium, Edge, Brave or Firefox and test the **official** MDM browser extension.
5. If the portable folder moved, use browser submenu **2** to repair journal-owned paths, then restart browsers. Do not delete the ownership journal.

## “No ownership journal”

This message comes only from the *portable-only unregister* function. It intentionally refuses to remove keys not previously registered by this script. To clean *verified old-installation* keys, use the distinct legacy scan/removal functions in the **same browser submenu**. The old legacy cleaner b1r2 was reported working; its registry safeguards remain but live b1r4 integration testing is still pending.

## Browser registration says “Existing key belongs to another installation”

This is an ownership conflict. Do not delete the key without inspecting its manifest path and whether an installed MDM still needs it. Browser submenu **1** lists paths and classifies potential legacy entries. The portable register option never hijacks another application's keys.

## What “Clean verified OLD” does

- Only exact MDM native-host keys for the five supported browser families are candidates.
- Entries are skipped if they look like portable registrations, contain unexpected values/subkeys, have an unrecognized manifest name or cannot be verified.
- Removal requires literal confirmation: `REMOVE LEGACY` for HKCU or `REMOVE SYSTEM LEGACY` for HKLM.
- The application must not be running. Backups are exported as `.reg`, verified, SHA-256-indexed, and stored under `data/Integration/Legacy-Registry-Backups/` *before* key removal.
- The older standalone b1r2 backup directory `MDM-Legacy-Registry-Backups/` remains untouched. Retain it for restoration.
- It never removes download files, settings, browser extensions, native application binaries or unrelated keys.

## Manager Start, Stop or autostart issues

- The manager identifies a running process by its full EXE path so it should not target another installed copy with the same process name.
- Stop asks the application to exit using `/exit`, without forced termination. If MDM does not exit, use its tray menu and save downloads before troubleshooting.
- Startup is **off by default**. Main **5** → **2** enables one journal-owned HKCU Run entry after confirmation; **3** disables it; **4** repairs that specific entry after a folder move. Existing or modified entries are protected.
- Running CMD as a *different* administrator account accesses that account's HKCU, not your normal browser profile.

## Build errors

- GitHub API HTTP 401/403/429: authentication, permissions or rate-limit issue; the resolver must not silently fall back to main.
- No stable release: no matching published semver release. Check the version selected in Run workflow.
- Exact source adapter mismatch: upstream changed `crates/ipc/src/lib.rs`; source patch intentionally refuses to guess. Audit the new source version before updating it.
- PowerShell 5.1 parse/SelfTest/read-only scan fails: fix the integrated script before building/publishing.
- Rust build fails: inspect `cargo fetch --locked`, MSVC dependencies and compiler output. Do not force unlocked compilation.
- Package validation fails: real x64 binaries, source identity, extension assets, and exactly one unified manager are required.
- Publisher validation fails: check verified immutable v1.1.1 action, asset identity and dry-run. Do not replace tags blindly.
- Duplicate managed release: the existing managed release has already published matching upstream tag/revision. Increase revision only for an intentional new builder change.

## Upgrade and rollback

Stop MDM completely. Back up the full `data/` directory and old standalone `.reg` backups. Replace the program files and unified console files, **never** the existing `data/` tree or owner journals. If you downgrade across data-schema changes, restore a matching older data backup. Re-register/repair the portable host after a folder move only if journal ownership is preserved. Unsigned binaries may show normal Windows security warnings; do not disable system security tools.
