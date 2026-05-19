import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_intelligence_screen.dart';
import 'package:bharat_flow/features/khata/presentation/screens/digital_khata_screen.dart';
import 'package:bharat_flow/features/store/presentation/screens/bharat_brand_store_screen.dart';
import 'package:bharat_flow/features/news/presentation/screens/market_news_hub_screen.dart';

// Import category screens
import 'weather_impact_screen.dart';
import 'soil_health_screen.dart';
import 'logistics_screen.dart';
import 'route_optimizer_screen.dart';
import 'subsidy_tracker_screen.dart';
import 'daily_market_report_screen.dart';
import 'mandi_calendar_screen.dart';
import 'price_intelligence_screen.dart';
import 'profit_analytics_screen.dart';
import 'trend_comparison_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/warehouse_locator_screen.dart';
import 'offline_maps_screen.dart';
import 'crop_comparison_map_screen.dart';
import 'voice_assistant_screen.dart';
import 'favorites_alerts_screen.dart';
import 'share_price_card_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomeWithCategories(),
    const MandiIntelligenceScreen(),
    const DigitalKhataScreen(),
    const BharatBrandStoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Mandi'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Khata'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Store'),
        ],
      ),
    );
  }
}

class _HomeWithCategories extends StatelessWidget {
  const _HomeWithCategories();

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'icon': Icons.wb_sunny, 'label': 'Weather', 'screen': const WeatherImpactScreen()},
      {'icon': Icons.eco, 'label': 'Soil Health', 'screen': const SoilHealthScreen()},
      {'icon': Icons.local_shipping, 'label': 'Logistics', 'screen': const LogisticsScreen()},
      {'icon': Icons.map, 'label': 'Route', 'screen': const RouteOptimizerScreen()},
      {'icon': Icons.assignment, 'label': 'Subsidy', 'screen': const SubsidyTrackerScreen()},
      {'icon': Icons.description, 'label': 'Reports', 'screen': const DailyMarketDigestScreen()},
      {'icon': Icons.calendar_month, 'label': 'Calendar', 'screen': const MandiCalendarScreen()},
      {'icon': Icons.psychology, 'label': 'AI Price', 'screen': const PriceIntelligenceScreen()},
      {'icon': Icons.calculate, 'label': 'Profit', 'screen': const ProfitAnalyticsScreen()},
      {'icon': Icons.trending_up, 'label': 'Trends', 'screen': const TrendComparisonScreen()},
      {'icon': Icons.store_mall_directory_outlined, 'label': 'Warehouse', 'screen': const WarehouseLocatorScreen()},
      {'icon': Icons.map_outlined, 'label': 'Offline Map', 'screen': const OfflineMapsScreen()},
      {'icon': Icons.compare, 'label': 'Compare', 'screen': const RefinedAgricultureMapScreen()},
      {'icon': Icons.mic, 'label': 'Voice', 'screen': const VoiceMarketAssistantScreen()},
      {'icon': Icons.favorite, 'label': 'Alerts', 'screen': const FavoritesAlertsScreen()},
      {'icon': Icons.credit_card, 'label': 'Share Card', 'screen': const SharePriceCardScreen()},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        title: const Text('BharatFlow', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.white)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => cat['screen'] as Widget)),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                        child: Icon(cat['icon'] as IconData, color: const Color(0xFF1B5E20), size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(cat['label'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
