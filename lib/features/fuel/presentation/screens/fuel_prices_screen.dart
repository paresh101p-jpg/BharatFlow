import 'package:flutter/material.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/services/share_manager.dart';
import 'package:bharat_flow/core/services/notification_service.dart';
import 'fuel_history_screen.dart';

class FuelPricesScreen extends ConsumerStatefulWidget {
  const FuelPricesScreen({super.key});

  @override
  ConsumerState<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends ConsumerState<FuelPricesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _currentCity = "Surat";
  String _currentDistrict = "Surat";
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
          // Use District (subAdministrativeArea) as the primary city for Fuel Prices
          // because small villages like 'Kathodara' fail on scraping and give garbage data.
          String locality = placemarks[0].locality ?? "Surat";
          String district = placemarks[0].subAdministrativeArea ?? locality;
          
          _currentCity = district.isNotEmpty ? district : locality;
          _currentDistrict = district;
          _currentState = placemarks[0].administrativeArea ?? "Gujarat";
        }
      } catch (_) {}

      final results = await Future.wait([
        _supabase.from('fuel_prices').select().ilike('city', '%$_currentCity%').limit(1).maybeSingle(),
        _supabase.from('fuel_price_history').select().ilike('city', '%$_currentCity%').order('recorded_at', ascending: false).limit(30),
      ]);

      var fuelData = results[0] as Map<String, dynamic>?;
      var historyData = List<Map<String, dynamic>>.from(results[1] as List? ?? []);

      if (fuelData == null) {
        // City not found in DB. Let's dynamically fetch it from the Edge Function!
        await _fetchAndLoadDynamicCity();
        return;
      }

      if (mounted) {
        setState(() {
          _fuelData = fuelData ?? {};
          _historyData = historyData;
          _isLoading = false;
        });

        // Note: Global Edge Function call removed here to prevent "Thundering Herd" problem.
        // Data updates will now strictly rely on the Supabase pg_cron job running in the background.
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndLoadDynamicCity() async {
    try {
      // 1. Invoke edge function to scrape this specific live city
      await Supabase.instance.client.functions.invoke(
        'fetch-fuel-prices',
        body: {'city': _currentCity, 'state': _currentState},
      ).timeout(const Duration(seconds: 15));

      // 2. Query again
      final results = await Future.wait([
        _supabase.from('fuel_prices').select().ilike('city', '%$_currentCity%').limit(1).maybeSingle(),
        _supabase.from('fuel_price_history').select().ilike('city', '%$_currentCity%').order('recorded_at', ascending: false).limit(30),
      ]);
      
      var dynamicFuelData = results[0] as Map<String, dynamic>?;
      var dynamicHistory = List<Map<String, dynamic>>.from(results[1] as List? ?? []);

      // 3. If STILL null (GoodReturns doesn't support this small city/village), fallback to District
      if (dynamicFuelData == null) {
        // Try scraping for the District instead
        await Supabase.instance.client.functions.invoke(
          'fetch-fuel-prices',
          body: {'city': _currentDistrict, 'state': _currentState},
        ).timeout(const Duration(seconds: 15)).catchError((e) => null);

        final districtResults = await Future.wait([
          _supabase.from('fuel_prices').select().ilike('city', '%$_currentDistrict%').limit(1).maybeSingle(),
          _supabase.from('fuel_price_history').select().ilike('city', '%$_currentDistrict%').order('recorded_at', ascending: false).limit(30),
        ]);
        dynamicFuelData = districtResults[0] as Map<String, dynamic>?;
        dynamicHistory = List<Map<String, dynamic>>.from(districtResults[1] as List? ?? []);
        
        // If District also fails, fallback to Surat
        if (dynamicFuelData == null) {
          final suratResults = await Future.wait([
            _supabase.from('fuel_prices').select().ilike('city', '%Surat%').limit(1).maybeSingle(),
            _supabase.from('fuel_price_history').select().ilike('city', '%Surat%').order('recorded_at', ascending: false).limit(30),
          ]);
          dynamicFuelData = suratResults[0] as Map<String, dynamic>?;
          dynamicHistory = List<Map<String, dynamic>>.from(suratResults[1] as List? ?? []);
        }
      }

      if (mounted) {
        setState(() {
          _fuelData = dynamicFuelData ?? {};
          _historyData = dynamicHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, fallback to Surat
      final fallback = await _supabase.from('fuel_prices').select().ilike('city', '%Surat%').limit(1).maybeSingle();
      if (mounted) {
         setState(() {
           _fuelData = fallback ?? {};
           _isLoading = false;
         });
      }
    }
  }

  Future<void> _refreshFromEdgeFunction() async {
    try {
      await Supabase.instance.client.functions.invoke('fetch-fuel-prices').timeout(const Duration(seconds: 30));

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
    final t = ref.watch(translationsProvider);
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
                        const SizedBox(height: 16),
                        const DynamicAdmobCardWidget(),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
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

  // ... (keeping other methods same until _buildPriceCard) ...

  Widget _buildSliverHeader() {
    final t = ref.read(translationsProvider);
    String updateTime = '${t['updated'] ?? 'Updating'}...';
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(t['fuel_price'] ?? 'FUEL INTELLIGENCE',
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.greenAccent, size: 24),
              const SizedBox(width: 8),
              Text(_currentCity,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
          Text("$_currentState, India",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.update, color: Colors.greenAccent, size: 12),
              const SizedBox(width: 4),
              Text('${t['updated'] ?? 'Updated'}: $updateTime',
                  style: const TextStyle(
                      color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNotificationToggle(),
              const SizedBox(width: 12),
              _buildShareButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    final t = ref.read(translationsProvider);
    final box = Hive.box('settings');
    final isEnabled = box.get('fuel_notifications', defaultValue: true);

    return Container(
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
          Text(t['price_alerts'] ?? 'Price Alerts', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                  if (val) {
                    await NotificationService.subscribeToTopic('fuel_prices_update');
                  } else {
                    await NotificationService.unsubscribeFromTopic('fuel_prices_update');
                  }
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildShareButton() {
    final t = ref.read(translationsProvider);
    return GestureDetector(
      onTap: _shareFuelPrices,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.share, color: Colors.greenAccent, size: 12),
            const SizedBox(width: 6),
            Text(
              t['share'] ?? 'Share',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _shareFuelPrices() {
    String updateTime = "Updating...";
    if (_fuelData['updated_at'] != null) {
      updateTime = DateFormat('dd MMM yyyy, hh:mm a').format(
        DateTime.parse(_fuelData['updated_at']).toLocal(),
      );
    }

    final petrol = _fuelData['petrol'] != null ? '₹${_fuelData['petrol']}/Ltr' : 'N/A';
    final diesel = _fuelData['diesel'] != null ? '₹${_fuelData['diesel']}/Ltr' : 'N/A';
    final cng = _fuelData['cng'] != null ? '₹${_fuelData['cng']}/Kg' : 'N/A';
    final png = _fuelData['png'] != null ? '₹${_fuelData['png']}/SCM' : 'N/A';
    final lpg = _fuelData['lpg'] != null ? '₹${_fuelData['lpg']}/14.2kg' : 'N/A';
    final commLpg = _fuelData['commercial_lpg'] != null ? '₹${_fuelData['commercial_lpg']}/19kg' : 'N/A';

    final buffer = StringBuffer();
    buffer.writeln('⛽ *BharatFlow - Live Fuel & Gas Prices* ⛽\n');
    buffer.writeln('📍 *City:* $_currentCity, $_currentState');
    buffer.writeln('📅 *Updated:* $updateTime\n');
    buffer.writeln('🔸 *Petrol:* $petrol');
    buffer.writeln('🔸 *Diesel:* $diesel');
    buffer.writeln('🔸 *CNG:* $cng');
    buffer.writeln('🔸 *PNG:* $png');
    buffer.writeln('🔸 *LPG (Domestic):* $lpg');
    buffer.writeln('🔸 *Commercial LPG:* $commLpg\n');
    buffer.writeln('📲 Download *BharatFlow App* for live fuel prices, mandi rates & weather alerts:');
    buffer.writeln('https://play.google.com/store/apps/details?id=com.BharatFlow');

    ShareManager.share(context, buffer.toString(), subject: 'Live Fuel Prices in $_currentCity - BharatFlow');
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
                      ? "PNG is ₹$savings/unit cheaper than LPG!"
                      : "LPG is ₹$savings/unit cheaper than PNG!",
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
    final t = ref.read(translationsProvider);
    String key = type.toLowerCase();
    if (type.contains('Commercial')) key = 'commercial_lpg';
    if (type.contains('Domestic')) key = 'lpg';

    double? currentVal = double.tryParse(val?.toString() ?? '');
    double? prevVal;
    
    for (var h in _historyData) {
      final hVal = double.tryParse(h[key]?.toString() ?? '');
      if (hVal != null && currentVal != null && hVal != currentVal) {
        prevVal = hVal;
        break;
      }
    }

    Widget trendWidget = Text(t['stable'] ?? 'Live Rate', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600));
    
    if (currentVal != null && prevVal != null && prevVal > 0) {
      double diff = currentVal - prevVal;
      double pct = (diff / prevVal) * 100;
      bool isUp = diff > 0;
      Color trendColor = isUp ? Colors.red : Colors.green;
      IconData trendIcon = isUp ? Icons.arrow_upward : Icons.arrow_downward;
      
      trendWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 14, color: trendColor),
          const SizedBox(width: 2),
          Text(
            '${pct.abs().toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 14, color: trendColor, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (_historyData.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => FuelHistoryScreen(
                  fuelType: key,
                  city: _currentCity,
                  history: _historyData,
                  themeColor: color)));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    type.replaceAll(' (Domestic)', ''), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text("₹${val ?? '...'}", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 3),
            trendWidget,
            const SizedBox(height: 3),
            Text(unit, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterInfo() {
    final t = ref.read(translationsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(t['data_source'] ?? 'Data Sources',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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