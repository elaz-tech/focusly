# Project Understanding: Focusly

## Purpose
Focusly is an Android-only Flutter app that enforces timed phone-lock focus sessions (1–120 min) using a multi-layer "Iron Curtain" model: Do Not Disturb + optional Android Screen Pinning + Accessibility-based app-switch monitoring + full-screen native overlay curtain + reboot recovery.

## Architecture
- Pattern: Flutter UI + thin native enforcement core. Single source of truth is `lock_end_time` (epoch ms) in `SharedPreferences`.
- Layers:
  - `lib/main.dart` → `services/startup_check.dart` → `screens/home_screen.dart` | `screens/lock_screen.dart`
  - `services/lock_service.dart`: sole bridge over `MethodChannel('com.focusly/lock')` + prefs keys (`lock_end_time`, `use_system_pinning`, `emergency_escape`, `require_enforced_mode`).
  - `screens/settings_screen.dart`: permission/persistence/safety toggles driven by `getAllSecurityStatus`.
  - Native (`android/app/src/main/kotlin/com/eafmicroservice/focusly/`):
    - `MainActivity.kt`: all MethodChannel handlers (DND, pinning, overlay/battery/accessibility checks, OEM auto-start intents).
    - `LockMonitorService.kt`: `AccessibilityService` watching `flutter.lock_end_time`, 3s watchdog (`bringLockScreenToFront`), overlay start/stop, SystemUI shade dismiss, Settings-app blocking, pinning-dialog auto-confirm.
    - `OverlayService.kt`: `START_STICKY` foreground service (`specialUse`) drawing `TYPE_APPLICATION_OVERLAY` dark curtain.
    - `BootReceiver.kt`: on `BOOT_COMPLETED`, if lock still active, launches `MainActivity` (relies on `StartupCheck.reAssertLock` for full restore).
- Key manifest facts (`android/app/src/main/AndroidManifest.xml`): `singleInstance` + empty `taskAffinity` `MainActivity`, `showWhenLocked`/`turnScreenOn`, permissions `ACCESS_NOTIFICATION_POLICY`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE`, `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`; accessibility service bound with `BIND_ACCESSIBILITY_SERVICE`.

## Cross-Layer Contracts (verified in code)
- Prefs keys: Dart `lock_end_time` == native `flutter.lock_end_time`, Dart `lock_end_elapsed` == native `flutter.lock_end_elapsed` (monotonic `elapsedRealtime` deadline written once in `startLock`, cleared in `stopLock`, never touched by `reAssertLock`).
- Lock rule everywhere (Dart, `LockMonitorService`, `BootReceiver`): locked = wall-clock active OR monotonic active; unlock only when both expire. Displayed remaining = max of the two.
- Channel `com.focusly/lock` methods: `startLock{usePinning}`, `stopLock`, `getElapsedRealtime`, `setDND{enable}`, `checkDND`, `requestDND`, `checkAccessibility`, `requestAccessibility`, `checkOverlay`, `requestOverlay`, `checkBatteryOptimization`, `requestBatteryOptimization`, `openAutoStartSettings`, `getAllSecurityStatus{hasDND,hasAccessibility,hasOverlay,hasBatteryOptimization}`.
- Call exemption: `ALLOWED_CALL_PACKAGES` (AOSP/Google/Samsung dialer, `server.telecom`, `phone`) bypass overlay, snap-back, and watchdog relaunch so incoming/outgoing calls work during lock.
- Security levels: `enforced` = DND + accessibility + overlay; `standard` = DND only; `minimal` = otherwise. Battery exemption is checked/displayed but excluded from level computation.

## Conventions & Constraints
- Dart: Material3, `AppColors` teal/navy theme (`lib/utils/app_colors.dart`), `WidgetsBindingObserver` resume-refresh pattern on Home/Lock/Settings.
- Lock UX: `LockScreen` countdown with local 1s tick + 10s storage resync; `PopScope(canPop:false)`; 2s hold-to-unlock emergency hatch (default ON).
- Android `minSdk`: launcher-icons config says 21; README claims API 24+. Overlay uses `TYPE_APPLICATION_OVERLAY` on O+, `TYPE_PHONE` fallback. Shade dismiss uses `GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE` on S+, `GLOBAL_ACTION_BACK` fallback.
- iOS directory exists but has no enforcement equivalents — effectively Android-only.
- Tests: `test/widget_test.dart` is empty; no unit/integration coverage. Lints via `flutter_lints`, with `use_build_context_synchronously: ignore`.

## Dependencies (from `pubspec.yaml`)
- `shared_preferences`, `package_info_plus`, `cupertino_icons`, `flutter_launcher_icons`; dev: `flutter_test`, `flutter_lints`. No network/state-management/database packages — local-only design matches "zero data collection" claim.

## Known Risk Areas (for future tasks, not defects to fix now)
- Empty test suite; `getSecurityStatusMap` error fallback omits `hasBatteryOptimization`; watchdog relaunch every 3s is aggressive; Settings-blocking via `"Focusly"` text search is locale/OEM-fragile; pinning-dialog auto-click on generic keywords is broad; `BootReceiver` direct `startActivity` likely blocked by Android 10+ background-start limits; 14 files currently dirty in git with large line-churn (possible line-ending reformat).
