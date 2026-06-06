import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../home_screen.dart';
import '../setup/society_setup_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // Small delay to show the logo
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final provider = context.read<AppProvider>();
    await provider.init();

    if (!provider.isOnboardingCompleted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    } else if (provider.society == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SocietySetupScreen(isFirst: true)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance, size: 80, color: Color(0xFF1565C0)),
            const SizedBox(height: 24),
            const Text(
              'Society Manager',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1565C0), letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1565C0).withAlpha(128))),
          ],
        ),
      ),
    );
  }
}
