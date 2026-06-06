import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../setup/society_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(title: 'Welcome to Society Manager', description: 'The easiest way to manage your society accounts and maintenance records.', icon: Icons.apartment),
    OnboardingData(title: 'Track Maintenance', description: 'Easily track who has paid and who is pending for each month.', icon: Icons.receipt_long),
    OnboardingData(title: 'Generate Reports', description: 'Get detailed PDF and Excel reports with a single tap for all members.', icon: Icons.bar_chart),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (_, idx) => OnboardingPage(data: _pages[idx]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(color: _currentPage == index ? const Color(0xFF1565C0) : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_currentPage == _pages.length - 1) {
                        final provider = context.read<AppProvider>();
                        await provider.setOnboardingCompleted();
                        if (mounted) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SocietySetupScreen(isFirst: true)));
                        }
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title, description;
  final IconData icon;
  OnboardingData({required this.title, required this.description, required this.icon});
}

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(26), borderRadius: BorderRadius.circular(14)),
            child: Icon(data.icon, size: 100, color: const Color(0xFF1565C0)),
          ),
          const SizedBox(height: 60),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5),
          ),
          const SizedBox(height: 20),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }
}
