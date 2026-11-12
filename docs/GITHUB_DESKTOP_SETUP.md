# GitHub Desktop setup — no command line or local compiler required

1. Create a **new** GitHub repository named for example
   `MisterDownloadManager-Native-Builder` (NOT a fork of upstream).
2. Choose **Public** if you want public-repository GitHub-hosted Actions usage and
   public release downloads. Choose Private if the artifacts and code must be
   private; check your plan's Windows runner minutes (Windows hosted usage can
   consume more billable minutes on private repositories).
3. In GitHub Desktop: File → Clone repository → choose your new repository.
4. Extract the **entire builder kit ZIP** into the cloned repository folder.
   Include hidden `.github/workflows/build-native.yml` (Windows Explorer may
   hide folders starting with a dot). Do not create a second enclosing folder.
5. In GitHub Desktop, review changed files, type a commit message such as
   `Add MDM native source builder`, choose Commit to main, then Push origin.
6. On GitHub website, open the builder repository → Actions →
   **Build MDM NATIVE Portable (Rust source)** → Run workflow.
7. Set Version = `latest`, Revision = `b1r5`, Publish = checked. For an older
   stable release enter a specific version like `0.5.2`.
8. Open the workflow run → `native` job and inspect the named stages.
   A green check means static checks and compilation ran; it does NOT mean GUI,
   browser or registry integration has been interactively tested.
9. Open the builder repository → Releases. Download
   `MisterDownloadManager-<version>-NativePortable-b1r5.zip` and
   `SHA256SUMS.txt`. SHA-256 should match the release checksum (Windows:
   `Get-FileHash "file.zip" -Algorithm SHA256` in PowerShell).
10. Extract to a writable folder and run `misterdownloadmanager.exe` directly.
    Test portable settings before opting into the browser registration console.
11. To build another app revision, change Revision (e.g. `b1r5`) so release
    identity is not overwritten. Published source SHA/tag are stored inside
    the ZIP's `BUILD-IDENTITY.json`.
12. To upgrade, stop MDM, back up existing `data/`, replace only the program
    binaries/resources/scripts. Keep existing `data/` and recovery records.
13. To rollback, use previously downloaded binaries **with the data backup
    from that matching version**. An older binary may not read a newer schema.

If a release already exists for the *same upstream stable tag, commit and
revision*, the workflow intentionally skips redundant compilation/upload.
If any action has failed, open the red step's logs and check upstream changes,
Rust version, dependency-lock drift, or source-adapter guard failure.

No PAT, local Rust installation, local `git init`, elevation or Windows installer
is required to run the builder on GitHub. Manual Windows acceptance testing is
still required before calling the produced app a verified portable release.

## b1r5 single-manager notes

After extracting the validated NATIVE ZIP, double-click `Mister-Manager.cmd`. It uses only `Manager.ps1`; do not copy or launch the old Browser Integration or Legacy Cleanup consoles. To check old installations choose main **4**, browser **1** (read-only); browser **4** and **5** offer opt-in verified cleanup with backup. Browser **2** registers the portable host. To enable startup choose main **5**. The application EXE itself runs without this manager.
