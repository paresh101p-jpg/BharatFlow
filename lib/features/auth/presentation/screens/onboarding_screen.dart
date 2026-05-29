import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _isLastPage = false;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Mandi Intelligence',
      description: 'Get real-time prices from 500+ mandis across India with AI-driven buy/sell signals.',
      icon: Icons.analytics_rounded,
      color: const Color(0xFF1B5E20),
    ),
    _OnboardingPage(
      title: 'Smart Logistics',
      description: 'Optimize your crop transport with real-time route planning and logistics tracking.',
      icon: Icons.local_shipping_rounded,
      color: const Color(0xFF1565C0),
    ),
    _OnboardingPage(
      title: 'Weather Impact',
      description: 'Precise weather forecasts tailored for your crops and harvest planning.',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFFE65100),
    ),
    _OnboardingPage(
      title: 'Digital Khata',
      description: 'Manage your farm expenses and earnings with our secure digital ledger.',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF6A1B9A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _isLastPage = index == _pages.length - 1),
            itemCount: _pages.length,
            itemBuilder: (context, index) => _pages[index],
          ),
          Container(
            alignment: const Alignment(0, 0.85),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _isLastPage
                    ? const SizedBox(width: 64) // Hide SKIP on last page while keeping alignment centered
                    : TextButton(
                        onPressed: () {
                          Hive.box('settings').put('seenOnboarding', true);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: const Text('SKIP', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                      ),
                SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: const WormEffect(
                    dotHeight: 10,
                    dotWidth: 10,
                    activeDotColor: Color(0xFF1B5E20),
                  ),
                ),
                _isLastPage
                    ? TextButton(
                        onPressed: () {
                          Hive.box('settings').put('seenOnboarding', true);
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        child: const Text('DONE', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                      )
                    : TextButton(
                        onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeIn),
                        child: const Text('NEXT', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 100, color: color),
          ),
          const SizedBox(height: 60),
          Text(
            title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }
}
