import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../mandi/presentation/providers/mandi_providers.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../mandi/data/repositories/mandi_repository.dart';
import '../../../mandi/presentation/utils/commodity_utils.dart';

class AddAlertSheet extends ConsumerStatefulWidget {
  final PriceAlert? existing;
  final Map<String, dynamic>? initialProduct; // For direct alert from mandi cards

  const AddAlertSheet({super.key, this.existing, this.initialProduct});

  @override
  ConsumerState<AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends ConsumerState<AddAlertSheet> {
  Map<String, dynamic>? selectedProduct;
  final TextEditingController _priceController = TextEditingController();
  bool isAbove = true;
  List<Map<String, dynamic>> allProducts = [];
  bool isLoading = true;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  bool _hasMore = true;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      // Use existing alert data as fallback so we don't show ₹0
      selectedProduct = {
        'commodity_name': widget.existing!.commodityGuj,
        'commodity_name_original': widget.existing!.commodity,
        'mandi_name': widget.existing!.mandiNameGuj,
        'mandi_name_original': widget.existing!.mandiName,
        'modal_price': widget.existing!.currentPrice,
        'arrival_date': widget.existing!.arrivalDate,
      };
      _priceController.text = widget.existing!.targetPrice.toInt().toString();
      isAbove = widget.existing!.isAbove;
      
      // Try to fetch live price in background
      _fetchLivePriceForEdit();
    } else if (widget.initialProduct != null) {
      selectedProduct = widget.initialProduct;
      if (widget.initialProduct!['modal_price'] != null) {
        _priceController.text = (widget.initialProduct!['modal_price'] as num).toInt().toString();
      }
    }
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoading && _hasMore) _loadMore();
    }
  }

  Future<void> _fetchLivePriceForEdit() async {
    final latest = await ref.read(mandiRepositoryProvider).fetchLatestPrice(
      widget.existing!.commodity,
      mandiName: widget.existing!.mandiName,
    );
    
    if (latest != null && mounted) {
      setState(() {
        selectedProduct = {
          'commodity_name': widget.existing!.commodityGuj,
          'commodity_name_original': widget.existing!.commodity,
          'mandi_name': widget.existing!.mandiNameGuj,
          'mandi_name_original': widget.existing!.mandiName,
          'modal_price': latest['modal_price'],
          'arrival_date': latest['arrival_date'],
        };
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts([String query = '']) async {
    if (!mounted) return;
    _currentPage = 0; _hasMore = true; _lastQuery = query;
    setState(() => isLoading = true);
    final loc = ref.read(locationProvider);
    final products = await ref.read(mandiRepositoryProvider).fetchUniqueProducts(page: 0, searchQuery: query, userState: loc.state, userCity: loc.city);
    if (mounted) setState(() { allProducts = products; isLoading = false; _hasMore = products.isNotEmpty; });
  }

  Future<void> _loadMore() async {
    if (!mounted || isLoading || !_hasMore) return;
    _currentPage++;
    final loc = ref.read(locationProvider);
    final products = await ref.read(mandiRepositoryProvider).fetchUniqueProducts(page: _currentPage, searchQuery: _lastQuery, userState: loc.state, userCity: loc.city);
    if (mounted) setState(() {
      if (products.isEmpty) _hasMore = false;
      else {
        final currentNames = allProducts.map((e) => e['commodity_name_original'] ?? e['commodity_name']).toSet();
        final uniqueNew = products.where((e) => !currentNames.contains(e['commodity_name_original'] ?? e['commodity_name'])).toList();
        allProducts.addAll(uniqueNew);
        _hasMore = products.length >= 5;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final primary = const Color(0xFF1B5E20);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['set_price_alert'] ?? 'Set Price Alert', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primary, letterSpacing: 0.5)),
              IconButton(onPressed: () => Navigator.pop(context), icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: const Icon(Icons.close, size: 20))),
            ],
          ),
          const SizedBox(height: 20),
          if (selectedProduct == null) ...[
            TextField(
              onChanged: (v) {
                if (_debounce?.isActive ?? false) _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () => _loadProducts(v));
              },
              decoration: InputDecoration(
                hintText: t['search_products'] ?? 'Search product...',
                prefixIcon: Icon(Icons.search, color: primary),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading 
                ? Center(child: CircularProgressIndicator(color: primary)) 
                : ListView.separated(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: allProducts.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade50, height: 1),
                    itemBuilder: (context, i) {
                      if (i >= allProducts.length) return Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: primary)));
                      final p = allProducts[i];
                      return ListTile(
                        onTap: () {
                          setState(() {
                            selectedProduct = p;
                            if (p['modal_price'] != null) _priceController.text = (p['modal_price'] as num).toInt().toString();
                          });
                        },
                        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(CommodityUtils.getImageUrl(p['commodity_name'] ?? ''), width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 45, height: 45, color: primary.withOpacity(0.1), child: Icon(Icons.eco, color: primary)))),
                        title: Text(p['commodity_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p['mandi_name'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 10, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      p['mandi_name'], 
                                      style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                            if (p['modal_price'] != null) 
                              Text('Current: ₹${(p['modal_price'] as num).toInt()}', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Icon(Icons.add_circle_outline, color: primary, size: 20),
                      );
                    },
                  ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary.withOpacity(0.05), primary.withOpacity(0.02)]),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(CommodityUtils.getImageUrl(selectedProduct!['commodity_name'] ?? ''), width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.eco, color: primary, size: 30))),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                          child: const Icon(Icons.account_balance, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(selectedProduct!['commodity_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2C3E50)))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                              child: const Text('GOVT DATA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(t['live_price'] ?? 'Live Price: ', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(' ₹${(selectedProduct!['modal_price'] as num?)?.toInt() ?? '0'}', style: TextStyle(fontSize: 15, color: primary, fontWeight: FontWeight.w900)),
                            Text(' / q', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.account_balance, size: 10, color: Colors.green),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Market Updated: ${CommodityUtils.getFullDateTime(selectedProduct!['arrival_date']?.toString() ?? '')}',
                                style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (selectedProduct!['mandi_name'] != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 10, color: Colors.deepOrange),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Market: ${selectedProduct!['mandi_name']}',
                                  style: const TextStyle(fontSize: 9, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.existing == null && widget.initialProduct == null)
                    IconButton(onPressed: () => setState(() => selectedProduct = null), icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]), child: const Icon(Icons.edit_outlined, size: 18))),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(t['alert_me_when_price'] ?? 'Alert me when price is:', style: const TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 15),
            Row(
              children: [
                _toggleBtn(t['above'] ?? 'Above', true, primary),
                const SizedBox(width: 15),
                _toggleBtn(t['below'] ?? 'Below', false, primary),
              ],
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50)),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primary),
                labelText: t['target_price'] ?? 'Target Price',
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixText: '/ Quintal',
                suffixStyle: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: primary, width: 2)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(_priceController.text) ?? 0;
                if (price > 0) {
                  ref.read(priceAlertsProvider.notifier).addOrUpdateAlert(PriceAlert(
                    commodity: selectedProduct!['commodity_name_original'] ?? selectedProduct!['commodity_name'],
                    commodityGuj: selectedProduct!['commodity_name'],
                    mandiName: selectedProduct!['mandi_name_original'] ?? selectedProduct!['mandi_name'],
                    mandiNameGuj: selectedProduct!['mandi_name'],
                    targetPrice: price,
                    isAbove: isAbove,
                    currentPrice: selectedProduct!['modal_price'] != null 
                        ? (selectedProduct!['modal_price'] as num).toDouble() 
                        : (widget.existing?.currentPrice ?? 0),
                    lastUpdated: DateTime.now(),
                    arrivalDate: selectedProduct!['last_updated']?.toString(),
                  ));
                  Navigator.pop(context);
                  String successMsg = 'Price alert set for ${selectedProduct!['commodity_name']}';
                  if (selectedProduct!['mandi_name'] != null) {
                    successMsg += ' at ${selectedProduct!['mandi_name']}';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 8, shadowColor: primary.withOpacity(0.4)),
              child: Text(t['save_alert'] ?? 'SAVE PRICE ALERT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool value, Color primary) {
    final isSelected = isAbove == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => isAbove = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primary, width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : primary, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ),
    );
  }
}
