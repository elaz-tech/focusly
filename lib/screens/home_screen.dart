import 'package:flutter/material.dart';
import '../services/lock_service.dart';
import '../widgets/about.dart' show showAboutMe;
import '../utils/app_colors.dart';
import 'lock_screen.dart';
import 'settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _minutes = 30;
  SecurityStatus _securityStatus = SecurityStatus.minimal;
  bool _isLocking = false;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSecurityStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSecurityStatus();
    }
  }

  Future<void> _checkSecurityStatus() async {
    if (_isCheckingStatus) return;
    _isCheckingStatus = true;

    try {
      // Small delay to let navigation transitions finish smoothly
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final status = await LockService.getSecurityStatus();
      if (mounted) {
        setState(() {
          _securityStatus = status;
        });
      }
    } finally {
      _isCheckingStatus = false;
    }
  }

  Future<void> _startLock() async {
    if (_isLocking) return;
    setState(() => _isLocking = true);

    try {
      // Check DND permission (Universal)
      final hasDND = await LockService.checkDNDPermission();
      if (!hasDND) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Permission Required"),
              content: const Text(
                "Please grant 'Do Not Disturb' access to allow the app to silence notifications.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    LockService.requestDNDPermission();
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Check Enforced Mode (Admin + Accessibility)
      final status = await LockService.getSecurityStatus();
      final requireEnforced = await LockService.isRequireEnforcedModeEnabled();

      if (requireEnforced && status != SecurityStatus.enforced) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Enforced Mode Required"),
              content: const Text(
                "You have enabled 'Require Enforced Mode' in settings. "
                "Please grant Accessibility and Overlay permissions to ensure the lock is bypass-proof.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        )
                        .then((_) => _checkSecurityStatus());
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Check Battery Optimization (Recommendation for stability)
      final hasBatteryExemption = await LockService.checkBatteryOptimization();
      if (!hasBatteryExemption && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Battery Optimization Active"),
            content: const Text(
              "Your system may close Focusly to save battery. "
              "For maximum reliability, we recommend disabling battery optimization for this app.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Ignore & Start"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, false);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: const Text("Go to Settings"),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isLocking = false);
          return;
        }
      }

      // Start Lock
      final usePinning = await LockService.isSystemPinningEnabled();
      await LockService.startLock(_minutes, usePinning: usePinning);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LockScreen(initialSeconds: _minutes * 60),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocking = false);
      }
    }
  }

  // about me
  Future<void> _aboutMe() async {
    return await showAboutMe(
      context,
      "assets/icon/icon.png",
      "Focusly",
      "Focusly helps you reclaim your attention. Set a timer from 1 to 120 minutes and your phone stays locked until it expires — only phone calls get through. Bypass attempts are blocked automatically, with an optional long-press emergency escape for genuine emergencies. Less scrolling, more living.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Focusly"),
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          IconButton(icon: const Icon(Icons.info), onPressed: () => _aboutMe()),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_clock,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                // Security Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getSecurityColor(
                      _securityStatus,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getSecurityColor(_securityStatus),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSecurityIcon(_securityStatus),
                        size: 16,
                        color: _getSecurityColor(_securityStatus),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getSecurityText(_securityStatus),
                        style: TextStyle(
                          color: _getSecurityColor(_securityStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Set Lock Duration",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  "$_minutes Minutes",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Slider(
                  value: _minutes.toDouble(),
                  min: 1,
                  max: 120,
                  activeColor: AppColors.primaryTeal,
                  inactiveColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                  divisions: 119,
                  label: "$_minutes min",
                  onChanged: (val) {
                    setState(() {
                      _minutes = val.toInt();
                    });
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _startLock,
                  child: const Text(
                    "START FOCUSING",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Warning: You will not be able to use your phone until the timer expires. Only calls are allowed.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSecurityColor(SecurityStatus status) {
    switch (status) {
      case SecurityStatus.enforced:
        return Colors.green;
      case SecurityStatus.standard:
        return Colors.orange;
      case SecurityStatus.minimal:
        return Colors.red;
    }
  }

  IconData _getSecurityIcon(SecurityStatus status) {
    switch (status) {
      case SecurityStatus.enforced:
        return Icons.verified_user;
      case SecurityStatus.standard:
        return Icons.shield;
      case SecurityStatus.minimal:
        return Icons.warning;
    }
  }

  String _getSecurityText(SecurityStatus status) {
    switch (status) {
      case SecurityStatus.enforced:
        return "ENFORCED MODE ACTIVE";
      case SecurityStatus.standard:
        return "STANDARD MODE";
      case SecurityStatus.minimal:
        return "MINIMAL PROTECTION";
    }
  }
}
