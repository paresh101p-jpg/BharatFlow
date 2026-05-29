import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/ai_service.dart';

class SoilHealthScreen extends ConsumerStatefulWidget {
  const SoilHealthScreen({super.key});

  @override
  ConsumerState<SoilHealthScreen> createState() => _SoilHealthScreenState();
}

class _SoilHealthScreenState extends ConsumerState<SoilHealthScreen> {
  bool _isLoading = false;
  String? _currentView = 'landing'; // landing, nahi_flow, results
  Map<String, dynamic>? _analysisResults;
  List<Map<String, dynamic>> _labs = [];
  List<Map<String, dynamic>> _history = [];
  String? _nextPageToken;
  int _shownCount = 10;
  bool _showAllLabs = false;
  final ScrollController _labScrollController = ScrollController();

  final _supabase = Supabase.instance.client;
  final _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _labScrollController.addListener(_onLabScroll);
  }

  @override
  void dispose() {
    _labScrollController.dispose();
    super.dispose();
  }

  void _onLabScroll() {
    if (_labScrollController.position.pixels >=
        _labScrollController.position.maxScrollExtent - 200) {
      if (_shownCount < _labs.length) {
        setState(() {
          _shownCount += 10;
        });
      } else if (_nextPageToken != null && !_isLoading) {
        _loadMoreLabs();
      }
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await _supabase
          .from('soil_reports')
          .select()
          .order('created_at', ascending: false);
      if (res != null) {
        setState(() => _history = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('History fetch error: $e');
    }
  }

  void _showSampleCard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Soil Health Card (Sample)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                'https://pib.gov.in/WriteReadData/userfiles/image/image001W6K6.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.description_rounded, size: 100, color: Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bhai, kripya karke aisi saaf photo kheenchein jisme Nitrogen (N), Phosphorus (P), aur Potassium (K) ke values saaf dikh rahe hon.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Samajh Gaya', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScan() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final loc = ref.read(locationProvider);
      final result = await _aiService.analyzeSoilCard(image, loc.city);
      if (result != null) {
        await _supabase.from('soil_reports').insert({
          ...result,
          'created_at': DateTime.now().toIso8601String(),
        });
        setState(() {
          _analysisResults = result;
          _currentView = 'results';
          _isLoading = false;
        });
        _fetchHistory();
      } else {
        throw 'Analysis failed';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scanning failed: Photo clear nahi hai ya ye Soil Health Card nahi hai. Wapas try karein.')),
        );
      }
    }
  }

  Future<void> _handleNoCard() async {
    setState(() {
      _isLoading = true;
      _currentView = 'nahi_flow';
      _labs = [];
      _nextPageToken = null;
      _showAllLabs = false;
      _shownCount = 10;
    });

    try {
      final loc = ref.read(locationProvider);
      final double lat = loc.latitude;
      final double lng = loc.longitude;
      final String district = loc.city;

      // 1. Check Global Cache (Supabase)
      List<Map<String, dynamic>> cachedLabs = [];
      try {
        final res = await _supabase
            .from('labs_cache')
            .select()
            .eq('district', district);

        if (res != null && (res as List).isNotEmpty) {
          final first = (res as List).first;
          final lastSyncStr = first['last_detailed_sync'] ?? first['created_at'] ?? '';
          final lastSync = DateTime.tryParse(lastSyncStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final now = DateTime.now();
          final daysSinceSync = now.difference(lastSync).inDays;
          final isSunday = now.weekday == DateTime.sunday;
          
          bool isStale = daysSinceSync >= 30 || (isSunday && daysSinceSync >= 1);
          
          if (!isStale && (res as List).length >= 15) {
            cachedLabs = (res as List).map((l) {
              final m = Map<String, dynamic>.from(l);
              final double d = Geolocator.distanceBetween(lat, lng, m['lat'] ?? 0.0, m['lng'] ?? 0.0);
              m['distanceValue'] = d;
              m['distanceLabel'] = '${(d / 1000).toStringAsFixed(1)} km away';
              m['isOpen'] = m['is_open'];
              return m;
            }).toList();
            cachedLabs.sort((a, b) => (a['distanceValue'] as double).compareTo(b['distanceValue'] as double));
          }
        }
      } catch (e) {
        debugPrint('Cache check error: $e');
      }

      if (cachedLabs.isNotEmpty) {
        setState(() {
          _labs = cachedLabs;
          _isLoading = false;
        });
        return;
      }

      // 2. Google Places Search (Multi-Query Parallel Search)
      List<Map<String, dynamic>> foundLabs = [];
      try {
        final queries = [
          'Soil Testing Laboratory near $district OR Soil Health Card Lab',
          'Krishi Vigyan Kendra near $district OR Agriculture Research Center',
          'Agriculture Testing Laboratory near $district OR Fertilizer Seed Lab'
        ];

        final List<Future<http.Response>> requests = queries.map((q) {
          final url = 'https://maps.googleapis.com/maps/api/place/textsearch/json'
              '?query=${Uri.encodeComponent(q)}'
              '&location=$lat,$lng'
              '&radius=1000000'
              '&key=${ConfigService.get('google_places_key')}';
          return http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        }).toList();

        final responses = await Future.wait(requests);
        final Set<String> seenIds = {};

        for (final response in responses) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final List results = data['results'] as List;
            if (_nextPageToken == null) _nextPageToken = data['next_page_token'];
            
            for (final p in results) {
              final String pid = p['place_id'];
              if (seenIds.contains(pid)) continue;
              seenIds.add(pid);

              final double labLat = p['geometry']['location']['lat'];
              final double labLng = p['geometry']['location']['lng'];
              final double dist = Geolocator.distanceBetween(lat, lng, labLat, labLng);
              
              if (dist <= 1000000) {
                foundLabs.add({
                  'place_id': pid,
                  'name': p['name'],
                  'address': p['formatted_address'] ?? p['vicinity'] ?? '',
                  'distanceValue': dist,
                  'distanceLabel': '${(dist / 1000).toStringAsFixed(1)} km away',
                  'lat': labLat,
                  'lng': labLng,
                  'phone': 'N/A',
                });
              }
            }
          }
        }
        foundLabs.sort((a, b) => (a['distanceValue'] as double).compareTo(b['distanceValue'] as double));

        // 3. Deep Fetch Details for Top 10
        final topBatch = foundLabs.take(10).toList();
        await Future.wait(topBatch.map((l) async {
          try {
            final dUrl = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=${l['place_id']}&fields=formatted_phone_number,website,opening_hours&key=${ConfigService.get('google_places_key')}';
            final dRes = await http.get(Uri.parse(dUrl)).timeout(const Duration(seconds: 5));
            final dData = json.decode(dRes.body);
            if (dData['status'] == 'OK') {
              final r = dData['result'];
              l['phone'] = r['formatted_phone_number'] ?? l['phone'];
              l['website'] = r['website'];
              l['isOpen'] = r['opening_hours']?['open_now'];
            }
          } catch (_) {}
        }));

        // 4. Global Sync (Cache results for other users in same district)
        if (foundLabs.isNotEmpty) {
          final uploadList = foundLabs.map((l) => {
            'name': l['name'],
            'address': l['address'],
            'lat': l['lat'],
            'lng': l['lng'],
            'district': district,
            'phone': l['phone'],
            'website': l['website'],
            'is_open': l['isOpen'],
            'last_detailed_sync': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          }).toList();
          await _supabase.from('labs_cache').upsert(uploadList, onConflict: 'name, address');
        }
      } catch (e) {
        debugPrint('Places API error: $e');
      }

      // 5. Fallback if no results found from API
      if (foundLabs.isEmpty) {
        foundLabs = _staticFallbackLabs.map((lab) {
          if (lab['lat'] == 0.0) return {...lab, 'distanceLabel': 'Online'};
          final d = Geolocator.distanceBetween(lat, lng, lab['lat'], lab['lng']);
          return {
            ...lab,
            'distanceValue': d,
            'distanceLabel': '${(d / 1000).toStringAsFixed(0)} km away',
          };
        }).toList();
        foundLabs.sort((a, b) => (a['distanceValue'] as dynamic).compareTo(b['distanceValue'] as dynamic));
      }

      setState(() {
        _labs = foundLabs;
        _isLoading = false;
      });

      // AUTOMATIC BATCHING: Fetch next page automatically to reach 50 labs
      if (_labs.length < 50 && _nextPageToken != null) {
        Future.delayed(const Duration(seconds: 2), () => _loadMoreLabs());
      }
    } catch (e) {
      debugPrint('_handleNoCard global error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreLabs() async {
    if (_nextPageToken == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final loc = ref.read(locationProvider);
      final url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?pagetoken=$_nextPageToken&key=${ConfigService.get('google_places_key')}';
      await Future.delayed(const Duration(seconds: 2));
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final List results = data['results'] as List;
        List<Map<String, dynamic>> moreLabs = [];
        for (final p in results) {
          final double labLat = p['geometry']['location']['lat'];
          final double labLng = p['geometry']['location']['lng'];
          final double d = Geolocator.distanceBetween(loc.latitude, loc.longitude, labLat, labLng);
          if (d <= 1000000) {
            moreLabs.add({
              'name': p['name'],
              'address': p['formatted_address'] ?? p['vicinity'] ?? '',
              'distanceLabel': '${(d / 1000).toStringAsFixed(1)} km away',
              'distanceValue': d,
              'phone': 'N/A', 
              'lat': labLat,
              'lng': labLng,
            });
          }
        }

        setState(() {
          _labs.addAll(moreLabs);
          _labs.sort((a, b) => (a['distanceValue'] as double).compareTo(b['distanceValue'] as double));
          _nextPageToken = data['next_page_token'];
          _isLoading = false;
        });

        if (_labs.length < 50 && _nextPageToken != null) {
          Future.delayed(const Duration(seconds: 2), () => _loadMoreLabs());
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Load More Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: Text(t['soil_health'] ?? 'Soil Health'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        leading: _currentView != 'landing'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentView = 'landing'),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF1B5E20)),
            onPressed: () => shareAppBranding(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _labScrollController,
            child: Column(
              children: [
                if (_currentView == 'landing') _buildLandingView(t),
                if (_currentView == 'nahi_flow') _buildNahiFlow(t),
                if (_currentView == 'results') _buildResultsView(t),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_currentView != 'nahi_flow') _buildPrivacyFooter(),
        ],
      ),
    );
  }

  Widget _buildLandingView(Map<String, String> t) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)
              ],
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showSampleCard(context),
                  icon: const Icon(Icons.image_outlined, size: 16, color: Colors.blue),
                  label: const Text('See Sample Card (Example)', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 12),
                Text(
                  t['bhai_have_card'] ?? 'Bhai, kya aapke paas Soil Health Card hai?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                ),
                const SizedBox(height: 32),
                _buildActionButton(
                  t['scan_report'] ?? 'Haan, Report Scan Karein',
                  Icons.camera_alt_rounded,
                  const Color(0xFF2E7D32),
                  _handleScan,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  t['find_lab'] ?? 'Nahi, Nazdeeki Lab Dhoondhein',
                  Icons.location_on_rounded,
                  const Color(0xFFEF6C00),
                  _handleNoCard,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const DynamicAdmobCardWidget(),
          _buildAmazonBanner(),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(t['previous_reports'] ?? 'Pichli Reports',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ..._history.map((h) => _buildHistoryCard(h, t)),
          ]
        ],
      ),
    );
  }

  Widget _buildAmazonBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_cart_checkout, color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Improve Soil Health! Buy top-quality Fertilizers & Testing Kits from Amazon.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse('https://amzn.to/4a8n8pM');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Buy Now on Amazon', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNahiFlow(Map<String, String> t) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['how_to_sample'] ?? 'Step-by-Step: Mitti ka sample kaise le?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSampleGuide(t),
          const SizedBox(height: 32),
          Text(t['nearby_labs'] ?? 'Aapke Nazdeeki Labs',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_labs.isEmpty && !_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Labs load nahi hui. Wapas try karein.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            ..._labs.take(_shownCount).map((l) => _buildLabCard(l, t)),
            const SizedBox(height: 100),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView(Map<String, String> t) {
    if (_analysisResults == null) return const SizedBox();
    final n = (_analysisResults!['n'] ?? 0).toString();
    final p = (_analysisResults!['p'] ?? 0).toString();
    final k = (_analysisResults!['k'] ?? 0).toString();
    final ph = (_analysisResults!['ph'] ?? 0).toString();
    final score = (_analysisResults!['health_score'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildSoilMeter(score),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildParamCard('N', n, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _buildParamCard('P', p, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildParamCard('K', k, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildParamCard('pH', ph, Colors.purple)),
            ],
          ),
          const SizedBox(height: 24),
          _buildAdviceCard('Crop Suggestions', _analysisResults!['crop_suggestions'], Icons.grass),
          const SizedBox(height: 12),
          _buildAdviceCard('Fertilizer Dosage', _analysisResults!['fertilizer_dosage'], Icons.science),
          const SizedBox(height: 12),
          _buildAdviceCard('Weather Advice', _analysisResults!['weather_advice'], Icons.wb_sunny),
          if (_history.length > 1) ...[
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Progress (Pichle saal vs Is saal)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _buildProgressGraph(),
          ]
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> h, Map<String, String> t) {
    final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(h['created_at']));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.assignment_rounded, color: Color(0xFF1B5E20)),
        title: Text('${t['reports'] ?? 'Report'}: ${h['best_crop']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Tariq: $date | Score: ${h['health_score']}%'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() {
          _analysisResults = h;
          _currentView = 'results';
        }),
      ),
    );
  }

  Widget _buildSampleGuide(Map<String, String> t) {
    final steps = [
      {'icon': Icons.vignette_rounded, 'text': t['step1'] ?? 'Khet se 8-10 jagah se mitti lein.', 'color': Colors.blue},
      {'icon': Icons.architecture_rounded, 'text': t['step2'] ?? '6-inch gehra "V" shape ka gadda khodein.', 'color': Colors.orange},
      {'icon': Icons.cleaning_services_rounded, 'text': t['step3'] ?? 'Ghas aur kachra saaf karein.', 'color': Colors.teal},
      {'icon': Icons.inventory_2_rounded, 'text': t['step4'] ?? 'Sabko milakar 500g mitti lab bhejein.', 'color': Colors.purple},
    ];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: idx < steps.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))) : null),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: (s['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(s['text'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLabCard(Map<String, dynamic> l, Map<String, String> t) {
    final String distanceLabelRaw = (l['distanceLabel'] ?? l['distance'] ?? '').toString();
    String distanceLabel = distanceLabelRaw;
    if (distanceLabelRaw == 'National Level') distanceLabel = t['national_level'] ?? 'National Level';
    if (distanceLabelRaw == 'State Level') distanceLabel = t['state_level'] ?? 'State Level';
    if (distanceLabelRaw == 'Online') distanceLabel = t['online'] ?? 'Online';
    if (distanceLabelRaw.contains('km away')) distanceLabel = distanceLabelRaw.replaceAll('km away', t['km_away'] ?? 'km away');

    final bool hasPhone = (l['phone'] != null && l['phone'].toString() != 'N/A');
    final bool hasLocation = (l['lat'] != null && l['lng'] != null) && !((l['lat'] == 0.0) && (l['lng'] == 0.0));
    const accentColor = Color(0xFF1B5E20);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: accentColor.withOpacity(0.15), width: 1.5), boxShadow: [BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(height: 50, width: 50, decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.science_rounded, color: accentColor, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2E3E2E))),
                        Text(l['address'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.2)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.near_me_rounded, size: 12, color: accentColor),
                                  const SizedBox(width: 4),
                                  Text(distanceLabel, style: const TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            if (l['isOpen'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (l['isOpen'] == true ? Colors.green : Colors.red).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: l['isOpen'] == true ? Colors.green : Colors.red),
                                    const SizedBox(width: 4),
                                    Text(l['isOpen'] == true ? 'OPEN' : 'CLOSED', 
                                      style: TextStyle(fontSize: 10, 
                                        color: l['isOpen'] == true ? Colors.green : Colors.red, 
                                        fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: _buildLabButton('Call', Icons.phone_in_talk_rounded, hasPhone ? Colors.blue : Colors.grey, hasPhone ? () => launchUrl(Uri.parse('tel:${l['phone']}')) : null, isPrimary: false)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildLabButton('Map', Icons.directions_rounded, accentColor, hasLocation ? () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${l['lat']},${l['lng']}')) : null, isPrimary: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildLabButton('Web', Icons.language_rounded, Colors.blue, l['website'] != null ? () => launchUrl(Uri.parse(l['website'])) : null, isPrimary: false)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLabButton(String label, IconData icon, Color color, VoidCallback? onTap, {required bool isPrimary}) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? color : Colors.white,
          foregroundColor: isPrimary ? Colors.white : color,
          elevation: 0,
          padding: EdgeInsets.zero,
          side: isPrimary ? null : BorderSide(color: color.withOpacity(0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilMeter(double score) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0, maximum: 100,
            ranges: <GaugeRange>[
              GaugeRange(startValue: 0, endValue: 40, color: Colors.red),
              GaugeRange(startValue: 40, endValue: 70, color: Colors.orange),
              GaugeRange(startValue: 70, endValue: 100, color: Colors.green),
            ],
            pointers: <GaugePointer>[NeedlePointer(value: score)],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(widget: Text('$score%', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)), angle: 90, positionFactor: 0.5)
            ],
          )
        ],
      ),
    );
  }

  Widget _buildParamCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildAdviceCard(String title, String? advice, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1B5E20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(advice ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressGraph() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['health_score'] ?? 0).toDouble())).toList(),
              isCurved: true,
              color: const Color(0xFF1B5E20),
              barWidth: 4,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyFooter() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white.withOpacity(0.9),
        child: const Text(
          '🔒 Privacy Guarantee: Aapki photo analysis ke turant baad mita di jati hai. Hum sirf aapki report save rakhte hain.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static final List<Map<String, dynamic>> _staticFallbackLabs = [
    {'name': 'IARI Pusa Laboratory', 'address': 'Pusa Campus, New Delhi', 'lat': 28.6345, 'lng': 77.1587, 'phone': '011-25841471'},
    {'name': 'National Fertilizer Quality Lab', 'address': 'NH-IV, Faridabad, Haryana', 'lat': 28.4089, 'lng': 77.3178, 'phone': '0129-2412234'},
    {'name': 'MP Soil Health Lab', 'address': 'Arera Hills, Bhopal', 'lat': 23.2355, 'lng': 77.4241, 'phone': '0755-2551461'},
    {'name': 'Gujarat Soil Lab', 'address': 'Sector 10, Gandhinagar', 'lat': 23.2156, 'lng': 72.6369, 'phone': '079-23256101'},
    {'name': 'UP State Soil Lab', 'address': 'Krishi Bhawan, Lucknow', 'lat': 26.8467, 'lng': 80.9462, 'phone': '0522-2204910'},
  ];
}
