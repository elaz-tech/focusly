import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/home_screen.dart';
import '../services/lock_service.dart';
import '../utils/app_colors.dart';

class LockScreen extends StatefulWidget {
  final int initialSeconds;
  const LockScreen({super.key, required this.initialSeconds});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  SecurityStatus _securityStatus = SecurityStatus.minimal;

  bool _isEmergencyEscapeEnabled = true;

  // Hold-to-unlock animation
  late AnimationController _holdController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _checkSecurityStatus();
    _startTimer();

    _holdController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _holdController.reset();
              setState(() => _isHolding = false);
              HapticFeedback.heavyImpact();
              _showEmergencyUnlockDialog();
            }
          });
  }

  Future<void> _loadPreferences() async {
    final enabled = await LockService.isEmergencyEscapeEnabled();
    setState(() {
      _isEmergencyEscapeEnabled = enabled;
    });
  }

  Future<void> _checkSecurityStatus() async {
    final status = await LockService.getSecurityStatus();
    setState(() {
      _securityStatus = status;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _holdController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-assert lock if user tried to minimise or leave
      LockService.reAssertLock();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds <= 0) {
        _unlock();
      } else {
        // Sync with source of truth occasionally or just decrement
        setState(() {
          _remainingSeconds--;
        });

        // Every 10 seconds, sync with storage and check security
        if (_remainingSeconds % 10 == 0) {
          _checkSecurityStatus();
          final realRemaining = await LockService.getRemainingSeconds();
          if (realRemaining <= 0) {
            _unlock();
          } else {
            setState(() {
              _remainingSeconds = realRemaining;
            });
          }
        }
      }
    });
  }

  Future<void> _unlock() async {
    _timer?.cancel();
    await LockService.stopLock();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.iconGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 50, color: Colors.white70),
                const SizedBox(height: 20),
                const Text(
                  "PHONE LOCKED",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: widget.initialSeconds > 0
                            ? _remainingSeconds / widget.initialSeconds
                            : 0,
                        strokeWidth: 8,
                        backgroundColor: Colors.white10,
                        color: AppColors.accentTeal,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Time Remaining",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "Focus on your task. You can still receive calls.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 30),
                // Security Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getSecurityColor(
                      _securityStatus,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _getSecurityColor(
                        _securityStatus,
                      ).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSecurityIcon(_securityStatus),
                        size: 14,
                        color: _getSecurityColor(_securityStatus),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getSecurityText(_securityStatus),
                        style: TextStyle(
                          color: _getSecurityColor(_securityStatus),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Emergency Escape Hatch
                if (_isEmergencyEscapeEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) {
                        setState(() => _isHolding = true);
                        _holdController.forward();
                      },
                      onTapUp: (_) {
                        setState(() => _isHolding = false);
                        if (_holdController.status !=
                            AnimationStatus.completed) {
                          _holdController.reverse();
                        }
                      },
                      onTapCancel: () {
                        setState(() => _isHolding = false);
                        _holdController.reverse();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: AnimatedBuilder(
                                    animation: _holdController,
                                    builder: (context, child) {
                                      return CircularProgressIndicator(
                                        value: _holdController.value,
                                        strokeWidth: 3,
                                        backgroundColor: Colors.white10,
                                        color: _isHolding
                                            ? Colors.orangeAccent
                                            : Colors.white24,
                                      );
                                    },
                                  ),
                                ),
                                Icon(
                                  Icons.touch_app,
                                  size: 20,
                                  color: _isHolding
                                      ? Colors.orangeAccent
                                      : Colors.white24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isHolding
                                  ? "Release to Cancel"
                                  : "Hold to Unlock",
                              style: TextStyle(
                                color: _isHolding
                                    ? Colors.orangeAccent
                                    : Colors.white.withValues(alpha: 0.3),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyUnlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Unlock"),
        content: const Text(
          "Are you sure you want to end the lock now? This defeats the purpose of the focus session.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Keep Locking"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _unlock();
            },
            child: const Text("Unlock Now"),
          ),
        ],
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
        return "PROTECTION AT RISK";
    }
  }
}
