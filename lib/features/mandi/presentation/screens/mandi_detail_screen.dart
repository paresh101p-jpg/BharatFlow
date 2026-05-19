import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:hive/hive.dart';
import '../utils/commodity_utils.dart';
import '../providers/mandi_providers.dart';
import '../../data/repositories/mandi_repository.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/location_provider.dart';
import 'mandi_product_detail_screen.dart';
import '../../../dashboard/presentation/widgets/add_alert_sheet.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';

class MandiDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const MandiDetailScreen({super.key, required this.data});

  @override
  ConsumerState<MandiDetailScreen> createState() => _MandiDetailScreenState();
}

class _MandiDetailScreenState extends ConsumerState<MandiDetailScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late ScrollController _scrollCtrl;
  bool _isAppBarCollapsed = false;
  String _selectedUnit = 'Quintal'; // Default unit

  // Theme colors
  static const _green = Color(0xFF00C853);
  static const _red = Color(0xFFFF1744);
  static const _amber = Color(0xFFFFAB00);
  static const _bg = Color(0xFFF0F4F0);
  static const _card = Colors.white;
  static const _primary = Color(0xFF1B5E20);
  static const _primaryLight = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.offset > 140 && !_isAppBarCollapsed) {
        setState(() => _isAppBarCollapsed = true);
      } else if (_scrollCtrl.offset <= 140 && _isAppBarCollapsed) {
        setState(() => _isAppBarCollapsed = false);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final mandiName = d['mandi_name'] ?? 'Unknown Mandi';
    final originalMandiName = d['mandi_name_original'] ?? mandiName;
    final t = ref.watch(translationsProvider);
    
    final mandiProductsAsync = ref.watch(mandiProductsProvider(originalMandiName));
    final bizInfoAsync = ref.watch(mandiBusinessInfoProvider({'name': originalMandiName, 'district': d['district'] ?? ''}));
    
    final locationUrl =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$originalMandiName, ${d['district'] ?? ''}, ${d['state'] ?? ''}')}';

    String suffix = _selectedUnit == 'Quintal' ? '/q' : '/${_selectedUnit.toLowerCase().replaceAll(' ', '')}';

    return Scaffold(
      backgroundColor: _bg,
      appBar: const CommonAppBar(showBack: true),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _primary,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: _isAppBarCollapsed
                  ? Text(mandiName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1))
                  : null,
              actions: [
                Consumer(
                  builder: (context, ref, child) {
                    final isFav = ref.watch(favoritesProvider).contains(mandiName);
                    return GestureDetector(
                      onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(mandiName, isFav),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(15)),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                          size: 26,
                        ),
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network('https://images.unsplash.com/photo-1605000797499-95a51c5269ae?q=80&w=1000&auto=format&fit=crop',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _primary)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primary.withOpacity(0.95),
                            _primary.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mandiName.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.store, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${t['explore_all_items'] ?? 'Explore All Items'} in $mandiName',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
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
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _mandiInfoGrid(d, locationUrl, t, bizInfoAsync),
                    const SizedBox(height: 24),

                    mandiProductsAsync.when(
                      data: (products) => products.isEmpty
                          ? const SizedBox()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(t['top_movers'] ?? 'Top Movers'),
                                const SizedBox(height: 12),
                                _topMovers(products, suffix, t),
                                const SizedBox(height: 24),

                                _sectionTitle(t['high_demand'] ?? 'High Demand'),
                                const SizedBox(height: 12),
                                _highDemandProducts(products),
                                const SizedBox(height: 24),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _sectionTitle(t['all_products'] ?? 'All Products'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${products.length} ${t['items'] ?? 'items'}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _card,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
                                    ],
                                  ),
                                  child: TextField(
                                    onChanged: (v) => setState(() => _searchQuery = v),
                                    decoration: InputDecoration(
                                      hintText: t['search_products'] ?? 'Search products...',
                                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                () {
                                  final filtered = products.where((p) => (p['commodity_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                                  final grouped = <String, List<Map<String, dynamic>>>{};
                                  for (var p in filtered) {
                                    final name = p['commodity_name'] ?? 'Unknown';
                                    grouped.putIfAbsent(name, () => []).add(p);
                                  }

                                  return Column(
                                    children: grouped.entries.map((e) {
                                      final items = e.value;
                                      final firstItem = items.first;
                                      final varietiesCount = items.map((i) => i['variety']).toSet().length;
                                      final gradesCount = items.map((i) => i['grade']).toSet().length;
                                      
                                      return _productTile(firstItem, t, varietiesCount, gradesCount);
                                    }).toList(),
                                  );
                                }(),
                              ],
                            ),
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary),
    );
  }

  Widget _topMovers(List<Map<String, dynamic>> products, String suffix, Map<String, String> t) {
    if (products.length < 2) return const SizedBox();
    final sorted = List<Map<String, dynamic>>.from(products)..sort((a, b) => (b['modal_price'] ?? 0).compareTo(a['modal_price'] ?? 0));
    return Row(
      children: [
        _moverCard(t['top_price'] ?? 'TOP PRICE', sorted.first, _green, Icons.trending_up, suffix),
        const SizedBox(width: 10),
        _moverCard(t['low_price'] ?? 'LOW PRICE', sorted.last, _red, Icons.trending_down, suffix),
      ],
    );
  }

  Widget _moverCard(String label, Map<String, dynamic> p, Color color, IconData icon, String suffix) {
    final name = p['commodity_name'] ?? 'N/A';
    final rawPrice = (p['modal_price'] ?? 0).toDouble();
    double price = rawPrice;
    if (_selectedUnit == 'KG') price = rawPrice / 100;
    else if (_selectedUnit == '20 KG') price = rawPrice / 5;
    else if (_selectedUnit == '40 KG') price = rawPrice / 2.5;
    final variety = p['variety'] ?? 'General';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.12)), boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5))]),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis),
            Text(variety, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('₹${price.toStringAsFixed(price < 100 ? 2 : 0)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
              Text(suffix, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _highDemandProducts(List<Map<String, dynamic>> products) {
    final sorted = List<Map<String, dynamic>>.from(products)..sort((a, b) => (b['modal_price'] ?? 0).compareTo(a['modal_price'] ?? 0));
    final top5 = sorted.take(5).toList();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: top5.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = top5[i];
          final name = p['commodity_name'] ?? 'N/A';
          final rawPrice = (p['modal_price'] ?? 0).toDouble();
          double price = rawPrice;
          if (_selectedUnit == 'KG') price = rawPrice / 100;
          else if (_selectedUnit == '20 KG') price = rawPrice / 5;
          else if (_selectedUnit == '40 KG') price = rawPrice / 2.5;
          final img = CommodityUtils.getImageUrl(name);
          return Container(
            width: 140,
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img.isEmpty
                      ? Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                        )
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                          ),
                        ),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
                  Positioned(bottom: 10, left: 10, right: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    Text('₹${price.toStringAsFixed(price < 100 ? 2 : 0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w900)),
                  ])),
                  Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: i == 0 ? _amber : _primary, borderRadius: BorderRadius.circular(8)), child: Text('#${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> p, Map<String, String> t, int vCount, int gCount) {
    final name = p['commodity_name'] ?? 'Unknown';
    final originalName = p['commodity_name_original'] ?? name;
    final rawPrice = (p['modal_price'] ?? 0).toDouble();
    double price = rawPrice;
    String suffix = '/q';
    if (_selectedUnit == 'KG') { price /= 100; suffix = '/kg'; }
    else if (_selectedUnit == '20 KG') { price /= 5; suffix = '/20k'; }
    else if (_selectedUnit == '40 KG') { price /= 2.5; suffix = '/40k'; }
    final img = CommodityUtils.getImageUrl(name);
    final isFav = ref.watch(productFavoritesProvider).contains(originalName);
    final hasAlert = ref.watch(priceAlertsProvider).any((a) => a.commodity == originalName);

    return InkWell(
      onTap: () async {
        final repo = ref.read(mandiRepositoryProvider);
        final location = ref.read(locationProvider);
        final mandiName = widget.data['mandi_name_original'] ?? widget.data['mandi_name'] ?? '';
        final details = await repo.fetchVarietyDetails(mandiName, name, userState: location.state, userCity: location.city);
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => MandiProductDetailScreen(mandiName: mandiName, commodityName: name, varietyList: details)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: img.isEmpty
                  ? Container(
                      width: 80,
                      height: 80,
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    )
                  : Image.network(
                      img,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                      ),
                    ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2C3E50)), overflow: TextOverflow.ellipsis),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => AddAlertSheet(initialProduct: {
                                  ...p,
                                  'mandi_name': widget.data['mandi_name'],
                                  'mandi_name_original': widget.data['mandi_name_original'],
                                }),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: hasAlert ? Colors.red.withOpacity(0.1) : _primary.withOpacity(0.05), shape: BoxShape.circle),
                              child: Icon(hasAlert ? Icons.notifications_active : Icons.notifications_active_outlined, color: hasAlert ? Colors.red : _primary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _countBadge('${t['var'] ?? 'Var'}: $vCount', Colors.purple),
                      const SizedBox(width: 6),
                      _countBadge('${t['grd'] ?? 'Grd'}: $gCount', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 10, color: Colors.green),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'updated ${CommodityUtils.getFullDateTime(p['arrival_date']?.toString() ?? '', p['sync_at']?.toString())}',
                          style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('₹${price.toStringAsFixed(price < 100 ? 2 : 0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _primary)),
                      const SizedBox(width: 3),
                      Text(suffix, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
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

  Widget _mandiInfoGrid(Map<String, dynamic> d, String locationUrl, Map<String, String> t, AsyncValue<Map<String, String>?> bizInfoAsync) {
    final syncTimestamp = d['last_updated']?.toString();
    final lastChecked = CommodityUtils.getFullDateTime(syncTimestamp);

    return Column(
      children: [
        Row(children: [
          Expanded(child: _infoBox(Icons.history, t['updated'] ?? 'Updated', lastChecked, Colors.blue, isClickable: false)),
          const SizedBox(width: 12),
          Expanded(child: _infoBox(Icons.unfold_more, t['qty_unit'] ?? 'Unit', _selectedUnit, _green, isClickable: true, onTap: () => _showUnitPicker(context, t))),
        ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => launchUrl(Uri.parse(locationUrl), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.near_me, size: 18),
          label: Text(t['get_directions'] ?? 'GET DIRECTIONS', style: const TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.withOpacity(0.08),
            foregroundColor: Colors.blue,
            minimumSize: const Size(double.infinity, 50),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.withOpacity(0.2))),
          ),
        ),
      ],
    );
  }

  void _showUnitPicker(BuildContext context, Map<String, String> t) {
    final units = ['Quintal', 'KG', '20 KG', '40 KG'];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) {
      return Container(padding: const EdgeInsets.symmetric(vertical: 25), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t['qty_unit'] ?? 'Select Weight Unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ...units.map((u) => ListTile(
          leading: Icon(u == _selectedUnit ? Icons.radio_button_checked : Icons.radio_button_off, color: _primary),
          title: Text(u, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Text(u.contains('20') ? '(Mann)' : u.contains('40') ? '(Badi Mann)' : ''),
          onTap: () { setState(() => _selectedUnit = u); Navigator.pop(context); },
        )),
      ]));
    });
  }

  Widget _countBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
  );

  Widget _infoBox(IconData icon, String label, String value, Color color, {required bool isClickable, VoidCallback? onTap}) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(15), border: isClickable ? Border.all(color: color.withOpacity(0.3)) : null, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]), child: Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)]))] )));
  }
}