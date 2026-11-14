package com.eafmicroservice.focusly

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Accessibility Service that monitors app switching
 * Returns user to lock screen if they try to leave while locked
 */
class LockMonitorService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {
    
    companion object {
        private const val TAG = "LockMonitorService"
        private const val LOCK_SCREEN_CLASS = "com.eafmicroservice.focusly.MainActivity"
        
        // Apps that should be blocked during lock
        private val BLOCKED_PACKAGES = setOf(
            "com.android.settings",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            "com.android.systemui"
        )
        
        // Specific settings to block (e.g., Force Stop, Disable Accessibility)
        private const val FOCUSLY_PACKAGE = "com.eafmicroservice.focusly"
        private const val SETTINGS_PACKAGE = "com.android.settings"

        // Phone/Telecom packages allowed during lock so the user can receive calls.
        // Everything else is snapped back to the lock screen.
        private val ALLOWED_CALL_PACKAGES = setOf(
            "com.android.dialer",
            "com.google.android.dialer",
            "com.android.server.telecom",
            "com.android.phone",
            "com.samsung.android.dialer"
        )

        private const val KEY_END_TIME = "flutter.lock_end_time"
        private const val KEY_END_ELAPSED = "flutter.lock_end_elapsed"
    }

    private var isLocked = false
    private var currentPackage: String? = null
    private lateinit var prefs: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())
    
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (isLocked) {
                checkAndRelaunchIfNeeded()
                handler.postDelayed(this, 3000) // Check every 3 seconds
            }
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Lock Monitor Service connected")
        
        prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(this)
        updateLockStatus()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::prefs.isInitialized) {
            prefs.unregisterOnSharedPreferenceChangeListener(this)
        }
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        if (key == KEY_END_TIME || key == KEY_END_ELAPSED) {
            updateLockStatus()
        }
    }

    private fun updateLockStatus() {
        val endTime = prefs.getLong(KEY_END_TIME, 0)
        val endElapsed = prefs.getLong(KEY_END_ELAPSED, 0)
        val wasLocked = isLocked
        // Locked if EITHER clock says locked: wall-clock can be cheated by the
        // user, monotonic (elapsedRealtime) cannot. Unlock only when both expire.
        // Missing elapsed key (older installs) falls back to wall-clock.
        val wallLocked = endTime > System.currentTimeMillis()
        val elapsedLocked = endElapsed > 0 && endElapsed > SystemClock.elapsedRealtime()
        isLocked = wallLocked || elapsedLocked
        
        Log.d(TAG, "Lock status updated: $isLocked")
        
        if (isLocked) {
            handler.removeCallbacks(watchdogRunnable)
            handler.post(watchdogRunnable)
        } else {
            handler.removeCallbacks(watchdogRunnable)
        }
        
        // If lock just ended, stop overlay
        if (wasLocked && !isLocked) {
            stopOverlay()
        }
    }
    
    private fun startOverlay() {
        try {
            val intent = Intent(this, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start overlay service", e)
        }
    }
    
    private fun stopOverlay() {
        try {
            stopService(Intent(this, OverlayService::class.java))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop overlay service", e)
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        // Monitor window state and content changes (for shade)
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && 
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return

        if (!::prefs.isInitialized) {
            return
        }
        
        // Check if lock is active (using cached value)
        if (!isLocked) return

        val packageName = event.packageName?.toString() ?: return
        val className = event.className?.toString() ?: return

        currentPackage = packageName

        // Double check both clocks if cached value says locked, to be sure we
        // don't block unnecessarily if time just expired. Unlock needs BOTH expired.
        val wallExpired = System.currentTimeMillis() > prefs.getLong(KEY_END_TIME, 0)
        val endElapsed = prefs.getLong(KEY_END_ELAPSED, 0)
        val elapsedExpired = endElapsed <= 0 || SystemClock.elapsedRealtime() > endElapsed
        if (wallExpired && elapsedExpired) {
            isLocked = false
            return
        }

        Log.d(TAG, "App switched to: $packageName / $className")

        // 0. Incoming/outgoing calls are always allowed: no curtain, no snap-back.
        if (packageName in ALLOWED_CALL_PACKAGES) {
            Log.i(TAG, "Call UI active ($packageName) - allowing during lock")
            stopOverlay()
            return
        }
        
        // 1. Manage Overlay Curtain
        if (packageName == FOCUSLY_PACKAGE) {
            stopOverlay()
        } else if (isLocked) {
            startOverlay()
        }
        
        // 2. Auto-confirm pinning dialog if it appears
        if (packageName == "com.android.systemui" || 
            packageName == "com.google.android.packageinstaller" ||
            packageName == "com.android.packageinstaller" ||
            packageName == "android") {
            
            val confirmed = autoConfirmPinningDialog(event)
            if (!confirmed && isLocked && (packageName == "com.android.systemui" || packageName == "android")) {
                // If we couldn't find the button, it might be the notification shade or Recent Apps
                Log.w(TAG, "System UI active (shade/gestures) - dismissing/collapsing")
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // API 31+ (Android 12+) specific action to close notification shade
                    performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
                } else {
                    // Legacy fallback
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
                
                // Also try to bring app to front to counteract Home/Recent gestures
                bringLockScreenToFront()
            }
        }
        
        // 3. Block access to sensitive settings while locked
        if (isLocked && packageName == SETTINGS_PACKAGE) {
            // Check if user is looking at Focusly's App Info or Accessibility Switch
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                // Look for "Focusly" in the current window to see if they are trying to force stop or uninstall
                val nodes = rootNode.findAccessibilityNodeInfosByText("Focusly")
                if (nodes.isNotEmpty() || className.contains("AppDetails") || className.contains("Accessibility")) {
                    Log.w(TAG, "User attempting to access sensitive settings - blocking")
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    bringLockScreenToFront()
                    return
                }
            }
        }
        
        // 4. If user is in lock screen, allow it
        if (className == LOCK_SCREEN_CLASS) {
            return
        }
        
        // 5. If user tries to leave lock screen app entirely, bring it back
        if (packageName != FOCUSLY_PACKAGE) {
            Log.w(TAG, "User left lock app: $packageName - returning to lock")
            bringLockScreenToFront()
        }
    }

    private fun autoConfirmPinningDialog(event: AccessibilityEvent): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        // Search for common confirm buttons
        val keywords = listOf("Got it", "OK", "Allow", "Start now", "Authorize", "Start", "Accept")
        val allNodes = mutableListOf<AccessibilityNodeInfo>()
        
        for (text in keywords) {
            allNodes.addAll(rootNode.findAccessibilityNodeInfosByText(text))
        }
        
        for (node in allNodes) {
            if (node.isClickable) {
                Log.i(TAG, "Auto-confirming pinning dialog with button: ${node.text}")
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
        }
        return false
    }
    
    override fun onInterrupt() {
        Log.w(TAG, "Lock Monitor Service interrupted")
    }
    
    private fun bringLockScreenToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error bringing lock screen to front", e)
        }
    }

    private fun checkAndRelaunchIfNeeded() {
        // Don't yank the user out of an active call: the watchdog has no
        // foreground visibility except the last package seen in events.
        if (currentPackage in ALLOWED_CALL_PACKAGES) {
            Log.v(TAG, "Watchdog: call active ($currentPackage) - skipping relaunch")
            return
        }
        // Since we can't easily check 'top activity' from here without more permissions,
        // we rely on the fact that if isLocked is true, we WANT Focusly visible.
        // The service's onAccessibilityEvent usually handles transitions, 
        // but this heartbeat ensures that if the process was killed and restarted, 
        // the UI comes back even without a transition event.
        Log.v(TAG, "Watchdog: ensuring lock is active")
        // We only relaunch if we haven't seen an event for Focusly in a while
        // For simplicity in this version, we'll just trigger the bringToFront
        // which will do nothing if it's already on top (SINGLE_TOP/REORDER_TO_FRONT)
        bringLockScreenToFront()
    }

}
