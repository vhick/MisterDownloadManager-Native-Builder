MISTER DOWNLOAD MANAGER - OPTIONAL CONSOLES (b1r2)
==================================================

Fixes original b1r1 startup error:
  Exception calling GetFullPath: The path is not of a legal form.

THIS IS AN OPTIONAL BROWSER INTEGRATION / MANAGER SCRIPT PATCH.
No MDM application rebuild is needed. No EXEs are included.

INSTALL
1. Exit MDM and close your browsers.
2. Open your EXISTING PORTABLE folder, e.g.:
      D:\AutorunApps\MisterDownloadManager\
3. Back up the four old console files, if present.
4. Copy these four updated files DIRECTLY into that folder, replacing only
   the matching script/CMD files:
      BrowserIntegration.ps1
      Mister-Browser-Integration.cmd
      Manager.ps1
      Mister-Manager.cmd
5. Do not move or delete the data folder. Do not replace MDM EXEs.
6. Double-click Mister-Browser-Integration.cmd.
7. Choose 2 (Status) to inspect existing native messaging registrations.
8. If there is no conflicting installed application, choose 1 (Register).
9. Close and restart your browsers, open the official MDM extension and test
   a normal downloadable file link. This has NOT been runtime verified here.
10. Mister-Manager.cmd is optional; try 3 (Status) first.

REQUIREMENTS
- Browser integration expects both misterdownloadmanager.exe and
  misterdownloadmanager-nmhost.exe, plus the writable data\ folder, directly
  beside the console scripts.
- Windows 10/11; Windows PowerShell 5.1.
- Integration is OPT-IN: creates per-user registry entries for browser hosts.
- Refuses to overwrite registered native messaging hosts owned by an installed
  MDM copy or another app. If it reports a conflict, do NOT delete keys
  blindly. It will not try to override an installed program's registrations.
- If you move the portable folder, run option 1 again to repair ONLY owned
  registrations. To remove the integration, choose 3 and type REMOVE.

REGRESSION NOTE
The old scripts evaluated $PSScriptRoot as a parameter default; it could be
empty before GetFullPath was called, preventing both menus from opening.
The new CMD launchers supply -AppRoot explicitly and the scripts independently
resolve their own path after parameter binding as a fallback.

TEST STATUS
- Static/regression checks pass in the builder environment.
- Live Windows PowerShell/menu/browser tests: NOT YET VERIFIED.
