import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../features/mandi/data/repositories/mandi_repository.dart';
import '../../../../features/mandi/presentation/providers/mandi_providers.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:bharat_flow/core/services/sync_service.dart';
class EnhancedSplashScreen extends ConsumerStatefulWidget {
  const EnhancedSplashScreen({super.key});

  @override
  ConsumerState<EnhancedSplashScreen> createState() =>
      _EnhancedSplashScreenState();
}

class _EnhancedSplashScreenState extends ConsumerState<EnhancedSplashScreen> {
  String _loadingStatus = "";
  int _percentage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = ref.read(translationsProvider);
      setState(() => _loadingStatus =
          t['system_initializing'] ?? "System Initializing...");
      _initializeApp(t);
    });
  }

  Future<void> _initializeApp(Map<String, String> t) async {
    final rand = math.Random();

    _updateProgress(rand.nextInt(4) + 1,
        t['connecting_to_bharat_network'] ?? "Connecting to Bharat Network...");
    await Future.delayed(const Duration(milliseconds: 300));

    _updateProgress(rand.nextInt(8) + 6,
        t['finding_farm_location'] ?? "Finding farm location...");
    try {
      await ref.read(locationProvider.notifier).getCurrentLocation();
    } catch (_) {}
    _updateProgress(
        rand.nextInt(10) + 15, t['location_found'] ?? "Location Found.");

    // Sync cloud favorites and alerts
    await SyncService.restoreFromCloud();

    // Detect and set default language based on location if not already set by the user (first time install)
    try {
      final box = Hive.box('settings');
      if (!box.containsKey('language') || box.get('language') == null) {
        final loc = ref.read(locationProvider);
        if (loc.address.contains('denied') ||
            loc.address.contains('disabled') ||
            loc.address.contains('Error')) {
          await box.put('language', 'English');
          await box.put('selected_language', 'English');
          await ref.read(settingsProvider.notifier).setLanguage('English');
        } else {
          final stateName = loc.state.trim();
          final langCode = LanguageHelper.indiaLanguageMap[stateName];
          final codeToName = {
            'hi': 'Hindi',
            'gu': 'Gujarati',
            'pa': 'Punjabi',
            'mr': 'Marathi',
            'bn': 'Bengali',
            'te': 'Telugu',
            'ta': 'Tamil',
            'kn': 'Kannada',
            'ml': 'Malayalam'
          };
          final detectedLang = codeToName[langCode] ?? 'English';

          debugPrint(
              'Splash: First-time location detected: "$stateName". Auto-setting language to "$detectedLang"');

          await box.put('language', detectedLang);
          await box.put('selected_language', detectedLang);
          await ref.read(settingsProvider.notifier).setLanguage(detectedLang);
        }
        ref.invalidate(translationsProvider);
      }
    } catch (e) {
      debugPrint('Splash: Error auto-setting language: $e');
    }

    try {
      final box = Hive.box('settings');
      final lastSyncStr = box.get('mandi_last_sync');
      bool isFresh = false;

      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        final diff = DateTime.now().difference(lastSync);
        if (diff.inHours < 12) isFresh = true;
      }

      if (isFresh) {
        _updateProgress(
            rand.nextInt(20) + 60, t['welcome_exclamation'] ?? "Welcome!");
        await Future.wait([
          ref.read(mandiPricesProvider.notifier).loadInitial(),
          ref.read(productListProvider.notifier).loadInitial(),
        ]);
        _updateProgress(100, t['bharat_flow_ready'] ?? "BharatFlow Ready.");
      } else {
        final loc = ref.read(locationProvider);
        await ref.read(mandiRepositoryProvider).syncRealData(
              userState: loc.state,
              userCity: loc.city,
              onProgress: (msg, prog) {
                // Add a little random jitter to the real progress
                double scaled = (25 + (prog * 45) + rand.nextInt(5)).toDouble();
                _updateProgress(scaled.toInt().clamp(0, 95), msg);
              },
            );

        _updateProgress(
            rand.nextInt(10) + 75, t['mandi_loaded'] ?? "Mandis Loaded...");
        await ref.read(mandiPricesProvider.notifier).loadInitial();

        _updateProgress(
            rand.nextInt(5) + 90, t['preparing_crops'] ?? "Preparing Crops...");
        await ref.read(productListProvider.notifier).loadInitial();

        _updateProgress(100, t['ready_exclamation'] ?? "Ready!");
      }
    } catch (_) {
      _updateProgress(100, t['ready_exclamation'] ?? "Ready!");
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _navigateAway();
  }

  void _updateProgress(int p, String msg) {
    if (mounted) {
      setState(() {
        _percentage = p;
        _loadingStatus = msg;
      });
    }
  }

  Future<void> _navigateAway() async {
    final box = Hive.box('settings');
    final bool seenOnboarding = box.get('seenOnboarding', defaultValue: false);
    final bool isLoggedIn = box.get('isLoggedIn', defaultValue: false);
    final auth = Supabase.instance.client.auth;

    if (mounted) {
      // ✅ Level 1: Attempt to restore session if Hive says we are logged in but Supabase is empty
      if (isLoggedIn && auth.currentSession == null) {
        debugPrint(
            'Splash: isLoggedIn=true but session=null. Attempting silent recovery...');
        try {
          // Use the global singleton to avoid conflicts
          final googleUser = await googleSignInInstance.signInSilently();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            if (googleAuth.idToken != null) {
              await auth.signInWithIdToken(
                provider: OAuthProvider.google,
                idToken: googleAuth.idToken!,
                accessToken: googleAuth.accessToken,
              );
              debugPrint('Splash: Session recovered successfully ✓');
            }
          }
        } catch (e) {
          debugPrint('Splash: Session recovery failed: $e');
        }
      }

      final session = auth.currentSession;

      Widget nextScreen;
      if (!seenOnboarding) {
        nextScreen = const OnboardingScreen();
      } else if (session != null) {
        // ✅ Only trust a REAL session now
        nextScreen = const DashboardScreen();
      } else {
        // If Hive was true but we failed to get a real session, reset Hive
        if (isLoggedIn) {
          await box.put('isLoggedIn', false);
        }
        nextScreen = const LoginScreen();
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF003D2B), Color(0xFF004D40), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // INDEPENDENT ANIMATION LAYER (Never rebuilds from progress setState)
            const _IndependentAnimationLayer(),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.3),
                                  blurRadius: 40,
                                  spreadRadius: 10)
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'BharatFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                            color: Colors.black45,
                            offset: Offset(0, 4),
                            blurRadius: 15)
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ref.watch(translationsProvider)['empowered_kisan_bharat'] ??
                        'Empowered Kisan · Empowered Bharat',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                  ),
                ],
              ),
            ),

            // Bottom Progress
            Positioned(
              bottom: 30, // Adjusted to fit branding beautifully
              left: 40,
              right: 40,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _loadingStatus,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$_percentage%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: (MediaQuery.of(context).size.width - 80) *
                              (_percentage / 100),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Colors.greenAccent, Colors.white]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.5),
                                  blurRadius: 10)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'From',
                    style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'MOJILO®',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
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

// Separate StatefulWidget for silky smooth background animation
class _IndependentAnimationLayer extends StatefulWidget {
  const _IndependentAnimationLayer();

  @override
  State<_IndependentAnimationLayer> createState() =>
      _IndependentAnimationLayerState();
}

class _IndependentAnimationLayerState extends State<_IndependentAnimationLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FloatingProduct> _products =
      List.generate(20, (_) => _FloatingProduct());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ProductPainter(_products, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ProductPainter extends CustomPainter {
  final List<_FloatingProduct> products;
  final double animationValue;

  _ProductPainter(this.products, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in products) {
      final double currentY =
          ((p.y - (animationValue * p.speed)) % 1.2 + 1.2) % 1.2 - 0.1;
      final double xPos = p.x * size.width;
      final double yPos = currentY * size.height;

      canvas.save();
      canvas.translate(xPos, yPos);
      canvas.rotate(animationValue * 2 * math.pi * p.rotationSpeed);
      p.painter.paint(canvas, Offset(-p.size / 2, -p.size / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ProductPainter oldDelegate) => true;
}

class _FloatingProduct {
  final double x = math.Random().nextDouble();
  final double y = math.Random().nextDouble();
  final double size = math.Random().nextDouble() * 30 + 20;
  final double speed = math.Random().nextDouble() * 0.8 + 0.3;
  final double rotationSpeed = math.Random().nextDouble() * 0.5 + 0.2;
  final IconData icon;
  late final TextPainter painter;

  _FloatingProduct()
      : icon = [
          Icons.grain,
          Icons.eco,
          Icons.grass,
          Icons.agriculture,
          Icons.spa,
          Icons.local_florist,
          Icons.forest,
        ][math.Random().nextInt(7)] {
    painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.greenAccent.withOpacity(0.2),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
