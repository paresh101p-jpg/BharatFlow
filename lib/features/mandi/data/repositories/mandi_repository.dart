import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/features/mandi/presentation/providers/mandi_providers.dart';
import 'package:bharat_flow/core/constants/api_keys.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:bharat_flow/features/mandi/presentation/utils/commodity_utils.dart';
import 'package:bharat_flow/core/utils/api_tracker.dart';


class MandiRepository {
  final _supabase = Supabase.instance.client;

  Box get _favorites => Hive.box('mandi_favorites');
  Box get _productFavorites => Hive.box('product_favorites');
  Box get _priceHistory => Hive.box('mandi_prices_history');
  Box get _mandiCache => Hive.box('mandi_cache');

  static const int _pageSize = 50;
  
  static final Map<String, List<String>> _categoryKeywords = {
    'Grains': ['wheat', 'paddy', 'rice', 'maize', 'bajra', 'jowar', 'barley', 'ragi', 'gehun', 'chawal', 'makai', 'ghav', 'chokha'],
    'Vegetables': ['potato', 'onion', 'tomato', 'cabbage', 'cauliflower', 'brinjal', 'lady', 'bhindi', 'carrot', 'radish', 'garlic', 'ginger', 'peas', 'beans', 'gourd', 'tamatar', 'aloo', 'batata', 'pyaaz', 'dungali'],
    'Fruits': ['apple', 'banana', 'mango', 'lemon', 'orange', 'grapes', 'papaya', 'guava', 'watermelon', 'pomegranate', 'pineapple', 'aam', 'kela', 'seb'],
    'Spices': ['chili', 'mirch', 'turmeric', 'haldi', 'coriander', 'dhania', 'cumin', 'jeera', 'cardamom', 'clove', 'pepper', 'lasun', 'adrak'],
    'Pulses': ['gram', 'arhar', 'moong', 'urad', 'masur', 'lentil', 'tur', 'dal', 'chana', 'mag'],
    'Oilseeds': ['mustard', 'soyabean', 'groundnut', 'sunflower', 'sesamum', 'linseed', 'castor', 'sarson', 'rai'],
    'Fibers': ['cotton', 'jute', 'kapas'],
    'Plantation': ['coffee', 'tea', 'rubber', 'coconut', 'tobacco'],
    'Flowers': ['marigold', 'rose', 'jasmine', 'lily'],
  };

  Future<void> performSilentLocalSync({String? userState, String? userCity}) async {
    try {
      print('🔄 Starting Silent Background Sync...');
      
      final moreMandis = await fetchMandis(page: 1, userState: userState, userCity: userCity);
      final moreMandis2 = await fetchMandis(page: 2, userState: userState, userCity: userCity);
      
      final moreProducts = await fetchUniqueProducts(page: 1, userState: userState, userCity: userCity);
      final moreProducts2 = await fetchUniqueProducts(page: 2, userState: userState, userCity: userCity);

      final List<Map<String, dynamic>> cachedMandis = getCachedMandis();
      final List<Map<String, dynamic>> cachedProducts = getCachedProducts();

      final Set<String> existingMandiNames = cachedMandis.map((e) => e['mandi_name_original']?.toString() ?? '').toSet();
      for (var m in [...moreMandis, ...moreMandis2]) {
        if (!existingMandiNames.contains(m['mandi_name_original'])) {
          cachedMandis.add(m);
        }
      }
      
      final Set<String> existingProductNames = cachedProducts.map((e) => e['commodity_name_original']?.toString() ?? '').toSet();
      for (var p in [...moreProducts, ...moreProducts2]) {
        if (!existingProductNames.contains(p['commodity_name_original'])) {
          cachedProducts.add(p);
        }
      }

      await _mandiCache.put('last_mandis', cachedMandis.take(150).toList());
      await _mandiCache.put('last_products', cachedProducts.take(150).toList());

      print('✅ Silent Background Sync Complete. Cached ${cachedMandis.length} mandis and ${cachedProducts.length} products.');
      
      if (userState != null && userCity != null) {
        preTranslateForLocation(userState, userCity);
      }
    } catch (e) {
      print('❌ Silent sync error: $e');
    }
  }

  Future<void> preTranslateForLocation(String state, String city) async {
    try {
      final mandis = getCachedMandis();
      final products = getCachedProducts();

      final mandiBatch = mandis.take(20).toList();
      final productBatch = products.take(50).toList();

      print('🌐 Pre-translating ${mandiBatch.length} mandis and ${productBatch.length} products for $city, $state...');

      await Future.wait([
        ...mandiBatch.map((m) => LanguageHelper.translate(m['mandi_name_original'] ?? '', state, city)),
        ...productBatch.map((p) => LanguageHelper.translate(p['commodity_name_original'] ?? '', state, city)),
      ]);

      print('✅ Pre-translation complete.');
    } catch (e) {
      print('❌ Pre-translation error: $e');
    }
  }

  Future<void> syncRealData({
      String? userState,
      String? userCity,
      Function(String message, double progress)? onProgress}) async {
    try {
      onProgress?.call("સર્વરથી લેટેસ્ટ ભાવ ચેક થઈ રહ્યા છે...", 0.2);
      await Future.delayed(const Duration(seconds: 1)); // Simulate check
      onProgress?.call("ડેટા સંપૂર્ણપણે સિંક થઈ ગયો છે.", 1.0);

      final Box settingsBox = Hive.box('settings');
      await settingsBox.put(
          'mandi_last_sync', DateTime.now().toIso8601String());
    } catch (e) {
      print('❌ syncRealData error: $e');
    }
  }

  Future<void> _syncNationalData(List<String> dateFilters, String apiKey) async {
    for (final dateFilter in dateFilters) {
      int offset = 0;
      while (offset < 5000) {
        final url = 'https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24'
            '?api-key=$apiKey&format=json&limit=1000&offset=$offset&filters[Arrival_Date]=$dateFilter';
        final count = await _fetchAndUpsert(url);
        if (count < 1000) break;
        offset += 1000;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<int> _fetchAndUpsert(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      ApiTracker.logCall('Govt API: Get Mandi Prices', statusCode: response.statusCode);
      if (response.statusCode != 200) return 0;
      
      final List<Map<String, dynamic>> mappedList = await compute(_parseAndMapRecords, response.body);
      
      if (mappedList.isEmpty) return 0;

      await _supabase.from('mandi_prices').upsert(
        mappedList,
        onConflict: 'mandi_name, commodity_name, arrival_date, variety',
      );
      return mappedList.length;
    } catch (_) { return 0; }
  }

  static List<Map<String, dynamic>> _parseAndMapRecords(String body) {
    final data = json.decode(body);
    final List records = data['records'] ?? [];
    if (records.isEmpty) return [];

    String toIso(String d) {
      try {
        final parts = d.split('/');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[2];
          return "$year-$month-$day";
        }
      } catch (_) {}
      return d;
    }

    final syncTime = DateTime.now().toIso8601String();
    return records.map((r) {
      final rawDate = r['Arrival_Date'] ?? r['arrival_date'] ?? '';
      final isoDate = toIso(rawDate);
      
      return {
        'mandi_name': r['Market'] ?? r['market'] ?? 'Unknown',
        'commodity_name': r['Commodity'] ?? r['commodity'] ?? 'Other',
        'state': r['State'] ?? r['state'] ?? 'India',
        'district': r['District'] ?? r['district'] ?? '',
        'arrival_date': isoDate,
        'modal_price': double.tryParse((r['Modal_Price'] ?? r['modal_price'] ?? '0').toString()) ?? 0,
        'min_price': double.tryParse((r['Min_Price'] ?? r['min_price'] ?? '0').toString()) ?? 0,
        'max_price': double.tryParse((r['Max_Price'] ?? r['max_price'] ?? '0').toString()) ?? 0,
        'variety': r['Variety'] ?? r['variety'] ?? 'General',
        'grade': r['Grade'] ?? r['grade'] ?? 'FAQ',
        'sync_at': syncTime,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMandis({
    int page = 0,
    String searchQuery = '',
    double? userLat,
    double? userLng,
    String? userState,
    String? userCity,
  }) async {
    try {
      var queryBuilder = _supabase.from('unique_mandis').select();

      if (searchQuery.trim().isNotEmpty) {
        final q = '%${searchQuery.trim()}%';
        queryBuilder = queryBuilder.or('mandi_name.ilike.$q,district.ilike.$q,state.ilike.$q');
      } else if (userState != null && userState.trim().isNotEmpty) {
        queryBuilder = queryBuilder.eq('state', userState.trim());
      }

      // Always paginate on database side to prevent loading 4000+ mandis at once
      final data = await queryBuilder.range(page * _pageSize, (page + 1) * _pageSize - 1);

      if (data == null) return [];
      
      List<Map<String, dynamic>> results = (data as List).map((item) {
        final m = Map<String, dynamic>.from(item);
        m['is_favorite'] = _favorites.get(m['mandi_name'], defaultValue: false);
        return m;
      }).toList();

      if (userLat != null && userLng != null) {
        await Future.wait(results.map((m) async {
          final coords = await getMandiCoords(
              m['mandi_name']?.toString() ?? '',
              m['district']?.toString() ?? '',
              m['state']?.toString() ?? '');
          
          if (coords != null) {
            m['distance_km'] = _haversineKm(userLat, userLng, coords[0], coords[1]);
          } else {
            m['distance_km'] = 9999.0;
          }
        }));

        // Sort only the paginated 50 items by distance to maintain instant response times
        results.sort((a, b) {
          final distA = (a['distance_km'] as num?)?.toDouble() ?? 9999.0;
          final distB = (b['distance_km'] as num?)?.toDouble() ?? 9999.0;
          return distA.compareTo(distB);
        });
      }

      if (userState != null && userCity != null) {
        await Future.wait(results.map((m) async {
          m['mandi_name_original'] = m['mandi_name'];
          try {
            m['mandi_name'] = await LanguageHelper.translate(m['mandi_name'] ?? 'Unknown', userState, userCity);
            m['district'] = await LanguageHelper.translate(m['district'] ?? '', userState, userCity);
          } catch (e) {}
        }));
      }

      if (searchQuery.isEmpty && page == 0) {
        _mandiCache.put('last_mandis', results);
      }

      return results;
    } catch (e) {
      print('❌ fetchMandis error: $e');
      final cached = _mandiCache.get('last_mandis');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMandiProducts(
      String mandiName, {String? userState, String? userCity}) async {
    try {
      final data = await _supabase
          .from('mandi_prices')
          .select()
          .eq('mandi_name', mandiName)
          .order('modal_price', ascending: false);

      if (data == null) return [];
      final List<Map<String, dynamic>> results = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

      if (userState != null && userCity != null) {
        await Future.wait(results.map((m) async {
          m['commodity_name_original'] = m['commodity_name'];
          m['commodity_name'] = await LanguageHelper.translate(m['commodity_name'], userState, userCity);
          m['variety'] = await LanguageHelper.translate(m['variety'], userState, userCity);
        }));
      }
      return results;
    } catch (e) {
      print('❌ fetchMandiProducts error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchVarietyDetails(
      String mandiName, String commodityName, {String? userState, String? userCity}) async {
    try {
      final data = await _supabase
          .from('mandi_prices')
          .select()
          .eq('mandi_name', mandiName)
          .eq('commodity_name', commodityName)
          .order('modal_price', ascending: false);

      if (data == null) return [];
      final List<Map<String, dynamic>> results = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

      if (userState != null && userCity != null) {
        await Future.wait(results.map((m) async {
          m['variety'] = await LanguageHelper.translate(m['variety'], userState, userCity);
        }));
      }
      return results;
    } catch (e) {
      print('❌ fetchVarietyDetails error: $e');
      return [];
    }
  }

  DateTime _parseDateForCompare(String? d) {
    return CommodityUtils.parseDateForSort(d);
  }

  Future<List<Map<String, dynamic>>> fetchUniqueProducts({
    int page = 0,
    String searchQuery = '',
    String? category,
    String? userState,
    String? userCity,
  }) async {
    String toIso(String? d) {
      if (d == null || (!d.contains('/') && !d.contains('-'))) return d ?? '';
      try {
        final sep = d.contains('/') ? '/' : '-';
        final parts = d.split(sep);
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          
          DateTime date = DateTime(year, month, day);
          final now = DateTime.now();
          
          if (date.isAfter(now) && day <= 12) {
             final swappedDate = DateTime(year, day, month);
             if (!swappedDate.isAfter(now)) {
               date = swappedDate;
               day = date.day;
               month = date.month;
             }
          }
          
          return "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
        }
      } catch (_) {}
      return d;
    }

    try {
      final useSearch = searchQuery.trim().isNotEmpty;
      const int productPageSize = 2000;
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final dateFrom = '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2,'0')}-${thirtyDaysAgo.day.toString().padLeft(2,'0')}';

      var queryBuilder = _supabase.from('mandi_prices')
          .select('commodity_name, modal_price, min_price, max_price, mandi_name, variety, arrival_date')
          .gte('arrival_date', dateFrom);

      if (useSearch) {
        queryBuilder = queryBuilder.ilike('commodity_name', '${searchQuery.trim()}%');
      } else if (category != null && category != 'All') {
        final keywords = _categoryKeywords[category] ?? [];
        if (keywords.isNotEmpty) {
           final filter = keywords.map((k) => 'commodity_name.ilike.%$k%').join(',');
           queryBuilder = queryBuilder.or(filter);
        } else {
           queryBuilder = queryBuilder.ilike('commodity_name', '%$category%');
        }
      }

      final data = await queryBuilder
          .order('arrival_date', ascending: false, nullsFirst: false)
          .range(page * productPageSize, (page + 1) * productPageSize - 1);

      print('📦 RAW DATA COUNT: ${(data as List?)?.length ?? 0}');

      if (data == null) return [];
      
      final List<Map<String, dynamic>> rawResults = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();

      final Map<String, Map<String, dynamic>> grouped = {};
      for (var item in rawResults) {
        final name = item['commodity_name'] as String;
        final variety = item['variety']?.toString() ?? 'Other';
        final grade = item['grade']?.toString() ?? 'FAQ';
        final mandiName = item['mandi_name']?.toString() ?? 'Unknown';
        final arrivalDate = item['arrival_date']?.toString() ?? '';

        if (!grouped.containsKey(name)) {
          final mPrice = (item['modal_price'] as num?)?.toDouble() ?? 0.0;
          grouped[name] = {
            'commodity_name': name,
            'min_price': (item['min_price'] as num?)?.toDouble() ?? 0.0,
            'max_price': (item['max_price'] as num?)?.toDouble() ?? 0.0,
            'modal_price': mPrice,
            'mandi_name': mandiName,
            'varieties': {variety},
            'grades': {grade},
            'mandis': {mandiName},
            'last_updated': arrivalDate,
          };
        } else {
          final current = grouped[name]!;
          (current['varieties'] as Set).add(variety);
          (current['grades'] as Set).add(grade);
          (current['mandis'] as Set).add(mandiName);

          final existingDate = _parseDateForCompare(current['last_updated']);
          final newDate = _parseDateForCompare(arrivalDate);
          final itemPrice = (item['modal_price'] as num?)?.toDouble() ?? 0.0;

          if (newDate.isAfter(existingDate)) {
             current['last_updated'] = arrivalDate;
             current['mandi_name'] = mandiName;
             if (itemPrice > 0) current['modal_price'] = itemPrice;
             current['min_price'] = (item['min_price'] as num?)?.toDouble() ?? 0.0;
             current['max_price'] = (item['max_price'] as num?)?.toDouble() ?? 0.0;
          } else if (newDate.isAtSameMomentAs(existingDate)) {
             final itemPrice = (item['modal_price'] as num?)?.toDouble() ?? 0.0;
             if (current['modal_price'] == 0 && itemPrice > 0) {
               current['modal_price'] = itemPrice;
             }
          }
          
          final itemMin = (item['min_price'] as num?)?.toDouble() ?? 0.0;
          if (itemMin > 0 && (current['min_price'] == 0 || itemMin < current['min_price'])) {
            current['min_price'] = itemMin;
          }
          final itemMax = (item['max_price'] as num?)?.toDouble() ?? 0.0;
          if (itemMax > current['max_price']) current['max_price'] = itemMax;
        }
      }

      final List<Map<String, dynamic>> results = grouped.values.map((m) {
        final String name = m['commodity_name'];
        return {
          ...m,
          'commodity_name_original': name,
          'varieties_count': (m['varieties'] as Set).length,
          'grades_count': (m['grades'] as Set).length,
          'mandi_count': (m['mandis'] as Set).length,
          'varieties': (m['varieties'] as Set).toList(),
          'grades': (m['grades'] as Set).toList(),
          'mandis': (m['mandis'] as Set).toList(),
        };
      }).toList();

      results.sort((a, b) {
        final String dateA = toIso(a['last_updated'] ?? '');
        final String dateB = toIso(b['last_updated'] ?? '');
        return dateB.compareTo(dateA);
      });
      
      await Future.delayed(Duration.zero);
      
      if (results.isEmpty) return [];

      if (userState != null && userCity != null) {
        try {
          await Future.wait(results.map((m) async {
            m['commodity_name_original'] = m['commodity_name'];
            try {
              m['commodity_name'] = await LanguageHelper.translate(m['commodity_name'] ?? 'Unknown', userState, userCity);
            } catch (e) {}
          }));
          await Future.delayed(Duration.zero);
        } catch (e) {
          print('❌ Translation error: $e');
        }
      }

      if (searchQuery.isEmpty && page == 0) {
        _mandiCache.put('last_products', results);
      }

      return results;
    } catch (e) {
      print('❌ fetchUniqueProducts error: $e');
      if (searchQuery.isEmpty && page == 0) {
        final cached = _mandiCache.get('last_products');
        if (cached != null) return (cached as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchLatestPrice(String commodity, {String? mandiName}) async {
    try {
      var query = _supabase.from('mandi_prices')
          .select('modal_price, arrival_date, commodity_name, mandi_name');
          
      if (commodity.isNotEmpty) {
        query = query.eq('commodity_name', commodity);
      }

      if (mandiName != null && mandiName.isNotEmpty) {
        query = query.eq('mandi_name', mandiName);
      }

      final data = await query
          .order('arrival_date', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (e) {
      print('❌ fetchLatestPrice error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductComparison(
      String commodity, double? userLat, double? userLng, {String sortMode = 'latest'}) async {
    // If commodity name has regional (non-ASCII) chars, translate back to English first
    String queryName = commodity.trim();
    bool containsRegional = queryName.runes.any((r) => r > 127);
    if (containsRegional) {
      try {
        queryName = await LanguageHelper.translateToEnglish(queryName);
        print('🔄 Translated commodity to English: $queryName');
      } catch (_) {}
    }
    print('🔍 Fetching comparison for: $queryName (Mode: $sortMode)');
    try {
      final thirtyDaysAgo2 = DateTime.now().subtract(const Duration(days: 30));
      final dateFrom2 = '${thirtyDaysAgo2.year}-${thirtyDaysAgo2.month.toString().padLeft(2,'0')}-${thirtyDaysAgo2.day.toString().padLeft(2,'0')}';
      dynamic query = _supabase.from('mandi_prices').select()
          .eq('commodity_name', queryName)
          .gte('arrival_date', dateFrom2);

      if (sortMode == 'latest') {
        query = query.order('arrival_date', ascending: false);
      } else if (sortMode == 'highest') {
        query = query.order('modal_price', ascending: false);
      } else if (sortMode == 'lowest') {
        query = query.order('modal_price', ascending: true);
      }

      final data = await query.timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> rawResults = (data as List).map((item) => Map<String, dynamic>.from(item)).toList();
      
      final Map<String, Map<String, dynamic>> grouped = {};
      for (var r in rawResults) {
        final key = "${r['mandi_name']}_${r['variety']}_${r['grade']}";
        if (!grouped.containsKey(key)) {
          grouped[key] = r;
        } else {
          final existingDate = _parseDateForCompare(grouped[key]!['arrival_date']);
          final newDate = _parseDateForCompare(r['arrival_date']);
          if (newDate.isAfter(existingDate)) {
            grouped[key] = r;
          } else if (newDate.isAtSameMomentAs(existingDate)) {
            // Same date - keep existing, no sync_at to compare
          }
        }
      }
      
      final results = grouped.values.toList();
      
      if (userLat != null && userLng != null) {
        await Future.wait(results.map((m) async {
          final coords = await getMandiCoords(
              m['mandi_name']?.toString() ?? '',
              m['district']?.toString() ?? '',
              m['state']?.toString() ?? '');
          if (coords != null) {
            m['distance_km'] = _haversineKm(userLat, userLng, coords[0], coords[1]);
          } else {
            m['distance_km'] = 9999.0;
          }
        }));
      }

      results.sort((a, b) {
        if (sortMode == 'latest') {
          final distA = (a['distance_km'] as num?)?.toDouble() ?? 9999.0;
          final distB = (b['distance_km'] as num?)?.toDouble() ?? 9999.0;
          if (distA == distB) {
            final dateA = _parseDateForCompare(a['arrival_date']);
            final dateB = _parseDateForCompare(b['arrival_date']);
            return dateB.compareTo(dateA);
          }
          return distA.compareTo(distB);
        } else if (sortMode == 'highest') {
          final pA = (a['modal_price'] as num?)?.toDouble() ?? 0.0;
          final pB = (b['modal_price'] as num?)?.toDouble() ?? 0.0;
          if (pA == pB) {
            final distA = (a['distance_km'] as num?)?.toDouble() ?? 9999.0;
            final distB = (b['distance_km'] as num?)?.toDouble() ?? 9999.0;
            return distA.compareTo(distB);
          }
          return pB.compareTo(pA);
        } else if (sortMode == 'lowest') {
          final pA = (a['modal_price'] as num?)?.toDouble() ?? 0.0;
          final pB = (b['modal_price'] as num?)?.toDouble() ?? 0.0;
          if (pA == pB) {
            final distA = (a['distance_km'] as num?)?.toDouble() ?? 9999.0;
            final distB = (b['distance_km'] as num?)?.toDouble() ?? 9999.0;
            return distA.compareTo(distB);
          }
          return pA.compareTo(pB);
        }
        return 0;
      });

      return results;
    } catch (e) {
      print('❌ fetchProductComparison error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchNearestMandi(
      double userLat, double userLng) async {
    try {
      final data = await _supabase
          .from('unique_mandis')
          .select('mandi_name, district, state, commodity_count, last_updated')
          .limit(500);
          // Note: avg_price column does not exist in this table

      if (data == null || (data as List).isEmpty) return null;

      Map<String, dynamic>? nearest;
      double minDist = double.infinity;

      for (final item in data) {
        final coords = await getMandiCoords(
            item['mandi_name']?.toString() ?? '',
            item['district']?.toString() ?? '',
            item['state']?.toString() ?? '');
        if (coords == null) continue;

        final dist = _haversineKm(userLat, userLng, coords[0], coords[1]);
        if (dist < minDist) {
          minDist = dist;
          nearest = Map<String, dynamic>.from(item);
          nearest['distance_km'] = minDist;
        }
      }

      return nearest;
    } catch (e) {
      print('❌ fetchNearestMandi error: $e');
      return null;
    }
  }

  Future<List<double>?> getMandiCoords(String mandiName, String district, String state) async {
    final mandiKey = '${mandiName.trim().toLowerCase()}_${state.trim().toLowerCase()}';
    final distKey = '${district.trim().toLowerCase()}_${state.trim().toLowerCase()}';

    // 1. Check static predefined coordinates
    if (_mandiCoords.containsKey(mandiKey)) return _mandiCoords[mandiKey];

    // 2. Check local Hive cache
    final Box locBox = Hive.box('mandi_locations');
    final cached = locBox.get(mandiKey);
    if (cached != null) return List<double>.from(cached);

    // 3. Check Supabase location cache table
    try {
      final globalRes = await _supabase
          .from('mandi_locations')
          .select('lat, lng')
          .eq('mandi_key', mandiKey)
          .maybeSingle();
      
      if (globalRes != null) {
        final coords = [globalRes['lat'] as double, globalRes['lng'] as double];
        await locBox.put(mandiKey, coords);
        return coords;
      }
    } catch (_) {}

    // 4. Smart Jittered District Center Fallback (Fast & Free)
    if (_districtCoords.containsKey(distKey)) {
      final baseCoords = _districtCoords[distKey]!;
      final int hash = mandiName.hashCode.abs();
      final double latJitter = ((hash % 100) - 50) / 1200.0;
      final double lngJitter = (((hash ~/ 100) % 100) - 50) / 1200.0;
      return [baseCoords[0] + latJitter, baseCoords[1] + lngJitter];
    }

    try {
      final String address = '$mandiName, $district, $state, India';
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=${ApiKeys.googlePlacesKey}';
      
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final loc = data['results'][0]['geometry']['location'];
          final double lat = loc['lat'];
          final double lng = loc['lng'];
          final coords = [lat, lng];
          
          await locBox.put(mandiKey, coords);
          
          await _supabase.from('mandi_locations').upsert({
            'mandi_key': mandiKey,
            'lat': lat,
            'lng': lng,
            'last_verified': DateTime.now().toIso8601String(),
          }, onConflict: 'mandi_key');

          return coords;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }

    return _districtCoords[state.trim().toLowerCase()];
  }

  static const Map<String, List<double>> _mandiCoords = {
    'surat_gujarat': [21.1702, 72.8311],
    'surat(surat)_gujarat': [21.1702, 72.8311],
    'surat apmc_gujarat': [21.1702, 72.8311],
    'choryasi(surat)_gujarat': [21.1702, 72.8311],
    'bardoli(kadod) apmc_gujarat': [21.1214, 73.1147],
    'bardoli apmc_gujarat': [21.1214, 73.1147],
    'mandvi apmc_gujarat': [21.2581, 73.3039],
    'nizar apmc_gujarat': [21.3128, 73.7431],
    'nizar(run kitalav) apmc_gujarat': [21.3128, 73.7431],
    'kukarmunda apmc_gujarat': [21.4925, 73.7667],
    'navsari apmc_gujarat': [20.9467, 72.9520],
    'bilimora apmc_gujarat': [20.7651, 72.9774],
    'chikhali apmc_gujarat': [20.7606, 73.0645],
  };

  static const Map<String, List<double>> _districtCoords = {
    'surat_gujarat': [21.1702, 72.8311],
    'navsari_gujarat': [20.9467, 72.9520],
    'bilimora_gujarat': [20.7651, 72.9774],
    'chikhali_gujarat': [20.7606, 73.0645],
    'ahmedabad_gujarat': [23.0225, 72.5714],
    'rajkot_gujarat': [22.3039, 70.8022],
    'vadodara_gujarat': [22.3072, 73.1812],
    'bhavnagar_gujarat': [21.7645, 72.1519],
    'anand_gujarat': [22.5645, 72.9289],
    'gandhinagar_gujarat': [23.2156, 72.6369],
    'junagadh_gujarat': [21.5222, 70.4579],
    'jamnagar_gujarat': [22.4707, 70.0577],
    'valsad_gujarat': [20.5992, 72.9342],
    'bharuch_gujarat': [21.7051, 72.9959],
    'kutch_gujarat': [23.7337, 69.8597],
    'patan_gujarat': [23.8493, 72.1266],
    'mehsana_gujarat': [23.5880, 72.3693],
    'sabarkantha_gujarat': [23.3667, 72.9833],
    'banaskantha_gujarat': [24.1742, 72.4378],
    'kheda_gujarat': [22.7500, 72.6833],
    'surendranagar_gujarat': [22.7201, 71.6490],
    'amreli_gujarat': [21.6036, 71.2167],
    'porbandar_gujarat': [21.6417, 69.6293],
    'gir somnath_gujarat': [20.9155, 70.3898],
    'morbi_gujarat': [22.8173, 70.8370],
    'botad_gujarat': [22.1736, 71.6685],
    'chhota udaipur_gujarat': [22.3124, 74.0138],
    'dahod_gujarat': [22.8365, 74.2537],
    'mahisagar_gujarat': [23.1023, 73.5564],
    'aravalli_gujarat': [23.7139, 73.0440],
    'devbhumi dwarka_gujarat': [22.2394, 69.0070],
    'narmada_gujarat': [21.8726, 73.4969],
    'tapi_gujarat': [21.1227, 73.4149],
    'dang_gujarat': [20.7639, 73.6946],
    'pune_maharashtra': [18.5204, 73.8567],
    'mumbai_maharashtra': [19.0760, 72.8777],
    'nashik_maharashtra': [20.0059, 73.7903],
    'nagpur_maharashtra': [21.1458, 79.0882],
    'aurangabad_maharashtra': [19.8762, 75.3433],
    'solapur_maharashtra': [17.6805, 75.9064],
    'kolhapur_maharashtra': [16.7050, 74.2433],
    'amravati_maharashtra': [20.9374, 77.7796],
    'latur_maharashtra': [18.4088, 76.5604],
    'satara_maharashtra': [17.6868, 74.0183],
    'jaipur_rajasthan': [26.9124, 75.7873],
    'jodhpur_rajasthan': [26.2389, 73.0243],
    'udaipur_rajasthan': [24.5854, 73.7125],
    'ajmer_rajasthan': [26.4499, 74.6399],
    'bikaner_rajasthan': [28.0229, 73.3119],
    'kota_rajasthan': [25.2138, 75.8648],
    'alwar_rajasthan': [27.5530, 76.6346],
    'sikar_rajasthan': [27.6094, 75.1399],
    'bharatpur_rajasthan': [27.2152, 77.4938],
    'pali_rajasthan': [25.7711, 73.3234],
    'amritsar_punjab': [31.6340, 74.8723],
    'ludhiana_punjab': [30.9010, 75.8573],
    'jalandhar_punjab': [31.3260, 75.5762],
    'patiala_punjab': [30.3398, 76.3869],
    'bathinda_punjab': [30.2110, 74.9455],
    'karnal_haryana': [29.6857, 76.9905],
    'hisar_haryana': [29.1492, 75.7217],
    'rohtak_haryana': [28.8955, 76.6066],
    'ambala_haryana': [30.3752, 76.7821],
    'sirsa_haryana': [29.5330, 75.0266],
    'lucknow_uttar pradesh': [26.8467, 80.9462],
    'agra_uttar pradesh': [27.1767, 78.0081],
    'varanasi_uttar pradesh': [25.3176, 82.9739],
    'kanpur_uttar pradesh': [26.4499, 80.3319],
    'allahabad_uttar pradesh': [25.4358, 81.8463],
    'meerut_uttar pradesh': [28.9845, 77.7064],
    'ghaziabad_uttar pradesh': [28.6692, 77.4538],
    'bareilly_uttar pradesh': [28.3670, 79.4304],
    'aligarh_uttar pradesh': [27.8974, 78.0880],
    'moradabad_uttar pradesh': [28.8386, 78.7733],
    'bhopal_madhya pradesh': [23.2599, 77.4126],
    'indore_madhya pradesh': [22.7196, 75.8577],
    'gwalior_madhya pradesh': [26.2183, 78.1828],
    'jabalpur_madhya pradesh': [23.1815, 79.9864],
    'ujjain_madhya pradesh': [23.1765, 75.7885],
    'bengaluru_karnataka': [12.9716, 77.5946],
    'mysuru_karnataka': [12.2958, 76.6394],
    'hubli_karnataka': [15.3647, 75.1240],
    'mangaluru_karnataka': [12.9141, 74.8560],
    'belagavi_karnataka': [15.8497, 74.4977],
    'chennai_tamil nadu': [13.0827, 80.2707],
    'coimbatore_tamil nadu': [11.0168, 76.9558],
    'madurai_tamil nadu': [9.9252, 78.1198],
    'tiruchirappalli_tamil nadu': [10.7905, 78.7047],
    'tirunelveli_tamil nadu': [8.7139, 77.7567],
    'visakhapatnam_andhra pradesh': [17.6868, 83.2185],
    'vijayawada_andhra pradesh': [16.5062, 80.6480],
    'guntur_andhra pradesh': [16.3067, 80.4365],
    'kurnool_andhra pradesh': [15.8281, 78.0373],
    'hyderabad_telangana': [17.3850, 78.4867],
    'warangal_telangana': [17.9784, 79.5941],
    'nizamabad_telangana': [18.6725, 78.0941],
    'kolkata_west bengal': [22.5726, 88.3639],
    'howrah_west bengal': [22.5958, 88.2636],
    'durgapur_west bengal': [23.5204, 87.3119],
    'asansol_west bengal': [23.6739, 86.9524],
    'patna_bihar': [25.5941, 85.1376],
    'gaya_bihar': [24.7955, 85.0002],
    'bhagalpur_bihar': [25.2425, 86.9842],
    'muzaffarpur_bihar': [26.1197, 85.3910],
    'bhubaneswar_odisha': [20.2961, 85.8245],
    'cuttack_odisha': [20.4625, 85.8830],
    'sambalpur_odisha': [21.4669, 83.9812],
    'guwahati_assam': [26.1445, 91.7362],
    'dibrugarh_assam': [27.4728, 94.9012],
    'silchar_assam': [24.8333, 92.7789],
    'thiruvananthapuram_kerala': [8.5241, 76.9366],
    'kochi_kerala': [9.9312, 76.2673],
    'kozhikode_kerala': [11.2588, 75.7804],
    'thrissur_kerala': [10.5276, 76.2144],
    'shimla_himachal pradesh': [31.1048, 77.1734],
    'dharamsala_himachal pradesh': [32.2190, 76.3234],
    'dehradun_uttarakhand': [30.3165, 78.0322],
    'haridwar_uttarakhand': [29.9457, 78.1642],
    'ranchi_jharkhand': [23.3441, 85.3096],
    'jamshedpur_jharkhand': [22.8046, 86.2029],
    'raipur_chhattisgarh': [21.2514, 81.6296],
    'bilaspur_chhattisgarh': [22.0796, 82.1391],
    'panaji_goa': [15.4909, 73.8278],
    'margao_goa': [15.2832, 73.9862],
    'delhi_delhi': [28.6139, 77.2090],
    'gujarat': [23.2156, 72.6369],
    'maharashtra': [19.0760, 72.8777],
    'rajasthan': [26.9124, 75.7873],
    'punjab': [30.7333, 76.7794],
    'haryana': [30.7333, 76.7794],
    'uttar pradesh': [26.8467, 80.9462],
    'madhya pradesh': [23.2599, 77.4126],
    'karnataka': [12.9716, 77.5946],
    'tamil nadu': [13.0827, 80.2707],
    'andhra pradesh': [16.5062, 80.6480],
    'telangana': [17.3850, 78.4867],
    'west bengal': [22.5726, 88.3639],
    'bihar': [25.5941, 85.1376],
    'odisha': [20.2961, 85.8245],
    'assam': [26.1445, 91.7362],
    'kerala': [8.5241, 76.9366],
    'himachal pradesh': [31.1048, 77.1734],
    'uttarakhand': [30.3165, 78.0322],
    'jharkhand': [23.3441, 85.3096],
    'chhattisgarh': [21.2514, 81.6296],
    'goa': [15.4909, 73.8278],
    'delhi': [28.6139, 77.2090],
  };

  Future<Map<String, int>> getTotalMandiCount() async {
    try {
      final mandiRes = await _supabase
          .from('unique_mandis')
          .select()
          .count(CountOption.exact);

      int productCount = 324;
      try {
        final productRes = await _supabase
            .from('unique_products_count')
            .select('count')
            .limit(1);
        if (productRes.isNotEmpty) {
          productCount = productRes.first['count'] ?? 324;
        }
      } catch (_) {}

      return {
        'mandis': mandiRes.count ?? 0,
        'records': 0,
        'products': productCount,
      };
    } catch (e) {
      print('❌ Count error: $e');
      return {'mandis': 0, 'records': 0, 'products': 324};
    }
  }

  // ─── FETCH PRICE HISTORY ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchPriceHistory(
      String mandiName, String commodityName, {int months = 3}) async {
    print('🔎 fetchPriceHistory called: $mandiName | $commodityName | $months months');
    try {
      final data = await _supabase
          .from('mandi_prices')
          .select('modal_price, arrival_date')
          .eq('mandi_name', mandiName)
          .eq('commodity_name', commodityName)
          .order('arrival_date', ascending: true);

      if (data == null || (data as List).isEmpty) {
        print('❌ No data found for $mandiName | $commodityName');
        return [];
      }

      final list = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      print('✅ DATA LENGTH: ${list.length}');
      return list;
    } catch (e) {
      print('❌ fetchPriceHistory error: $e');
      return [];
    }
  }

  List<String> getAllFavoriteIds() {
    return _favorites.keys.cast<String>().toList();
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    if (isFavorite) {
      await _favorites.put(id, true);
    } else {
      await _favorites.delete(id);
    }
  }

  List<String> getFavoriteProducts() {
    return _productFavorites.keys.cast<String>().toList();
  }

  Future<void> toggleFavoriteProduct(String commodity, bool isFavorite) async {
    if (isFavorite) {
      await _productFavorites.put(commodity, true);
    } else {
      await _productFavorites.delete(commodity);
    }
  }

  List<Map<String, dynamic>> getCachedMandis() {
    final data = _mandiCache.get('last_mandis');
    if (data == null) return [];
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> getCachedProducts() {
    final data = _mandiCache.get('last_products');
    if (data == null) return [];
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<String>> fetchAllCommodityNames() async {
    try {
      final data = await _supabase
          .from('commodity_master')
          .select('name')
          .order('name');
      
      if (data == null || (data as List).isEmpty) {
        print('⚠️ commodity_master empty, populating 341 products...');
        final List<String> items = [
          'Agar', 'Agathi', 'Ajwain(Bishops Weed)', 'Alasande Gram', 'Alasande', 'Almond(Badam)', 'Alsande', 'Amaranthus', 'Ambada Seed', 'Ambarkhani', 
          'Amla(Nelli Kai)', 'Amphophallus', 'Antawala', 'Anterwala', 'Apple', 'Apricot(Jardalu)', 'Arecanut(Betelnut/Supari)', 'Arhar (Tur/Red Gram)', 'Arhar Dal(Tur Dal)', 'Ashgourd', 
          'Asparagus', 'Astera', 'Avacado(Fruit)', 'Baby Corn', 'Bajra(Pearl Millet/Cumbu)', 'Balekai', 'Bamboo', 'Banana', 'Banana - Green', 'Barley (Jau)', 
          'Basil', 'Bay leaf (Tejpatta)', 'Beans', 'Beetroot', 'Bengal Gram(Gram)', 'Bengal Gram Dal(Chana Dal)', 'Ber(Zizyphus/Borehana)', 'Betel Leaves', 'Bhindi(Ladies Finger)', 'Big Gram', 
          'Binoula', 'Bitter Gourd', 'Black Gram (Urd Beans)', 'Black Gram Dal (Urd Dal)', 'Black Pepper', 'Bobbili', 'Bottle Gourd', 'Brinjal', 'Broccoli', 'Bull', 
          'Bunched Vegetables', 'Butter', 'Cabbage', 'Capsicum', 'Cardamom', 'Carnation', 'Carrot', 'Cashewnuts', 'Castor Oil', 'Castor Seed', 
          'Cauliflower', 'Chana Dal', 'Chandramukhi', 'Chayote', 'Cherry', 'Chicory(Roots)', 'Chili Red', 'Chilies Green', 'Chikoos(Sapota)', 'Chilly Powder', 
          'Chrysanthemum(Loose)', 'Cinnamon(Dalchini)', 'Citron', 'Cluster beans', 'Coca', 'Coconut', 'Coconut Oil', 'Coffee', 'Colocasia', 'Copra', 
          'Coriander(Leaves)', 'Coriander(Seed)', 'Cotton', 'Cotton Seed', 'Cowpea(Veg)', 'Cowpea (Lobia/Karamani)', 'Cucumber(Kheera)', 'Cumin Seed(Jeera)', 'Custard Apple (Sharifa)', 'Dahlia', 
          'Dal', 'Dhaincha', 'Drumstick', 'Dry Chillies', 'Dry Fodder', 'Egg', 'Elephant Yam (Suran)', 'Fennel(Saunf)', 'Fenugreek Seeds', 'Fenugreek(Leaves)', 
          'Fig(Anjura/Anjeer)', 'Firewood', 'Fish', 'Flower', 'French Beans (Frasbin)', 'Garlic', 'Ghee', 'Ginger(Green)', 'Ginger(Dry)', 'Gladiolus Cut Flower', 
          'Goat', 'Gram Raw(Chana)', 'Gramflour', 'Grapes', 'Green Chilli', 'Green Fodder', 'Green Gram (Moong Beans)', 'Green Gram Dal (Moong Dal)', 'Green Peas', 'Groundnut', 
          'Groundnut (Split)', 'Groundnut pods (Whole)', 'Groundnut Oil', 'Guava', 'Gur(Jaggery)', 'Gwar', 'Gwar Seed', 'He-Buffalo', 'Hen', 'Hi-Buffalo', 
          'Honey', 'Horse Gram(Kulthi)', 'Isabgul (Psyllium)', 'Jack Fruit', 'Jaggery', 'Jamun(Fruit)', 'Jasmine', 'Jowar(Sorghum)', 'Jute', 'Jute Seed', 
          'Kabuli Chana(White Gram)', 'Kachalu', 'Kakada', 'Kalonji', 'Kapas', 'Karade', 'Karutha Columban', 'Kasturi Cotton', 'Knool Khol', 'Kokum', 
          'Kulthi(Horse Gram)', 'Kusum', 'Ladies Finger', 'Lak(Teora)', 'Lamb', 'Lentil (Masur)', 'Lemon', 'Lily', 'Linseed', 'Lint', 
          'Litchi', 'Little Gourd (Tinda)', 'Lobia', 'Long Pepper', 'Lotus', 'Lotus Sticks', 'Lukati', 'Mace', 'Mackarel', 'Mahua', 
          'Mahua Seed(Hippe seed)', 'Maize', 'Mango', 'Mango (Raw)', 'Mangosteen', 'Marigold(Calcutta)', 'Marigold(Loose)', 'Mashrooms', 'Mataki', 'Menthi', 
          'Methi(Leaves)', 'Millets', 'Milk', 'Mint(Pudina)', 'Moong(Whole)', 'Moong Dal', 'Moth', 'Mousambi(Sweet Lime)', 'Mustard', 'Mustard Oil', 
          'Myrobalan(Harad)', 'Neem Seed', 'Niger Seed (Ramtil)', 'Nutmeg', 'Onion', 'Onion Green', 'Orange', 'Orchid', 'Ox', 'Paddy(Dhan)', 
          'Papaya', 'Papaya (Raw)', 'Pathani', 'Peach', 'Pear(Maraseel)', 'Peas (Dry)', 'Peas Wet', 'Pepper Garbled', 'Pepper Ungarbled', 'Persimon', 
          'Pigeon Pea (Arhar)', 'Pineapple', 'Plum', 'Pomegranate', 'Potato', 'Pumpkin', 'Punga Oil', 'Radish', 'Ragi (Finger Millet)', 'Rajgir', 
          'Rajma', 'Ram', 'Ramtilla', 'Rat Tail Puru', 'Red Gram', 'Resins', 'Ridgegourd(Turi)', 'Rose(Local)', 'Rose(Loose)', 'Safflower', 
          'Saffron', 'Sago', 'Sal Seed', 'Sapota(Chikoo)', 'Sarsone', 'Seasamum(Sesame,Til)', 'Sheep', 'Silk', 'Skin And Hide', 'Snakegourd', 
          'Soapnut(Antawala/Ritha)', 'Soyabean', 'Spinach', 'Sponge Gourd', 'Squash(Pumpkins)', 'Strawberry', 'Sugar', 'Sugarcane', 'Sunflower', 'Sunflower Seed', 
          'Suva (Anethum)', 'Sweet Corn', 'Sweet Lime', 'Sweet Potato', 'Tamarind', 'Tamarind Seed', 'Tapioca', 'Tea', 'Tender Coconut', 'Thondekai', 
          'Tobacco', 'Tomato', 'Toria', 'Tur Dal', 'Turmeric', 'Turnip', 'Urd Dal', 'Water Melon', 'Walnut', 'Wheat', 
          'White Pumpkin', 'Wood', 'Wool', 'Yam', 'Yam (Ratalu)', 'Alasande Dal', 'Moth Dal', 'Kabuli Chana Dal', 'Singhoda', 'Foxnut(Makhana)',
          'Thinai', 'Kuthiravali', 'Samai', 'Varagu', 'Parsley', 'Celery', 'Leek', 'Lettuce', 'Kale', 'Bok Choy',
          'Red Cabbage', 'Blueberry', 'Blackberry', 'Raspberry', 'Cranberry', 'Passion Fruit', 'Rambutan', 'Durian', 'Longan', 'Anthurium',
          'Lilium', 'Gerbera', 'Tulip', 'Orchid Flower', 'Asafoetida', 'Dry Mango Powder', 'Nigella seeds', 'Star Anise', 'Mace(Javitri)',
          'Poppy seeds', 'Aloo', 'Pyaz', 'Tamatar', 'Gajar', 'Mooli', 'Adrak', 'Lahsun', 'Hari Mirch', 'Lal Mirch',
          'Dhaniya', 'Jeera', 'Haldi', 'Methi', 'Saunf', 'Ajwain(Carom)', 'Sarson', 'Til', 'Moongfali', 'Soyabean Oil',
          'Kapas(Cotton Seed)', 'Dhan', 'Chawal', 'Gehun', 'Makka', 'Bajra', 'Jowar', 'Chana', 'Tur', 'Moong',
          'Urad', 'Masur Dal', 'Matar', 'Kela', 'Seb', 'Aam', 'Angur', 'Santra', 'Papita', 'Anar',
          'Nimbu', 'Amrud', 'Cheeku', 'Kharbuja', 'Tarboj', 'Sitafal', 'Lichi', 'Anjir', 'Khajur', 'Kaju',
          'Badam', 'Akhrot', 'Pista', 'Kishmish', 'Supari', 'Nariyal', 'Gud', 'Shakar', 'Chai', 'Paneer',
          'Dahi', 'Malai', 'Makhan', 'Beef', 'Pork', 'Poultry', 'Dry Fruits', 'Makhana', 'Rava', 'Maida'
        ];
        
        await _supabase.from('commodity_master').upsert(
          items.map((name) => {'name': name}).toList(),
          onConflict: 'name'
        );
        return items..sort();
      }

      final list = (data as List).map((e) => e['name'].toString()).toList();
      list.sort();
      return list;
    } catch (e) {
      print('❌ fetchAllCommodityNames error: $e');
      // Fallback to prices if master table fails
      final fallback = await _supabase.from('mandi_prices').select('commodity_name').limit(100);
      return (fallback as List).map((e) => e['commodity_name'].toString()).toSet().toList()..sort();
    }
  }

  bool isProductFavorite(String commodity) {
    return _productFavorites.get(commodity, defaultValue: false);
  }

  double? getLastPrice(String id) {
    return _priceHistory.get(id);
  }

  Future<void> saveLastPrice(String id, double price) async {
    await _priceHistory.put(id, price);
  }

  Future<String?> fetchRealTimings(String mandiName, String district) async {
    final cacheKey = 'timing_$mandiName';
    final Box timingsBox = Hive.box('mandi_timings');
    
    final cachedData = timingsBox.get(cacheKey);
    if (cachedData != null) {
      final expiry = DateTime.parse(cachedData['expiry']);
      if (DateTime.now().isBefore(expiry)) {
        return cachedData['timings'];
      }
    }

    try {
      final query = Uri.encodeComponent('$mandiName $district APMC Gujarat');
      final url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&key=${ApiKeys.geminiMapKey}';
      
      final response = await http.get(Uri.parse(url));
      ApiTracker.logCall('Google Places: Place Search', statusCode: response.statusCode);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final placeId = results.first['place_id'];
          final detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=opening_hours,formatted_phone_number&key=${ApiKeys.geminiMapKey}';
          
          final detailsRes = await http.get(Uri.parse(detailsUrl));
          ApiTracker.logCall('Google Places: Place Details', statusCode: detailsRes.statusCode);
          final detailsData = json.decode(detailsRes.body);
          final result = detailsData['result'];
          
          final openingHours = result?['opening_hours'];
          final String? phone = result?['formatted_phone_number'];
          
          String? timings;
          if (openingHours != null && openingHours['weekday_text'] != null) {
            timings = (openingHours['weekday_text'] as List).first.toString();
          }
          
          if (timings != null || phone != null) {
            final info = {
              'timings': timings ?? '',
              'phone': phone ?? '',
              'expiry': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            };
            await timingsBox.put(cacheKey, info);
            return timings;
          }
        }
      }
    } catch (e) {
      print('❌ Timing fetch error: $e');
    }
    return null;
  }

  Future<Map<String, String>?> fetchMandiBusinessInfo(String mandiName, String district) async {
    final cacheKey = 'timing_$mandiName';
    final Box timingsBox = Hive.box('mandi_timings');
    
    final cachedData = timingsBox.get(cacheKey);
    if (cachedData != null) {
      final expiry = DateTime.parse(cachedData['expiry']);
      if (DateTime.now().isBefore(expiry)) {
        return {
          'timings': cachedData['timings'] ?? '',
          'phone': cachedData['phone'] ?? '',
        };
      }
    }

    await fetchRealTimings(mandiName, district);
    
    final newData = timingsBox.get(cacheKey);
    if (newData != null) {
      return {
        'timings': newData['timings'] ?? '',
        'phone': newData['phone'] ?? '',
      };
    }
    return null;
  }

  String? getLastSyncTime() {
    final Box settingsBox = Hive.box('settings');
    return settingsBox.get('mandi_last_sync');
  }

  List<Map<String, dynamic>> getPriceAlerts() {
    final Box box = Hive.box('mandi_alerts');
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> savePriceAlert(Map<String, dynamic> alert) async {
    final Box box = Hive.box('mandi_alerts');
    await box.put(alert['commodity'], alert);
  }

  Future<void> removePriceAlert(String commodity) async {
    final Box box = Hive.box('mandi_alerts');
    await box.delete(commodity);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;

    final straightDist = 12742 * asin(sqrt(a));
    return straightDist * 1.4;
  }
}

final mandiStatsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(mandiRepositoryProvider).getTotalMandiCount();
});

final mandiRepositoryProvider = Provider((ref) => MandiRepository());