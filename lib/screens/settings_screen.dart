import 'package:flutter/material.dart';
import '../services/lock_service.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _hasDND = false;
  bool _hasAccessibility = false;
  bool _hasOverlay = false;
  bool _hasBatteryOptimization = true; // Assume true till checked
  bool _emergencyEscape = true;
  bool _requireEnforcedMode = false;
  bool _useSystemPinning = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions(silent: true);
    }
  }

  Future<void> _checkPermissions({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final resultMap = await LockService.getSecurityStatusMap();

      final bool dnd = resultMap['hasDND'] ?? false;
      final bool accessibility = resultMap['hasAccessibility'] ?? false;
      final bool overlay = resultMap['hasOverlay'] ?? false;
      final bool battery = resultMap['hasBatteryOptimization'] ?? false;
      final escape = await LockService.isEmergencyEscapeEnabled();
      final requireEnforced = await LockService.isRequireEnforcedModeEnabled();
      final systemPinning = await LockService.isSystemPinningEnabled();
 
       if (mounted) {
         setState(() {
           _hasDND = dnd;
           _hasAccessibility = accessibility;
           _hasOverlay = overlay;
           _hasBatteryOptimization = battery;
           _emergencyEscape = escape;
           _requireEnforcedMode = requireEnforced;
           _useSystemPinning = systemPinning;
           _isLoading = false;
         });
       }
    } catch (e) {
      debugPrint("Error checking permissions: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getSecurityStatus();

    return Scaffold(
      appBar: AppBar(title: const Text('Security Settings'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkPermissions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Security Status Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.iconGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getStatusTitle(status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getStatusDescription(status),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Permissions Section
                  Text(
                    'REQUIRED PERMISSIONS',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // DND Permission
                  _buildPermissionCard(
                    title: 'Do Not Disturb',
                    description: 'Required for basic lock functionality',
                    icon: Icons.do_not_disturb_on,
                    isGranted: _hasDND,
                    onRequest: () async {
                      await LockService.requestDNDPermission();
                      await Future.delayed(const Duration(seconds: 1));
                      await _checkPermissions();
                    },
                  ),


                  // Accessibility Service Permission
                  _buildPermissionCard(
                    title: 'Accessibility Service',
                    description:
                        'Monitors and prevents app switching during lock',
                    icon: Icons.accessibility,
                    isGranted: _hasAccessibility,
                    badge: 'ENFORCED',
                    onRequest: () async {
                      await LockService.requestAccessibilityService();
                      if (mounted) {
                        _showAccessibilityGuide();
                      }
                      await Future.delayed(const Duration(seconds: 1));
                      await _checkPermissions();
                    },
                  ),

                  // Overlay Permission
                   _buildPermissionCard(
                     title: 'Overlay Window',
                     description:
                         'Draws a curtain if user tries to escape while locked',
                     icon: Icons.layers,
                     isGranted: _hasOverlay,
                     badge: 'ENFORCED',
                     onRequest: () async {
                       await LockService.requestOverlayPermission();
                       await Future.delayed(const Duration(seconds: 1));
                       await _checkPermissions();
                     },
                   ),
 
                   const SizedBox(height: 24),
 
                   // Persistence Section
                   Text(
                     'PERSISTENCE & BATTERY',
                     style: TextStyle(
                       color: AppColors.primaryBlue,
                       fontSize: 13,
                       fontWeight: FontWeight.bold,
                       letterSpacing: 1.2,
                     ),
                   ),
                   const SizedBox(height: 12),
 
                   // Battery Optimization
                   _buildPermissionCard(
                     title: 'Ignore Battery Optimization',
                     description: 'Prevents the OS from killing the app during lock',
                     icon: Icons.battery_saver,
                     isGranted: _hasBatteryOptimization,
                     onRequest: () async {
                       await LockService.requestIgnoreBatteryOptimizations();
                       await Future.delayed(const Duration(seconds: 1));
                       await _checkPermissions();
                     },
                   ),
 
                   // Auto-Start
                   _buildPermissionCard(
                     title: 'Manufacturer Settings',
                     description: 'Enable Auto-start/Background run for stability',
                     icon: Icons.settings_suggest,
                     isGranted: false, // Always show button as we can't check this easily
                     onRequest: () async {
                       await LockService.openAutoStartSettings();
                     },
                   ),

                  const SizedBox(height: 24),

                  // Emergency Escape Section
                  Text(
                    'SAFETY SETTINGS',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: AppColors.primaryTeal,
                      secondary: Icon(
                        Icons.exit_to_app,
                        color: _emergencyEscape
                            ? AppColors.primaryTeal
                            : Colors.grey,
                      ),
                      title: const Text('Emergency Escape'),
                      subtitle: const Text(
                        'Allows unlocking via long-press in emergencies',
                      ),
                      value: _emergencyEscape,
                      onChanged: (val) async {
                        await LockService.setEmergencyEscape(val);
                        setState(() {
                          _emergencyEscape = val;
                        });
                      },
                    ),
                  ),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: AppColors.primaryTeal,
                      secondary: Icon(
                        Icons.verified_user,
                        color: _requireEnforcedMode
                            ? AppColors.primaryTeal
                            : Colors.grey,
                      ),
                      title: const Text('Require Enforced Mode'),
                      subtitle: const Text(
                        'Will not start lock unless all permissions are granted',
                      ),
                      value: _requireEnforcedMode,
                      onChanged: (val) async {
                        await LockService.setRequireEnforcedMode(val);
                        setState(() {
                          _requireEnforcedMode = val;
                        });
                      },
                    ),
                  ),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: AppColors.primaryTeal,
                      secondary: Icon(
                        Icons.pin,
                        color: _useSystemPinning
                            ? AppColors.primaryTeal
                            : Colors.grey,
                      ),
                      title: const Text('System App Pinning'),
                      subtitle: const Text(
                        'Uses Android Screen Pinning. Shows a system dialog.',
                      ),
                      value: _useSystemPinning,
                      onChanged: (val) async {
                        await LockService.setSystemPinningEnabled(val);
                        setState(() {
                          _useSystemPinning = val;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info Card
                  Card(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: AppColors.primaryTeal),
                              const SizedBox(width: 8),
                              Text(
                                'About Enforced Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enforced Mode makes the lock bypass-proof by:\n'
                            '• Blocking access to Settings\n'
                            '• Drawing a curtain overlay on escape attempts\n'
                            '• Forcing return to lock screen\n\n'
                            'Standard Mode only uses Do Not Disturb.',
                            style: TextStyle(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.8,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
    String? badge,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isGranted ? AppColors.primaryTeal : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isGranted)
              Icon(Icons.check_circle, color: AppColors.primaryTeal)
            else
              ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Grant'),
              ),
          ],
        ),
      ),
    );
  }

  SecurityStatus _getSecurityStatus() {
    if (_hasAccessibility && _hasDND && _hasOverlay) {
      return SecurityStatus.enforced;
    } else if (_hasDND) {
      return SecurityStatus.standard;
    } else {
      return SecurityStatus.minimal;
    }
  }

  IconData _getStatusIcon(SecurityStatus status) {
    switch (status) {
      case SecurityStatus.enforced:
        return Icons.verified_user;
      case SecurityStatus.standard:
        return Icons.shield;
      case SecurityStatus.minimal:
        return Icons.warning;
    }
  }

  String _getStatusTitle(SecurityStatus status) {
    switch (status) {
      case SecurityStatus.enforced:
        return 'Enforced Mode';
      case SecurityStatus.standard:
        return 'Standard Mode';
      case SecurityStatus.minimal:
        return 'Minimal Protection';
    }
  }

  String _getStatusDescription(SecurityStatus status) {
    switch (status) {
      case SecurityStatus.enforced:
        return 'Maximum security - Lock is bypass-proof';
      case SecurityStatus.standard:
        return 'Basic lock with DND - Can be bypassed';
      case SecurityStatus.minimal:
        return 'No protection - Grant permissions to enable lock';
    }
  }

  void _showAccessibilityGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Accessibility Service'),
        content: const Text(
          'To enable the Accessibility Service:\n\n'
          '1. Find "Focusly" in the list\n'
          '2. Toggle the switch to ON\n'
          '3. Confirm by tapping OK\n\n'
          'This allows the app to monitor app switching and prevent bypassing the lock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
