# Troubleshooting (beginner-friendly)

## Existing official portable copy: browser extension says disconnected

1. Confirm `misterdownloadmanager.exe`, `misterdownloadmanager-nmhost.exe` and **`data/`** are in the same folder.
2. Copy `BrowserIntegration.ps1` and `Mister-Browser-Integration.cmd` beside them, double-click CMD, choose **2** (Status).
3. If the console reports an unowned key or an HKLM system-wide collision, an installed MDM (or a previous registration) may already control browser integration. **Do not delete the key manually.** Use the installed application's own uninstall/unregister flow after making backups, or keep using that copy.
4. If no collisions, choose **1** to register. This creates intentional HKCU native messaging entries and local JSON manifests. Restart browser completely.
5. Install/enable the official MDM extension in the browser. If using unpacked extension, only the exact built-in ID is authorized by the host. In Firefox use the store-signed add-on.
6. Run the MDM GUI once, and test context-menu Download with MDM and a normal eligible download. Check app Options for any disabled capture rules.
7. If portable folder was relocated, copy the whole folder including `data`, rerun option **1** to repair owned absolute paths. If `data/Integration` was deleted, ownership evidence is lost: the script deliberately refuses to overwrite or remove existing registry entries.
8. To remove only this integration, choose **3** then type `REMOVE`. Manually confirm keys are absent with option **2**. Registry parent keys remain as Windows state.

### What the console does not do

It does not inject into browsers, bypass browser security, overwrite other native messaging registrations, modify HKLM, create firewall exceptions or install extensions silently. Browser extension communication is still a **manual acceptance test**.

## b1r1 console error: "GetFullPath" / "The path is not of a legal form"

This came from the original b1r1 consoles evaluating `$PSScriptRoot` as a
parameter default before PowerShell had populated it. Both `.ps1` scripts and
both `.cmd` launchers were corrected in **b1r2**. Replace only these four files
beside MDM's two `.exe` binaries; **do not delete or replace `data/`**.

With the b1r2 CMD launchers, `-AppRoot` points explicitly to the console's
folder even when the parent folder contains spaces or is on a movable drive.
The PowerShell scripts also resolve their own location when run without a
specified `-AppRoot`. This change only fixes startup; it does not, by itself,
prove that browser integration is working. Existing installed-app native
messaging entries are still protected.

## Build errors

- **Release resolver HTTP 401/403/429:** authenticated API permission/rate-limit failure. Check Actions token/repository settings; retry rather than compiling the wrong branch.
- **No stable release:** the upstream may have only prereleases or an explicit version wasn't published. Do not silently use main.
- **Publisher tag/interface mismatch:** pinned v1.1.1 tag or action inputs changed unexpectedly. Inspect the action repository before updating any immutable SHA.
- **Adapter source drift:** new upstream version changed `crates/ipc/src/lib.rs` or the browser extension IDs. Reaudit source. Do not make a broad text replacement or bypass the guard.
- **Cargo lock dependency resolution:** source release may have dependency/MSVC compatibility issues. Check `cargo fetch --locked`, rustc and cargo error output; do not remove `--locked` to force an unreviewed dependency upgrade.
- **Rust Windows build error:** inspect exact failing crate and diagnostics; this kit was **not compiled in Windows during its creation**.
- **Missing EXE or extensions:** source compilation/official extension pack was incomplete; packaging intentionally refuses placeholders or repacked unrelated binaries.
- **Publisher dry-run fails:** required output files were missing/invalid or action interface no longer matches; do not force real publish.
- **Duplicate release exists:** same source/version/revision tag is already managed by publisher. Increase revision only if something changed; unrelated/manual tag conflicts are refused.

## Runtime errors

- **Settings written in AppData unexpectedly:** ensure the `data/` folder exists next to the running EXE and `MDM_DATA_DIR` isn't explicitly set to another path. For an official upstream release, a read-only `data` directory may cause fallback; this builder patches that behavior to fail instead. Inspect `data/` permissions.
- **Settings lost after move:** copy entire `data/` including hidden files and browser ownership journals; avoid mixing different Windows-account encrypted logins.
- **Manager Stop does not close:** the script only sends upstream `/exit`, no forced process kill. Quit using the tray Exit menu if necessary. Save state before testing.
- **Autostart works for installed copy instead:** console owns only value `MisterDownloadManager_NativePortable_Builder`. It refuses another owner's value and controls only the exact portable EXE process.
- **SmartScreen or antivirus prompt:** locally compiled unsigned programs may be flagged; inspect provenance and SHA-256. Do not disable security protection system-wide.
- **Portable updater/uninstaller wants privileges:** stop; the builder has no installer and no guarantee the upstream updater supports unofficial native builds. Use manual upgrades with `data/` backup.

## Upgrade/rollback safety

Exit first; back up `data/` and downloaded files. Extract the new release into a separate folder and move a copy of `data/` to it; leave original untouched until tested. If it works, retire the older binaries. If the folder path changes, repair owned browser and startup registrations with their console options. If you must roll back after a data-schema migration, restore **matching old `data` backup**; simply replacing EXEs may corrupt newer data. Never run old and new copies against the same `data` folder simultaneously.
