import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';
import 'package:bharat_flow/features/mandi/presentation/providers/mandi_providers.dart';
import 'package:bharat_flow/features/mandi/presentation/utils/commodity_utils.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_detail_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/product_comparison_screen.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:intl/intl.dart';
import 'package:bharat_flow/core/providers/location_provider.dart' as core_loc;
import 'package:bharat_flow/features/dashboard/presentation/widgets/location_weather_widget.dart';
import 'package:bharat_flow/features/notifications/presentation/screens/notification_history_screen.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';
import 'package:bharat_flow/features/dashboard/presentation/widgets/add_alert_sheet.dart';


class MandiIntelligenceScreen extends ConsumerStatefulWidget {
  final bool isFromBottomNav;
  final String? initialCategory;
  final int initialTabIndex;
  final String? standaloneMode; // 'mandi' or 'product'
  const MandiIntelligenceScreen({
    super.key,
    this.isFromBottomNav = false,
    this.initialCategory,
    this.initialTabIndex = 0,
    this.standaloneMode,
  });

  @override
  ConsumerState<MandiIntelligenceScreen> createState() =>
      _MandiIntelligenceScreenState();
}

class _MandiIntelligenceScreenState
    extends ConsumerState<MandiIntelligenceScreen> with SingleTickerProviderStateMixin {
  final _mandiScrollController = ScrollController();
  final _productScrollController = ScrollController();
  final _searchController = TextEditingController();
  final _productSearchController = TextEditingController();
  late TabController _tabController;

  static const _primary = Color(0xFF1B5E20);
  static const _green = Color(0xFF00C853);
  static const _red = Color(0xFFFF1744);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    
    _mandiScrollController.addListener(() {
      if (_mandiScrollController.position.pixels >=
          _mandiScrollController.position.maxScrollExtent - 300) {
        ref.read(mandiPricesProvider.notifier).loadMore();
      }
    });

    _productScrollController.addListener(() {
      if (_productScrollController.position.pixels >=
          _productScrollController.position.maxScrollExtent - 300) {
        ref.read(productListProvider.notifier).loadMore();
      }
    });
    
    if (widget.initialCategory != null) {
      _tabController.index = 1;
      // Do not put category name in search box, just use the filter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(productListProvider.notifier).filterByCategory(widget.initialCategory!);
      });
    }

    // AUTO REFRESH: Mandatory sync on screen entry as requested
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoRefresh();
    });
  }

  Future<void> _triggerAutoRefresh() async {
    final t = ref.read(translationsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t['syncing_data'] ?? 'Syncing latest market data...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.12,
          left: 70,
          right: 70,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    final loc = ref.read(core_loc.locationProvider);
    await ref.read(mandiRepositoryProvider).syncRealData(
      userState: loc.state,
      userCity: loc.city,
    );
    if (!mounted) return;
    ref.read(mandiPricesProvider.notifier).loadInitial();
    ref.read(productListProvider.notifier).loadInitial();
    ref.read(priceAlertsProvider.notifier).refreshAlertPrices();
  }

  @override
  void dispose() {
    _mandiScrollController.dispose();
    _productScrollController.dispose();
    _searchController.dispose();
    _productSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pricesState = ref.watch(mandiPricesProvider);
    final nearestAsync = ref.watch(nearestMandiProvider);
    final t = ref.watch(translationsProvider);
    final locationAsync = ref.watch(core_loc.dashboardLocationProvider);

    // Dynamic listener for category taps from Dashboard
    ref.listen<String>(mandiTabCategoryProvider, (prev, next) {
      if (next != 'All' && next.isNotEmpty) {
        _productSearchController.text = next;
        ref.read(productListProvider.notifier).search(next);
        _tabController.index = 1;
        // Reset category so it can be re-triggered
        Future.microtask(() {
          ref.read(mandiTabCategoryProvider.notifier).state = 'All';
        });
      }
    });

    final googleUserAsync = ref.watch(googleUserProvider);
    final photoUrl = googleUserAsync.when(data: (u) => u?.photoUrl, loading: () => null, error: (_, __) => null);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CommonAppBar(
        bottom: widget.standaloneMode != null ? null : TabBar(
          controller: _tabController,
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelColor: _primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: t['mandis'] ?? 'MANDIS'),
            Tab(text: t['products'] ?? 'PRODUCTS'),
          ],
          onTap: (index) => setState(() {}),
        ),
      ),
      body: widget.standaloneMode == 'mandi' 
        ? _buildMandiTab(pricesState, nearestAsync, t)
        : widget.standaloneMode == 'product'
            ? _buildProductTab(t)
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildMandiTab(pricesState, nearestAsync, t),
                  _buildProductTab(t),
                ],
              ),
    );
  }

  Widget _buildMandiTab(MandiPricesState pricesState, AsyncValue<Map<String, dynamic>?> nearestAsync, Map<String, String> t) {
    return Column(
      children: [
        _buildSearchBar(false),
        Expanded(
          child: RefreshIndicator(
            color: _primary,
            onRefresh: () async {
              _searchController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t['syncing_data'] ?? 'Syncing latest market data...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _primary.withOpacity(0.9),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.12,
                    left: 70,
                    right: 70,
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
              final loc = ref.read(core_loc.locationProvider);
              await ref.read(mandiRepositoryProvider).syncRealData(
                userState: loc.state,
                userCity: loc.city,
              );
              await ref.read(settingsProvider.notifier).updateLastSync(DateTime.now());
              ref.invalidate(mandiStatsProvider); // Refresh the count
              return ref
                  .read(mandiPricesProvider.notifier)
                  .loadInitial(searchQuery: '');
            },
            child: pricesState.items.isEmpty && pricesState.isLoading
                ? _buildLoadingState(t['fetching_rates'] ?? 'Fetching market rates...')
                : pricesState.items.isEmpty
                    ? _buildEmptyState(t['no_mandis_found'] ?? 'No mandis found', false)
                    : ListView.builder(
                        controller: _mandiScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: pricesState.items.length + (pricesState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < pricesState.items.length) {
                            final mandi = pricesState.items[index];
                            return _mandiCard(context, mandi);
                          }
                          if (pricesState.hasMore) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary.withOpacity(0.5))
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductTab(Map<String, String> t) {
    return Consumer(
      builder: (context, ref, child) {
        final prodState = ref.watch(productListProvider);
        
        return Column(
          children: [
            _buildSearchBar(true),
            _buildUnitSelector(),
            _buildCategoryChips(t),
            Expanded(
              child: prodState.items.isEmpty && prodState.isLoading
                  ? _buildLoadingState(t['fetching_products'] ?? 'Preparing crop list...')
                  : prodState.items.isEmpty
                      ? _buildEmptyState(t['no_products_found'] ?? 'No products found', true)
                      : ListView.builder(
                          controller: _productScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: prodState.items.length + (prodState.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < prodState.items.length) {
                              return _buildProductListTile(prodState.items[index]);
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary.withOpacity(0.5))
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildCategoryChips(Map<String, String> t) {
    final currentCat = ref.watch(productListProvider).category;
    final cats = ['All', 'Grains', 'Vegetables', 'Fruits', 'Spices', 'Pulses', 'Oilseeds', 'Fibers', 'Plantation', 'Flowers'];
    
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, i) {
          final cat = cats[i];
          final isSelected = (currentCat ?? 'All') == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                ref.read(productListProvider.notifier).filterByCategory(cat == 'All' ? null : cat);
                _productSearchController.clear(); // Clear search when switching categories
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? _primary : Colors.grey.shade300),
                ),
                child: Text(
                  t[cat.toLowerCase()] ?? cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isProduct, [int? count]) {
    final stats = ref.watch(mandiStatsProvider).value ?? {'mandis': 0, 'records': 0};
    final mandiCount = stats['mandis'] ?? 0;
    final t = ref.watch(translationsProvider);


    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: TextField(
        controller: isProduct ? _productSearchController : _searchController,
        onChanged: (v) {
          if (isProduct) {
            ref.read(productListProvider.notifier).search(v);
          } else {
            ref.read(mandiPricesProvider.notifier).search(v);
          }
        },
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: Colors.grey),
          hintText: isProduct 
              ? (t['search_products']?.replaceAll('...', '') ?? 'Search Products')
              : (t['search_hint']?.replaceAll('...', '') ?? 'Search Mandis'),
          border: InputBorder.none,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((isProduct ? _productSearchController : _searchController).text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                  onPressed: () {
                    if (isProduct) {
                      _productSearchController.clear();
                      ref.read(productListProvider.notifier).search('');
                    } else {
                      _searchController.clear();
                      ref.read(mandiPricesProvider.notifier).search('');
                    }
                  },
                ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isProduct ? '${stats['products'] ?? 324}+ ${t['products'] ?? 'Products'}' : '$mandiCount ${t['mandis'] ?? 'Mandis'}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductListTile(Map<String, dynamic> p) {
    final name = p['commodity_name'] ?? 'Unknown';
    final vCount = p['varieties_count'] ?? 1;
    final gCount = p['grades_count'] ?? 1;
    final img = CommodityUtils.getImageUrl(name);

    final String arrivalRaw = p['last_updated']?.toString() ?? '';
    print('🗓️ RAW: $arrivalRaw');
    final String arrivalDisplay = CommodityUtils.getFormattedDateTime(arrivalRaw);
    print('✅ PARSED: $arrivalDisplay');

    String syncedAgoText = '';
    if (p['sync_at'] != null) {
      final syncTime = DateTime.tryParse(p['sync_at']);
      if (syncTime != null) {
        final diff = DateTime.now().difference(syncTime);
        if (diff.inSeconds < 60) {
          syncedAgoText = 'synced just now';
        } else if (diff.inMinutes < 60) {
          syncedAgoText = 'synced ${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          syncedAgoText = 'synced ${diff.inHours}h ago';
        } else {
          syncedAgoText = 'synced ${diff.inDays}d ago';
        }
      }
    }

    final String lastUpdatedText = arrivalDisplay;
    
    return Consumer(
      builder: (context, ref, _) {
        final selectedUnit = ref.watch(priceUnitProvider);
        final rawPrice = (p['modal_price'] as num?)?.toDouble() ?? 0.0;
        
        double displayPrice = rawPrice;
        String suffix = 'Price';
        if (selectedUnit == 'KG') {
          displayPrice = rawPrice / 100;
          suffix = 'Per KG';
        } else if (selectedUnit == '20 KG') {
          displayPrice = rawPrice / 5;
          suffix = 'Per 20 KG';
        } else if (selectedUnit == '40 KG') {
          displayPrice = rawPrice / 2.5;
          suffix = 'Per 40 KG';
        } else {
          suffix = 'Latest Price';
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductComparisonScreen(
                  commodity: name,
                  originalCommodity: p['commodity_name_original'] ?? name,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          img,
                          width: 55,
                          height: 55,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 55,
                            height: 55,
                            color: _primary.withOpacity(0.1),
                            child: const Icon(Icons.grass, color: _primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 10, color: Colors.green),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    lastUpdatedText.replaceAll('Updated: ', 'updated '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _countBadge('Varieties: $vCount', Colors.purple),
                                _countBadge('Grades: $gCount', Colors.orange),
                                _countBadge('Mandis: ${p['mandi_count'] ?? 1}', Colors.green),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 28),
                          Text(
                            '₹${displayPrice.toStringAsFixed(displayPrice < 100 ? 1 : 0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: _primary, fontSize: 16),
                          ),
                          Text(suffix,
                              style: const TextStyle(color: Colors.grey, fontSize: 8)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
                Positioned(
                  top: -4,
                  right: 6,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final isFav = ref.watch(productFavoritesProvider).contains(p['commodity_name_original'] ?? name);
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey.shade400,
                          size: 22,
                        ),
                        onPressed: () => ref.read(productFavoritesProvider.notifier).toggleFavorite(p['commodity_name_original'] ?? name, !isFav),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _countBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 8, fontWeight: FontWeight.bold, color: color),
        ),
      );

  Widget _buildUnitSelector() {
    return Consumer(
      builder: (context, ref, _) {
        final selectedUnit = ref.watch(priceUnitProvider);
        final units = ['Quintal', 'KG', '20 KG', '40 KG'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: units.map((u) {
              final isSelected = selectedUnit == u;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => ref.read(priceUnitProvider.notifier).state = u,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade300),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 4)] : [],
                    ),
                    child: Text(
                      u,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }


  // ── Market Pulse (fallback when GPS unavailable) ────────────────────────────

  Widget _buildMarketPulseCard(MandiPricesState state) {
    final items = state.items;
    final avgPrice = items.isEmpty
        ? 0.0
        : items.fold<double>(
                0, (s, e) => s + (e['avg_price'] ?? 0).toDouble()) /
            items.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF003D2B), Color(0xFF005C41)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MARKET PULSE',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              Text('LIVE',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Average Mandi Price (All)',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₹${avgPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900),
              ),
              const Text(' /quintal',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              const Icon(Icons.trending_up,
                  color: Colors.greenAccent, size: 16),
              Text(' ${items.length} mandis',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mandi Card (one card = one mandi) ──────────────────────────────────────

  Widget _mandiCard(BuildContext context, Map<String, dynamic> d) {
    final name = d['mandi_name'] ?? 'Unknown';
    final district = d['district'] ?? '';
    final state = d['state'] ?? '';
    final commodityCount = d['commodity_count'] ?? 0;
    final distKm = (d['distance_km'] as num?)?.toDouble();
    final lastUpdated = d['last_updated']?.toString();
    final isFav = ref.watch(favoritesProvider).contains(name);
    final t = ref.watch(translationsProvider);

    // Mock trend for now (can be calculated from history later)
    final bool isUp = (name.length % 2 == 0); 

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MandiDetailScreen(data: d),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00695C)], // Different green shade
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF004D40).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$district, $state',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(name, isFav),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : Colors.white24,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (distKm != null)
                    _whiteChip('${distKm.toStringAsFixed(1)} km', Icons.near_me)
                  else
                    _whiteChip('Dist N/A', Icons.near_me),
                  const SizedBox(width: 8),
                  _whiteChip('$commodityCount ${t['items'] ?? 'Items'}', Icons.inventory_2_outlined),
                  const SizedBox(width: 8),
                  _trendChip(isUp),
                ],
              ),
              // Date/Time removed from card as requested
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteChip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _trendChip(bool isUp) {
    final t = ref.watch(translationsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            size: 11,
            color: isUp ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 4),
          Text(
            isUp ? (t['trend_up'] ?? 'TREND UP') : (t['trend_down'] ?? 'TREND DOWN'),
            style: TextStyle(
              color: isUp ? Colors.greenAccent : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(String message, bool isProduct) {
    final t = ref.watch(translationsProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isProduct ? Icons.inventory_2_outlined : Icons.store_mall_directory_outlined,
              size: 60, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Manual button removed as requested for auto-refresh
        ],
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
                color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}