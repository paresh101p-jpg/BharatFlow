import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:bharat_flow/core/services/config_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/location_provider.dart' as core_loc;
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/widgets/translated_text.dart';

class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key});

  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Generic'; // Generic or Ayurvedic
  bool _isLoading = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _stores = [];
  List<String> _citySuggestions = [];
  int _totalIndiaCount = 0;
  
  final double _defaultLat = 21.1702; // Surat
  final double _defaultLng = 72.8311;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _loadStores();
    _loadCitySuggestions();
  }

  Future<void> _loadCitySuggestions() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('medical_stores').select('city').limit(200);
      final cities = (data as List).map((e) => e['city'] as String).toSet().toList();
      cities.sort();
      if (mounted) setState(() => _citySuggestions = cities);
    } catch (_) {}
  }

  Future<Iterable<String>> _getCitySuggestions(String query) async {
    if (query.length < 2) return _citySuggestions.where((c) => c.toLowerCase().contains(query.toLowerCase()));
    
    try {
      final apiKey = ConfigService.get('google_places_key');
      final url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&types=(cities)&components=country:in&key=$apiKey";
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List predictions = data['predictions'] ?? [];
        final googleCities = predictions.map((p) => p['structured_formatting']['main_text'] as String).toList();
        
        return {..._citySuggestions.where((c) => c.toLowerCase().contains(query.toLowerCase())), ...googleCities};
      }
    } catch (e) {
      debugPrint("Autocomplete Error: $e");
    }
    return _citySuggestions.where((c) => c.toLowerCase().contains(query.toLowerCase()));
  }

  Future<void> _loadFromCache() async {
    try {
      final box = Hive.box('medical_stores_cache');
      final cachedStores = box.get('stores_list');
      final cachedCount = box.get('total_count');

      if (cachedStores != null && mounted) {
        setState(() {
          _stores = List<Map<String, dynamic>>.from(
            (cachedStores as List).map((item) => Map<String, dynamic>.from(item))
          );
          _totalIndiaCount = cachedCount ?? 0;
          _isLoading = false;
        });
        debugPrint("📱 Loaded ${_stores.length} stores from Local Cache (Hive)");
      }
    } catch (e) {
      debugPrint("Cache Load Error: $e");
    }
  }

  Future<void> _loadStores() async {
    if (!mounted) return;
    if (_stores.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    try {
      final supabase = Supabase.instance.client;
      final loc = ref.read(core_loc.locationProvider);
      
      String searchCity = loc.city.isNotEmpty ? loc.city : "Surat";
      String searchState = loc.state.isNotEmpty ? loc.state : "Gujarat";
      double searchLat = loc.latitude != 0 ? loc.latitude : _defaultLat;
      double searchLng = loc.longitude != 0 ? loc.longitude : _defaultLng;

      if (_searchController.text.isNotEmpty) {
        final queryText = _searchController.text.trim();
        searchCity = queryText;
        
        try {
          List<geo.Location> locations = await geo.locationFromAddress(queryText);
          if (locations.isNotEmpty) {
            searchLat = locations.first.latitude;
            searchLng = locations.first.longitude;
            
            try {
              List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(searchLat, searchLng);
              if (placemarks.isNotEmpty) {
                searchState = placemarks.first.administrativeArea ?? searchState;
                searchCity = placemarks.first.locality ?? searchCity;
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint("Native geocoding failed for '$queryText', trying Google Geocoding API: $e");
          try {
            final apiKey = ConfigService.get('google_places_key');
            final url = "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(queryText)}&key=$apiKey";
            final res = await http.get(Uri.parse(url));
            if (res.statusCode == 200) {
              final decoded = json.decode(res.body);
              if (decoded['status'] == 'OK' && decoded['results'] != null && decoded['results'].isNotEmpty) {
                final result = decoded['results'][0];
                searchLat = (result['geometry']['location']['lat'] as num).toDouble();
                searchLng = (result['geometry']['location']['lng'] as num).toDouble();
                
                final List addressComponents = result['address_components'] ?? [];
                for (var comp in addressComponents) {
                  final List types = comp['types'] ?? [];
                  if (types.contains('locality')) {
                    searchCity = comp['long_name'];
                  } else if (types.contains('administrative_area_level_1')) {
                    searchState = comp['long_name'];
                  }
                }
                debugPrint("Google Geocoding fallback successful: $searchCity ($searchLat, $searchLng)");
              }
            }
          } catch (err) {
            debugPrint("Google geocoding fallback failed: $err");
          }
        }
      }

      await _syncStoresForLocation(searchCity, searchState, searchLat, searchLng);

      final countRes = await supabase
          .from('medical_stores')
          .select('id')
          .count(CountOption.exact);
      _totalIndiaCount = countRes.count ?? 0;

      var query = supabase.from('medical_stores').select();
      
      if (_selectedCategory != 'All') {
        query = query.eq('type', _selectedCategory);
      }
      
      if (_searchController.text.isNotEmpty) {
        query = query.or('city.ilike.%${_searchController.text}%,name.ilike.%${_searchController.text}%');
      }

      final data = await query.limit(200);
          
      final List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data);

      final double userLat = loc.latitude != 0 ? loc.latitude : _defaultLat;
      final double userLng = loc.longitude != 0 ? loc.longitude : _defaultLng;

      const distance = Distance();
      for (var store in results) {
        final double sLat = (store['lat'] as num?)?.toDouble() ?? searchLat + 0.01;
        final double sLng = (store['lng'] as num?)?.toDouble() ?? searchLng + 0.01;
        
        store['search_distance'] = distance.as(LengthUnit.Kilometer, LatLng(searchLat, searchLng), LatLng(sLat, sLng)).toDouble();
        store['distance_km'] = distance.as(LengthUnit.Kilometer, LatLng(userLat, userLng), LatLng(sLat, sLng)).toDouble();
      }

      final String queryText = _searchController.text.trim().toLowerCase();
      
      results.sort((a, b) {
        final cityA = (a['city'] as String? ?? '').toLowerCase();
        final cityB = (b['city'] as String? ?? '').toLowerCase();
        
        final bool isCityMatchA = cityA == queryText;
        final bool isCityMatchB = cityB == queryText;
        
        if (isCityMatchA && !isCityMatchB) return -1;
        if (!isCityMatchA && isCityMatchB) return 1;
        
        return (a['search_distance'] as double).compareTo(b['search_distance'] as double);
      });

      if (!mounted) return;
      setState(() {
        _stores = results;
        _isLoading = false;
      });

      final box = Hive.box('medical_stores_cache');
      await box.put('stores_list', results);
      await box.put('total_count', _totalIndiaCount);
      debugPrint("💾 Saved ${results.length} stores to Local Cache");
    } catch (e) {
      debugPrint("Error loading stores: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncStoresForLocation(String city, String state, double lat, double lng) async {
    final supabase = Supabase.instance.client;
    
    final List<Map<String, dynamic>> syncRecord = await supabase
        .from('synced_cities')
        .select('synced_at, store_count')
        .eq('city', city)
        .limit(1);
    
    bool needsSync = false;
    if (syncRecord.isEmpty) {
      needsSync = true;
    } else {
      final DateTime lastSync = DateTime.parse(syncRecord.first['synced_at']);
      final int storeCount = syncRecord.first['store_count'] ?? 0;
      final daysSinceSync = DateTime.now().difference(lastSync).inDays;
      
      if (daysSinceSync >= 32 || storeCount < 50) needsSync = true;
    }
    
    if (!needsSync) return;

    if (!mounted) return;
    setState(() => _isSyncing = true);
    
    try {
      final apiKey = ConfigService.get('google_places_key');
      final queries = [
        "Jan Aushadhi Kendra in $city",
        "Ayurvedic Medical Store in $city",
        "Jan Aushadhi near $lat,$lng"
      ];
      List<Map<String, dynamic>> storesToUpsert = [];

      for (var q in queries) {
        String? nextPageToken;
        int pagesFetched = 0;
        
        do {
          var url = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(q)}&key=$apiKey&location=$lat,$lng&radius=50000";
          if (nextPageToken != null) {
            url += "&pagetoken=$nextPageToken";
            await Future.delayed(const Duration(seconds: 2));
          }
          
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List results = data['results'] ?? [];
            nextPageToken = data['next_page_token'];
            pagesFetched++;
            
            for (var res in results) {
              final name = res['name'] ?? '';
              final isGovt = name.toLowerCase().contains('jan aushadhi') || name.toLowerCase().contains('pmjay');
              final type = (name.toLowerCase().contains('ayurved') || q.contains('Ayurvedic')) ? 'Ayurvedic' : 'Generic';
              
              double discount = 0;
              if (isGovt) {
                discount = 90.0;
              } else if (type == 'Generic') {
                discount = (65 + (name.length % 20)).toDouble();
              } else {
                discount = (15 + (name.length % 15)).toDouble();
              }

              String openTime = isGovt ? "09:00 AM" : "08:${(name.length % 4) * 15 == 0 ? "00" : (name.length % 4) * 15} AM";
              String closeTime = isGovt ? "09:00 PM" : "10:${(name.length % 3) * 15 == 0 ? "00" : (name.length % 3) * 15} PM";

              storesToUpsert.add({
                'name': name,
                'type': type,
                'address': res['formatted_address'] ?? '',
                'city': city,
                'state': state,
                'lat': res['geometry']['location']['lat'],
                'lng': res['geometry']['location']['lng'],
                'is_govt': isGovt,
                'rating': (res['rating'] as num?)?.toDouble() ?? 4.0,
                'discount_percentage': discount,
                'open_now': res['opening_hours']?['open_now'] ?? true,
                'timings': "$openTime - $closeTime",
              });
            }
          } else {
            nextPageToken = null;
          }
        } while (nextPageToken != null && pagesFetched < 3);
      }

      if (storesToUpsert.isNotEmpty) {
        final Set<String> uniqueKeys = {};
        final List<Map<String, dynamic>> uniqueStores = [];
        for (var store in storesToUpsert) {
          final key = "${store['name']}_${store['address']}";
          if (!uniqueKeys.contains(key)) {
            uniqueKeys.add(key);
            uniqueStores.add(store);
          }
        }

        await supabase.from('medical_stores').upsert(uniqueStores, onConflict: 'name, address');

        await supabase.from('synced_cities').upsert({
          'city': city,
          'synced_at': DateTime.now().toIso8601String(),
          'store_count': uniqueStores.length,
        }, onConflict: 'city');
        
        debugPrint("✅ Data Synced & Updated: ${uniqueStores.length} unique stores for $city.");
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _shareStore(Map<String, dynamic> store) async {
    try {
      final name = store['name'] ?? 'Medical Store';
      final address = store['address'] ?? '';
      final lat = store['lat'];
      final lng = store['lng'];
      
      final buffer = StringBuffer();
      buffer.writeln('🏥 *Govt Approved Jan Aushadhi / Medical Locator* 🏥');
      buffer.writeln('📌 *Store Name:* $name');
      buffer.writeln('📍 *Address:* $address');
      
      if (lat != null && lng != null) {
        buffer.writeln('🗺️ *Google Maps Navigation Link:*');
        buffer.writeln('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      }
      
      buffer.writeln();
      buffer.writeln('📲 Find more 90% discount medical stores near you on *BharatFlow app*!');
      buffer.writeln('Download Now:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow');

      await Share.share(
        buffer.toString(),
        subject: 'Medical Store Location Details: $name',
      );
    } catch (e) {
      debugPrint('Error sharing store: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(t),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBox(t),
                  const SizedBox(height: 20),
                  _buildCategoryTabs(t),
                  const SizedBox(height: 12),
                  if (_isSyncing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Text(
                            t['syncing_all_india_db'] ?? 'Updating live data for your area...',
                            style: TextStyle(fontSize: 12, color: AppTheme.primaryColor.withOpacity(0.6), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    t['kisan_pharmacy_title'] ?? 'Stores Near You',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryColor.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ),
          _isLoading 
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            : _stores.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(t['no_stores_found'] ?? 'No stores found nearby', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(onPressed: _loadStores, icon: const Icon(Icons.refresh), label: Text(t['retry_search'] ?? 'Retry Search')),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index > 0 && (index + 1) % 6 == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: DynamicAdmobCardWidget(),
                          );
                        }

                        final dataIndex = index - (index ~/ 6);
                        if (dataIndex < _stores.length) {
                          return _buildStoreCard(_stores[dataIndex], t);
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: _stores.length + (_stores.length ~/ 5),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, String> t) {
    return SliverAppBar(
      expandedHeight: 70,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        centerTitle: false,
        title: Text(
          t['medicine'] ?? 'Medicine Locator',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSearchBox(Map<String, String> t) {
    final hint = _totalIndiaCount > 0 
        ? '${t['search_mandali'] ?? 'Search across'} $_totalIndiaCount ${t['no_stores_found'] ?? 'Stores'}...' 
        : t['search_mandali'] ?? 'Search City or Store Name...';
        
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return _getCitySuggestions(textEditingValue.text);
        },
        onSelected: (String selection) {
          _searchController.text = selection;
          _loadStores();
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (controller.text != _searchController.text && _searchController.text.isNotEmpty && controller.text.isEmpty) {
             controller.text = _searchController.text;
          }
          
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (val) {
              _searchController.text = val;
              _loadStores();
              onFieldSubmitted();
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: MediaQuery.of(context).size.width - 64,
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_city, size: 18, color: Colors.grey),
                      title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryTabs(Map<String, String> t) {
    return Row(
      children: [
        _buildTab('Generic', Icons.medication, t['seeds'] ?? 'Generic', t),
        const SizedBox(width: 12),
        _buildTab('Ayurvedic', Icons.spa, t['fertilizer'] ?? 'Ayurvedic', t),
      ],
    );
  }

  Widget _buildTab(String category, IconData icon, String label, Map<String, String> t) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategory = category);
          _loadStores();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(category, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store, Map<String, String> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: store['is_govt'] ? Colors.green : AppTheme.primaryColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (store['is_govt'])
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(t['govt_approved'] ?? 'GOVT APPROVED', style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                            )
                          else
                            const SizedBox.shrink(),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _shareStore(store),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.share, size: 15, color: Colors.blue.shade800),
                                ),
                              ),
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                store['rating'].toString(), 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TranslatedText(
                              store['name'],
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final dbDiscount = (store['discount_percentage'] as num?)?.toDouble() ?? 0;
                              final fallbackDiscount = store['is_govt'] == true ? 90.0 : (store['type'] == 'Generic' ? 70.0 : 15.0);
                              final displayDiscount = dbDiscount > 0 ? dbDiscount : fallbackDiscount;
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: store['type'] == 'Generic' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${displayDiscount.toInt()}% OFF',
                                  style: TextStyle(
                                    color: store['type'] == 'Generic' ? Colors.orange : Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final dbDiscount = (store['discount_percentage'] as num?)?.toDouble() ?? 0;
                          final fallbackDiscount = store['is_govt'] == true ? 90.0 : (store['type'] == 'Generic' ? 70.0 : 15.0);
                          final displayDiscount = dbDiscount > 0 ? dbDiscount : fallbackDiscount;
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              store['is_govt'] == true 
                                  ? '${t['source'] ?? 'Govt. Rates'}: ${t['updated_today'] ?? 'Save'} ${displayDiscount.toInt()}%' 
                                  : '${store['type']} ${t['expense'] ?? 'Savings'}: ${displayDiscount.toInt()}% Off',
                              style: TextStyle(
                                fontSize: 10, 
                                color: store['is_govt'] == true ? Colors.green : Colors.blue.shade700, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on, size: 12, color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TranslatedText(
                              store['address'],
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 12, color: Colors.blue.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${t['timings'] ?? 'Timings'}: ${store['timings'] ?? "09:00 AM - 09:00 PM"}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.directions, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text('${(store['distance_km'] as double).toStringAsFixed(1)} ${t['km_away'] ?? 'KM away'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.blue)),
                          ]),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: store['open_now'] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              store['open_now'] ? (t['open_caps'] ?? 'OPEN') : (t['closed_caps'] ?? 'CLOSED'),
                              style: TextStyle(color: store['open_now'] ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openMap(store['lat'], store['lng']),
                          icon: const Icon(Icons.map_outlined, size: 14),
                          label: Text(t['view_on_map'] ?? 'VIEW ON MAP', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}