import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/auth_providers.dart';

class WarehouseLocatorScreen extends ConsumerStatefulWidget {
  const WarehouseLocatorScreen({super.key});

  @override
  ConsumerState<WarehouseLocatorScreen> createState() => _WarehouseLocatorScreenState();
}

class _WarehouseLocatorScreenState extends ConsumerState<WarehouseLocatorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedType = 'All';

  List<Warehouse> _allWarehouses = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  int _totalCount = 0;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchTotalCount();

    // ✅ GPS ready hone ka wait karo, phir load karo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = ref.read(locationProvider);

      // Agar GPS already ready hai (real coords hain), seedha load karo
      if (location.address != 'Fetching location...') {
        _loadInitial();
      }

      // GPS update hone pe listener — initial fetch ya reload
      ref.listenManual(locationProvider, (prev, next) {
        // Pehli baar GPS aaye (Fetching → real address)
        if (prev?.address == 'Fetching location...' &&
            next.address != 'Fetching location...') {
          _loadInitial();
        }
      });
    });
  }

  Future<void> _fetchTotalCount() async {
    try {
      final response = await Supabase.instance.client
          .from('warehouses')
          .select('id')
          .limit(10000);

      if (mounted && response != null) {
        setState(() => _totalCount = (response as List).length);
      }
    } catch (e) {
      debugPrint('Count error: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _allWarehouses = [];
      _currentOffset = 0;
      _hasMore = true;
    });

    // ✅ GPS ready nahi hai toh wait karo
    final location = ref.read(locationProvider);
    if (location.address == 'Fetching location...') {
      await ref.read(locationProvider.notifier).getCurrentLocation();
    }

    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    // ✅ Fresh location read karo har baar
    final location = ref.read(locationProvider);

    final nextBatch =
        await ref.read(warehouseRepositoryProvider).getNearbyWarehouses(
              location.latitude,
              location.longitude,
              limit: _limit,
              offset: _currentOffset,
              filterType: _selectedType,
            );

    if (mounted) {
      setState(() {
        _allWarehouses.addAll(nextBatch);
        _currentOffset += _limit;
        if (nextBatch.length < _limit) _hasMore = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final filteredList = _allWarehouses.where((w) {
      final query = _searchQuery.toLowerCase();
      return w.name.toLowerCase().contains(query) ||
          w.address.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F1),
      appBar: AppBar(
        title: Text(t['warehouses'] ?? 'Warehouse Locator',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInitial),
        ],
      ),
      body: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHeader(_totalCount, t),
              Positioned(
                left: 0,
                right: 0,
                bottom: -25,
                child: _buildSearchBar(filteredList.length, t),
              ),
            ],
          ),
          const SizedBox(height: 30), // Space for the floating bar
          _buildFilters(t),
          Expanded(
            child: filteredList.isEmpty && !_isLoadingMore
                ? _buildEmptyState(t)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length + (_hasMore ? 1 : 1),
                    itemBuilder: (context, i) {
                      if (i < filteredList.length) {
                        return _WarehouseCard(
                            warehouse: filteredList[i], t: t);
                      } else if (_hasMore) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator()));
                      } else {
                        return _buildSourceFooter(t);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count, Map<String, String> t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 5),
          Text(
            '8,500+ Verified Warehouses in India',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSearchBar(int count, Map<String, String> t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), // No more negative margin
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
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: t['search_warehouses'] ?? 'Search Warehouses...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'NEARBY',
                      style: TextStyle(
                          fontSize: 7,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(Map<String, String> t) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _filterBtn('All', t['all'] ?? 'All'),
          _filterBtn('Government', t['government'] ?? 'Government'),
          _filterBtn('Private', t['private'] ?? 'Private'),
        ],
      ),
    );
  }

  Widget _filterBtn(String type, String label) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _selectedType = type);
            _loadInitial();
          }
        },
        selectedColor: AppTheme.primaryColor,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildSourceFooter(Map<String, String> t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Source: WDRA, Government of India\nShowing All Registered Warehouses',
        style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmptyState(Map<String, String> t) {
    return Center(
        child: Text(t['no_results'] ?? 'No Warehouses Found',
            style: const TextStyle(color: Colors.grey)));
  }
}

class _WarehouseCard extends StatelessWidget {
  final Warehouse warehouse;
  final Map<String, String> t;
  const _WarehouseCard({required this.warehouse, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.black.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.warehouse_rounded,
                      color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(warehouse.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      _typeTag(warehouse.type),
                      const SizedBox(height: 6),
                      Text(warehouse.address,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700),
                          maxLines: 2),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.green.shade200)),
                      child: Text(
                          '${warehouse.distanceKm?.toStringAsFixed(1)} KM',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800)),
                    ),
                    if (!warehouse.isLive)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('PERMANENTLY CLOSED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1.2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(
                    Icons.storage_rounded, 'Capacity', warehouse.capacity),
                _statItem(Icons.payments_rounded, 'Est. Rent',
                    '₹${warehouse.monthlyRentPerQuintal.toInt()}/Qtl',
                    color: Colors.blue.shade700),
                _statItem(
                    warehouse.isLive ? Icons.check_circle : Icons.cancel,
                    'Status',
                    warehouse.isLive ? 'OPEN' : 'CLOSED',
                    color: warehouse.isLive ? Colors.green : Colors.red),
              ],
            ),
          ),
          _buildVotingStats(warehouse),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (warehouse.contactNo != null &&
                    warehouse.contactNo!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filled(
                      onPressed: () => launchUrl(
                          Uri.parse('tel:${warehouse.contactNo}')),
                      icon: const Icon(Icons.phone),
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final query = Uri.encodeComponent(
                          '${warehouse.name}, ${warehouse.address}');
                      launchUrl(Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$query'));
                    },
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(t['map'] ?? 'MAP',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FeedbackSection(
                    warehouseId: warehouse.id, t: t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTag(String type) {
    final isGovt = type.toLowerCase() == 'government';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: isGovt
              ? Colors.indigo.withOpacity(0.1)
              : Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(type.toUpperCase(),
          style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isGovt ? Colors.indigo : Colors.purple)),
    );
  }

  Widget _statItem(IconData icon, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildVotingStats(Warehouse warehouse) {
    final total = warehouse.yesCount + warehouse.noCount;
    if (total == 0) return const SizedBox();
    final yesPerc = (warehouse.yesCount / total * 100).toInt();
    final noPerc = (warehouse.noCount / total * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Farmer Activity:',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold)),
              Text('$total votes',
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Expanded(
                    flex: warehouse.yesCount,
                    child: Container(height: 4, color: Colors.red.shade400)),
                Expanded(
                    flex: warehouse.noCount,
                    child:
                        Container(height: 4, color: Colors.green.shade400)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$yesPerc% Full',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
              Text('$noPerc% Available',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackSection extends ConsumerStatefulWidget {
  final String warehouseId;
  final Map<String, String> t;
  const _FeedbackSection({required this.warehouseId, required this.t});
  @override
  ConsumerState<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends ConsumerState<_FeedbackSection> {
  bool? _isFull;

  void _sendFeedback(bool full) async {
    final user = await ref.read(googleUserProvider.future);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              widget.t['login_to_vote'] ?? 'Please login to vote'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _isFull = full);
    ref
        .read(warehouseRepositoryProvider)
        .saveWarehouseFeedback(widget.warehouseId, full, user.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Full?',
              style:
                  TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _feedbackBtn(true),
          const SizedBox(width: 6),
          _feedbackBtn(false),
        ],
      ),
    );
  }

  Widget _feedbackBtn(bool full) {
    final isSelected = _isFull == full;
    return GestureDetector(
      onTap: () => _sendFeedback(full),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: isSelected
                ? (full ? Colors.red : Colors.green)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSelected
                    ? (full ? Colors.red : Colors.green)
                    : Colors.grey.shade300)),
        child: Text(full ? 'YES' : 'NO',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey)),
      ),
    );
  }
}