import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bharat_flow/core/services/share_manager.dart';
import 'package:intl/intl.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/theme/app_theme.dart';
import 'package:bharat_flow/features/mandi/presentation/utils/commodity_utils.dart';
import 'package:bharat_flow/features/mandi/presentation/providers/mandi_providers.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/product_comparison_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_detail_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_product_history_screen.dart';
import 'package:bharat_flow/features/mandi/data/repositories/mandi_repository.dart';
import '../widgets/add_alert_sheet.dart';

class FavoritesAlertsScreen extends ConsumerStatefulWidget {
  const FavoritesAlertsScreen({super.key});

  @override
  ConsumerState<FavoritesAlertsScreen> createState() => _FavoritesAlertsScreenState();
}

class _FavoritesAlertsScreenState extends ConsumerState<FavoritesAlertsScreen> {
  bool _isEditingCommodities = false;
  bool _isEditingMandis = false;
  final _primary = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(priceAlertsProvider.notifier).refreshAlertPrices();
    });
  }

  String formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final productFavorites = ref.watch(productFavoritesProvider);
    final alerts = ref.watch(priceAlertsProvider);
    final t = ref.watch(translationsProvider);

    final hitAlerts = alerts.where((e) => e.isHit).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildTopAppBar(context, t),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                const DynamicAdmobCardWidget(),
                const SizedBox(height: 16),
                _buildActiveAlertsBanner(hitAlerts, t),
                const SizedBox(height: 24),
                _buildPriceAlertsList(alerts, t),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                const SizedBox(height: 32),
                _buildFavoritesSection(favorites.toList(), productFavorites.toList(), t),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, Map<String, String> t) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Text(
        t['favorites_alerts'] ?? 'Favorites & Alerts',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20), letterSpacing: 1),
      ),
      actions: [
        IconButton(
          onPressed: _shareAppDetails,
          icon: const Icon(Icons.share, color: Color(0xFF1B5E20)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildActiveAlertsBanner(List<PriceAlert> hitAlerts, Map<String, String> t) {
    if (hitAlerts.isEmpty) return const SizedBox();
    final names = hitAlerts.map((e) {
      if (e.mandiNameGuj != null && e.mandiNameGuj!.isNotEmpty) return '${e.commodityGuj} (${e.mandiNameGuj})';
      if (e.mandiName != null) return '${e.commodityGuj} (${e.mandiName})';
      return e.commodityGuj;
    }).join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.notifications_active, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${hitAlerts.length} ${t['price_targets_met'] ?? 'Price Targets Met'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('$names ${t['reached_desired_price'] ?? 'reached your desired prices.'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection(List<String> mandiIds, List<String> products, Map<String, String> t) {
    if (mandiIds.isEmpty && products.isEmpty) return _buildEmptyFavorites(t);

    final globalProducts = products.where((p) => !p.contains('|')).toList();
    final mandiProducts = products.where((p) => p.contains('|')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mandiProducts.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['favorite_products'] ?? 'Favorite Products', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              _editBtn(isCommodity: true),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: mandiProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _favoriteChip(mandiProducts[i], t['favorite'] ?? 'Favorite', Colors.blueAccent, isProduct: true, isEditing: _isEditingCommodities),
            ),
          ),
          const SizedBox(height: 32),
        ],
        if (globalProducts.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['favorite_commodities'] ?? 'Favorite Commodities', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
              if (mandiProducts.isEmpty) _editBtn(isCommodity: true),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: globalProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _favoriteChip(globalProducts[i], t['favorite'] ?? 'Favorite', const Color(0xFF1B5E20), isProduct: true, isEditing: _isEditingCommodities),
            ),
          ),
          const SizedBox(height: 32),
        ],
        if (mandiIds.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['favorite_mandis'] ?? 'Favorite Mandis', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
              _editBtn(isCommodity: false),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: mandiIds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _favoriteChip(mandiIds[i], t['mandi'] ?? 'Mandi', Colors.orange, isProduct: false, isEditing: _isEditingMandis),
            ),
          ),
        ],
      ],
    );
  }

  Widget _editBtn({required bool isCommodity}) {
    final t = ref.watch(translationsProvider);
    final isEditing = isCommodity ? _isEditingCommodities : _isEditingMandis;
    return TextButton(
      onPressed: () => setState(() {
        if (isCommodity) _isEditingCommodities = !_isEditingCommodities;
        else _isEditingMandis = !_isEditingMandis;
      }),
      child: Text(
        isEditing ? (t['done_caps'] ?? 'DONE') : (t['edit_caps'] ?? 'EDIT'),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
      ),
    );
  }

  Widget _favoriteChip(String label, String subtitle, Color color, {required bool isProduct, required bool isEditing}) {
    String displayLabel = label;
    String? subLabel;
    String originalCommodity = label;
    String? originalMandi;

    if (isProduct && label.contains('|')) {
      final parts = label.split('|');
      originalCommodity = parts[0];
      originalMandi = parts[1];
      displayLabel = originalCommodity;
      subLabel = originalMandi;
    }

    final imageUrl = isProduct 
        ? CommodityUtils.getImageUrl(originalCommodity)
        : 'https://images.unsplash.com/photo-1605000797499-95a51c5269ae?q=80&w=1000&auto=format&fit=crop';
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (!isEditing) {
              if (isProduct) {
                if (label.contains('|')) {
                  final parts = label.split('|');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MandiProductHistoryScreen(
                    mandiName: parts[1], 
                    commodityName: parts[0],
                  )));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductComparisonScreen(
                    commodity: originalCommodity, 
                    originalCommodity: originalCommodity,
                  )));
                }
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MandiDetailScreen(
                  data: {'mandi_name': label, 'mandi_name_original': label},
                )));
              }
            }
          },
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8)),
              ],
              border: Border.all(color: color.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                 ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Image.network(imageUrl, height: 90, width: double.infinity, fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => Container(
                      height: 90, 
                      width: double.infinity,
                      color: color.withOpacity(0.05), 
                      padding: const EdgeInsets.all(12),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    )),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    children: [
                      Text(displayLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subLabel != null)
                         Text(subLabel, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)
                      else
                         Text(subtitle, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Consumer(
                        builder: (context, ref, _) {
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: isProduct 
                              ? ref.read(mandiRepositoryProvider).fetchLatestPrice(originalCommodity, mandiName: originalMandi)
                              : ref.read(mandiRepositoryProvider).fetchLatestPrice('', mandiName: label),
                            builder: (context, snapshot) {
                              final price = snapshot.data?['modal_price'] ?? 0;
                              final commodity = snapshot.data?['commodity_name'] ?? '';
                              
                              return Column(
                                children: [
                                  if (!isProduct && commodity.isNotEmpty)
                                    Text(commodity, style: TextStyle(fontSize: 8, color: color.withOpacity(0.6), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      price == 0 ? '₹--' : '₹$price', 
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                                    ),
                                  ),
                                ],
                              );
                            }
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isEditing)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                if (isProduct) {
                  ref.read(productFavoritesProvider.notifier).toggleFavorite(label, false);
                } else {
                  ref.read(favoritesProvider.notifier).toggleFavorite(label, true);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyFavorites(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          const Icon(Icons.favorite_border, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text(t['no_favorites_yet'] ?? 'No favorites yet', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(t['add_mandis_track'] ?? 'Add mandis to track them easily', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPriceAlertsList(List<PriceAlert> alerts, Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['active_price_alerts'] ?? 'Active Price Alerts', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(t['no_alerts_set'] ?? 'No alerts set yet', style: const TextStyle(color: Colors.grey))))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) => _alertItem(alerts[i], t),
          ),
      ],
    );
  }

  Widget _alertItem(PriceAlert alert, Map<String, String> t) {
    final progress = alert.currentPrice > 0 ? (alert.isAbove ? (alert.currentPrice / alert.targetPrice).clamp(0.0, 1.0) : (alert.targetPrice / alert.currentPrice).clamp(0.0, 1.0)) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alert.isHit ? Colors.green : Colors.grey.shade100, width: alert.isHit ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFF1B5E20).withOpacity(0.05),
                  child: Image.network(
                    CommodityUtils.getImageUrl(alert.commodity),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.white,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: LanguageHelper.translate(alert.commodity, '', ''),
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? alert.commodity;
                        return Row(
                          children: [
                            Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1B5E20)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(t['live_caps'] ?? 'LIVE', style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold))),
                          ],
                        );
                      }
                    ),
                    if (alert.mandiName != null)
                      FutureBuilder<String>(
                        future: LanguageHelper.translate(alert.mandiName!, '', ''),
                        builder: (context, mSnapshot) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 10, color: Colors.deepOrange),
                              const SizedBox(width: 4),
                              Text(
                                mSnapshot.data ?? alert.mandiName!, 
                                style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w900)
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text('${t['target'] ?? 'Target'}: ${alert.isAbove ? '>' : '<'} ₹${alert.targetPrice.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 10, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Market Updated: ${CommodityUtils.getFullDateTime(alert.arrivalDate ?? '')}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${alert.currentPrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1B5E20))),
                  Text(t['live_price_caps'] ?? 'LIVE PRICE', style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    backgroundColor: Colors.grey.shade100,
                    color: alert.isHit ? Colors.green : const Color(0xFF1B5E20),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(onPressed: () => _showAddAlertDialog(context, t, existing: alert), icon: const Icon(Icons.edit_notifications_outlined, color: Color(0xFF1B5E20), size: 22)),
              IconButton(onPressed: () => ref.read(priceAlertsProvider.notifier).removeAlert(alert.commodity), icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewAlertButton(Map<String, String> t) {
    return ElevatedButton(
      onPressed: () => _showAddAlertDialog(context, t),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67E22), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0),
      child: Text(t['set_new_alert'] ?? 'SET NEW ALERT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
    );
  }

  void _showAddAlertDialog(BuildContext context, Map<String, String> t, {PriceAlert? existing}) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AddAlertSheet(existing: existing));
  }

  Future<void> _shareAppDetails() async {
    try {
      // 1. Load app logo from assets
      final byteData = await rootBundle.load('assets/images/logo.png');
      
      // 2. Write it to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/bharat_flow_logo.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes, 
        byteData.lengthInBytes,
      ));

      // 3. Share the file with the text message (caption)
      await ShareManager.shareXFiles(
        context,
        [XFile(tempFile.path)],
        text: '🌾 *BharatFlow super app* 🌾\n\nLive Mandi Prices, Proximity Crop Calendars, Kisan Market Store, and Real-time Price Alerts! 📲\n\nDownload Now:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow',
        subject: 'Download BharatFlow App',
      );
    } catch (e) {
      // Fallback: If anything fails, share the text link directly
      await ShareManager.share(
        context,
        '🌾 *BharatFlow super app* 🌾\n\nLive Mandi Prices, Proximity Crop Calendars, Kisan Market Store, and Real-time Price Alerts! 📲\n\nDownload Now:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow',
        subject: 'Download BharatFlow App',
      );
    }
  }
}
