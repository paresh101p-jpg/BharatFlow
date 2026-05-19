import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/api_keys.dart';
import 'fuel_history_screen.dart';

class FuelPricesScreen extends StatefulWidget {
  const FuelPricesScreen({super.key});

  @override
  State<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends State<FuelPricesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _currentCity = "Surat";
  String _currentState = "Gujarat";
  Map<String, dynamic> _fuelData = {};
  List<Map<String, dynamic>> _historyData = [];

  @override
  void initState() {
    super.initState();
    _loadLocationAndPrices();
  }

  Future<void> _loadLocationAndPrices() async {
    try {
      if (!mounted) return;
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          _currentCity = placemarks[0].locality ?? "Surat";
          _currentState = placemarks[0].administrativeArea ?? "Gujarat";
        }
      } catch (_) {}

      final results = await Future.wait([
        _supabase.from('fuel_prices').select().ilike('city', '%$_currentCity%').limit(1).maybeSingle(),
        _supabase.from('fuel_price_history').select().ilike('city', '%$_currentCity%').order('recorded_at', ascending: false).limit(7),
      ]);

      var fuelData = results[0] as Map<String, dynamic>?;
      var historyData = List<Map<String, dynamic>>.from(results[1] as List? ?? []);

      if (fuelData == null) {
        final fallback = await _supabase.from('fuel_prices').select().ilike('city', '%Surat%').limit(1).maybeSingle();
        fuelData = fallback;
      }

      if (mounted) {
        setState(() {
          _fuelData = fuelData ?? {};
          _historyData = historyData;
          _isLoading = false;
        });

        final lastUpdate = _fuelData['updated_at'] != null
            ? DateTime.parse(_fuelData['updated_at'])
            : DateTime.fromMillisecondsSinceEpoch(0);

        if (DateTime.now().difference(lastUpdate).inHours >= 4 || fuelData == null) {
          _refreshFromEdgeFunction();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshFromEdgeFunction() async {
    try {
      await http.get(
        Uri.parse('${ApiKeys.supabaseUrl}/functions/v1/fetch-fuel-prices'),
        headers: {'Authorization': 'Bearer ${ApiKeys.supabaseAnonKey}'},
      ).timeout(const Duration(seconds: 30));

      final response = await _supabase
          .from('fuel_prices')
          .select()
          .ilike('city', '%$_currentCity%')
          .limit(1)
          .maybeSingle();
      if (mounted && response != null) {
        setState(() => _fuelData = response);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF064E3B)))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 190,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF064E3B),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildSliverHeader(),
                    collapseMode: CollapseMode.pin,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 15),
                        _buildRecommendationCard(),
                        const SizedBox(height: 15),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _buildPriceCard('Petrol', _fuelData['petrol'], Icons.local_gas_station, Colors.orange, "per Ltr"),
                            _buildPriceCard('Diesel', _fuelData['diesel'], Icons.ev_station, Colors.blue, "per Ltr"),
                            _buildPriceCard('CNG', _fuelData['cng'], Icons.eco_rounded, Colors.teal, "per Kg"),
                            _buildPriceCard('PNG', _fuelData['png'], Icons.gas_meter_rounded, Colors.blueGrey, "per SCM"),
                            _buildPriceCard('LPG (Domestic)', _fuelData['lpg'], Icons.home_rounded, Colors.pink, "14.2kg Cyl"),
                            _buildPriceCard('Commercial LPG', _fuelData['commercial_lpg'], Icons.business_rounded, Colors.deepPurple, "19kg Cyl"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildFooterInfo(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverHeader() {
    String updateTime = "Updating...";
    if (_fuelData['updated_at'] != null) {
      updateTime = DateFormat('dd MMM yyyy, hh:mm a').format(
        DateTime.parse(_fuelData['updated_at']).toLocal(),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF065F46), Color(0xFF064E3B)]),
      ),
      padding: const EdgeInsets.fromLTRB(25, 60, 25, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("FUEL INTELLIGENCE",
              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.greenAccent, size: 24),
            const SizedBox(width: 8),
            Text(_currentCity,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text("$_currentState, India",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              children: [
                const Icon(Icons.update, color: Colors.greenAccent, size: 12),
                const SizedBox(width: 4),
                Text("Updated: $updateTime",
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildNotificationToggle(),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    final box = Hive.box('settings');
    final isEnabled = box.get('fuel_notifications', defaultValue: true);

    return Container(
      margin: const EdgeInsets.only(left: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.greenAccent, size: 12),
          const SizedBox(width: 8),
          const Text("Price Alerts", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          SizedBox(
            height: 20,
            width: 32,
            child: Transform.scale(
              scale: 0.6,
              child: Switch(
                value: isEnabled,
                activeColor: Colors.greenAccent,
                onChanged: (val) async {
                  await box.put('fuel_notifications', val);
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final lpg = (_fuelData['lpg'] as num?)?.toDouble() ?? 918.5;
    final png = (_fuelData['png'] as num?)?.toDouble() ?? 49.6;
    if (png == 0) return const SizedBox();
    final lpgEquivalentCost = lpg / 18.5;
    final isPngCheaper = png < lpgEquivalentCost;
    final savings = (lpgEquivalentCost - png).abs().toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPngCheaper
              ? [const Color(0xFF065F46), const Color(0xFF047857)]
              : [Colors.indigo.shade800, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPngCheaper ? "SMART CHOICE: SWITCH TO PNG" : "SMART CHOICE: USE LPG",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  isPngCheaper
                      ? "PNG, LPG se ₹$savings/unit sasta hai!"
                      : "LPG, PNG se ₹$savings/unit sasta hai!",
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String type, dynamic val, IconData icon, Color color, String unit) {
    return GestureDetector(
      onTap: () {
        if (_historyData.isNotEmpty) {
          String key = type.toLowerCase();
          if (type.contains('Commercial')) key = 'commercial_lpg';
          if (type.contains('Domestic')) key = 'lpg';
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => FuelHistoryScreen(
                  fuelType: key,
                  city: _currentCity,
                  history: _historyData,
                  themeColor: color)));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.replaceAll(' (Domestic)', ''), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("₹${val ?? '...'}", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(unit, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    const Text('Live Rate', style: TextStyle(fontSize: 7, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
              SizedBox(width: 6),
              Text("Data Sources",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 8),
          const Text("⛽ Petrol, Diesel, CNG, PNG, LPG",
              style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
          const Text("goodreturns.in",
              style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          const Text("🥇 Gold & Silver Rates",
              style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
          const Text("gold-api.com (Live International Rates)",
              style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          const Divider(),
          const Text("Prices are indicative & may vary slightly by retailer.",
              style: TextStyle(fontSize: 9, color: Colors.grey)),
          const Text("Data verified by BharatFlow Intelligence",
              style: TextStyle(fontSize: 9, color: Colors.blueGrey)),
        ],
      ),
    );
  }
}