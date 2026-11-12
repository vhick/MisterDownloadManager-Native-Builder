# NATIVE portable use — unified manager b1r3

Mister Download Manager launches **directly** from `misterdownloadmanager.exe`. The optional `Mister-Manager.cmd` does not make the application portable; it only provides convenient lifecycle, Windows-startup and explicitly approved browser integration actions.

## First run — source-built native ZIP

1. Extract the entire NATIVE ZIP to a writable folder, including `data/`.
2. Start `misterdownloadmanager.exe` directly. Close, reopen, and confirm settings were retained in `data/`.
3. If browser integration is desired, double-click `Mister-Manager.cmd` and choose main **4** → browser **1** (read-only status). If no old registrations conflict, choose browser **2** (Register/Repair).
4. Restart the browser and test the official browser extension with a real download. This is an interactive Windows test, not a CI verification.

## No-rebuild browser fix for the official portable MDM ZIP

Copy **only** the two files below from the builder kit's `portable_integration/` folder into your existing official portable MDM folder, beside the application EXE and `misterdownloadmanager-nmhost.exe`:

- `Manager.ps1`
- `Mister-Manager.cmd`

The portable folder must already have a writable `data/` directory. Back up your earlier manager files before replacing them; do **not** delete existing app binaries or `data/`. Unlike b1r1/b1r2, no extra browser/cleanup CMD consoles or PS1 files are needed.

### Single-menu guide

**Main menu**: 1 Start; 2 Gracefully stop; 3 Status; 4 Browser integration; 5 Windows login autostart; 6 Open Data; 0 Exit.

**Browser menu**: 1 Show portable + old-installation registrations (read only); 2 Register/repair the portable browser host; 3 Unregister only this script's portable host (requires its ownership record); 4 Clean VERIFIED old HKCU registrations with `.reg` backup; 5 Clean VERIFIED old HKLM registrations with `.reg` backup (administrator required); 0 Back.

**Autostart menu**: 1 Status; 2 Enable; 3 Disable; 4 Repair after move; 0 Back.

## Preserving integration state and backups

- Browser registration journals and manifests: `data/Integration/browser-registration.json`, `com.misterdownloadmanager.host.json`, `com.misterdownloadmanager.host.firefox.json`.
- Autostart journal: `data/Integration/autostart-ownership.json`.
- New legacy-cleanup `.reg` backups: `data/Integration/Legacy-Registry-Backups/`.
- The older standalone cleanup saved backups in `MDM-Legacy-Registry-Backups/` beside the EXE. These previous backups remain untouched by the unified manager. Retain them in case rollback is needed.

Browser registry keys under HKCU are **intentional host integration**, not an application-profile write. No browser extension is installed automatically. A normal installed MDM may own the same host name. The manager refuses registration collisions; it never takes ownership without evidence. The separate legacy-cleanup submenu requires an inventory, recognized old-host path, confirmation and a verified backup before a targeted deletion. Do not remove entries for an installed MDM you still intend to use.

## Relocation, update and rollback

1. Exit MDM; make a backup of the entire `data/` directory and any older standalone `.reg` backup folder.
2. Replace executable/resources/manager files but **not** `data/`.
3. If you moved folders or drive letters, select browser 2 (Repair) to update journal-owned native host paths and autostart 4 (Repair) if you had enabled per-user startup. Do not change unrelated registry values.
4. Test the extension and MDM settings. For downgrades, restore the matching prior `data/` backup if a schema change occurred.

The launcher avoids passing a path argument ending in backslash (`%~dp0`) into PowerShell and locates its own script from `$PSCommandPath`, following the fixed working b1r2 strategy. Run normally (non-admin) for HKCU; use administrator rights only if you explicitly authorize cleaning old HKLM registrations. Be aware that elevating using another account changes which account's HKCU is accessed.

## What remains outside the portable folder

Windows and browsers may keep OS-managed caches/history. Authorized native messaging registry entries, optional per-user startup and store-installed extensions remain on the host by design. Direct startup does not require those optional integrations. Browser/notification behavior and Windows app runtime portability require manual testing.
