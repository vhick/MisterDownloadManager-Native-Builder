# NATIVE Windows acceptance checklist (MUST run on a real desktop)

Mark each item PASS/FAIL and retain redacted screenshots/logs. CI passes alone
are insufficient for a claim of actual runtime portability.

## Core NATIVE app

- [ ] Extract to `C:\Test MDM Portable\MisterDownloadManager-NativePortable`.
- [ ] Double-click `misterdownloadmanager.exe` directly, without any console.
- [ ] Close normally, reopen; language, settings, queue, torrent state persist.
- [ ] Launch from an arbitrary working directory using an absolute EXE path.
- [ ] Open from a path containing spaces and Unicode (e.g. `C:\测试 MDM\`).
- [ ] Verify `data/` newly contains app-owned persistent files including logs.
- [ ] Verify writable `data/` required: make `data/` read-only and confirm no
  **new** `%APPDATA%\misterdownloadmanager` profile was created (the patched
  app should fail to save or quit, not silently switch to a host profile).
- [ ] Test custom download destination, Downloads default, and moved drive.
- [ ] Check browser extension's ability to request a download with app already
  running, and when app is not running (native host auto-launch).
- [ ] Verify no duplicate app on repeated starts; check tray exit versus close.
- [ ] Check installed MDM coexistence, especially duplicate process and mutex.
- [ ] Check native Windows notifications and taskbar behavior.
- [ ] Monitor `%APPDATA%`, `%LOCALAPPDATA%`, LocalLow, `%PROGRAMDATA%`, `%TEMP%`,
  HKCU application integration, Startup entries, shortcuts, and Windows shell
  with ProcMon or equivalent. Distinguish incidental OS caches from app writes.
- [ ] Verify crashed app leaves saved data recoverable; don't delete recovery files.

## Browser integration console (opt in)

- [ ] Record a pre-registration HKCU snapshot (five host keys).
- [ ] If any key is held by an installed app, Register refuses without overwrite.
- [ ] With keys unoccupied, run `Mister-Browser-Integration.cmd` -> 1.
- [ ] Verify exact host JSON path and allowed extension IDs (unpacked/store/Firefox).
- [ ] Restart Chrome, Edge, Brave, Firefox. Use official extension from store.
- [ ] Verify extension connects and browser hands MDM an example test download.
- [ ] Verify downloaded file is not lost if native host is unavailable.
- [ ] Move folder with `data/`, choose Register/repair, verify only owned paths updated.
- [ ] Change a key manually in a temporary test profile; ensure unregister preserves
  changed/unowned key and warns.
- [ ] Run unregister; verify only script-owned keys removed; preserve `data/`.
- [ ] Re-register after intentional unregister; no duplicate keys or stale host path.
- [ ] Kill the console during registration and retry; journal supports recovery.
- [ ] Ensure other browser extensions, existing applications, HKLM keys untouched.

## Optional Manager

- [ ] Start/status/stop: only current native-folder instance is targeted.
- [ ] Graceful `/exit` saves queue; never terminates unrelated installed copy.
- [ ] Autostart default OFF. Enable explicitly; reboot; verify startup/tray.
- [ ] Disable autostart; verify owned value removed, no other Run values changed.
- [ ] Move whole folder; choose repair; verify stale target updated only with journal.
- [ ] Existing same-name Run entry triggers refusal.

## Upgrade, rollback, and privacy

- [ ] Back up `data/`, record checksum, stop all MDM/tray processes.
- [ ] Replace executable/resources without overwriting `data/`.
- [ ] Reopen and verify queue/downloads/browser integration persisted.
- [ ] Test previous version with a matching older data backup (schema may change).
- [ ] Verify password storage remains protected by Windows account security.
- [ ] Verify extension works on your actual browser variants (forks not guaranteed).
- [ ] Check antivirus/SmartScreen unsigned-app prompts; never disable security tools.

## Sign-off

Date, Windows edition, browser versions, upstream tag/commit, builder revision,
ZIP SHA-256, tested path and evidence location must be recorded by the operator.
