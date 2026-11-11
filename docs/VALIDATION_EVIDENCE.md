# Verification evidence and unverified boundaries

This report describes evidence for the BUILDER KIT before any user-run GitHub Actions build. It is NOT a report of a completed Windows app build.

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
| Actual NATIVE ZIP packaging and GPL source ZIP | NOT YET VERIFIED | Packaging scripts provided and logically tested; no upstream source/BIN checkout in this offline container |
| Direct GUI EXE startup | NOT YET VERIFIED | Interactive Windows test required |
| Persistent settings and moving USB folder | NOT YET VERIFIED | Interactive Windows and filesystem inspection required |
| Browser-extension communication | NOT YET VERIFIED | Test Chromium/Firefox with real Windows native messaging and installed add-on |
| HKCU registration repair, removal, coexistence | NOT YET VERIFIED | Requires Windows test account and controlled registry fixtures; do not test destructive cases on user's main account |
| Native manager start/stop/autostart | NOT YET VERIFIED | Requires Windows integration session |
| Tray, notifications, credentials, installer | NOT YET VERIFIED / not applicable | Tray/notifications need GUI test; no installer in NATIVE product |
| PortableApps, TraceGuard/ShellGuard | NOT APPLICABLE | Explicit NATIVE mode, intentionally absent |
| Shared publisher dry run / real GitHub publication | NOT YET VERIFIED | Planned CI; no published release claimed |

## Acceptance gate for calling the app “working”

Run `.github/workflows/build-native.yml`, inspect every step, obtain and independently inspect both release ZIPs, then run `docs/NATIVE_WINDOWS_ACCEPTANCE.md` on an actual Windows 10/11 x64 machine. Observe first/second start, data location, browser messaging, coexistence, relocation, crashes and safe upgrade/rollback before upgrading the status to `MANUAL-WINDOWS-TESTED` or `USER-CONFIRMED`.

No assertion of a complete Windows runtime pass, absence of all host traces, automatic updater compatibility, native host extension communication or actual GitHub release publication is made by this kit.
