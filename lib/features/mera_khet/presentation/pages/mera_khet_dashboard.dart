import 'package:bharat_flow/features/dashboard/presentation/screens/weather_impact_screen.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:bharat_flow/core/services/notification_service.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';
import 'package:bharat_flow/core/providers/location_provider.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'mera_khet_home.dart';
class MeraKhetDashboard extends ConsumerStatefulWidget {
  final String farmId;
  const MeraKhetDashboard({Key? key, required this.farmId}) : super(key: key);

  @override
  ConsumerState<MeraKhetDashboard> createState() => _MeraKhetDashboardState();
}

class _MeraKhetDashboardState extends ConsumerState<MeraKhetDashboard> with TickerProviderStateMixin {
  bool _isPremiumUnlocked = false;

  double _farmArea = 5.2;
  String _areaUnit = 'Acres';

  // Weather State Variables
  bool _isLoadingWeather = true;
  String _weatherError = '';
  String _currentTemp = '--';
  String _currentWeatherDesc = '--';
  String _currentHigh = '--';
  String _currentLow = '--';
  String _currentWind = '--';
  String _currentHumidity = '--';
  String _currentRainMM = '--';
  String _sunriseTime = '--';
  String _sunsetTime = '--';
  String _displayLocationName = 'My Farm';
  bool _isSpecificFarm = false;
  DateTime? _weatherLastUpdated;
  List<Map<String, dynamic>> _forecastList = [];
  List<Map<String, dynamic>> _crops = [
    {'name': 'Wheat', 'area': 3.0},
    {'name': 'Mustard', 'area': 2.2},
  ];

  List<String> _allCrops = [];
  late AnimationController _sunController;

  // Satellite Scanning State
  Map<String, bool> _isSatelliteDataUnlocked = {};
  Map<String, bool> _isScanningSatellite = {};
  Map<String, int> _satelliteMoistureResult = {};
  Map<String, DateTime> _satelliteScanTime = {};

  @override
  void initState() {
    super.initState();
    _migrateOldFarmsToCropPatches();
    _sunController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _checkPremiumStatus();
    _loadCrops();
    _fetchWeatherData();
  }

  void _migrateOldFarmsToCropPatches() {
    final box = Hive.box('settings');
    List<dynamic> farms = box.get('saved_farms_list', defaultValue: []) as List<dynamic>;
    List<dynamic> cropPatches = box.get('saved_crop_patches', defaultValue: []) as List<dynamic>;

    if (farms.isNotEmpty) {
      for (var farm in farms) {
        final farmMap = Map<String, dynamic>.from(farm);
        final List<dynamic> crops = farmMap['crops'] ?? [];
        
        // If farm has crops, create a patch for each crop
        if (crops.isNotEmpty) {
          for (var crop in crops) {
            final cropMap = Map<String, dynamic>.from(crop);
            cropPatches.add({
              'id': 'patch_${DateTime.now().microsecondsSinceEpoch}',
              'cropName': cropMap['name'] ?? 'Unknown',
              'sowingDate': DateTime.now().toIso8601String(), // default to now
              'area': cropMap['area'] ?? farmMap['area'] ?? 0.0,
              'points': farmMap['points'],
              'locationName': farmMap['name'] ?? 'Migrated Farm',
            });
          }
        } else {
          // Farm with no crops
          cropPatches.add({
            'id': 'patch_${DateTime.now().microsecondsSinceEpoch}',
            'cropName': 'Migrated Crop',
            'sowingDate': DateTime.now().toIso8601String(),
            'area': farmMap['area'] ?? 0.0,
            'points': farmMap['points'],
            'locationName': farmMap['name'] ?? 'Migrated Farm',
          });
        }
      }
      // Clear old farms
      box.put('saved_farms_list', []);
      box.put('saved_crop_patches', cropPatches);
    }
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = '';
    });

    try {
      final box = Hive.box('settings');
      final farms = box.get('saved_farms_list', defaultValue: []) as List<dynamic>;
      
      double? lat;
      double? lng;
      
      String locName = 'My Location';
      for (var f in farms) {
        if ((f as Map)['id'] == widget.farmId) {
          final points = f['points'];
          if (points != null && points.isNotEmpty) {
            lat = points[0]['lat'];
            lng = points[0]['lng'];
            _isSpecificFarm = true;
          }
          break;
        }
      }

      // If no farm is selected or farm has no points, fetch LIVE location
      if (lat == null || lng == null) {
        _isSpecificFarm = false;
        try {
          Position? position = await Geolocator.getLastKnownPosition();
          position ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 3),
          );
          lat = position.latitude;
          lng = position.longitude;
        } catch (e) {
          lat = 20.5937; // Default India
          lng = 78.9629;
        }
      }

      // Reverse geocode to get exact Area/Society and City name
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat!, lng!);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          String area = place.subLocality ?? '';
          String city = place.locality ?? '';
          
          if (area.isNotEmpty && city.isNotEmpty && area != city) {
            locName = '$area, $city';
          } else if (city.isNotEmpty) {
            locName = city;
          } else if (area.isNotEmpty) {
            locName = area;
          } else {
            locName = place.name ?? 'My Farm';
          }
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }

      _displayLocationName = locName;

      // 1. Try to fetch from Supabase (15 KM Radius)
      final supabase = Supabase.instance.client;
      Map<String, dynamic>? cachedData;
      
      try {
        final closeRecords = await supabase
            .from('india_weather_data')
            .select()
            .gte('latitude', lat - 0.135)
            .lte('latitude', lat + 0.135)
            .gte('longitude', lng - 0.135)
            .lte('longitude', lng + 0.135)
            .order('updated_at', ascending: false)
            .limit(1);

        if (closeRecords != null && (closeRecords as List).isNotEmpty) {
          final record = closeRecords.first as Map<String, dynamic>;
          final updatedAt = DateTime.parse(record['updated_at']);
          // Check if it's recent (less than 6 hours old)
          if (DateTime.now().difference(updatedAt).inHours < 6) {
            cachedData = record;
            debugPrint('✅ Loaded Weather from Supabase for $locName (VPS Cache Hit)');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Supabase Weather Fetch Error: $e');
      }

      if (cachedData != null) {
        // PARSE FROM SUPABASE
        final temp = (cachedData['temperature'] as num?)?.toDouble() ?? 0.0;
        final wind = (cachedData['wind_speed'] as num?)?.toDouble() ?? 0.0;
        final rain = (cachedData['precipitation_1h'] as num?)?.toDouble() ?? 0.0;
        
        _currentTemp = temp.round().toString();
        _currentWind = '${wind.round()} km/h';
        _currentRainMM = '$rain mm';
        _currentHumidity = '55%'; // Default fallback if missing in DB
        
        _sunriseTime = _formatTime(cachedData['sunrise'] ?? '2023-01-01T06:00');
        _sunsetTime = _formatTime(cachedData['sunset'] ?? '2023-01-01T18:00');
        _weatherLastUpdated = DateTime.parse(cachedData['updated_at']);
        
        final dailyRaw = cachedData['forecast_14d'];
        if (dailyRaw is Map<String, dynamic>) {
          final times = dailyRaw['time'] as List? ?? [];
          _forecastList.clear();
          
          for (int i = 0; i < times.length && i < 15; i++) {
            _forecastList.add({
              'date': times[i],
              'max': (dailyRaw['temperature_2m_max'][i] as num?)?.round() ?? 0,
              'min': (dailyRaw['temperature_2m_min'][i] as num?)?.round() ?? 0,
              'rain_prob': (dailyRaw['precipitation_probability_max']?[i] as num?)?.round() ?? 0,
              'code': dailyRaw['weather_code']?[i] ?? 0
            });
          }
          if (_forecastList.isNotEmpty) {
            _currentHigh = _forecastList[0]['max'].toString();
            _currentLow = _forecastList[0]['min'].toString();
            _currentWeatherDesc = _getWeatherDescription(_forecastList[0]['code']);
          }
        }
      } else {
        // 2. Fetch from Open-Meteo (Cache Miss)
        final url = Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=${lat!}&longitude=${lng!}&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max&timezone=auto&forecast_days=16');
        
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          final current = data['current'];
          final daily = data['daily'];
          
          _currentTemp = current['temperature_2m'].round().toString();
          _currentHumidity = current['relative_humidity_2m'].round().toString() + '%';
          _currentRainMM = current['precipitation'].toString() + ' mm';
          _currentWind = current['wind_speed_10m'].round().toString() + ' km/h';
          
          final code = current['weather_code'];
          _currentWeatherDesc = _getWeatherDescription(code);
          
          _currentHigh = daily['temperature_2m_max'][0].round().toString();
          _currentLow = daily['temperature_2m_min'][0].round().toString();
          
          String sunriseStr = daily['sunrise'][0];
          String sunsetStr = daily['sunset'][0];
          _sunriseTime = _formatTime(sunriseStr);
          _sunsetTime = _formatTime(sunsetStr);
          
          _weatherLastUpdated = DateTime.now();

          _forecastList.clear();
          for (int i = 1; i <= 15 && i < (daily['time'] as List).length; i++) {
            _forecastList.add({
              'date': daily['time'][i],
              'max': daily['temperature_2m_max'][i].round(),
              'min': daily['temperature_2m_min'][i].round(),
              'rain_prob': daily['precipitation_probability_max'][i],
              'code': daily['weather_code'][i]
            });
          }

          // 3. Upsert newly fetched data to Supabase
          try {
            await supabase.from('india_weather_data').upsert({
              'location_name': locName,
              'latitude': lat!,
              'longitude': lng!,
              'temperature': current['temperature_2m'],
              'precipitation_1h': current['precipitation'],
              'wind_speed': current['wind_speed_10m'],
              'sunrise': sunriseStr,
              'sunset': sunsetStr,
              'forecast_14d': daily,
              'updated_at': DateTime.now().toIso8601String(),
            });
            debugPrint('✅ Weather Upserted to Supabase VPS successfully');
          } catch (e) {
            debugPrint('⚠️ Auto-Registration Failed: $e');
          }
        } else {
          _weatherError = 'Failed to fetch weather data';
        }
      }
    } catch (e) {
      _weatherError = 'Network error: $e';
    }

    if (mounted) {
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      int h = dt.hour;
      int m = dt.minute;
      String ampm = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '$h:${m.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '--:--';
    }
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1 || code == 2 || code == 3) return 'Partly Cloudy';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Raining';
    if (code >= 71 && code <= 77) return 'Snowing';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Unknown';
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code == 1 || code == 2 || code == 3) return Icons.cloud;
    if (code >= 51 && code <= 67) return Icons.cloudy_snowing;
    if (code >= 80 && code <= 82) return Icons.cloudy_snowing;
    if (code >= 95) return Icons.thunderstorm;
    return Icons.wb_cloudy;
  }


  String _getUpdatedTimeAgo() {
    if (_weatherLastUpdated == null) return 'now';
    final diff = DateTime.now().difference(_weatherLastUpdated!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  void dispose() {
    _sunController.dispose();
    super.dispose();
  }

  void _checkPremiumStatus() {
    final box = Hive.box('settings');
    final expiryStr = box.get('mera_khet_premium_expiry');
    if (expiryStr != null) {
      final expiryTime = DateTime.tryParse(expiryStr);
      if (expiryTime != null && DateTime.now().isBefore(expiryTime)) {
        _isPremiumUnlocked = true;
      }
    }
  }

  List<Map<String, dynamic>> _cropCalendarData = [];

  Future<void> _loadCrops() async {
    try {
      final jsonStr = await DefaultAssetBundle.of(context).loadString('assets/data/india_crop_calendar_master.json');
      final List<dynamic> data = json.decode(jsonStr);
      _cropCalendarData = List<Map<String, dynamic>>.from(data);
      
      final Set<String> uniqueCrops = {};
      for (var item in data) {
        if (item['Crop'] != null) {
          uniqueCrops.add(item['Crop'].toString().trim());
        }
      }

      // Add Mandi products
      try {
        final repo = MandiRepository();
        final mandiCrops = await repo.fetchAllCommodityNames();
        uniqueCrops.addAll(mandiCrops);
      } catch (e) {
        debugPrint("Error loading mandi crops: $e");
      }

      setState(() {
        _allCrops = uniqueCrops.toList()..sort();
      });
    } catch (e) {
      debugPrint("Error loading crops: $e");
    }
  }

  void _showAdToUnlock() {
    AdmobService.showRewardConfirmationDialog(context, () {
      if (mounted) {
        setState(() {
        });
        final box = Hive.box('settings');
        box.put('mera_khet_premium_expiry', DateTime.now().add(const Duration(hours: 24)).toIso8601String());
      }
    });
  }

  Future<void> _scanSatelliteSoilMoisture(String patchId, List<dynamic> points) async {
    // 1. Show Ad First
    AdmobService.showRewardConfirmationDialog(context, () async {
      if (mounted) {
        setState(() {
          _isScanningSatellite[patchId] = true;
        });

        // 2. Call our Oracle VPS Python API
        try {
          // Pointing to the live Oracle VPS
          final url = Uri.parse('http://92.4.66.182:8000/scan-soil-moisture');
          
          final body = json.encode({
            "crop_id": patchId,
            "points": points.isEmpty ? [{"lat": 23.0, "lng": 72.0}, {"lat": 23.01, "lng": 72.0}, {"lat": 23.0, "lng": 72.01}] : points
          });

          final response = await http.post(
            url, 
            headers: {"Content-Type": "application/json"},
            body: body
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (mounted) {
              setState(() {
                _satelliteMoistureResult[patchId] = data['soil_moisture_percentage'] ?? data['moisture_percentage'];
                _satelliteScanTime[patchId] = DateTime.now();
                _isSatelliteDataUnlocked[patchId] = true;
                _isScanningSatellite[patchId] = false;
              });
            }
          } else {
            throw Exception('API Error');
          }
        } catch (e) {
          // Fallback to mock data if VPS is unreachable or not configured yet
          debugPrint("VPS Error: $e. Falling back to mock calculation.");
          await Future.delayed(const Duration(seconds: 3)); // simulate processing
          if (mounted) {
            setState(() {
              _satelliteMoistureResult[patchId] = 42; // Mock value
              _satelliteScanTime[patchId] = DateTime.now();
              _isSatelliteDataUnlocked[patchId] = true;
              _isScanningSatellite[patchId] = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Warning: VPS unreachable. Showing offline estimated data.'))
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(t['farm_insights'] ?? 'Farm Insights', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: t['weather_tab'] ?? 'Weather'),
              Tab(text: t['my_farms_tab'] ?? 'My Farms'),
              Tab(text: t['diary_fertilizer_tab'] ?? 'Diary & Fertilizer'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildWeatherTab(),
            _buildMyFarmsTab(t),
            _buildDiaryTab(t),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherTab() {
    return const WeatherImpactScreen(isEmbedded: true);
  }



  Widget _buildTodaysWeatherCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], 
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0072FF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _displayLocationName, 
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.update, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(_weatherLastUpdated != null ? 'Updated ${_getUpdatedTimeAgo()}' : 'Updating...', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_currentTemp, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
                            const Padding(
                              padding: EdgeInsets.only(top: 6.0),
                              child: Text('°C', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_currentWeatherDesc, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('H: $_currentHigh°   L: $_currentLow°', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Animated Sun
                    RotationTransition(
                      turns: _sunController,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 20, spreadRadius: 5)
                          ]
                        ),
                        child: const Icon(Icons.wb_sunny, color: Colors.amber, size: 60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Glassmorphism Stats Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _WeatherStat(icon: Icons.air, label: 'Wind', value: _currentWind),
                          _WeatherStat(icon: Icons.opacity, label: 'Humidity', value: _currentHumidity),
                          _WeatherStat(icon: Icons.cloudy_snowing, label: 'Rain', value: _currentRainMM),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Colors.white.withOpacity(0.3), height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _WeatherStat(icon: Icons.wb_twilight, label: 'Sunrise', value: _sunriseTime),
                          _WeatherStat(icon: Icons.nights_stay, label: 'Sunset', value: _sunsetTime),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyForecastCard(int index) {
    if (index >= _forecastList.length) return const SizedBox.shrink();
    final data = _forecastList[index];
    
    final date = DateTime.parse(data['date']);
    final dateStr = '${date.day} ${_getMonth(date.month)}';
    
    final temp = data['max'];
    final tempMin = data['min'];
    final rainChance = data['rain_prob'];
    final icon = _getWeatherIcon(data['code']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 70,
            child: Text(dateStr, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Icon(icon, color: rainChance > 30 ? Colors.blue : Colors.amber, size: 28),
          SizedBox(
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$temp°', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('$tempMin°', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.cloudy_snowing, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text('$rainChance%', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Map<String, dynamic> _getFertilizerNeeds(String cropName, double area, String unit) {
    double areaInAcres = area;
    if (unit == 'Hectares') areaInAcres = area * 2.471;
    if (unit == 'Bigha') areaInAcres = area * 0.625;

    String cropLower = cropName.toLowerCase();
    
    // Default fallback (Generic crops)
    double ureaPerAcre = 40.0;
    double dapPerAcre = 20.0;
    double potashPerAcre = 10.0;

    if (cropLower.contains('wheat') || cropLower.contains('gehu')) {
      ureaPerAcre = 60.0; dapPerAcre = 25.0; potashPerAcre = 15.0;
    } else if (cropLower.contains('rice') || cropLower.contains('paddy') || cropLower.contains('chawal')) {
      ureaPerAcre = 80.0; dapPerAcre = 30.0; potashPerAcre = 20.0;
    } else if (cropLower.contains('cotton') || cropLower.contains('kapas')) {
      ureaPerAcre = 50.0; dapPerAcre = 25.0; potashPerAcre = 25.0;
    } else if (cropLower.contains('mango') || cropLower.contains('aam')) {
      ureaPerAcre = 100.0; dapPerAcre = 50.0; potashPerAcre = 50.0; 
    } else if (cropLower.contains('sugarcane') || cropLower.contains('ganna')) {
      ureaPerAcre = 120.0; dapPerAcre = 40.0; potashPerAcre = 30.0;
    } else if (cropLower.contains('chana') || cropLower.contains('gram')) {
      ureaPerAcre = 10.0; dapPerAcre = 20.0; potashPerAcre = 0.0; // Legumes need less N
    }

    return {
      'urea': (ureaPerAcre * areaInAcres),
      'dap': (dapPerAcre * areaInAcres),
      'potash': (potashPerAcre * areaInAcres),
    };
  }

  Widget _buildMyFarmsTab(Map<String, String> t) {
    final box = Hive.box('settings');
    final cropPatches = box.get('saved_crop_patches', defaultValue: []) as List<dynamic>;

    double totalAcres = 0;
    for (var patch in cropPatches) {
      final p = Map<String, dynamic>.from(patch);
      final area = p['area'] ?? 0.0;
      final unit = p['areaUnit'] ?? 'Acres';
      if (unit == 'Hectares') {
        totalAcres += area * 2.471;
      } else if (unit == 'Bigha') {
        totalAcres += area * 0.625;
      } else {
        totalAcres += area;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t['my_farms_tab'] ?? 'Manage Crops', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () {
                _showAddCropBottomSheet();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(t['add_transaction'] ?? 'Add Crop'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
            )
          ],
        ),
        if (cropPatches.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200)
            ),
            child: Row(
              children: [
                const Icon(Icons.landscape, color: Colors.green),
                const SizedBox(width: 8),
                Text('${t['farm_area_label'] ?? 'Total Farm Size'}: ${totalAcres.toStringAsFixed(2)} ${t['acres'] ?? 'Acres'}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (cropPatches.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.landscape, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(t['no_products_found'] ?? 'No crops added yet.', style: const TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          )
        else
          ...cropPatches.map((patch) {
            final patchData = Map<String, dynamic>.from(patch);
            return _buildCropPatchDetailsRichCard(patchData, t);
          }).toList(),
      ],
    );
  }

  Widget _buildCropPatchDetailsRichCard(Map<String, dynamic> patchData, Map<String, String> t) {
    final patchId = patchData['id'] ?? 'unknown';
    final points = patchData['points'] ?? [];
    
    final bool isUnlocked = _isSatelliteDataUnlocked[patchId] ?? false;
    final bool isScanning = _isScanningSatellite[patchId] ?? false;
    final int? moistureResult = _satelliteMoistureResult[patchId];
    final DateTime? scanTime = _satelliteScanTime[patchId];
    
    final cropName = patchData['cropName'] ?? 'Unknown Crop';
    final sowingDateStr = patchData['sowingDate'] ?? DateTime.now().toIso8601String();
    final sowingDate = DateTime.tryParse(sowingDateStr) ?? DateTime.now();
    final area = patchData['area'] ?? 0.0;
    final areaUnit = patchData['areaUnit'] ?? 'Acres';
    
    // Find crop data from JSON
    Map<String, dynamic>? cropInfo;
    for (var info in _cropCalendarData) {
      if (info['Crop'].toString().toLowerCase().contains(cropName.toLowerCase())) {
        cropInfo = info;
        break; // take first match
      }
    }

    final sowMonths = cropInfo?['Sowing'] ?? 'Unknown';
    final harvestMonths = cropInfo?['Harvesting'] ?? 'Unknown';
    final cropCycle = cropInfo?['Duration'] ?? 'Unknown';
    final season = cropInfo?['Season'] ?? 'Unknown';

    final ageInDays = DateTime.now().difference(sowingDate).inDays;
    
    // Calculate exact harvest date
    String exactHarvestDateStr = 'Unknown';
    if (cropCycle.toString().toLowerCase().contains('perennial')) {
      exactHarvestDateStr = 'Year-round';
    } else {
      final match = RegExp(r'\d+').firstMatch(cropCycle.toString());
      if (match != null) {
        int days = int.parse(match.group(0)!);
        DateTime harvestDate = sowingDate.add(Duration(days: days));
        exactHarvestDateStr = '${harvestDate.day} ${_getMonth(harvestDate.month)} ${harvestDate.year}';
      }
    }

    // AI Risk Logic (Smart Crop Categorizer Engine)
    bool isRisk = false;
    String riskMsg = 'Stable weather conditions. Good for crop growth.';
    
    final String cNameLower = cropName.toLowerCase();
    final String cCategory = (cropInfo?['Category']?.toString() ?? '').toLowerCase();

    // 1. Water Loving (Needs standing water / tolerant to heavy rain)
    final bool isWaterLoving = cCategory.contains('sugar') || cNameLower.contains('paddy') || cNameLower.contains('rice') || cNameLower.contains('sugarcane');
    
    // 2. Rain Sensitive (Extremely sensitive to rain, especially at harvest)
    final bool isRainSensitive = cCategory.contains('fiber') || cCategory.contains('oilseed') || cCategory.contains('pulse') || cCategory.contains('spices') || 
                                 cNameLower.contains('cotton') || cNameLower.contains('kapas') || cNameLower.contains('mustard') || cNameLower.contains('chana') || 
                                 cNameLower.contains('gram') || cNameLower.contains('onion') || cNameLower.contains('chilli') || cNameLower.contains('soybean') || 
                                 cNameLower.contains('groundnut') || cNameLower.contains('moong') || cNameLower.contains('urad');

    // 3. Heat Sensitive (Requires frequent watering in extreme heat)
    final bool isHeatSensitive = cCategory.contains('vegetable') || cCategory.contains('fruit') || cNameLower.contains('tomato') || cNameLower.contains('potato');

    if (_forecastList.isNotEmpty) {
      final todayMax = _forecastList[0]['max'] as int;
      final todayRain = _forecastList[0]['rain_prob'] as int;
      
      // Rule 1: Young Seedling Risk (0-15 days)
      if (todayRain > 60 && ageInDays < 15) {
        if (!isWaterLoving) {
          isRisk = true;
          riskMsg = 'Heavy rain predicted. High risk of seed wash-off since $cropName is only $ageInDays days old.';
        } else {
          riskMsg = 'Heavy rain predicted. Good for young $cropName seedlings.';
        }
      } 
      // Rule 2: Heat Stress
      else if (todayMax > 40) {
        if (isHeatSensitive) {
          isRisk = true;
          riskMsg = 'CRITICAL: High temperature ($todayMax°C) detected. $cropName is heat-sensitive. Ensure immediate irrigation or shade nets!';
        } else {
          isRisk = true;
          riskMsg = 'High temperature ($todayMax°C) detected. Ensure adequate irrigation to prevent heat stress for $cropName.';
        }
      } 
      // Rule 3: Harvest Stage Risk
      else if (todayRain > 70 && ageInDays > 80) {
        if (isRainSensitive) {
          isRisk = true;
          riskMsg = 'CRITICAL: Heavy rain predicted near harvest stage. High risk of $cropName damage. Harvest early if possible!';
        } else if (!isWaterLoving) {
          isRisk = true;
          riskMsg = 'Heavy rain predicted near harvest stage. Keep drainage clear for $cropName.';
        }
      } 
      // Rule 4: Drought / Dry Spell Risk
      else if (todayRain < 10 && todayMax > 35 && ageInDays > 20 && ageInDays < 60) {
        if (isWaterLoving) {
          isRisk = true;
          riskMsg = 'Dry spell & high heat. $cropName needs standing water, ensure immediate irrigation.';
        }
      } 
      // Pre-sowing
      else if (ageInDays < 0) {
        riskMsg = 'Scheduled for sowing on ${sowingDate.day}/${sowingDate.month}. Conditions look favorable.';
      }
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.shade200, shape: BoxShape.circle),
                      child: const Icon(Icons.eco, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cropName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                        Text('${area.toStringAsFixed(2)} ${t[areaUnit.toLowerCase()] ?? areaUnit} • ${t['sown'] ?? 'Sown'} ${sowingDate.day}/${sowingDate.month}/${sowingDate.year}', style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditCropBottomSheet(patchData);
                    } else if (val == 'delete') {
                      _deleteCropPatch(patchData['id']);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Crop Details', style: TextStyle(color: Colors.blue))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Crop Map', style: TextStyle(color: Colors.red))),
                  ],
                )
              ],
            ),
          ),
          
          // AI Risk Scan Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Text(t['smart_fertilizer_schedule'] ?? '14-DAY AI RISK SCAN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: LanguageHelper.translate(riskMsg, ref.read(locationProvider).state ?? '', ref.read(locationProvider).city ?? ''),
                  builder: (context, snapshot) => Text(
                    '🌱 ${t['sowing_on'] ?? 'Sowing on'} ${sowingDate.day} ${_getMonth(sowingDate.month)}: ${snapshot.data ?? riskMsg}',
                    style: TextStyle(color: isRisk ? Colors.red.shade800 : Colors.green.shade800, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 5-Day Timeline
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t['crop_cycle'] ?? 'DAILY FORECAST RISK TIMELINE', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(t['open_caps'] ?? 'Safe to Work ✅', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    if (index >= _forecastList.length) return const SizedBox.shrink();
                    final f = _forecastList[index];
                    final fDate = DateTime.parse(f['date']);
                    final isRainy = (f['rain_prob'] as int) > 50;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                        decoration: BoxDecoration(
                          color: isRainy ? Colors.red.shade50 : Colors.green.shade50,
                          border: Border.all(color: isRainy ? Colors.red.shade200 : Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      child: Column(
                        children: [
                          Text('${t['days_old'] ?? 'Day'} ${index+1}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          Text('${fDate.day} ${_getMonth(fDate.month)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Icon(isRainy ? Icons.warning : Icons.check_circle, size: 14, color: isRainy ? Colors.red : Colors.green),
                        ],
                      ),
                      ),
                    );
                  }),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),

                // Satellite Soil Moisture Section
                Row(
                  children: [
                    const Icon(Icons.satellite_alt, color: Colors.blue, size: 16),
                    const SizedBox(width: 6),
                    Text(t['current_soil_moisture'] ?? 'SATELLITE SOIL MOISTURE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isUnlocked && !isScanning)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _scanSatelliteSoilMoisture(patchId, points),
                      icon: const Icon(Icons.play_circle_fill),
                      label: Text(t['watch_video'] ?? 'Watch Ad to Scan Soil Moisture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)
                      ),
                    ),
                  )
                else if (isScanning)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.blue),
                  ))
                else if (moistureResult != null)
                  (() {
                    int minOptimal = 40;
                    int maxOptimal = 75;
                    final cLower = cropName.toLowerCase();
                    final cCategory = (cropInfo?['Category']?.toString() ?? '').toLowerCase();

                    if (cLower.contains('rice') || cLower.contains('paddy') || cLower.contains('sugarcane') || cCategory.contains('sugar')) { minOptimal = 70; maxOptimal = 100; }
                    else if (cCategory.contains('vegetable') || cCategory.contains('fruit') || cLower.contains('wheat')) { minOptimal = 50; maxOptimal = 80; }
                    else if (cCategory.contains('fiber') || cCategory.contains('oilseed') || cCategory.contains('pulse') || cCategory.contains('spices') || cCategory.contains('cereal')) { minOptimal = 30; maxOptimal = 60; }
                    
                    String statusText = 'Optimal';
                    Color statusColor = Colors.green;
                    IconData statusIcon = Icons.check_circle;
                    if (moistureResult < minOptimal - 5) {
                      int diff = minOptimal - moistureResult;
                      statusText = 'Low Moisture: $diff% below target. Needs watering.';
                      statusColor = Colors.orangeAccent;
                      statusIcon = Icons.water_drop;
                    } else if (moistureResult < minOptimal) {
                      int diff = minOptimal - moistureResult;
                      statusText = 'Acceptable: $diff% below optimal. No urgent watering.';
                      statusColor = Colors.lightGreenAccent;
                      statusIcon = Icons.check_circle_outline;
                    } else if (moistureResult > maxOptimal + 5) {
                      int diff = moistureResult - maxOptimal;
                      statusText = 'High Moisture: $diff% above target. Hold watering.';
                      statusColor = Colors.blueAccent;
                      statusIcon = Icons.water_damage;
                    } else if (moistureResult > maxOptimal) {
                      int diff = moistureResult - maxOptimal;
                      statusText = 'Acceptable: $diff% above optimal. No urgent action.';
                      statusColor = Colors.lightGreenAccent;
                      statusIcon = Icons.check_circle_outline;
                    } else {
                      statusText = 'Optimal Moisture: Perfect for this crop.';
                      statusColor = Colors.greenAccent;
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black, // Pure Black Background
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                          BoxShadow(color: Colors.cyan.withOpacity(0.1), blurRadius: 30, spreadRadius: 5), // Glow
                        ]
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t['current_soil_moisture'] ?? 'Satellite Soil Moisture',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.info_outline, color: Colors.cyanAccent.withOpacity(0.7), size: 24),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Soil Moisture Info', style: TextStyle(fontWeight: FontWeight.bold)),
                                      content: const Text('This index is calculated using Sentinel-1 radar satellite data. It shows the real-time volumetric water content in your farm\'s soil, helping you make smart irrigation decisions.'),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Got it!'),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          // Legend removed to match the reference image's minimalistic look
                          SizedBox(
                            height: 130, // Dramatically reduced layout height to pull bottom elements up
                            child: SfRadialGauge(
                              axes: <RadialAxis>[
                                RadialAxis(
                                  centerY: 0.8, // Center is near bottom
                                  showLabels: true,
                                  showTicks: true,
                                  labelsPosition: ElementsPosition.inside,
                                  ticksPosition: ElementsPosition.inside,
                                  tickOffset: 5,
                                  labelOffset: 15,
                                  minimum: 0,
                                  maximum: 100,
                                  interval: 20,
                                  axisLabelStyle: const GaugeTextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  majorTickStyle: const MajorTickStyle(color: Colors.white, length: 15, thickness: 2),
                                  minorTicksPerInterval: 0,
                                  startAngle: 180,
                                  endAngle: 0,
                                  radiusFactor: 1.35, // Renders the gauge 35% larger, eating up the top gap without changing layout
                                  axisLineStyle: const AxisLineStyle(
                                    thickness: 0.1,
                                    color: Colors.transparent, // Handled by GaugeRange
                                    thicknessUnit: GaugeSizeUnit.factor,
                                  ),
                                  ranges: <GaugeRange>[
                                    GaugeRange(
                                      startValue: 0,
                                      endValue: 100,
                                      startWidth: 0.1,
                                      endWidth: 0.1,
                                      sizeUnit: GaugeSizeUnit.factor,
                                      gradient: const SweepGradient(colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red]),
                                    )
                                  ],
                                  pointers: <GaugePointer>[
                                    NeedlePointer(
                                      value: moistureResult?.toDouble() ?? 0,
                                      needleStartWidth: 2,
                                      needleEndWidth: 8,
                                      needleLength: 0.9,
                                      needleColor: Colors.red,
                                      enableAnimation: true,
                                      knobStyle: const KnobStyle(
                                        knobRadius: 0.1,
                                        borderColor: Colors.grey,
                                        borderWidth: 0.05,
                                        color: Colors.black,
                                      ),
                                      tailStyle: const TailStyle(
                                        color: Colors.red,
                                        width: 8,
                                        length: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${moistureResult}%',
                            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.cyanAccent),
                          ),
                          Text(
                            t['current_soil_moisture'] ?? 'Current Soil Moisture',
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          if (scanTime != null) Builder(
                            builder: (context) {
                              final localTime = scanTime.toLocal();
                              int hour = localTime.hour;
                              String amPm = hour >= 12 ? 'PM' : 'AM';
                              if (hour > 12) hour -= 12;
                              if (hour == 0) hour = 12;
                              return Column(
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.white54, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${t['updated'] ?? 'Last Updated'}: ${localTime.day}/${localTime.month}/${localTime.year} at $hour:${localTime.minute.toString().padLeft(2, '0')} $amPm',
                                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  statusIcon,
                                  color: statusColor,
                                  size: 20
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    statusText,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  })(),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),

                // Crop Details Grid
                Row(
                  children: [
                    Expanded(child: _buildTranslatedDetailRow(Icons.calendar_month, t['sow_months'] ?? 'Sow Months', sowMonths, ref.read(locationProvider).state ?? '', ref.read(locationProvider).city ?? '')),
                    Expanded(child: _buildTranslatedDetailRow(Icons.timelapse, t['crop_cycle'] ?? 'Crop Cycle', cropCycle, ref.read(locationProvider).state ?? '', ref.read(locationProvider).city ?? '')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTranslatedDetailRow(Icons.agriculture, t['est_harvest_date'] ?? 'Est. Harvest Date', exactHarvestDateStr, ref.read(locationProvider).state ?? '', ref.read(locationProvider).city ?? '')),
                    Expanded(child: _buildTranslatedDetailRow(Icons.wb_sunny, t['season'] ?? 'Season', season, ref.read(locationProvider).state ?? '', ref.read(locationProvider).city ?? '')),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),

                // Real Fertilizer Schedule Section
                Row(
                  children: [
                    const Icon(Icons.science, color: Colors.purple, size: 16),
                    const SizedBox(width: 6),
                    Text(t['smart_fertilizer_schedule'] ?? 'SMART FERTILIZER SCHEDULE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                
                Builder(
                  builder: (context) {
                    final fNeeds = _getFertilizerNeeds(cropName, area, areaUnit);
                    final totalUrea = fNeeds['urea'] as double;
                    final totalDap = fNeeds['dap'] as double;
                    final totalPotash = fNeeds['potash'] as double;

                    // Timeline logic based on Sowing Date
                    final day20Date = sowingDate.add(const Duration(days: 20));
                    final day45Date = sowingDate.add(const Duration(days: 45));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t['total_requirement_for'] ?? 'Total Requirement for'} ${area.toStringAsFixed(2)} $areaUnit:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('${t['undo'] ?? 'Urea'}: ${totalUrea.toStringAsFixed(1)} KG | DAP: ${totalDap.toStringAsFixed(1)} KG | ${t['fruit_grain_potash'] ?? 'Potash'}: ${totalPotash.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 12),
                        
                        // Schedule List
                        _buildFertilizerTask(
                          t['sowing_time'] ?? 'Sowing Time', 
                          sowingDate, 
                          '${t['apply_npk_dose'] ?? 'Apply'} ${totalDap.toStringAsFixed(1)} KG DAP + ${(totalUrea * 0.25).toStringAsFixed(1)} KG Urea (Basal Dose)', t
                        ),
                        _buildFertilizerTask(
                          t['first_top_dressing'] ?? 'First Top Dressing (Day 20)', 
                          day20Date, 
                          '${t['apply_npk_dose'] ?? 'Apply'} ${(totalUrea * 0.35).toStringAsFixed(1)} KG Urea.', t
                        ),
                        _buildFertilizerTask(
                          t['second_top_dressing'] ?? 'Second Top Dressing (Day 45)', 
                          day45Date, 
                          '${t['apply_npk_dose'] ?? 'Apply'} ${(totalUrea * 0.40).toStringAsFixed(1)} KG Urea + ${totalPotash.toStringAsFixed(1)} KG Potash.', t
                        ),
                      ],
                    );
                  }
                ),

              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFertilizerTask(String title, DateTime date, String instruction, Map<String, String> t) {
    final daysDiff = date.difference(DateTime.now()).inDays;
    bool isPast = daysDiff < 0;
    bool isToday = daysDiff == 0;
    
    Color statusColor = isPast ? Colors.grey : (isToday ? Colors.red : Colors.green);
    String timeStr = isPast ? '${daysDiff.abs()} ${t['days_ago'] ?? 'days ago'}' : (isToday ? (t['today'] ?? 'Today') : '${t['all_time'] ?? 'In'} $daysDiff ${t['days'] ?? 'days'}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isPast ? Icons.check_circle : Icons.circle_outlined, color: statusColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isPast ? Colors.grey : Colors.black87)),
                const SizedBox(height: 2),
                Text(instruction, style: TextStyle(fontSize: 12, color: isPast ? Colors.grey : Colors.black87)),
                Text('${date.day}/${date.month}/${date.year} ($timeStr)', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        )
      ],
    );
  }

  Widget _buildTranslatedDetailRow(IconData icon, String label, String value, String userState, String userCity) {
    return FutureBuilder<String>(
      future: LanguageHelper.translate(value, userState, userCity),
      builder: (context, snapshot) {
        return Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(snapshot.data ?? value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        );
      }
    );
  }

  void _deleteCropPatch(String id) {
    final box = Hive.box('settings');
    List<dynamic> cropPatches = box.get('saved_crop_patches', defaultValue: []) as List<dynamic>;
    cropPatches.removeWhere((p) => p['id'] == id);
    box.put('saved_crop_patches', cropPatches);
    setState(() {});
  }

  void _showEditCropBottomSheet(Map<String, dynamic> patchData) {
    final t = ref.read(translationsProvider);
    TextEditingController cropNameController = TextEditingController(text: patchData['cropName'] ?? '');
    
    // Fix: Round to 2 decimal places to prevent huge numbers
    double parsedArea = patchData['area'] ?? 0.0;
    TextEditingController areaController = TextEditingController(text: parsedArea.toStringAsFixed(2));
    
    DateTime selectedDate = DateTime.tryParse(patchData['sowingDate'] ?? '') ?? DateTime.now();
    String selectedUnit = patchData['areaUnit'] ?? 'Acres';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['edit_caps'] != null ? '${t['edit_caps']} ${t['product'] ?? 'Crop Details'}' : 'Edit Crop Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: cropNameController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _allCrops.where((String option) {
                        final optLower = option.toLowerCase();
                        if (optLower.startsWith(query)) return true;
                        final words = optLower.split(RegExp(r'[\s\(\)/\-]+'));
                        return words.any((word) => word.startsWith(query));
                      });
                    },
                    onSelected: (String selection) {
                      cropNameController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Fasal ka Naam (Search Crop)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (val) {
                          cropNameController.text = val; // allow manual unknown names
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: areaController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Farm Size (Zameen)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true, // Fix for text overflow
                          value: selectedUnit,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: ['Acres', 'Bigha', 'Hectares'].map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setModalState(() {
                                selectedUnit = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Sowing Date (Bovai kab hui?)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (cropNameController.text.isEmpty) return;
                        
                        final box = Hive.box('settings');
                        List<dynamic> cropPatches = box.get('saved_crop_patches', defaultValue: []) as List<dynamic>;
                        
                        final index = cropPatches.indexWhere((p) => p['id'] == patchData['id']);
                        if (index != -1) {
                           cropPatches[index] = {
                             ...Map<String, dynamic>.from(cropPatches[index]),
                             'cropName': cropNameController.text,
                             'sowingDate': selectedDate.toIso8601String(),
                             'area': double.tryParse(areaController.text) ?? 0.0,
                             'areaUnit': selectedUnit,
                           };
                           box.put('saved_crop_patches', cropPatches);
                           
                           // Schedule fertilizer notifications based on updated sowing date
                           try {
                             NotificationService.scheduleFertilizerAlerts(cropNameController.text, selectedDate);
                           } catch(e) {}
                        }
                        
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(t['done'] ?? 'Save Changes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showAddCropBottomSheet() {
    final t = ref.read(translationsProvider);
    TextEditingController cropNameController = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['add_transaction'] != null ? '${t['add_transaction']} (${t['mera_khet'] ?? 'Nayi Fasal Jodein'})' : 'Add New Crop (Nayi Fasal Jodein)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _allCrops.where((String option) {
                        final optLower = option.toLowerCase();
                        if (optLower.startsWith(query)) return true;
                        final words = optLower.split(RegExp(r'[\s\(\)/\-]+'));
                        return words.any((word) => word.startsWith(query));
                      });
                    },
                    onSelected: (String selection) {
                      cropNameController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      cropNameController = controller; 
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Fasal ka Naam (Search Crop)',
                          hintText: 'e.g., Gehu, Chana, Cotton',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 40,
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(option),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Sowing Date (Bovni ki Tarikh)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.calendar_month),
                      ),
                      child: Text(
                        selectedDate != null 
                          ? '${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}' 
                          : 'Select Sowing Date',
                        style: TextStyle(color: selectedDate != null ? Colors.black : Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = cropNameController.text.trim();

                        if (name.isNotEmpty && selectedDate != null) {
                          Navigator.pop(context); // Close modal
                          // Go to map
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MeraKhetHome(cropName: name, sowingDate: selectedDate!)
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kripya fasal ka naam aur tarikh chunein.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(t['select_map_area'] ?? 'Next: Select Map Area', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _addCropToFarm(String farmId, String cropName, double area) {
    final box = Hive.box('settings');
    List<dynamic> farms = box.get('saved_farms_list', defaultValue: []) as List<dynamic>;

    for (int i = 0; i < farms.length; i++) {
      if ((farms[i] as Map)['id'] == farmId) {
        Map<String, dynamic> farm = Map<String, dynamic>.from(farms[i]);
        List<dynamic> crops = farm['crops'] != null ? List.from(farm['crops']) : [];
        
        // Mock some safe/alert logic based on crop name length to simulate API
        bool isSafe = cropName.length % 2 == 0; 
        final riskDate1 = DateTime.now().add(const Duration(days: 3));
        
        crops.add({
          'name': cropName,
          'area': area,
          'safe': isSafe,
          'riskDate': '${riskDate1.day} ${_getMonth(riskDate1.month)}',
          'riskType': 'Heavy Rain 🌧️',
          'action': 'Avoid spraying pesticides.'
        });
        
        farm['crops'] = crops;
        farms[i] = farm;
        break;
      }
    }

    box.put('saved_farms_list', farms);
    setState(() {}); // Refresh UI
  }

  void _deleteFarm(String id) {
    final box = Hive.box('settings');
    List<dynamic> farms = box.get('saved_farms_list', defaultValue: []) as List<dynamic>;
    farms.removeWhere((f) => (f as Map)['id'] == id);
    box.put('saved_farms_list', farms);
    if (farms.isEmpty) {
      box.put('has_saved_farm', false);
    }
    setState(() {});
  }

  void _deleteCropFromFarm(String farmId, String cropName) {
    final box = Hive.box('settings');
    List<dynamic> farms = box.get('saved_farms_list', defaultValue: []) as List<dynamic>;

    for (int i = 0; i < farms.length; i++) {
      if ((farms[i] as Map)['id'] == farmId) {
        Map<String, dynamic> farm = Map<String, dynamic>.from(farms[i]);
        if (farm['crops'] != null) {
          List<dynamic> crops = List.from(farm['crops']);
          crops.removeWhere((c) => (c as Map)['name'] == cropName);
          farm['crops'] = crops;
          farms[i] = farm;
        }
        break;
      }
    }
    box.put('saved_farms_list', farms);
    setState(() {});
  }

  Widget _buildDiaryTab(Map<String, String> t) {
    final box = Hive.box('settings');
    final cropPatches = box.get('saved_crop_patches', defaultValue: []) as List<dynamic>;

    if (cropPatches.isEmpty) {
      return Center(child: Text(t['add_crop_farms_empty'] ?? 'Add a crop in My Farms to see the fertilizer schedule.'));
    }

    // Generate smart tasks
    List<Map<String, dynamic>> scheduleTasks = [];
    for (var patch in cropPatches) {
      final p = Map<String, dynamic>.from(patch);
      final cropName = p['cropName'] ?? 'Unknown';
      final sowingDate = DateTime.tryParse(p['sowingDate'] ?? '') ?? DateTime.now();
      
      // Standard 4-stage schedule
      scheduleTasks.add({
        'crop': cropName,
        'date': sowingDate.add(const Duration(days: 20)),
        'title': t['urea_npk_1st'] ?? '1st Top Dressing (Urea / NPK)',
        'desc': t['vegetative_growth_desc'] ?? 'Apply nitrogen-rich fertilizer for vegetative growth.',
        'icon': Icons.science
      });
      scheduleTasks.add({
        'crop': cropName,
        'date': sowingDate.add(const Duration(days: 45)),
        'title': t['weed_check_2nd'] ?? 'Weed Check & 2nd Fertilizer',
        'desc': t['secondary_nutrients_desc'] ?? 'Remove weeds and apply secondary nutrients.',
        'icon': Icons.grass
      });
      scheduleTasks.add({
        'crop': cropName,
        'date': sowingDate.add(const Duration(days: 60)),
        'title': t['preventive_pest_spray'] ?? 'Preventive Pest Spray',
        'desc': t['prevent_diseases_desc'] ?? 'Spray fungicide/insecticide to prevent common diseases.',
        'icon': Icons.pest_control
      });
      scheduleTasks.add({
        'crop': cropName,
        'date': sowingDate.add(const Duration(days: 80)),
        'title': t['fruit_grain_potash'] ?? 'Fruit/Grain Development (Potash)',
        'desc': t['boost_grain_desc'] ?? 'Apply Potassium (K) to boost grain size or fruit quality.',
        'icon': Icons.agriculture
      });
    }

    // Sort tasks by date
    scheduleTasks.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Assign distinct colors to unique crops
    final List<Color> bgColors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
      Colors.pink.shade50,
      Colors.amber.shade50,
      Colors.cyan.shade50,
      Colors.indigo.shade50,
      Colors.red.shade50,
    ];
    
    final Map<String, Color> cropColorMap = {};
    int colorIndex = 0;
    for (var task in scheduleTasks) {
      final cropName = task['crop'] as String;
      if (!cropColorMap.containsKey(cropName)) {
        cropColorMap[cropName] = bgColors[colorIndex % bgColors.length];
        colorIndex++;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      children: [
        Text(t['smart_fertilizer_schedule'] ?? 'Smart Fertilizer Schedule', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(t['based_on_icar_guidelines'] ?? 'Based on ICAR guidelines & your sowing dates', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        ...scheduleTasks.map((task) {
          final tDate = task['date'] as DateTime;
          final isPast = tDate.isBefore(DateTime.now());
          final daysDiff = tDate.difference(DateTime.now()).inDays;
          
          String timeStatus = '';
          Color statusColor = Colors.grey;
          if (daysDiff < 0) {
            timeStatus = '${daysDiff.abs()} ${t['days_ago'] ?? 'days ago'}';
            statusColor = Colors.orange;
          } else if (daysDiff == 0) {
            timeStatus = t['today'] ?? 'Today';
            statusColor = Colors.red;
          } else {
            timeStatus = '${t['loading_advice']?.split('.').first ?? 'In'} $daysDiff ${t['days'] ?? 'days'}';
            statusColor = Colors.green;
          }

          final String cropName = task['crop'] as String;
          final Color cardColor = cropColorMap[cropName] ?? Colors.white;

          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cardColor.withOpacity(0.5), width: 1),
            ),
            elevation: 1,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.2),
                child: Icon(task['icon'], color: statusColor),
              ),
              title: Text('${task['crop']} - ${task['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(task['desc'], style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text('${tDate.day} ${_getMonth(tDate.month)} ($timeStatus)', 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  )
                ],
              ),
              trailing: Checkbox(
                value: isPast, // Mock completion status
                onChanged: (val) {},
                activeColor: Colors.green,
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WeatherStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

