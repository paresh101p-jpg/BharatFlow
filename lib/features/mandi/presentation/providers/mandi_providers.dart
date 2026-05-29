import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';
import 'package:bharat_flow/core/providers/location_provider.dart';
import 'package:bharat_flow/core/providers/general_providers.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';

// ─── FILTERS ─────────────────────────────────────────────────────────────────

class MandiFilters {
  final String searchQuery;
  final int page;

  const MandiFilters({
    this.searchQuery = '',
    this.page = 0,
  });

  MandiFilters copyWith({String? searchQuery, int? page}) {
    return MandiFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
    );
  }
}

final mandiFilterProvider =
    StateProvider<MandiFilters>((ref) => const MandiFilters());

final mandiTabCategoryProvider = StateProvider<String>((ref) => 'All');
final mandiTabInitialIndexProvider = StateProvider<int>((ref) => 0);
final mandiStandaloneModeProvider = StateProvider<String?>((ref) => null);
final homeTabModeProvider =
    StateProvider<String>((ref) => 'home'); // 'home' or 'mandi'
final priceUnitProvider = StateProvider<String>((ref) => 'Quintal');

// ─── MANDI LIST STATE ─────────────────────────────────────────────────────────

class MandiPricesState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool hasMore;

  const MandiPricesState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
  });

  MandiPricesState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? hasMore,
  }) {
    return MandiPricesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ─── MANDI LIST NOTIFIER ──────────────────────────────────────────────────────

class MandiPricesNotifier extends StateNotifier<MandiPricesState> {
  final MandiRepository _repo;
  final Ref _ref;
  UserLocation? _currentLocation;
  String _lastQuery = '';
  int _searchCounter = 0;

  MandiPricesNotifier(this._repo, this._ref, [this._currentLocation])
      : super(const MandiPricesState(items: [])) {
    // Auto-reload when location is first acquired
    _ref.listen<UserLocation>(locationProvider, (prev, next) {
      if (_currentLocation == null ||
          _currentLocation!.address != next.address) {
        _currentLocation = next;
        loadInitial(searchQuery: _lastQuery);
      }
    });

    loadInitial();

    // AUTOMATIC BACKGROUND SYNC: No manual refresh needed
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        final loc = _ref.read(locationProvider);
        await _repo.performSilentLocalSync(
            userState: loc.state, userCity: loc.city);
        if (mounted) {
          await loadInitial(searchQuery: _lastQuery);
        }
      } catch (e) {
        print('❌ Background sync error: $e');
      }
    });
  }

  Future<void> loadInitial({String searchQuery = ''}) async {
    _lastQuery = searchQuery;
    final UserLocation location =
        _currentLocation ?? _ref.read(locationProvider);

    final int currentSearchId = ++_searchCounter;

    // 1. Try to load from cache first for instant UI
    if (searchQuery.isEmpty) {
      final cached = _repo.getCachedMandis();
      if (cached.isNotEmpty) {
        state = state.copyWith(items: cached, isLoading: true);
      }
    }

    final data = await _repo.fetchMandis(
      page: 0,
      searchQuery: searchQuery,
      userLat: location.latitude,
      userLng: location.longitude,
      userState: location.state,
      userCity: location.city,
    );

    if (!mounted || currentSearchId != _searchCounter) return;

    state = state.copyWith(
      isLoading: false,
      items: data,
      hasMore: data.length >= 50,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    final nextPage = state.items.length ~/ 50;
    final UserLocation location =
        _currentLocation ?? _ref.read(locationProvider);

    final newData = await _repo.fetchMandis(
      page: nextPage,
      searchQuery: _lastQuery,
      userLat: location.latitude,
      userLng: location.longitude,
      userState: location.state,
      userCity: location.city,
    );

    final allItems = [...state.items, ...newData];

    if (!mounted) return;
    state = state.copyWith(
      isLoading: false,
      items: allItems,
      hasMore: newData.length >= 50,
    );

    // PRE-FETCH: If we have more, fetch the next page in the background but don't show loader
    if (state.hasMore) {
      _preFetchNext(nextPage + 1);
    }
  }

  Future<void> _preFetchNext(int page) async {
    final UserLocation location =
        _currentLocation ?? _ref.read(locationProvider);
    final newData = await _repo.fetchMandis(
      page: page,
      searchQuery: _lastQuery,
      userLat: location.latitude,
      userLng: location.longitude,
      userState: location.state,
      userCity: location.city,
    );

    if (!mounted || newData.isEmpty) return;

    // Append silently if user hasn't scrolled more yet
    final currentNames =
        state.items.map((e) => e['mandi_name_original']).toSet();
    final uniqueNew = newData
        .where((e) => !currentNames.contains(e['mandi_name_original']))
        .toList();

    if (uniqueNew.isNotEmpty) {
      state = state.copyWith(items: [...state.items, ...uniqueNew]);
    }
  }

  Future<void> search(String query) async {
    await loadInitial(searchQuery: query);
  }
}

final mandiPricesProvider =
    StateNotifierProvider<MandiPricesNotifier, MandiPricesState>((ref) {
  final repo = ref.watch(mandiRepositoryProvider);
  final location = ref.watch(locationProvider);
  return MandiPricesNotifier(repo, ref, location);
});

// ─── FAVORITES ─────────────────────────────────────────────────────────────

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final MandiRepository _repo;
  FavoritesNotifier(this._repo) : super({}) {
    _loadFavorites();
  }

  void _loadFavorites() {
    state = _repo.getAllFavoriteIds().toSet();
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await _repo.toggleFavorite(id, !isFavorite);
    if (isFavorite) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }
}

// ─── LOCATION NAME PROVIDER ──────────────────────────────────────────────────

final userLocationNameProvider = FutureProvider<String>((ref) async {
  final posAsync = ref.watch(userLocationProvider);
  final pos = posAsync.valueOrNull;

  if (pos == null) return "Locating...";

  try {
    final placemarks =
        await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      final city = p.locality ?? p.subAdministrativeArea ?? 'Unknown';
      final state = p.administrativeArea ?? 'India';

      // Live Location Language Translation
      return await LanguageHelper.translate(city, state, city);
    }
  } catch (e) {
    return await LanguageHelper.translate(
        "Surat", "Gujarat", "Surat"); // Fallback translated
  }
  return "Unknown";
});

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final repo = ref.watch(mandiRepositoryProvider);
  return FavoritesNotifier(repo);
});

// ─── MANDI PRODUCTS ──────────────────────────────────────────────────────────

final mandiProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, name) {
  ref.watch(translationsProvider); // Auto-re-evaluates on language changes!
  final location = ref.watch(locationProvider);
  return ref.watch(mandiRepositoryProvider).fetchMandiProducts(name,
      userState: location.state, userCity: location.city);
});

final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  } catch (_) {
    return null;
  }
});

final nearestMandiProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final location = ref.watch(locationProvider);
  return ref.read(mandiRepositoryProvider).fetchNearestMandi(
        location.latitude,
        location.longitude,
      );
});

// --- REAL BUSINESS INFO PROVIDER (Timings + Phone) ---------------------------

final mandiBusinessInfoProvider =
    FutureProvider.family<Map<String, String>?, Map<String, String>>(
        (ref, params) async {
  final name = params['name'] ?? '';
  final district = params['district'] ?? '';
  return ref
      .read(mandiRepositoryProvider)
      .fetchMandiBusinessInfo(name, district);
});

// ─── PRODUCT LIST NOTIFIER ───────────────────────────────────────────────────

class ProductListState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool hasMore;
  final String? category;

  const ProductListState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
    this.category,
  });

  ProductListState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? hasMore,
    String? category,
    bool resetCategory = false,
  }) {
    return ProductListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      category: resetCategory ? null : (category ?? this.category),
    );
  }
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  final MandiRepository _repo;
  final Ref _ref;
  String _lastQuery = '';
  int _searchCounter = 0;
  int _currentPage = 0;

  ProductListNotifier(this._repo, this._ref)
      : super(const ProductListState(items: [])) {
    loadInitial();
  }

  Future<void> loadInitial({String searchQuery = '', String? category}) async {
    _lastQuery = searchQuery;
    state = state.copyWith(
      isLoading: true,
      items: [],
      hasMore: false,
      category: category,
      resetCategory: category == null,
    );

    final location = _ref.read(locationProvider);

    _currentPage = 0;
    final int currentSearchId = ++_searchCounter;

    // 1. Try to load from cache first for instant UI
    if (searchQuery.isEmpty) {
      final cached = _repo.getCachedProducts();
      if (cached.isNotEmpty) {
        state = state.copyWith(items: cached, isLoading: true);
      }
    }

    final data = await _repo.fetchUniqueProducts(
      page: _currentPage,
      searchQuery: searchQuery,
      category: state.category,
      userState: location.state,
      userCity: location.city,
    );

    if (!mounted || currentSearchId != _searchCounter) return;

    state = state.copyWith(
      isLoading: false,
      items: data,
      hasMore: false,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    _currentPage++;
    final location = _ref.read(locationProvider);

    final newData = await _repo.fetchUniqueProducts(
      page: _currentPage,
      searchQuery: _lastQuery,
      category: state.category,
      userState: location.state,
      userCity: location.city,
    );

    if (!mounted) return;

    // Strict de-duplication against current items
    final currentNames = state.items
        .map((e) => e['commodity_name_original'] ?? e['commodity_name'])
        .toSet();
    final uniqueNew = newData.where((e) {
      final name = e['commodity_name_original'] ?? e['commodity_name'];
      return !currentNames.contains(name);
    }).toList();

    state = state.copyWith(
      isLoading: false,
      items: [...state.items, ...uniqueNew],
      hasMore: newData.isNotEmpty,
    );

    // PRE-FETCH: Silent next page for products
    if (state.hasMore) {
      _preFetchNext(_currentPage + 1);
    }
  }

  Future<void> _preFetchNext(int page) async {
    final location = _ref.read(locationProvider);
    final newData = await _repo.fetchUniqueProducts(
      page: page,
      searchQuery: _lastQuery,
      userState: location.state,
      userCity: location.city,
    );

    if (!mounted || newData.isEmpty) return;

    final currentNames =
        state.items.map((e) => e['commodity_name_original']).toSet();
    final uniqueNew = newData
        .where((e) => !currentNames.contains(e['commodity_name_original']))
        .toList();

    if (uniqueNew.isNotEmpty) {
      state = state.copyWith(items: [...state.items, ...uniqueNew]);
    }
  }

  Future<void> search(String query) async {
    await loadInitial(searchQuery: query);
  }

  Future<void> filterByCategory(String? category) async {
    await loadInitial(category: category);
  }
}

final productListProvider =
    StateNotifierProvider<ProductListNotifier, ProductListState>((ref) {
  final repo = ref.watch(mandiRepositoryProvider);
  return ProductListNotifier(repo, ref);
});

final productComparisonProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, arg) {
  // arg is "commodity:sortMode:originalCommodity"
  final parts = arg.split(':');
  final commodity = parts[0];
  final sortMode = parts.length > 1 ? parts[1] : 'latest';
  final originalCommodity = parts.length > 2 ? parts[2] : commodity;

  final location = ref.watch(locationProvider);

  return ref.read(mandiRepositoryProvider).fetchProductComparison(
        originalCommodity,
        location.latitude,
        location.longitude,
        sortMode: sortMode,
      );
});

class ProductFavoritesNotifier extends StateNotifier<Set<String>> {
  final MandiRepository _repo;

  ProductFavoritesNotifier(this._repo) : super({}) {
    _load();
  }

  void _load() {
    state = _repo.getFavoriteProducts().toSet();
  }

  Future<void> toggleFavorite(String commodity, bool isFavorite) async {
    await _repo.toggleFavoriteProduct(commodity, isFavorite);
    if (isFavorite) {
      state = {...state, commodity};
    } else {
      state = {...state}..remove(commodity);
    }
  }
}

final productFavoritesProvider =
    StateNotifierProvider<ProductFavoritesNotifier, Set<String>>((ref) {
  final repo = ref.watch(mandiRepositoryProvider);
  return ProductFavoritesNotifier(repo);
});

// ─── PRICE ALERTS NOTIFIER ──────────────────────────────────────────────────

class PriceAlert {
  final String commodity;
  final String commodityGuj;
  final String? mandiName;
  final String? mandiNameGuj;
  final double targetPrice;
  final bool isAbove;
  final double currentPrice;
  final bool isHit;
  final DateTime? lastUpdated;
  final String? arrivalDate;

  PriceAlert({
    required this.commodity,
    required this.commodityGuj,
    this.mandiName,
    this.mandiNameGuj,
    required this.targetPrice,
    required this.isAbove,
    this.currentPrice = 0,
    this.isHit = false,
    this.lastUpdated,
    this.arrivalDate,
  });

  Map<String, dynamic> toMap() => {
        'commodity': commodity,
        'commodityGuj': commodityGuj,
        'mandiName': mandiName,
        'mandiNameGuj': mandiNameGuj,
        'targetPrice': targetPrice,
        'isAbove': isAbove,
        'currentPrice': currentPrice,
        'isHit': isHit,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'arrivalDate': arrivalDate,
      };

  factory PriceAlert.fromMap(Map<String, dynamic> map) => PriceAlert(
        commodity: map['commodity'],
        commodityGuj: map['commodityGuj'],
        mandiName: map['mandiName'],
        mandiNameGuj: map['mandiNameGuj'],
        targetPrice: (map['targetPrice'] as num).toDouble(),
        isAbove: map['isAbove'],
        currentPrice: (map['currentPrice'] as num).toDouble(),
        isHit: map['isHit'] ?? false,
        lastUpdated: map['lastUpdated'] != null
            ? DateTime.parse(map['lastUpdated'])
            : null,
        arrivalDate: map['arrivalDate'],
      );
}

class PriceAlertsNotifier extends StateNotifier<List<PriceAlert>> {
  final MandiRepository _repo;
  final Ref _ref;

  PriceAlertsNotifier(this._repo, this._ref) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final alerts = _repo.getPriceAlerts();
    state = alerts.map((e) => PriceAlert.fromMap(e)).toList();
    await refreshAlertPrices();
  }

  Future<void> refreshAlertPrices() async {
    if (state.isEmpty) return;

    final loc = _ref.read(locationProvider);
    List<PriceAlert> updatedList = [];
    bool changed = false;

    for (var alert in state) {
      // Fetch latest price for this specific commodity exactly
      final latest = await _repo.fetchLatestPrice(
        alert.commodity,
        mandiName: alert.mandiName, // New: optionally filter by mandi
      );

      if (latest != null) {
        final current = (latest['modal_price'] as num).toDouble();
        // Capture arrival_date if it has time, otherwise fallback to sync_at for time context
        String marketTime = latest['arrival_date']?.toString() ?? '';
        if (!marketTime.contains(':') && latest['sync_at'] != null) {
          // If arrival_date is just YYYY-MM-DD, we use sync_at but keep the date from arrival_date
          final syncAt = latest['sync_at'].toString();
          if (syncAt.contains('T')) {
            marketTime = '${marketTime.split('T')[0]}T${syncAt.split('T')[1]}';
          }
        }

        bool hit = alert.isAbove
            ? current >= alert.targetPrice
            : current <= alert.targetPrice;

        if (current != alert.currentPrice ||
            hit != alert.isHit ||
            (marketTime.isNotEmpty && marketTime != alert.arrivalDate)) {
          changed = true;
          if (hit && !alert.isHit) {
            _ref.read(hasUnreadNotificationsProvider.notifier).state = true;
          }
          updatedList.add(PriceAlert(
            commodity: alert.commodity,
            commodityGuj: alert.commodityGuj,
            mandiName: alert.mandiName,
            mandiNameGuj: alert.mandiNameGuj,
            targetPrice: alert.targetPrice,
            isAbove: alert.isAbove,
            currentPrice: current,
            isHit: hit,
            lastUpdated: DateTime.now(),
            arrivalDate: marketTime.isNotEmpty ? marketTime : alert.arrivalDate,
          ));
          continue;
        }
      }
      updatedList.add(alert);
    }

    if (changed) {
      state = updatedList;
      for (var a in state) {
        _repo.savePriceAlert(a.toMap());
      }
    }
  }

  Future<void> addOrUpdateAlert(PriceAlert alert) async {
    await _repo.savePriceAlert(alert.toMap());
    final index = state.indexWhere((e) => e.commodity == alert.commodity);
    if (index != -1) {
      state = [...state]..[index] = alert;
    } else {
      state = [...state, alert];
    }
  }

  Future<void> removeAlert(String commodity) async {
    await _repo.removePriceAlert(commodity);
    state = state.where((e) => e.commodity != commodity).toList();
  }
}

final priceAlertsProvider =
    StateNotifierProvider<PriceAlertsNotifier, List<PriceAlert>>((ref) {
  final repo = ref.watch(mandiRepositoryProvider);
  return PriceAlertsNotifier(repo, ref);
});

// ─── ALL UNIQUE COMMODITIES PROVIDER ────────────────────────────────────────

final mandiProductHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, key) {
  final repo = ref.watch(mandiRepositoryProvider);
  final parts = key.split('|');
  if (parts.length < 3) return Future.value([]);

  final mandiName = parts[0];
  final commodityName = parts[1];
  final months = int.tryParse(parts[2]) ?? 3;

  return repo.fetchPriceHistory(mandiName, commodityName, months: months);
});

final allCommodityNamesProvider = FutureProvider<List<String>>((ref) async {
  final mandiCrops =
      await ref.watch(mandiRepositoryProvider).fetchAllCommodityNames();

  // Also load from Master Dataset
  try {
    final jsonStr = await rootBundle
        .loadString('assets/data/india_crop_calendar_master.json');
    final List<dynamic> data = json.decode(jsonStr);
    final masterCrops = data.map((e) => e['Crop'] as String).toSet().toList();

    final combined = {...mandiCrops, ...masterCrops}.toList();
    combined.sort();
    return combined;
  } catch (e) {
    return mandiCrops;
  }
});
