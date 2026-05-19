import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:bharat_flow/features/mandi/presentation/utils/commodity_utils.dart';
import '../providers/mandi_providers.dart';
import '../../../dashboard/presentation/widgets/add_alert_sheet.dart';
import 'mandi_product_history_screen.dart';

class ProductComparisonScreen extends ConsumerStatefulWidget {
  final String commodity;
  final String originalCommodity;

  const ProductComparisonScreen({
    super.key,
    required this.commodity,
    required this.originalCommodity,
  });

  @override
  ConsumerState<ProductComparisonScreen> createState() => _ProductComparisonScreenState();
}

class _ProductComparisonScreenState extends ConsumerState<ProductComparisonScreen> {
  String _sortMode = 'latest'; 
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final comparisonAsync = ref.watch(productComparisonProvider('${widget.commodity}:$_sortMode:${widget.originalCommodity}'));
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(widget.commodity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: comparisonAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(t['no_mandi_reports'] ?? 'No mandi reports for this product yet.'));
          }
          final filteredList = list.where((item) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            final name = (item['mandi_name'] ?? '').toString().toLowerCase();
            final district = (item['district'] ?? '').toString().toLowerCase();
            final state = (item['state'] ?? '').toString().toLowerCase();
            return name.contains(q) || district.contains(q) || state.contains(q);
          }).toList();

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
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
                  decoration: InputDecoration(
                    hintText: t['search_mandi_city'] ?? 'Search Mandi or City...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchQuery.isNotEmpty) 
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey), 
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            }
                          ),
                        Builder(
                          builder: (context) {
                            final uniqueMandiCount = filteredList.map((e) => e['mandi_name']).toSet().length;
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$uniqueMandiCount ${t['mandis'] ?? 'Mandis'}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _sortChip(
                            icon: Icons.update,
                            label: t['latest_update'] ?? 'Latest Update',
                            isActive: _sortMode == 'latest',
                            onTap: () => setState(() => _sortMode = 'latest'),
                          ),
                          const SizedBox(width: 8),
                          _sortChip(
                            icon: Icons.arrow_downward,
                            label: t['highest_price'] ?? 'Highest Price',
                            isActive: _sortMode == 'highest',
                            onTap: () => setState(() => _sortMode = 'highest'),
                          ),
                          const SizedBox(width: 8),
                          _sortChip(
                            icon: Icons.arrow_upward,
                            label: t['lowest_price'] ?? 'Lowest Price',
                            isActive: _sortMode == 'lowest',
                            onTap: () => setState(() => _sortMode = 'lowest'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final selectedUnit = ref.watch(priceUnitProvider);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['Quintal', 'KG', '20 KG', '40 KG'].map((u) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _unitChip(u, selectedUnit == u, () => ref.read(priceUnitProvider.notifier).state = u),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredList.isEmpty 
                  ? Center(child: Text(t['no_matches_found'] ?? 'No matches found for "$_searchQuery"'))
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) => _mandiPriceTile(context, filteredList[index], t),
                  ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _mandiPriceTile(BuildContext context, Map<String, dynamic> item, Map<String, String> t) {
    final selectedUnit = ref.watch(priceUnitProvider);
    final mandiName = item['mandi_name'] ?? 'Unknown';
    final district = item['district'] ?? '';
    final state = item['state'] ?? '';
    final rawPrice = (item['modal_price'] ?? 0).toDouble();
    final distKm = (item['distance_km'] as num?)?.toDouble();
    final variety = item['variety'] ?? 'Other';
    final grade = item['grade'] ?? 'FAQ';
    final arrivalDate = item['arrival_date']?.toString() ?? '';

    double price = rawPrice;
    String suffix = '/ quintal';
    if (selectedUnit == 'KG') {
      price = rawPrice / 100;
      suffix = '/ kg';
    } else if (selectedUnit == '20 KG') {
      price = rawPrice / 5;
      suffix = '/ 20k';
    } else if (selectedUnit == '40 KG') {
      price = rawPrice / 2.5;
      suffix = '/ 40k';
    }

    // Use CommodityUtils to format date (future dates will show "Recently")
    String displayDate = CommodityUtils.getFormattedDateTime(arrivalDate);
    String displayTime = '';
    if (displayDate != 'Recently' && displayDate != 'No Date') {
      displayTime = ' 09:30 AM';  // Govt data only gives date, so add a standard time
    }
    final displayDateTime = displayDate == 'Recently' ? 'Recently' : '$displayDate$displayTime';

    final locationUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$mandiName, $district, $state')}';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MandiProductHistoryScreen(
              mandiName: item['mandi_name_original'] ?? item['mandi_name'] ?? mandiName,
              commodityName: widget.originalCommodity,
              variety: variety,
              grade: grade,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: LanguageHelper.translate(mandiName, '', ''),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? mandiName, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('$district, $state', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Text('$variety • $grade', style: const TextStyle(color: Colors.deepOrange, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 10, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('updated $displayDateTime', style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (distKm != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.near_me, size: 10, color: Color(0xFF1B5E20)),
                            const SizedBox(width: 4),
                            Text('${distKm.toStringAsFixed(1)} ${t['distance'] ?? 'km away'}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${price.toStringAsFixed(price < 100 ? 1 : 0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
                    Text(suffix, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(locationUrl), mode: LaunchMode.externalApplication),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1B5E20)), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map, size: 10, color: Color(0xFF1B5E20)),
                            const SizedBox(width: 4),
                            Text(t['map'] ?? 'MAP', style: const TextStyle(fontSize: 9, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionIcon(
                          icon: ref.watch(productFavoritesProvider).contains('${widget.originalCommodity}|${item['mandi_name_original'] ?? item['mandi_name']}') 
                              ? Icons.favorite : Icons.favorite_border,
                          color: ref.watch(productFavoritesProvider).contains('${widget.originalCommodity}|${item['mandi_name_original'] ?? item['mandi_name']}')
                              ? Colors.red : Colors.grey.shade400,
                          onTap: () {
                            final mandiName = item['mandi_name_original'] ?? item['mandi_name'];
                            final favKey = '${widget.originalCommodity}|$mandiName';
                            final isFavorite = ref.read(productFavoritesProvider).contains(favKey);
                            ref.read(productFavoritesProvider.notifier).toggleFavorite(favKey, !isFavorite);
                            
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(!isFavorite ? 'Saved to favorites' : 'Removed from favorites'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: !isFavorite ? Colors.redAccent : Colors.grey,
                            ));
                          },
                        ),
                        const SizedBox(width: 8),
                        _actionIcon(
                          icon: ref.watch(priceAlertsProvider).any((a) => a.commodity == (item['commodity_name_original'] ?? item['commodity_name'] ?? widget.originalCommodity) && a.mandiName == (item['mandi_name_original'] ?? item['mandi_name'])) 
                              ? Icons.notifications_active : Icons.notifications_active_outlined,
                          color: ref.watch(priceAlertsProvider).any((a) => a.commodity == (item['commodity_name_original'] ?? item['commodity_name'] ?? widget.originalCommodity) && a.mandiName == (item['mandi_name_original'] ?? item['mandi_name']))
                              ? Colors.red : const Color(0xFF1B5E20),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => AddAlertSheet(initialProduct: {
                                ...item,
                                'commodity_name': widget.commodity,
                                'commodity_name_original': widget.originalCommodity,
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _actionIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _sortChip({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    final color = const Color(0xFF1B5E20);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(isActive ? 1 : 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9, 
                fontWeight: FontWeight.bold, 
                color: isActive ? Colors.white : color
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitChip(String label, bool isActive, VoidCallback onTap) {
    final color = const Color(0xFF1B5E20);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.orange : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9, 
            fontWeight: FontWeight.bold, 
            color: isActive ? Colors.white : Colors.black87
          ),
        ),
      ),
    );
  }
}

