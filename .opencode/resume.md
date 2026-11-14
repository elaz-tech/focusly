# Task Resume

## Task

Fix 2 lock-correctness gaps (call allowlist + monotonic timer).

## Goal

Locked phone stays unusable until expiry except incoming/outgoing calls; forwarding the system clock can't end a session early.

## Status

`COMPLETED`

## Last Completed Action

Implemented both gaps, ran `flutter analyze` (no issues), reviewed diff hunks.

## Completed

- Gap 1: `ALLOWED_CALL_PACKAGES` (AOSP/Google dialer, telecom, phone, Samsung dialer) exempt from overlay, snap-back, and watchdog relaunch in `LockMonitorService.kt`; `currentPackage` tracking gates the 3s watchdog.
- Gap 2: dual-clock lock (`wall-clock OR elapsedRealtime`) across `lock_service.dart` (`lock_end_elapsed` + `getElapsedRealtime`), `MainActivity.kt` (new channel method), `LockMonitorService.kt` (status + event double-check), `BootReceiver.kt` (reboot check).
- Verification: `flutter analyze` → No issues found; diff review confirmed only intended hunks in the 4 touched files.

## Current Step

Device verification (requires physical Android device, not done here).

## Current State

- Lock = `wallLocked || elapsedLocked`; unlock/cleanup only when both expire. Old installs without elapsed key fall back to wall-clock.
- `reAssertLock` does not touch deadlines (no accidental extension) — elapsed is written only in `startLock`.
- Elapsed base resets on reboot; pre-reboot deadline stays in the future → conservative locked. Backward-compatible.

## Files Changed

- `lib/services/lock_service.dart`
- `android/app/src/main/kotlin/com/eafmicroservice/focusly/LockMonitorService.kt`
- `android/app/src/main/kotlin/com/eafmicroservice/focusly/MainActivity.kt`
- `android/app/src/main/kotlin/com/eafmicroservice/focusly/BootReceiver.kt`
- `.opencode/project-understanding.md` (contract update)

## Decisions

- `remaining = max(wall, monotonic)` for display; unlock needs both expired (forward-clock cheat blocked, backward-clock only extends display, which is safe).
- No new Android permission: call detection via foreground-package tracking instead of `TelephonyManager` (+ `READ_PHONE_STATE`).
- Watchdog skip window = "last seen package is dialer/telecom", no timeout — safe for long calls, resumes on next non-call event.

## Issues / Blockers

- Pre-existing dirty tree (14 files, large line-ending churn) untouched except the 4 files above; commit will include noise unless normalized.
- `BootReceiver` background `startActivity` still subject to Android 10+ restriction (known, out of scope for these 2 gaps).

## Verification

- `flutter analyze` → No issues found (ran 1.5s).
- `flutter test` not run (suite is empty, pre-existing).
- Device tests NOT run: (a) 1-min lock + incoming call answered/completed, curtain absent on dialer, lock resumes after; (b) forward system clock mid-lock → session persists; (c) reboot mid-lock → lock restores.

## Do Not Repeat

- Do not re-add elapsed writes to `reAssertLock` path (would extend sessions).
- Do not widen `ALLOWED_CALL_PACKAGES` without review (each entry is a lock exit).

## Next Steps

1. Fouad: on-device test (a)(b)(c) above.
2. Optional follow-ups (not started): reboot restore via full-screen intent notification; locale-independent Settings block; watchdog backoff.
