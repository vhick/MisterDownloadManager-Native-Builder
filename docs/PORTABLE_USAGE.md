# Mister Download Manager NATIVE portable usage

This package is an **unofficial source-built** edition of Mister Download Manager.
The main executable is `misterdownloadmanager.exe`. Launch it directly; neither
PowerShell nor the manager is needed for ordinary operation.

## First run

1. Extract the entire ZIP, including its `data` folder, to a writable location.
2. Double-click `misterdownloadmanager.exe`.
3. Verify `data` contains newly saved settings and download state after exiting.
4. For browser downloads, run `Mister-Browser-Integration.cmd` and choose 1.
5. Restart your browser and install the official MDM browser extension from its store.
6. Test a download; if no capture, see the acceptance checklist.

### Existing official portable distribution: NO REBUILD NECESSARY

For browser integration alone, copy these two files from the kit's `portable_integration` folder:

- `BrowserIntegration.ps1`
- `Mister-Browser-Integration.cmd`

For the optional manager too, copy `Manager.ps1` and `Mister-Manager.cmd` from
the same folder. b1r2 fixes the PowerShell 5.1 path-resolution issue affecting
all four console files.

Copy them beside the **existing official portable** `misterdownloadmanager.exe`
and `misterdownloadmanager-nmhost.exe`, with an existing writable `data/` folder.
Run the CMD file and select Register. This is a deliberate browser-OS integration;
portable downloads/settings remain in `data/`. It is not an invisible, registry-free
solution. This path does **not** produce a newly compiled application.

Do **not** run `misterdownloadmanager-nmhost.exe --register` on a portable copy.
Upstream refuses it. Do not use the upstream `--unregister` as a cleanup shortcut:
it does not distinguish our ownership records from an installed application's keys.

## Browser integration console

- **Register/repair:** Creates only five per-user HKCU native-messaging host keys
  if unoccupied (and no matching HKLM host), and two JSON manifests in `data/Integration`.
- **Status:** Shows which keys are absent, registered by this console, or owned
  by something else. Does not write registry state.
- **Unregister:** Deletes only keys whose current values match the recorded
  portable registration. Preserves backups and data.
- **Repair after moving:** Move the **whole** folder (including `data`), then
  run Register/repair again. The ownership journal lets it update its own
  obsolete absolute paths only. Restart browsers afterwards.

Supported host key families: Google Chrome, Chromium, Microsoft Edge,
Brave Browser, Mozilla Firefox (other Chromium/Firefox forks may read these
families; verify their actual native messaging policy). Browser store
extension IDs must match those in the inspected source tag.

**If an installed MDM owns the same HKCU keys or matching system-wide HKLM keys**, registration intentionally
fails instead of hijacking the installed copy. It does not remove an existing
installation or switch browsers behind your back. Use the installed version's
browser integration or explicitly unregister that version using its own
uninstaller after backing up user data. Never delete broad registry trees.

**Browser extension:** Install from the Chrome Web Store or Firefox Add-ons.
The source ZIP also includes `extension/chromium` for Chromium 'Load unpacked'.
Firefox's `.xpi` in the source package is not necessarily store-signed; use
addons.mozilla.org for a regular installation.

## Native manager (optional)

Double-click `Mister-Manager.cmd` for Start, graceful Stop, Status, open Data,
opt-in per-user login autostart and repair. Manager is optional; the application
works without it. It never forcibly kills an instance, installs services, or
uses a PortableApps launcher. It controls only processes with the exact same
running EXE path, protecting any installed MDM running elsewhere.

Autostart, when explicitly chosen, uses its own HKCU Run value named
`MisterDownloadManager_NativePortable_Builder`. An ownership record is saved to
`data/Integration/autostart-ownership.json`. After a folder move, select
Repair autostart. Disable it before deleting the folder. It never overwrites
an existing unowned same-name value.

## Data and upgrades

- The application-controlled core data root is **`data/`** beside the EXE,
  including logs, torrent state, themes, downloaded helper programs and site
  login information. Browser integration ownership journals are there too.
- The DEFAULT saved download destination may still be the Windows Downloads
  folder. Set MDM Options → Save To if you want downloaded files beside the EXE.
- Login secrets may be encrypted for the current Windows account; when moving
  to another PC/account, sign in again. Do not disable OS credential protections.
- Upgrades: quit app using Tasks → Exit or the optional Manager; back up all of
  `data/` and any downloaded files; extract new version into a NEW folder;
  copy existing `data/` into it without overwriting newer user files. To
  keep the exact same folder, replace the EXEs/resources and integration scripts
  without replacing `data/`. Browser registration path stays valid if folder
  path is unchanged.
- After moving folder or changing drive, repair browser integration and optional
  startup registrations. Previously saved absolute download destinations may
  need adjustment; **no arbitrary path rewriting is performed**.
- Rollback: exit, back up current `data/`, restore older app binaries to a
  separate folder and use a compatible `data` backup. Database schema changes
  may make downgrades unsafe; do not blindly mix schemas.
- Upstream integrated app updater may be unsuitable for an unofficial source
  build; inspect update behavior manually before accepting an update.

## Limits

Opt-in browser integration writes intentional HKCU registry keys. Windows shell,
Defender/SmartScreen, browser extensions and Windows network stacks create their
own normal caches/logs. The portable build is unsigned unless separately signed
by its builder. The native folder cannot be moved while the app is running.

Windows 10/11 x64. No forced elevation. No installers, drivers, services, or
PortableApps metadata. Runtime behavior still needs real Windows testing.
