# Mister Download Manager — Windows NATIVE portable builder (b1r2)

**Independent, unofficial application-specific GitHub Actions builder. Not an upstream fork.**

- Application: https://github.com/anefzaoui/misterdownloadmanager
- Resolved architecture: **NATIVE only** (direct source-built `misterdownloadmanager.exe`).
- Source identity: latest publicly published stable semver tag at build time, or an explicitly supplied stable version. `v0.5.2` was audited when this kit was created; newer releases must pass exact source-adapter checks.
- Windows: GitHub-hosted `windows-latest`, Windows x64 Rust/MSVC, Rust >= 1.95, `cargo --locked`.
- Releases: pinned shared publisher `vhick/portable-release-publisher@cb64f86ac2d8c67506db5832de07f9ff58cbeaeb` (v1.1.1), checked live against its official tag and `action.yml`. The PortableApps Package Builder is NOT used in NATIVE mode.

## Two ways to use this kit

### A. Fix browser integration on an existing OFFICIAL MDM portable ZIP, with NO rebuild

Copy only the following scripts from `portable_integration/` beside your **existing** official `misterdownloadmanager.exe` and `misterdownloadmanager-nmhost.exe`:

1. `BrowserIntegration.ps1`
2. `Mister-Browser-Integration.cmd`

The portable folder must already have a writable `data/` directory. Double-click `Mister-Browser-Integration.cmd`, choose **1** to register. Restart Chrome, Brave, Edge, Chromium, or Firefox; install/enable the MDM browser extension; perform a test download. Option **2** checks status; **3** safely unregisters only entries this console recorded. After moving the folder, choose **1** again to repair previously owned paths. No administrative rights are normally required. Details in `docs/PORTABLE_USAGE.md`.

**Caution:** Unlike the default upstream portable release, enabling integration intentionally creates browser native-messaging entries in `HKCU`. If another installation owns the HKCU keys or a matching HKLM host is present, the console refuses to take over browser integration. It does not alter HKLM, installed application binaries, system services or other extensions. Native-messaging support inferred from inspected source is **not yet tested on an interactive Windows installation**.

### B. Build a NATIVE source-built portable release with GitHub Actions

Use `docs/GITHUB_DESKTOP_SETUP.md`. In short: create a fresh independent GitHub repository, clone with GitHub Desktop, extract the kit **at repository root including `.github`**, commit, push, then run Actions > **Build MDM NATIVE Portable (Rust source)** > Run workflow.

The source builder:

1. Resolves GitHub's newest stable published release (numeric semver) and actual tag commit, never `main` or prerelease.
2. Detects a previously managed published revision and skips duplicates. An unrelated same-tag release causes a hard error, not a takeover.
3. Verifies pinned shared publisher tag/commit/action interface and pins the action at immutable commit.
4. Clones the *exact upstream stable tag*, verifies SHA, requires `Cargo.lock` and fetches crates with `--locked`.
5. Applies a minimal fail-closed source adaptation in `crates/ipc/src/lib.rs`: an existing `data` folder remains selected even if it later becomes unwritable; the application must fail to save rather than switching silently to `%APPDATA%`.
6. Builds the **real** Rust app, browser messaging host, CLI and MCP executable (`cargo build --release --locked`). Nothing is renamed to impersonate an executable.
7. Builds the browser extension resources using upstream's `tools/extension/pack.ps1`.
8. Stages the direct EXEs and supporting files beside `data/`, optional manager and native-messaging console, license, attribution, and build provenance.
9. Produces two separate archives: executable NATIVE ZIP and **modified corresponding-source ZIP** for GPL source distribution.
10. Verifies real x64 PE headers, checksums, data layout and ZIP contents; calls the publisher in dry-run mode before optional publishing. The publisher also creates `SHA256SUMS.txt` on GitHub Releases.

The produced native application is launchable **directly** by double-clicking `misterdownloadmanager.exe`; no launcher, pre-launch script, PortableApps format, installer, registry harvesting, global environment changes or resident manager are needed. Optional scripts are only for lifecycle and explicitly authorized OS integration.

## Repository contents

```text
.github/workflows/build-native.yml        Headless Windows stable-source build/release
scripts/resolve_release.py                Published stable semver + exact tag SHA
scripts/check_release.py                  Managed duplicate-release protection
scripts/verify_publisher.py               Immutable shared-action verification
scripts/apply_adapter.py                  Source-level portable data safety patch
scripts/package_native.py                 Windows binaries, native ZIP + GPL source ZIP
scripts/validate_native.py                Independent structural native ZIP validation
portable_integration/BrowserIntegration.ps1   Optional browser native-host registration
portable_integration/Mister-Browser-Integration.cmd  Double-click console
portable_integration/Manager.ps1          Optional start/stop/status/autostart
portable_integration/Mister-Manager.cmd    Double-click optional native manager
LICENSES/BUILD-KIT-LICENSE.txt            License scope, upstream attribution
scripts/ and tests/test_builder.py         Stdlib-only local regression suite
docs/SOURCE_AUDIT.md                      Source and host-state evidence
docs/NATIVE_WINDOWS_ACCEPTANCE.md         Interactive Windows acceptance checklist
docs/PORTABLE_USAGE.md                    No-build browser setup, data and upgrade
docs/GITHUB_DESKTOP_SETUP.md              Beginner's GitHub Desktop guide
docs/TROUBLESHOOTING.md                  Common build/runtime failures
docs/VALIDATION_EVIDENCE.md              Precisely what has and has not been verified
```

## Expected release output

The publisher creates a release in **your independent builder repository**, normally containing:

```text
MisterDownloadManager-<version>-NativePortable-b1r2.zip
MisterDownloadManager-<version>-NativePortable-SOURCE-b1r2.zip
SHA256SUMS.txt
```

**Important:** The downloadable file provided here is a **builder kit ZIP containing scripts, workflows, tests and documentation**, not a prebuilt Windows application. Application and modified-source ZIPs will only exist *after* the workflow runs successfully in your GitHub repository. This environment did not run Windows compilation, GUI tests or any registry modifications.

## Licensing and risk limits

MDM is GPL-3.0-or-later; its third-party notices and actual corresponding source must accompany redistribution. This kit uses separately identified MIT-licensed scripts. The builder retains full modified application source in a separate GitHub release asset and source-identity details in the executable ZIP. The author of this kit has not signed or certified binaries. Browser extensions must be installed by their respective browser's usual methods; the locally built Firefox XPI is not guaranteed to be signed for permanent installation.

No user data is included in the builder or generated distribution; your existing `data/` is always kept when upgrading. Source-inspected behavior is not proof of Windows-portable runtime operation. See `docs/VALIDATION_EVIDENCE.md` before use.

## b1r2 fix from b1r1

Both PowerShell console scripts now resolve their script directory only after
argument binding, and both CMD launchers supply the root folder explicitly.
This fixes `GetFullPath`: `The path is not of a legal form` on Windows
PowerShell 5.1 when the default `$PSScriptRoot` is empty. Existing users need
only replace the four files in `portable_integration` beside their portable
MDM EXEs; never replace `data/`. Browser native messaging must still be tested
on an interactive Windows machine. The manager remains optional.
