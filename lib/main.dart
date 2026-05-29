import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'core/providers/settings_provider.dart';
import 'features/profile/presentation/screens/pin_lock_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:bharat_flow/core/services/notification_service.dart';
import 'package:bharat_flow/core/services/config_service.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'core/constants/api_keys.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/splash/presentation/screens/enhanced_splash_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bharat_flow/features/dashboard/data/repositories/festival_repository.dart';
import 'package:bharat_flow/features/auth/presentation/screens/login_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/utils/commodity_utils.dart';
import 'core/services/ad_blocker_service.dart';
import 'features/security/presentation/screens/ad_block_warning_screen.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Required for Topic Subscriptions & FCM)
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }


  // ✅ FIX 1: autoRefreshToken true kiya — session automatically refresh hoga
  await Supabase.initialize(
    url: ApiKeys.supabaseUrl,
    anonKey: ApiKeys.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true, // ✅ Token expire hone se pehle auto refresh
    ),
  );

  // Initialize secure backend remote configurations
  await ConfigService.initialize();

  // Initialize Google Mobile Ads dynamically
  await AdmobService.initialize();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('mandi_cache');
  await Hive.openBox('weather_cache');
  await Hive.openBox('mandi_favorites');
  await Hive.openBox('product_favorites');
  await Hive.openBox('mandi_prices_history');
  await Hive.openBox('mandi_timings');
  await Hive.openBox('mandi_alerts');
  await Hive.openBox('translations_cache');
  await Hive.openBox('mandi_locations');
  await Hive.openBox('tool_usage');
  await Hive.openBox('weather_selected_crops');
  await Hive.openBox('offline_maps');
  await Hive.openBox('medical_stores_cache');
  await Hive.openBox('blocked_users');
  await Hive.openBox('flagged_users');
  await Hive.openBox('supabase_commodity_images');
  await Hive.openBox('khata_transactions');

  // Schedule Festival Notifications
  FestivalRepository.scheduleUpcomingFestivals();

  // Initialize Notifications
  await NotificationService.init();

  // Background Sync Custom Commodity Images from Supabase
  try {
    CommodityUtils.syncCustomImagesFromSupabase();
  } catch (_) {}
  
  // try {
  //   MandiRepository().bulkTranslateCommodities();
  // } catch (_) {}

  // Handle initial notification if app was closed
  final initialNotification = await NotificationService.getInitialNotification();
  if (initialNotification != null) {
    Future.delayed(const Duration(seconds: 2), () {
      NotificationService.handlePayload(initialNotification.payload);
    });
  }

  // Initialize WorkManager
  await Workmanager().cancelAll();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "news_sync_task",
    "news_sync_task",
    frequency: const Duration(minutes: 15),
  );

  runApp(
    const ProviderScope(
      child: BharatFlowApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class BharatFlowApp extends ConsumerStatefulWidget {
  const BharatFlowApp({super.key});

  @override
  ConsumerState<BharatFlowApp> createState() => _BharatFlowAppState();
}

class _BharatFlowAppState extends ConsumerState<BharatFlowApp> {
  @override
  void initState() {
    super.initState();

    // ✅ FIX 2: Global auth state listener — session expire ho toh auto login screen
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('🔐 Auth State Changed: $event');

      if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted) {
        // Hive me bhi logout mark karo
        Hive.box('settings').put('isLoggedIn', false);

        // Login screen pe redirect
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [
        if (isFirebaseInitialized)
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      title: 'BharatFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return SecurityWrapper(child: child!);
      },
      home: const EnhancedSplashScreen(),
    );
  }
}

class SecurityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const SecurityWrapper({super.key, required this.child});

  @override
  ConsumerState<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends ConsumerState<SecurityWrapper>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAdBlockerActive = false;
  DateTime? _lastBackgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initial Ad Blocker check
    _checkAdBlocker();

    final settings = ref.read(settingsProvider);
    if (settings.pinEnabled && settings.pinCode.isNotEmpty) {
      _isLocked = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAdBlocker() async {
    final active = await AdBlockerService.isAdBlockerOrPrivateDnsActive();
    if (mounted) {
      setState(() {
        _isAdBlockerActive = active;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check ad blocker on app resume
    if (state == AppLifecycleState.resumed) {
      _checkAdBlocker();
    }

    final settings = ref.read(settingsProvider);
    if (!settings.pinEnabled || settings.pinCode.isEmpty) return;

    if (state == AppLifecycleState.paused) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        final diff = DateTime.now().difference(_lastBackgroundTime!);
        if (diff.inSeconds > 60) {
          setState(() => _isLocked = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdBlockerActive) {
      return AdBlockWarningScreen(
        onAdBlockerDisabled: () => setState(() => _isAdBlockerActive = false),
      );
    }
    if (_isLocked) {
      return PinLockScreen(onUnlocked: () => setState(() => _isLocked = false));
    }
    return SafeArea(
      top: false, // Keep top behavior unchanged
      bottom: true, // Prevent cutoff at the bottom navigation bar
      child: widget.child,
    );
  }
}