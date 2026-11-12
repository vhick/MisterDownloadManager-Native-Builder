# Verification evidence and unverified boundaries

This report describes evidence for the b1r4 BUILDER KIT. A prior b1r2 release from this user's builder repository completed on a GitHub Windows runner (November 11, 2026, 19m03s, successful), with a published 18.5 MB executable ZIP and 934 MB SOURCE ZIP. That success is not evidence that the NEW b1r4 source-patch packaging has run or that browser integrations have passed GUI acceptance.

| Stage | Status at kit creation | Evidence and limit |
|---|---|---|
| Published upstream version/framework/license | SOURCE-INSPECTED | Official v0.5.2 tag files, Cargo workspace Rust 1.95, GPL-3.0-or-later |
| Native messaging registration refusal | SOURCE-INSPECTED | `crates/nmhost/src/main.rs:portable_refused()`, called by registration, not normal host `serve()` |
| Windows browser keys and extension IDs | SOURCE-INSPECTED | Host REGISTRY_KEYS, Firefox key, `crates/ipc/src/extension.rs` |
| Storage source and fail-closed adaptation | SOURCE-INSPECTED / STATIC-VALIDATED | `portable_dir()` and exact-block adapter unit test; adapter not run on cloned upstream checkout during kit authoring |
| Stable release selection and SHA verification logic | STATIC-VALIDATED | Numeric semver tests; actual GitHub API and clone in CI not run locally |
| Builder tests | STATIC-VALIDATED | Local Python stdlib unit tests: see README/test output; tests don't touch registry |
| Workflow YAML syntax | STATIC-VALIDATED | Local YAML parse; GitHub Actions runner job has not been executed |
| Publisher v1.1.1 tag/action interface | SOURCE-INSPECTED | Immutable SHA and actual `action.yml` inspected; workflow includes a runtime SHA check |
| PowerShell console source safety | STATIC-VALIDATED | Script reviewed / guarded against unowned keys; not executed with Windows PowerShell in this environment |
| Actual MSVC x64 Rust source compilation | NOT YET VERIFIED | Must run GitHub Windows hosted job |
| Actual source-built Windows EXEs and SHA-256 | NOT YET VERIFIED | No executable is prebundled with kit; generated and hashed only in CI |
| Actual NATIVE ZIP packaging and GPL source patch ZIP | NOT YET VERIFIED | Synthetic clean Git fixture compiles no binary but fully tests ZIP construction, a modified tracked Rust file, an untracked 5 MiB fixture exclusion, source-patch reconstruction pointers and application ZIP independent validation. Actual MDM build must run on Windows |
| Direct GUI EXE startup | NOT YET VERIFIED | Interactive Windows test required |
| Persistent settings and moving USB folder | NOT YET VERIFIED | Interactive Windows and filesystem inspection required |
| Browser-extension communication | NOT YET VERIFIED | Test Chromium/Firefox with real Windows native messaging and installed add-on |
| HKCU registration repair, removal, coexistence | NOT YET VERIFIED | Requires Windows test account and controlled registry fixtures; do not test destructive cases on user's main account |
| Native manager start/stop/autostart | NOT YET VERIFIED | Requires Windows integration session |
| Tray, notifications, credentials, installer | NOT YET VERIFIED / not applicable | Tray/notifications need GUI test; no installer in NATIVE product |
| PortableApps, TraceGuard/ShellGuard | NOT APPLICABLE | Explicit NATIVE mode, intentionally absent |
| Shared publisher dry run / real GitHub publication | NOT YET VERIFIED | Planned CI; no published release claimed |

## Acceptance gate for calling the app “working”

Run `.github/workflows/build-native.yml`, inspect every step, obtain and independently inspect both release ZIPs (application and source patch), then run `docs/NATIVE_WINDOWS_ACCEPTANCE.md` on an actual Windows 10/11 x64 machine. Observe first/second start, data location, browser messaging, coexistence, relocation, crashes and safe upgrade/rollback before upgrading the status to `MANUAL-WINDOWS-TESTED` or `USER-CONFIRMED`.

The previous b1r2 GitHub release did publish; the b1r4 release has NOT been published or Windows-compiled here. No assertion of a complete Windows runtime pass, absence of all host traces, automatic updater compatibility, or native host extension communication is made by this kit.

## b1r4 consolidated manager evidence

- SOURCE/STATIC: Legacy cleanup functions merged from user-confirmed working `MDM-Legacy-Browser-Cleanup.ps1` b1r2, without changing the deletion allowlist or confirmation phrases. New backups are redirected under `data/Integration/` for native local-data containment. Browser/manager functionality integrated in `Manager.ps1`; only one `.cmd` launcher is shipped.
- STATIC-VALIDATED: Additional Python regression tests verify one console, ownership journals, verified backup, no CMD trailing-root arguments, and correct NATIVE packaging. Full ZIP CRC/SHA-256 is validated after creation.
- PROPOSED CI: Windows PowerShell 5.1 parser, `SelfTest`, and read-only legacy scan are steps in the updated workflow; they have not yet run as part of a GitHub Actions job in this session.
- USER-CONFIRMED (older separate tool only): the standalone legacy cleanup b1r2 was reported working by the user. **NOT YET VERIFIED:** combined b1r4 menu on real Windows, live registration/cleanup, GUI, browser extension communication, autostart, GitHub compilation or release publication.

## b1r4 source archive correction

The actual b1r2 GitHub release verified application ZIP 18.5 MB and source ZIP 934 MB. The b1r4 packager removes the unbounded upstream-checkout ZIP creation. It emits a compact SOURCE-PATCH ZIP: original exact SHA/source URL, `PORTABILITY.patch`, copy of patched Rust file, Cargo.lock, and complete builder materials. The application ZIP includes `SOURCE-ACCESS.txt`. The source link is external, and GPL-3.0 source-access obligations remain on the redistributor. A synthetic test confirms an untracked 5 MiB generated file is not republished.
