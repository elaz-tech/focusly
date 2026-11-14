import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LockService {
  static const MethodChannel _channel = MethodChannel('com.focusly/lock');
  static const String _keyEndTime = 'lock_end_time';
  static const String _keyEndElapsed = 'lock_end_elapsed';
  static const String _keyUseSystemPinning = 'use_system_pinning';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Monotonic milliseconds since boot (SystemClock.elapsedRealtime).
  /// Immune to user/system wall-clock changes.
  static Future<int> _getElapsedRealtime() async {
    final result = await _channel.invokeMethod('getElapsedRealtime');
    return (result as num).toInt();
  }

  // Start the lock for a specific duration (in minutes)
  static Future<void> startLock(int minutes, {bool usePinning = false}) async {
    final endTime = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    final prefs = await _getPrefs();
    await prefs.setInt(_keyEndTime, endTime);
    // Monotonic deadline (immune to system-clock changes). Native enforces
    // locked = wallLocked || elapsedLocked, so forwarding the clock can't
    // end the session early. Best-effort: wall-clock still works if this fails.
    try {
      final nowElapsed = await _getElapsedRealtime();
      await prefs.setInt(
        _keyEndElapsed,
        nowElapsed + minutes * 60 * 1000,
      );
    } catch (e) {
      debugPrint("Could not store monotonic deadline: $e");
    }

    try {
      // Enable DND
      await _channel.invokeMethod('setDND', {'enable': true});
      // Start Lock Task (Optional)
      await _channel.invokeMethod('startLock', {'usePinning': usePinning});
    } catch (e) {
      debugPrint("Error starting lock: $e");
    }
  }

  // Stop the lock
  static Future<void> stopLock() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyEndTime);
    await prefs.remove(_keyEndElapsed);

    try {
      // Disable DND
      await _channel.invokeMethod('setDND', {'enable': false});
      // Stop Lock Task
      await _channel.invokeMethod('stopLock');
    } catch (e) {
      debugPrint("Error stopping lock: $e");
    }
  }

  // Check if lock is currently active and return remaining seconds.
  // Uses max(wall-clock, monotonic) so forwarding the system clock can't
  // shorten the session. Unlock (with cleanup) only when BOTH expire.
  static Future<int> getRemainingSeconds() async {
    final prefs = await _getPrefs();
    final endTime = prefs.getInt(_keyEndTime);

    if (endTime == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final wallRemaining = (endTime - now) ~/ 1000;

    int elapsedRemaining = 0;
    final endElapsed = prefs.getInt(_keyEndElapsed);
    if (endElapsed != null) {
      try {
        final nowElapsed = await _getElapsedRealtime();
        elapsedRemaining = (endElapsed - nowElapsed) ~/ 1000;
      } catch (e) {
        debugPrint("Could not read monotonic clock: $e");
      }
    }

    final remaining = wallRemaining > elapsedRemaining
        ? wallRemaining
        : elapsedRemaining;

    if (remaining <= 0) {
      // Time expired, cleanup
      await stopLock();
      return 0;
    }

    // Ensure we are in lock mode if we should be
    try {
      // We might want to re-assert lock here if it was broken, but be careful of loops
      // For now, relies on the UI to call startLock again if needed, or just let the user be stuck?
      // Let's just return the time.
    } catch (e) {
      debugPrint("Error checking lock: $e");
    }

    return remaining;
  }

  static Future<bool> isLocked() async {
    return (await getRemainingSeconds()) > 0;
  }

  static Future<bool> checkDNDPermission() async {
    try {
      return await _channel.invokeMethod('checkDND');
    } catch (e) {
      debugPrint("Error checking DND: $e");
      return false;
    }
  }

  static Future<void> requestDNDPermission() async {
    try {
      await _channel.invokeMethod('requestDND');
    } catch (e) {
      debugPrint("Error requesting DND: $e");
    }
  }

  // Re-assert lock (useful on app restart)
  static Future<void> reAssertLock() async {
    try {
      await _channel.invokeMethod('setDND', {'enable': true});
      await _channel.invokeMethod('startLock');
    } catch (e) {
      debugPrint("Error re-asserting lock: $e");
    }
  }



  // ========== ACCESSIBILITY SERVICE METHODS ==========

  /// Check if Accessibility Service is enabled
  static Future<bool> checkAccessibilityService() async {
    try {
      return await _channel.invokeMethod('checkAccessibility');
    } catch (e) {
      debugPrint("Error checking Accessibility Service: $e");
      return false;
    }
  }

  /// Request Accessibility Service permission
  static Future<void> requestAccessibilityService() async {
    try {
      await _channel.invokeMethod('requestAccessibility');
    } catch (e) {
      debugPrint("Error requesting Accessibility Service: $e");
    }
  }

  // ========== OVERLAY PERMISSION METHODS ==========

  /// Check if Overlay permission is granted
  static Future<bool> checkOverlayPermission() async {
    try {
      return await _channel.invokeMethod('checkOverlay');
    } catch (e) {
      debugPrint("Error checking Overlay permission: $e");
      return false;
    }
  }

  /// Request Overlay permission
   static Future<void> requestOverlayPermission() async {
     try {
       await _channel.invokeMethod('requestOverlay');
     } catch (e) {
       debugPrint("Error requesting Overlay permission: $e");
     }
   }
 
   // ========== BATTERY & PERSISTENCE METHODS ==========
 
   /// Check if Battery Optimization is ignored
   static Future<bool> checkBatteryOptimization() async {
     try {
       return await _channel.invokeMethod('checkBatteryOptimization');
     } catch (e) {
       debugPrint("Error checking battery optimization: $e");
       return true; // Default to true to not block user if call fails
     }
   }
 
   /// Request to ignore battery optimizations
   static Future<void> requestIgnoreBatteryOptimizations() async {
     try {
       await _channel.invokeMethod('requestBatteryOptimization');
     } catch (e) {
       debugPrint("Error requesting battery optimization: $e");
     }
   }
 
   /// Open manufacturer-specific Auto-Start settings
   static Future<bool> openAutoStartSettings() async {
     try {
       return await _channel.invokeMethod('openAutoStartSettings');
     } catch (e) {
       debugPrint("Error opening auto-start settings: $e");
       return false;
     }
   }

  // ========== SECURITY STATUS ==========

  /// Get detailed security status map
  static Future<Map<String, bool>> getSecurityStatusMap() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'getAllSecurityStatus',
      );
      return {
        'hasDND': result?['hasDND'] ?? false,
        'hasAccessibility': result?['hasAccessibility'] ?? false,
        'hasOverlay': result?['hasOverlay'] ?? false,
        'hasBatteryOptimization': result?['hasBatteryOptimization'] ?? false,
      };
    } catch (e) {
      debugPrint("Error fetching security status map: $e");
      return {
        'hasDND': false,
        'hasAccessibility': false,
        'hasOverlay': false,
      };
    }
  }

  /// Get overall security status
  static Future<SecurityStatus> getSecurityStatus() async {
    final map = await getSecurityStatusMap();
    final bool hasDND = map['hasDND'] ?? false;
    final bool hasAccessibility = map['hasAccessibility'] ?? false;
    final bool hasOverlay = map['hasOverlay'] ?? false;

    if (hasAccessibility && hasDND && hasOverlay) {
      return SecurityStatus.enforced;
    } else if (hasDND) {
      return SecurityStatus.standard;
    } else {
      return SecurityStatus.minimal;
    }
  }

  /// Check if all enforced mode permissions are granted
  static Future<bool> isEnforcedModeReady() async {
    final map = await getSecurityStatusMap();
    return (map['hasAccessibility'] ?? false) &&
        (map['hasDND'] ?? false) &&
        (map['hasOverlay'] ?? false);
  }

  // ========== EMERGENCY ESCAPE PREFERENCE ==========

  static const String _keyEmergencyEscape = 'emergency_escape';
  static const String _keyRequireEnforcedMode = 'require_enforced_mode';

  /// Enable or disable emergency escape hatch
  static Future<void> setEmergencyEscape(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyEmergencyEscape, enabled);
  }

  /// Check if emergency escape is enabled (defaults to true for safety)
  static Future<bool> isEmergencyEscapeEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyEmergencyEscape) ?? true;
  }

  /// Enable or disable requirement for enforced mode
  static Future<void> setRequireEnforcedMode(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool('require_enforced_mode', enabled);
  }

  static Future<bool> isSystemPinningEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyUseSystemPinning) ?? false;
  }

  static Future<void> setSystemPinningEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyUseSystemPinning, enabled);
  }


  /// Check if enforced mode is required (defaults to false)
  static Future<bool> isRequireEnforcedModeEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyRequireEnforcedMode) ?? false;
  }
}

/// Security level for the lock
enum SecurityStatus {
  /// Minimal - No permissions granted
  minimal,

  /// Standard - Only DND permission (current mode)
  standard,

  /// Enforced - All permissions granted (bypass-proof mode)
  enforced,
}
