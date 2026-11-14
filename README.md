# Focusly 🛡️

**Focusly** is a premium, robust Flutter-based Android application designed to help you regain focus by temporarily locking your device. Unlike standard timers, Focusly implements a multi-layered **"Iron Curtain"** security model to create a bypass-resistant environment: while locked, only phone calls get through.

---

## 🚀 Key Features

- **Timed Lock System:** Precise focus sessions from 1 to 120 minutes.
- **Calls Only:** Incoming and outgoing phone calls always work during a lock; everything else is blocked.
- **Tamper-Proof Timer:** The session deadline uses a monotonic clock, so changing the system time can't end a lock early.
- **Iron Curtain Overlay:** A native full-screen curtain that blocks interactions with other apps and system panels during a lock session.
- **Enforced Mode:** Leverages Accessibility Services to monitor app switching and prevent bypass attempts in real-time.
- **Self-Healing Watchdog:** A background heartbeat service that automatically relaunches the lock if the system or a user tries to kill the process.
- **OEM Stability Support:** Dedicated settings for Xiaomi, Oppo, Vivo, and Huawei to ensure background persistence.
- **Do Not Disturb:** Automatically silences notifications during a lock. Phone calls are always allowed through.
- **Battery Optimization Exemption:** Advanced persistence logic to prevent Android's battery saver from stopping your focus session.

---

## 🔒 Security & Persistence

The application offers a multi-layered defense strategy:

### 1. The Accessibility Guard 🛡️

Monitors system-level navigation events. If you try to leave Focusly, it immediately "snaps" you back or dismisses the system panel (Notification tray/Recents).

### 2. The Native Overlay (Iron Curtain)

A high-priority window that draws over other applications, ensuring that even if a system gesture succeeds, you are met with a focus barrier.

### 3. Background Watchdog

The app monitors its own lifecycle. If the Android system terminates the focus process, the watchdog identifies the interruption and relaunches the lock within seconds.

---

## 🛠️ Getting Started

### Prerequisites

- Android device (API 24+ / Android 7.0+)
- Flutter SDK (for building and development)

### Setup Instructions

1.  **Grant Do Not Disturb Access:** Required for basic lock functionality (silences notifications, keeps calls).
2.  **Grant Overlay Permission:** Allows Focusly to display the "Iron Curtain" over other apps.
3.  **Enable Accessibility Service:** Power the real-time bypass prevention and gesture blocking.
4.  **Disable Battery Optimization:** Critical for ensuring the app stays active during long sessions.
5.  **OEM / Manufacturer Settings:** For certain devices (Xiaomi, etc.), enable "Auto-start" in the app's persistence settings.

---

## 🏗️ Technical Stack

- **Framework:** Flutter (Dart)
- **Native Core:** Kotlin (Android)
- **High-Impact APIs:**
  - `AccessibilityService` (Gesture & App Monitoring)
  - `WindowManager` (Native Full-Screen Overlay)
  - `ForegroundService` (Special Use / Persistence)
  - `PowerManager` (Battery Optimization Management)

---

## 🛡️ Privacy & Compliance

Focusly is built with a "Privacy First" philosophy.

- **Zero Data Collection:** We do not collect, store, or transmit any user data. All processing happens locally on your device.
- **Transparent Permissions:** Permissions are used exclusively for focus enforcement.
- **Legal:** View our full [Privacy Policy](https://support-elaz.netlify.app/pages/privacy_policy/focusly.html).

---

## ⚠️ Safety Information

- **Emergency Escape:** A long-press safety hatch is available on the lock screen for genuine emergencies. It can be disabled in Settings for a stricter lock.
- **Safe Mode:** Like all Android-based lockers, the app cannot block a hardware-level "Safe Mode" boot.

---
