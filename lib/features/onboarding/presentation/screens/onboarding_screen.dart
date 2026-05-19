import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/theme/app_theme.dart';
import 'package:bharat_flow/features/auth/presentation/screens/auth_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _isLastPage = false;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Bharat ki Pragati',
      'description': 'BharatFlow ke saath judiye aur digital kranti ka hissa baniye. Sab kuch ab aapke hath mein!',
      'icon': '🚀',
    },
    {
      'title': 'Live Mandi Bhav',
      'description': 'Poore India ki mandiyon ke live rate aur sasti deals ab ek click par. Paisa bachaiye, khushali laiye!',
      'icon': '🌾',
    },
    {
      'title': 'Smarter Transport',
      'description': 'Vahan ka sahi samay aur live location. Ab kabhi bhi bus ya truck ke liye intezaar nahi!',
      'icon': '🚌',
    },
    {
      'title': 'AI Shakti',
      'description': 'Hamara AI aapko batayega ki kab aur kahan jana hai aapke fayde ke liye. BharatFlow - Aapka Sathi.',
      'icon': '🧠',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.15),
              ),
            ),
          ),

          PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => _isLastPage = index == 3);
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                title: _onboardingData[index]['title']!,
                description: _onboardingData[index]['description']!,
                icon: _onboardingData[index]['icon']!,
              );
            },
          ),

          // Bottom Controls
          Container(
            alignment: const Alignment(0, 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip Button
                TextButton(
                  onPressed: () => _controller.jumpToPage(3),
                  child: const Text('Skip', style: TextStyle(color: Colors.grey)),
                ),

                // Indicator
                SmoothPageIndicator(
                  controller: _controller,
                  count: 4,
                  effect: ExpandingDotsEffect(
                    activeDotColor: AppTheme.primaryColor,
                    dotColor: Colors.white24,
                    dotHeight: 8,
                    dotWidth: 8,
                    spacing: 8,
                  ),
                ),

                // Next/Get Started
                _isLastPage
                    ? ElevatedButton(
                        onPressed: () {
                          // Mark onboarding as complete
                          Hive.box('settings').put('is_first_time', false);
                          
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AuthWrapper()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('Shuru Karein'),
                      )
                    : IconButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeIn,
                        ),
                        icon: const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final String icon;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo placeholder with animation
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 80)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 60),
          Text(
            title,
            textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
