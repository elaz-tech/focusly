import 'package:flutter/material.dart';
import '../services/lock_service.dart';
import '../screens/home_screen.dart';
import '../screens/lock_screen.dart';

class StartupCheck extends StatefulWidget {
  const StartupCheck({super.key});

  @override
  State<StartupCheck> createState() => _StartupCheckState();
}

class _StartupCheckState extends State<StartupCheck> {
  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final remainingSeconds = await LockService.getRemainingSeconds();
    if (!mounted) return;

    if (remainingSeconds > 0) {
      // Resume lock
      await LockService.reAssertLock();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LockScreen(initialSeconds: remainingSeconds)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

