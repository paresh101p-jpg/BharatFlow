import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:flutter/material.dart';
import 'package:bharat_flow/features/khata/presentation/screens/digital_khata_screen.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:bharat_flow/core/services/update_service.dart';

import 'package:bharat_flow/features/mandi/presentation/screens/mandi_intelligence_screen.dart';
import 'package:bharat_flow/features/khata/presentation/screens/digital_khata_screen.dart';
import 'package:bharat_flow/features/sasta_bazaar/presentation/screens/sasta_bazaar_screen.dart';
import 'package:bharat_flow/features/store/presentation/screens/bharat_brand_store_screen.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/features/notifications/presentation/screens/notification_history_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/profit_calculator_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/medicine_screen.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';
import 'package:bharat_flow/features/mandi/data/repositories/warehouse_repository.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/features/mandi/presentation/providers/mandi_providers.dart';
import 'package:bharat_flow/features/mandi/presentation/utils/commodity_utils.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_product_detail_screen.dart';
import 'package:bharat_flow/core/providers/location_provider.dart';

import 'weather_impact_screen.dart';
import 'weather_history_screen.dart';
import 'soil_health_screen.dart';
import 'mandi_calendar_screen.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_intelligence_screen.dart';
import 'package:bharat_flow/features/helpline/presentation/screens/ask_expert_screen.dart';

import 'offline_maps_screen.dart';
import 'package:bharat_flow/features/mera_khet/presentation/pages/mera_khet_home.dart';
import 'favorites_alerts_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/warehouse_locator_screen.dart';
import 'package:bharat_flow/features/political/presentation/screens/political_hub_screen.dart';
import 'package:bharat_flow/core/providers/weather_provider.dart';
import 'package:bharat_flow/core/providers/location_provider.dart' as core_loc;
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:bharat_flow/core/providers/general_providers.dart';
import 'package:bharat_flow/features/dashboard/presentation/widgets/location_weather_widget.dart';
import 'package:bharat_flow/features/profile/data/repositories/profile_repository.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';
import 'package:bharat_flow/features/dashboard/presentation/widgets/add_alert_sheet.dart';
import '../../../news/presentation/screens/market_news_hub_screen.dart';
import 'package:bharat_flow/features/mera_khet/presentation/pages/mera_khet_home.dart';
import 'package:bharat_flow/features/mera_khet/presentation/pages/mera_khet_wrapper.dart';
import 'package:bharat_flow/core/widgets/animated_bottom_nav.dart';
import 'package:bharat_flow/features/fuel/presentation/screens/fuel_prices_screen.dart';
import 'package:bharat_flow/core/providers/news_provider.dart';
import 'package:bharat_flow/features/political/presentation/screens/political_hub_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Colors ─────────────────────────────────────────────────────────────────
const _primary = Color(0xFF1B5E20);
const _bg = Color(0xFFF1F5F1);
const _card = Colors.white;

// ── Tool Usage Provider ────────────────────────────────────────────────────
final toolUsageProvider =
    StateNotifierProvider<ToolUsageNotifier, List<String>>((ref) {
  return ToolUsageNotifier();
});

class ToolUsageNotifier extends StateNotifier<List<String>> {
  ToolUsageNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('tool_usage');
    final recent = box.get('recent_tools', defaultValue: <String>[]);
    state = List<String>.from(recent);
  }

  void trackUse(String label) {
    final box = Hive.box('tool_usage');
    final List<String> current = List.from(state);

    // LRU Logic: Remove if exists, then add to top
    current.remove(label);
    current.insert(0, label);

    // Keep only top 8 recent tools to avoid long lists
    if (current.length > 8) {
      current.removeLast();
    }

    state = current;
    box.put('recent_tools', current);
  }
}

// ── Dashboard Screen ───────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _checkProfileSetup();
    Future.microtask(() {
      UpdateService.checkForUpdate(context);
    });
  }

  void _checkProfileSetup() {
    Future.microtask(() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Force refresh the profile to ensure we have latest data
      final profile = await ref.refresh(profileProvider.future);
      if (profile == null || !profile.isSetupComplete) {
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const ProfileSetupScreen()));
          // Re-check after returning from setup screen
          _checkProfileSetup();
        }
      }
    });
  }

  void _showCropSelectionPopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _CropSelectionPopup(),
    );
  }

  void _showExitConfirmationDialog(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _ExitConfirmationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(dashboardIndexProvider);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final mode = ref.read(homeTabModeProvider);
        if (currentIndex == 0 && mode == 'mandi') {
          ref.read(homeTabModeProvider.notifier).state = 'home';
          return;
        }
        if (currentIndex != 0) {
          ref.read(dashboardIndexProvider.notifier).state = 0;
          return;
        }
        _showExitConfirmationDialog(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: IndexedStack(
            index: currentIndex,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final mode = ref.watch(homeTabModeProvider);
                  if (mode == 'mandi') {
                    final cat = ref.read(mandiTabCategoryProvider);
                    final initialTab = ref.read(mandiTabInitialIndexProvider);
                    final standalone = ref.read(mandiStandaloneModeProvider);
                    return MandiIntelligenceScreen(
                      initialCategory: cat == 'All' ? null : cat,
                      initialTabIndex: initialTab,
                      standaloneMode: standalone,
                    );
                  }
                  return _HomeTab(
                    onMandiTap: () {
                      ref.read(mandiTabInitialIndexProvider.notifier).state = 0;
                      ref.read(mandiStandaloneModeProvider.notifier).state =
                          'mandi';
                      ref.read(homeTabModeProvider.notifier).state = 'mandi';
                    },
                    onProductTap: () {
                      ref.read(mandiTabInitialIndexProvider.notifier).state = 1;
                      ref.read(mandiStandaloneModeProvider.notifier).state =
                          'product';
                      ref.read(homeTabModeProvider.notifier).state = 'mandi';
                    },
                    onCategoryTap: (cat) {
                      ref.read(mandiTabInitialIndexProvider.notifier).state = 1;
                      ref.read(mandiStandaloneModeProvider.notifier).state =
                          'product';
                      ref.read(mandiTabCategoryProvider.notifier).state = cat;
                      ref.read(homeTabModeProvider.notifier).state = 'mandi';
                    },
                  );
                },
              ),
              const FavoritesAlertsScreen(),
              const BharatBrandStoreScreen(),
            ],
          ),
          bottomNavigationBar: AnimatedBottomNav(
            currentIndex: currentIndex,
            onTap: (i) {
              if (i == 0) {
                ref.read(homeTabModeProvider.notifier).state = 'home';
              }
              if (i == 2) {
                // If rewarded video ads are not configured in Supabase, bypass the lock entirely!
                if (!AdmobService.hasRewardedAd) {
                  ref.read(dashboardIndexProvider.notifier).state = 2;
                  return;
                }

                final box = Hive.box('settings');
                final unlockStr = box.get('unlock_until_store');
                bool isUnlocked = false;
                if (unlockStr != null) {
                  final unlockTime = DateTime.tryParse(unlockStr);
                  if (unlockTime != null &&
                      unlockTime.isAfter(DateTime.now())) {
                    isUnlocked = true;
                  }
                }

                if (!isUnlocked) {
                  _showRewardedUnlockDialog(
                      context, 'store', 'Bharat Brand Store', () {
                    ref.read(dashboardIndexProvider.notifier).state = 2;
                  });
                  return;
                }
              }
              ref.read(dashboardIndexProvider.notifier).state = i;
            },
          ),
        ),
      ),
    );
  }
}

class _ExitConfirmationDialog extends StatefulWidget {
  const _ExitConfirmationDialog();

  @override
  State<_ExitConfirmationDialog> createState() =>
      _ExitConfirmationDialogState();
}

class _ExitConfirmationDialogState extends State<_ExitConfirmationDialog> {
  int _rating = 5;
  String _selectedTag = "Easy to use!";
  bool _adPlaying = true;
  double _adProgress = 0.4;
  late Timer _timer;

  Future<void> _launchPlayStore() async {
    final url = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.BharatFlow');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Play Store: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted && _adPlaying) {
        setState(() {
          _adProgress += 0.02;
          if (_adProgress >= 1.0) _adProgress = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return "Very Poor 😟";
      case 2:
        return "Needs Improvement 😐";
      case 3:
        return "Good 🙂";
      case 4:
        return "Excellent! 😃";
      default:
        return "Absolutely Amazing! 😍";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top App Bar Style Header with App Logo and Name
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 8)
                          ],
                        ),
                        child: Image.asset('assets/images/logo.png', height: 32),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "BharatFlow",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2),
                          ),
                          Text(
                            "Kisan Market Intelligence Hub",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Are you sure you want to exit?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // App Review and 5-Star Interactive Rating System
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                children: [
                  const Text(
                    "Support us by giving a rating",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // Star Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      final isSelected = starVal <= _rating;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _rating = starVal;
                          });
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _launchPlayStore();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: isSelected
                                ? Colors.amber
                                : Colors.grey.shade400,
                            size: 38,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getRatingText(_rating),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20)),
                  ),
                  const SizedBox(height: 14),

                  // Quick Review Tags Selection
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      "Excellent!",
                      "Easy to use!",
                      "Great features!",
                      "Very helpful!"
                    ].map((tag) {
                      final isSel = _selectedTag == tag;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTag = tag;
                          });
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _launchPlayStore();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFFC8E6C9)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0xFF1B5E20)
                                  : Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSel
                                  ? const Color(0xFF1B5E20)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const DynamicAdmobGreenCardWidget(),
            ),

            const SizedBox(height: 10),

            // Working Exit Yes and No Stay Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  // No Stay Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF1B5E20), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "No, Stay in App",
                        style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Yes Exit Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Yes, Exit",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
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

class _HomeTab extends ConsumerWidget {
  final VoidCallback onMandiTap;
  final VoidCallback onProductTap;
  final Function(String) onCategoryTap;
  const _HomeTab(
      {required this.onMandiTap,
      required this.onProductTap,
      required this.onCategoryTap});

  String _formatRelativeTime(DateTime time, Map<String, String> t) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return t['just_now'] ?? 'Just now';
    if (diff.inMinutes < 60)
      return '${diff.inMinutes} ${t['mins_ago'] ?? 'mins ago'}';
    if (diff.inHours < 24)
      return '${diff.inHours} ${t['hours_ago'] ?? 'hours ago'}';
    return DateFormat('dd MMM').format(time);
  }

  Widget _miniRecord(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final categories = [
      _Cat(t['mandi'] ?? 'Mandi', Icons.analytics_rounded,
          const Color(0xFF1B5E20), null,
          onTap: onMandiTap),
      _Cat(t['product'] ?? 'Product', Icons.grass_rounded,
          const Color(0xFF2E7D32), null,
          onTap: onProductTap),
      _Cat(t['soil_health'] ?? 'Soil Health', Icons.eco_rounded,
          const Color(0xFF558B2F), const SoilHealthScreen()),
      _Cat(t['munafa_advisor'] ?? 'Munafa Advisor', Icons.calculate_rounded,
          const Color(0xFFFF8F00), const ProfitCalculatorScreen()),
      _Cat(t['festival'] ?? 'Festival', Icons.calendar_month_rounded,
          const Color(0xFF283593), const MandiCalendarScreen()),
      _Cat(t['warehouse'] ?? 'Warehouse', Icons.store_mall_directory_rounded,
          const Color(0xFFBF360C), const WarehouseLocatorScreen()),
      _Cat(t['news'] ?? 'Market News', Icons.newspaper_rounded,
          const Color(0xFFD84315), const MarketNewsHubScreen()),
      _Cat('Neta Kundali', Icons.how_to_vote_rounded,
          const Color(0xFF006064), const PoliticalHubScreen()),
      _Cat(t['offline'] ?? 'Offline', Icons.map_outlined,
          const Color(0xFF4E342E), const OfflineMapsScreen()),
      _Cat(t['community_forum'] ?? 'Community', Icons.forum_rounded,
          const Color(0xFF0277BD), const AskExpertScreen()),
      _Cat(t['medicine'] ?? 'Medicine', Icons.medical_services_rounded,
          const Color(0xFFE91E63), const MedicineScreen()),
      _Cat(t['fuel_price'] ?? 'Fuel Price', Icons.local_gas_station_rounded,
          Colors.orange.shade700, const FuelPricesScreen()),
      _Cat(t['mera_khet'] ?? 'My Farm', Icons.landscape_rounded,
          const Color(0xFF689F38), const MeraKhetWrapper()),
      _Cat(t['sasta_bazaar'] ?? 'Sasta Bazaar', Icons.shopping_basket_rounded,
          const Color(0xFF0F3D2F), const SastaBazaarScreen()),
      _Cat(t['digital_khata'] ?? 'Digital Khata', Icons.account_balance_wallet_rounded,
          Colors.teal.shade700, const DigitalKhataScreen()),
    ];

    return CustomScrollView(
      slivers: [
        const CommonSliverAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final weatherAsync = ref.watch(weatherProvider);
                    final t = ref.watch(translationsProvider);
                    return weatherAsync.when(
                      data: (weather) {
                        final core_loc.UserLocation location =
                            ref.watch(core_loc.locationProvider);
                        final address = '${location.city}, ${location.state}';
                        return InkWell(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WeatherImpactScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blue.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10))
                              ],
                              gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.9),
                                    Colors.blue.withOpacity(0.05)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              t['local_forecast_caps'] ??
                                                  'LOCAL FORECAST',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                  letterSpacing: 1.0)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF1B5E20)
                                                    .withOpacity(0.05),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(
                                                '${t['updated'] ?? 'Updated'} ${_formatRelativeTime(weather.lastUpdated, t)}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1B5E20))),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                          DateFormat('EEEE, dd MMM')
                                              .format(DateTime.now()),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey)),
                                      const SizedBox(height: 8),
                                      Text('Hawa: ${weather.windSpeed} km/h',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1B5E20))),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Flexible(
                                              child: Text(address,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600),
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _miniRecord(
                                                '🔥',
                                                '${weather.yearlyMax ?? 48.5}°C',
                                                weather.yearlyMaxDate ??
                                                    '15 May 2025'),
                                            const SizedBox(width: 8),
                                            _miniRecord(
                                                '❄️',
                                                '${weather.yearlyMin ?? 8.2}°C',
                                                weather.yearlyMinDate ??
                                                    '12 Jan 2026'),
                                            const SizedBox(width: 8),
                                            _miniRecord(
                                                '🌧️',
                                                '${weather.yearlyMaxRain ?? 125.0}mm',
                                                weather.yearlyMaxRainDate ??
                                                    '24 Aug 2025'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Icon(
                                        weather.iconType == 'Clear'
                                            ? Icons.wb_sunny
                                            : (weather.iconType == 'Rain'
                                                ? Icons.water_drop
                                                : Icons.wb_cloudy),
                                        size: 48,
                                        color: Colors.orangeAccent),
                                    const SizedBox(height: 4),
                                    Text(weather.temp,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B5E20))),
                                    const SizedBox(height: 12),
                                    if (weather.sunrise.isNotEmpty)
                                      Row(children: [
                                        const Icon(Icons.wb_twilight,
                                            size: 14, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(weather.sunrise,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold))
                                      ]),
                                    const SizedBox(height: 4),
                                    if (weather.sunset.isNotEmpty)
                                      Row(children: [
                                        const Icon(Icons.wb_sunny_outlined,
                                            size: 14, color: Colors.deepOrange),
                                        const SizedBox(width: 4),
                                        Text(weather.sunset,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold))
                                      ]),
                                    const SizedBox(height: 12),
                                    InkWell(
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const WeatherImpactScreen())),
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                              color:
                                                  Colors.blue.withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: Colors.blue
                                                      .withOpacity(0.15))),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.history_rounded,
                                                    size: 10,
                                                    color: Colors.blue),
                                                const SizedBox(width: 3),
                                                const Text('10Y H',
                                                    style: TextStyle(
                                                        fontSize: 7,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue))
                                              ])),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => Container(
                          height: 150,
                          decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(24))),
                      error: (_, __) => const SizedBox(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const _CommodityTicker(),
                const SizedBox(height: 10),
                Consumer(
                  builder: (context, ref, child) {
                    final recentTools = ref.watch(toolUsageProvider);
                    if (recentTools.isEmpty) return const SizedBox();

                    // Filter and map to actual Category items
                    final topTools = recentTools
                        .map((label) => categories.firstWhere(
                            (c) => c.label == label,
                            orElse: () => categories.first))
                        .take(4) // Only show top 4
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 2,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 0.85),
                            itemCount: topTools.length,
                            itemBuilder: (context, i) =>
                                _CatTile(cat: topTools[i])),
                        const SizedBox(height: 0),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 15),
                      ],
                    );
                  },
                ),
                GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.85),
                    itemCount: categories.length,
                    itemBuilder: (context, i) => _CatTile(cat: categories[i])),
                const _HomeNewsSection(),
                const _TopNetasSection(),
                const SizedBox(height: 24),
                const _FavoriteMandiWatch(),
                const SizedBox(height: 24),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommodityTicker extends ConsumerStatefulWidget {
  const _CommodityTicker();
  @override
  ConsumerState<_CommodityTicker> createState() => _CommodityTickerState();
}

class _CommodityTickerState extends ConsumerState<_CommodityTicker> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      final loc = ref.read(core_loc.locationProvider);
      String city = loc.city.isEmpty ? "Surat" : loc.city;

      // 1. Try city specific
      final List cityRes = await Supabase.instance.client
          .from('commodity_prices')
          .select()
          .ilike('city', '%$city%')
          .limit(1);
      var res = cityRes.isNotEmpty ? cityRes.first : null;

      // 2. If null, try any row as fallback
      if (res == null) {
        final List fallbackRes = await Supabase.instance.client
            .from('commodity_prices')
            .select()
            .limit(1);
        res = fallbackRes.isNotEmpty ? fallbackRes.first : null;
      }

      // 3. Fallback to direct API if data is stale (> 30 mins) or missing or looks like dummy data
      bool isStale = false;
      if (res != null) {
        if (res['updated_at'] != null) {
          final updated = DateTime.parse(res['updated_at']);
          if (DateTime.now().difference(updated).inMinutes > 30) {
            isStale = true;
          }
        } else {
          isStale = true; // No timestamp = stale
        }

        // Force refresh if it matches the EXACT old "dummy" numbers (72000.0 or 85000.0)
        if (res['gold_24k'] == 72000.0 && res['silver'] == 85000.0) {
          isStale = true;
        }
      }

      if (res == null || isStale) {
        debugPrint('🔄 Fetching Real-time Gold/Silver from API...');
        try {
          // Try a more reliable Indian price source or better conversion
          final goldRes = await http
              .get(Uri.parse('https://api.gold-api.com/price/XAU/INR'))
              .timeout(const Duration(seconds: 10));
          final silverRes = await http
              .get(Uri.parse('https://api.gold-api.com/price/XAG/INR'))
              .timeout(const Duration(seconds: 10));

          if (goldRes.statusCode == 200 && silverRes.statusCode == 200) {
            final goldData = json.decode(goldRes.body);
            final silverData = json.decode(silverRes.body);

            double rawGold = (goldData['price'] as num).toDouble();

            final pricePerGramGold = (rawGold / 31.1035) * 1.03;
            final pricePerGramSilver =
                ((silverData['price'] as num) / 31.1035) * 1.05;

            res = {
              'city': city,
              'gold_24k': (pricePerGramGold * 10).round().toDouble(),
              'silver': (pricePerGramSilver * 1000).round().toDouble(),
              'updated_at': DateTime.now().toIso8601String(),
            };
          } else {
            throw Exception('API Error: Status ${goldRes.statusCode}');
          }
        } catch (e) {
          debugPrint('Direct API Fallback Error: $e');
          // FORCE OVERWRITE with 2026 Real Data (from user search)
          if (res == null || res['gold_24k'] <= 73000.0) {
            res = {
              'city': city,
              'gold_24k': 166720.0,
              'silver': 94420.0,
              'updated_at': DateTime.now().toIso8601String(),
            };
          }
        }
      }

      if (mounted)
        setState(() {
          _data = res;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 40);
    if (_data == null) return const SizedBox.shrink();

    final formatter = NumberFormat("#,##,###", "en_IN");
    final gold = _data!['gold_24k'] != null
        ? formatter.format(_data!['gold_24k'])
        : 'N/A';
    final silver =
        _data!['silver'] != null ? formatter.format(_data!['silver']) : 'N/A';
    final cityName = _data!['city'] ?? 'Surat';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(Icons.military_tech_rounded, "Gold 24K", "₹$gold/10g",
              Colors.orange),
          Container(width: 1, height: 15, color: Colors.black12),
          _item(Icons.layers_rounded, "Silver", "₹$silver/kg", Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, String price, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(price,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: color))
      ])
    ]);
  }
}

class _FavoriteMandiWatch extends ConsumerWidget {
  const _FavoriteMandiWatch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final t = ref.watch(translationsProvider);

    if (favorites.isEmpty) return const SizedBox.shrink();

    // We show the first favorite mandi's products for a focused "Watchlist"
    final mandiName = favorites.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['market_watch'] ?? 'MARKET WATCH',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mandiName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(mandiName, true);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.favorite, color: Colors.red.shade400, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Unit Selector Chips
        Consumer(
          builder: (context, ref, _) {
            final selectedUnit = ref.watch(priceUnitProvider);
            final t = ref.watch(translationsProvider);
            final units = ['Quintal', 'KG', '20 KG', '40 KG'];
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: units.map((u) {
                final isSelected = selectedUnit == u;
                String displayUnit = u;
                if (u == 'Quintal') {
                  displayUnit = t['quintal'] ?? 'Quintal';
                } else if (u == 'KG') {
                  displayUnit = t['kg'] ?? 'KG';
                } else if (u == '20 KG') {
                  displayUnit = t['20_kg'] ?? '20 KG';
                } else if (u == '40 KG') {
                  displayUnit = t['40_kg'] ?? '40 KG';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => ref.read(priceUnitProvider.notifier).state = u,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFF1B5E20) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.shade200),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF1B5E20)
                                        .withOpacity(0.2),
                                    blurRadius: 4)
                              ]
                            : [],
                      ),
                      child: Text(
                        displayUnit,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        Consumer(
          builder: (context, ref, _) {
            final productsAsync = ref.watch(mandiProductsProvider(mandiName));

            return productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        t['no_products_found'] ??
                            'No products found for this market',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: products
                      .map((p) => _MandiProductCompactCard(
                          product: p, originalMandiName: mandiName))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1B5E20)),
                ),
              ),
              error: (e, __) => const SizedBox.shrink(),
            );
          },
        ),
        if (favorites.length > 1) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {
                // Navigate to mandi list or show more logic could go here
                ref.read(homeTabModeProvider.notifier).state = 'mandi';
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                '${t['view_all'] ?? 'View All'} ${favorites.length} ${t['favorites'] ?? 'Favorites'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20)),
            ),
          ),
        ],
      ],
    );
  }
}

class _MandiProductCompactCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final String originalMandiName;
  const _MandiProductCompactCard(
      {required this.product, required this.originalMandiName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedUnit = ref.watch(priceUnitProvider);
    final t = ref.watch(translationsProvider);
    final name = product['commodity_name'] ?? 'Unknown';
    final originalName = product['commodity_name_original'] ?? name;
    final variety = product['variety'] ?? 'General';
    final grade = product['grade'] ?? 'FAQ';
    final price = (product['modal_price'] as num?)?.toDouble() ?? 0.0;
    final date = product['arrival_date'] ?? '';
    final syncAt = product['sync_at'] ?? '';

    double displayPrice = price;
    String suffix = '/q';
    if (selectedUnit == 'KG') {
      displayPrice = price / 100;
      suffix = '/kg';
    } else if (selectedUnit == '20 KG') {
      displayPrice = price / 5;
      suffix = '/20k';
    } else if (selectedUnit == '40 KG') {
      displayPrice = price / 2.5;
      suffix = '/40k';
    }

    final formattedPrice = displayPrice > 0
        ? "₹${displayPrice.toStringAsFixed(displayPrice < 100 ? 1 : 0)}"
        : "N/A";
    final timeStr = CommodityUtils.getFullDateTime(date, syncAt);
    final imageUrl = CommodityUtils.getImageUrl(originalName);

    return InkWell(
      onTap: () async {
        final repo = ref.read(mandiRepositoryProvider);
        final location = ref.read(locationProvider);

        // Show loading or just navigate? Better fetch then navigate like the original screen
        final details = await repo.fetchVarietyDetails(
            originalMandiName, originalName,
            userState: location.state, userCity: location.city);

        if (!context.mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MandiProductDetailScreen(
                      mandiName: originalMandiName,
                      commodityName: name,
                      varietyList: details,
                    )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.isEmpty
                      ? Container(
                          width: 80,
                          height: 80,
                          color: const Color(0xFFF9FBF9),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.contain),
                        )
                      : Image.network(
                          imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFF9FBF9),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset('assets/images/logo.png',
                                fit: BoxFit.contain),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B262C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildChip(
                              variety.length > 8
                                  ? "${t['var'] ?? 'Var'}: ${variety.substring(0, 5)}.."
                                  : "${t['var'] ?? 'Var'}: $variety",
                              Colors.purple.shade50,
                              Colors.purple.shade700),
                          const SizedBox(width: 8),
                          _buildChip("${t['grd'] ?? 'Grd'}: $grade",
                              Colors.orange.shade50, Colors.orange.shade700),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 12, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${t['updated'] ?? 'updated'} $timeStr",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formattedPrice,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          Text(
                            suffix,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Notification Bell
            Positioned(
              right: 0,
              top: 0,
              child: Consumer(
                builder: (context, ref, _) {
                  final hasAlert = ref
                      .watch(priceAlertsProvider)
                      .any((a) => a.commodity == originalName);
                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => AddAlertSheet(initialProduct: {
                          ...product,
                          'mandi_name': product['mandi_name'],
                          'mandi_name_original': originalMandiName,
                        }),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: hasAlert
                            ? Colors.red.shade50
                            : const Color(0xFFF1F5F1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                          hasAlert
                              ? Icons.notifications_active
                              : Icons.notifications_active_outlined,
                          size: 18,
                          color:
                              hasAlert ? Colors.red : const Color(0xFF1B5E20)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}

class _CatTile extends ConsumerWidget {
  final _Cat cat;
  const _CatTile({required this.cat});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(toolUsageProvider.notifier).trackUse(cat.label);

        String? lockKey;
        String? displayTitle;
        if (cat.icon == Icons.grass_rounded) {
          lockKey = 'product';
          displayTitle = 'Product Intelligence';
        } else if (cat.icon == Icons.calendar_month_rounded) {
          lockKey = 'festival';
          displayTitle = 'Festival Muhurat Calendar';
        } else if (cat.icon == Icons.medical_services_rounded) {
          lockKey = 'medicine';
          displayTitle = 'Medicine & Stores Locator';
        } else if (cat.icon == Icons.local_gas_station_rounded) {
          lockKey = 'fuel';
          displayTitle = 'Fuel Intelligence & LPG';
        }

        if (lockKey != null) {
          // If rewarded video ads are not configured in Supabase, bypass the lock entirely!
          if (!AdmobService.hasRewardedAd) {
            if (cat.onTap != null)
              cat.onTap!();
            else if (cat.screen != null)
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => cat.screen!));
            return;
          }

          final box = Hive.box('settings');
          final unlockStr = box.get('unlock_until_$lockKey');
          bool isUnlocked = false;
          if (unlockStr != null) {
            final unlockTime = DateTime.tryParse(unlockStr);
            if (unlockTime != null && unlockTime.isAfter(DateTime.now())) {
              isUnlocked = true;
            }
          }

          if (!isUnlocked) {
            _showRewardedUnlockDialog(context, lockKey, displayTitle!, () {
              if (cat.onTap != null)
                cat.onTap!();
              else if (cat.screen != null)
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => cat.screen!));
            });
            return;
          }
        }

        if (cat.onTap != null)
          cat.onTap!();
        else if (cat.screen != null)
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => cat.screen!));
      },
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: cat.color.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Icon(cat.icon, color: cat.color, size: 30)),
        const SizedBox(height: 4),
        Text(cat.label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis)
      ]),
    );
  }
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  final Widget? screen;
  final VoidCallback? onTap;
  const _Cat(this.label, this.icon, this.color, this.screen, {this.onTap});
}

class _CropSelectionPopup extends ConsumerStatefulWidget {
  const _CropSelectionPopup();
  @override
  ConsumerState<_CropSelectionPopup> createState() =>
      _CropSelectionPopupState();
}

class _CropSelectionPopupState extends ConsumerState<_CropSelectionPopup> {
  List<Map<String, dynamic>> allProducts = [];
  bool isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts([String query = '']) async {
    if (!mounted) return;
    if (query.isEmpty) {
      final cachedItems = ref.read(productListProvider).items;
      if (cachedItems.isNotEmpty) {
        setState(() {
          allProducts = cachedItems;
          isLoading = false;
        });
        return;
      }
    }
    setState(() => isLoading = true);
    final loc = ref.read(core_loc.locationProvider);
    final products = await ref
        .read(mandiRepositoryProvider)
        .fetchUniqueProducts(
            page: 0,
            searchQuery: query,
            userState: loc.state,
            userCity: loc.city);
    if (mounted)
      setState(() {
        allProducts = products;
        isLoading = false;
      });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadProducts(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final favs = ref.watch(productFavoritesProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.05),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.eco_rounded, color: _primary, size: 30),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(t['skip'] ?? 'Skip',
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)))
                    ]),
                const SizedBox(height: 12),
                Text(t['what_sown_short'] ?? 'What have you sown?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: _primary)),
                const SizedBox(height: 16),
                TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                        hintText: t['search_products'] ?? 'Search crops...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none)))
              ]),
            ),
            if (isLoading)
              const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: _primary))
            else if (allProducts.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(t['no_products_found'] ?? 'No products found'))
            else
              Flexible(
                  child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      itemCount: allProducts.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (context, i) {
                        final p = allProducts[i];
                        final name = p['commodity_name'] ?? 'Unknown';
                        final originalName =
                            p['commodity_name_original'] ?? name;
                        final isFav = favs.contains(originalName);
                        return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            trailing: IconButton(
                                icon: Icon(
                                    isFav
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded,
                                    color: isFav ? _primary : Colors.grey),
                                onPressed: () {
                                  ref
                                      .read(productFavoritesProvider.notifier)
                                      .toggleFavorite(originalName, !isFav);
                                }));
                      })),
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0),
                    child: Text(t['done'] ?? 'Done',
                        style: const TextStyle(fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }
}

class _HomeNewsSection extends ConsumerWidget {
  const _HomeNewsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsProvider);

    return newsAsync.when(
      data: (newsList) {
        if (newsList.isEmpty) return const SizedBox.shrink();
        final breakingNews = newsList.take(3).toList();
        final colors = [Colors.teal, Colors.orange, Colors.indigo];
        final icons = [
          Icons.campaign_rounded,
          Icons.wb_sunny_rounded,
          Icons.trending_up_rounded
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Taaza Khabar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: breakingNews.asMap().entries.map((e) {
                  final i = e.key;
                  final n = e.value;
                  return _alertCard(context, n, colors[i % colors.length],
                      icons[i % icons.length]);
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _alertCard(
      BuildContext context, NewsItem news, Color color, IconData icon) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(news.sourceUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12, left: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          image: news.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(news.imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.7), BlendMode.darken),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: news.imageUrl != null ? Colors.white : color,
                    size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM').format(news.publishedAt),
                  style: TextStyle(
                      color: news.imageUrl != null ? Colors.white : color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(news.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: news.imageUrl != null ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(news.summary,
                style: TextStyle(
                    color: news.imageUrl != null ? Colors.white70 : Colors.grey,
                    fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

void _showRewardedUnlockDialog(BuildContext context, String featureKey,
    String displayName, VoidCallback onUnlocked) {
  AdmobService.showRewardConfirmationDialog(context, () {
    // Unlock logic when ad is completed successfully
    final box = Hive.box('settings');
    box.put(
      'unlock_until_$featureKey',
      DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    );
    
    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: Color(0xFFC8E6C9), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 60),
              ),
              const SizedBox(height: 20),
              Text(
                "$displayName Unlocked!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 8),
              const Text(
                "This feature is now unlocked for the next 24 hours. Thank you!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onUnlocked();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text("Get Started",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  });
}

class _TopNetasSection extends StatefulWidget {
  const _TopNetasSection();
  @override
  State<_TopNetasSection> createState() => _TopNetasSectionState();
}

class _TopNetasSectionState extends State<_TopNetasSection> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _topLeaders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final res = await _supabase
          .from('leaders_master')
          .select()
          .eq('is_active', true)
          .order('total_likes', ascending: false)
          .limit(3);
      if (mounted) {
        setState(() {
          _topLeaders = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _topLeaders.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                'Bharat Ke Top 3 Favorite Neta 🇮🇳',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PoliticalHubScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1C72), Color(0xFF1E114D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_topLeaders.length > 1) _buildPodiumItem(_topLeaders[1], 2),
                  if (_topLeaders.isNotEmpty) _buildPodiumItem(_topLeaders[0], 1),
                  if (_topLeaders.length > 2) _buildPodiumItem(_topLeaders[2], 3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> leader, int rank) {
    final isFirst = rank == 1;
    final color = isFirst ? Colors.amber : (rank == 2 ? Colors.grey.shade300 : Colors.orange.shade300);
    final size = isFirst ? 80.0 : 60.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst) const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 32),
        if (!isFirst) Text('${rank}nd'.replaceFirst('3nd', '3rd'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isFirst ? 4 : 2),
            boxShadow: [if (isFirst) BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
          ),
          child: ClipOval(
            child: (leader['photo_url'] != null && leader['photo_url'].toString().isNotEmpty)
                ? Image.network(leader['photo_url'], fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person, color: Colors.grey))
                : Container(color: Colors.white, child: const Icon(Icons.person, color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: isFirst ? 100 : 80,
          child: Text(
            leader['name'] ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isFirst ? FontWeight.w900 : FontWeight.bold,
              fontSize: isFirst ? 13 : 11,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${leader['total_likes'] ?? 0} Votes',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isFirst ? 13 : 11,
          ),
        ),
      ],
    );
  }
}
