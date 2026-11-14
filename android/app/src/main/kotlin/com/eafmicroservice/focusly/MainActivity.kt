package com.eafmicroservice.focusly

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowInsetsController
import android.view.WindowInsets
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.Executors
import android.content.Context
import android.net.Uri
import android.os.PowerManager
import android.os.SystemClock
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.focusly/lock"
    private val executorService = Executors.newCachedThreadPool()

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLock" -> {
                    val usePinning = call.argument<Boolean>("usePinning") ?: false
                    try {
                        if (usePinning) {
                            startLockTask()
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not start lock task: ${e.message}", null)
                    }
                }
                "stopLock" -> {
                    try {
                        stopLockTask()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not stop lock task: ${e.message}", null)
                    }
                }
                "getElapsedRealtime" -> {
                    result.success(SystemClock.elapsedRealtime())
                }
                "checkDND" -> {
                    val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    result.success(notificationManager.isNotificationPolicyAccessGranted)
                }
                "requestDND" -> {
                     val intent = android.content.Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                     startActivity(intent)
                     result.success(null)
                }
                "setDND" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        if (enable) {
                            notificationManager.setInterruptionFilter(android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                        } else {
                            notificationManager.setInterruptionFilter(android.app.NotificationManager.INTERRUPTION_FILTER_ALL)
                        }
                        result.success(null)
                    } else {
                        result.error("PERMISSION_DENIED", "DND Permission not granted", null)
                    }
                }

                "checkAccessibility" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "requestAccessibility" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "getAllSecurityStatus" -> {
                    val startTime = System.currentTimeMillis()
                    android.util.Log.d("MainActivity", "getAllSecurityStatus: started")
                    executorService.execute {
                        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        val hasDND = notificationManager.isNotificationPolicyAccessGranted
                        val hasAccessibility = isAccessibilityServiceEnabled()
                        val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true
                        }
                        
                        val hasBattery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            (getSystemService(Context.POWER_SERVICE) as android.os.PowerManager).isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true
                        }

                        val statusMap = mapOf(
                            "hasDND" to hasDND,
                            "hasAccessibility" to hasAccessibility,
                            "hasOverlay" to hasOverlay,
                            "hasBatteryOptimization" to hasBattery
                        )
                        
                        val duration = System.currentTimeMillis() - startTime
                        android.util.Log.d("MainActivity", "getAllSecurityStatus: finished in ${duration}ms, posting result")
                        
                        runOnUiThread {
                            result.success(statusMap)
                        }
                    }
                }
                "checkOverlay" -> {
                    result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    })
                }
                "requestOverlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "checkBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            // Fallback to settings if direct request fails
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                "openAutoStartSettings" -> {
                    val opened = openAutoStartSettings()
                    result.success(opened)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        executorService.shutdown()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }
    
    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Modern API for Android 11+
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.systemBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            // Legacy API for older Android versions
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "${packageName}/${LockMonitorService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains(service) == true
    }

    private fun openAutoStartSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intent = Intent()
        
        try {
            when {
                manufacturer.contains("xiaomi") -> {
                    intent.component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                }
                manufacturer.contains("oppo") -> {
                    intent.component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                }
                manufacturer.contains("vivo") -> {
                    intent.component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                }
                manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                    intent.component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                }
                else -> {
                    intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    intent.data = Uri.fromParts("package", packageName, null)
                }
            }

            if (packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null) {
                startActivity(intent)
                return true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // Final fallback to App Info
        return try {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(fallback)
            true
        } catch (e: Exception) {
            false
        }
    }
}
