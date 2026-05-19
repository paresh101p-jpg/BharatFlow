import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/general_providers.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'new_post_screen.dart';
import 'my_post_screen.dart';
import 'product_details_screen.dart';
import '../../../mandi/presentation/providers/mandi_providers.dart';

class BharatBrandStoreScreen extends ConsumerStatefulWidget {
  const BharatBrandStoreScreen({super.key});

  @override
  ConsumerState<BharatBrandStoreScreen> createState() => _BharatBrandStoreScreenState();
}

class _BharatBrandStoreScreenState extends ConsumerState<BharatBrandStoreScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _searchQuery = '';
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(tableDataProvider('store_products'));
    final t = ref.watch(translationsProvider);
    final googleUserAsync = ref.watch(googleUserProvider);
    final photoUrl = googleUserAsync.when(data: (u) => u?.photoUrl, loading: () => null, error: (_, __) => null);
    
    // Get all commodities for autocomplete
    final productList = ref.watch(productListProvider).items;
    final List<String> commodityNames = productList
        .map((e) => e['commodity_name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final isBuyer = _tabController.index == 0;
    final activeTabColor = isBuyer ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final screenBgColor = isBuyer ? const Color(0xFFD0ECD5) : const Color(0xFFFBE9D0);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildTopAppBar(context, photoUrl, t),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: activeTabColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: activeTabColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [
                  Tab(text: t['buyer_tab'] ?? 'Buyer'),
                  Tab(text: t['seller_tab'] ?? 'Seller'),
                ],
              ),
            ),
          ),
        ],
        body: productsAsync.when(
          data: (products) {
            final now = DateTime.now();
            final blockedUsers = Hive.box('blocked_users');

            final activeProducts = products.where((p) {
              final userId = p['user_id'];
              if (userId != null && blockedUsers.containsKey(userId)) {
                return false; // Skip blocked user's products
              }

              // Only show approved posts publicly
              if (p['status'] != 'approved') {
                return false;
              }
              
              final endDateStr = p['end_date'];
              if (endDateStr == null) return true;
              final endDate = DateTime.tryParse(endDateStr);
              return endDate == null || !endDate.isBefore(now);
            }).toList();

            // Filter by search query
            final filteredProducts = _searchQuery.isEmpty 
                ? activeProducts 
                : activeProducts.where((p) => (p['commodity'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

            // Buyer Tab: Users looking for stuff to buy (Show SELL posts)
            final sellPosts = filteredProducts.where((p) => p['type'] == 'SELL').toList();
            // Seller Tab: Users looking for stuff to sell (Show BUY posts)
            final buyPosts = filteredProducts.where((p) => p['type'] == 'BUY').toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildProductGrid(context, sellPosts, t, commodityNames, true),
                _buildProductGrid(context, buyPosts, t, commodityNames, false),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: _buildPostFAB(context, t, isBuyer),
    );
  }

  Widget _buildPostFAB(BuildContext context, Map<String, String> t, bool isBuyer) {
    final activeColor = isBuyer ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildFABMenu(context, t, isBuyer),
        );
      },
      backgroundColor: activeColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  Widget _buildFABMenu(BuildContext context, Map<String, String> t, bool isBuyer) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _menuItem(
            context, 
            icon: Icons.add_circle_outline, 
            label: t['new_post'] ?? 'New Post', 
            isBuyer: isBuyer,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPostScreen()));
            }
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(),
          ),
          _menuItem(
            context, 
            icon: Icons.grid_view_rounded, 
            label: t['my_post'] ?? 'My Post', 
            isBuyer: isBuyer,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostScreen()));
            }
          ),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, required bool isBuyer}) {
    final activeColor = isBuyer ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: activeColor, size: 24),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, String? photoUrl, Map<String, String> t) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          const Icon(Icons.storefront, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(t['kisan_market'] ?? 'Kisan Market', style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 20) : null,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildProductGrid(BuildContext context, List<dynamic> products, Map<String, String> t, List<String> commodityNames, bool isBuyer) {
    final screenBgColor = isBuyer ? const Color(0xFFD0ECD5) : const Color(0xFFFBE9D0);
    final focusColor = isBuyer ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Column(
      children: [
        // Autocomplete Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: screenBgColor,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: _searchQuery),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') return const Iterable<String>.empty();
              final query = textEditingValue.text.toLowerCase();
              return commodityNames.where((String option) {
                final optLower = option.toLowerCase();
                if (optLower.startsWith(query)) return true;
                final words = optLower.split(RegExp(r'[\s\(\)/\-]+'));
                return words.any((word) => word.startsWith(query));
              });
            },
            onSelected: (String selection) {
              setState(() => _searchQuery = selection);
              FocusScope.of(context).unfocus();
            },
            fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: fieldController,
                focusNode: focusNode,
                onChanged: (val) {
                   setState(() => _searchQuery = val);
                },
                decoration: InputDecoration(
                  hintText: 'Search commodity (e.g. Onion)',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            fieldController.clear();
                            setState(() => _searchQuery = '');
                            FocusScope.of(context).unfocus();
                          },
                        ) 
                      : Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isBuyer ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isBuyer ? const Color(0xFFC8E6C9) : const Color(0xFFFFCC80),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isBuyer ? '${products.length} SELLING' : '${products.length} BUYING',
                                  style: TextStyle(
                                    color: isBuyer ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusColor, width: 2)),
                ),
              );
            },
          ),
        ),
        
        Expanded(
          child: products.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(t['no_posts_available'] ?? 'No posts available', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16).copyWith(top: 0),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return _productCard(context, p, t, isBuyer);
                },
              ),
        ),
      ],
    );
  }

  Widget _productCard(BuildContext context, Map<String, dynamic> p, Map<String, String> t, bool isBuyer) {
    final name = p['commodity'] ?? 'Agricultural Product';
    final price = '₹${p['price']}';
    final unit = '/ ${p['unit'] ?? 'Unit'}';
    final location = '${p['district'] ?? ''}, ${p['state'] ?? ''}';
    final imageUrl = p['image_url'] ?? 'https://images.unsplash.com/photo-1595246140625-573b715d11dc?q=80&w=500&auto=format&fit=crop';
    
    final priceColor = isBuyer ? const Color(0xFF0F5132) : const Color(0xFFB45309);
    final cardBgColor = isBuyer ? const Color(0xFFFAFEFB) : const Color(0xFFFFFDF9);
    final cardBorderColor = isBuyer ? const Color(0xFFC8E6C9) : const Color(0xFFFFCC80);
    final glowColor = isBuyer ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.06), 
              blurRadius: 15, 
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    imageUrl, 
                    width: double.infinity, 
                    height: 120, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p['is_organic'] == true ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (p['is_organic'] == true ? 'ORGANIC' : 'GENERAL').toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 2),
                            ValueListenableBuilder(
                              valueListenable: Hive.box('flagged_users').listenable(),
                              builder: (context, Box flagBox, _) {
                                final isFlagged = flagBox.containsKey(p['user_id']?.toString() ?? '');
                                return Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'By ${p['user_name'] ?? 'Kisan User'} | Stock: ${p['quantity'] ?? 'Available'}',
                                        style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isFlagged) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.flag, color: Colors.red, size: 14),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(location, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      _buildExpiryBadge(p['end_date']),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expected Price', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: priceColor)),
                              const SizedBox(width: 4),
                              Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                      if (p['user_id'] != null)
                        UserRatingBadge(
                          targetUserId: p['user_id'],
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p)));
                          },
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

  Widget _buildExpiryBadge(String? endDateStr) {
    if (endDateStr == null || endDateStr.isEmpty) return const SizedBox.shrink();
    final endDate = DateTime.tryParse(endDateStr);
    if (endDate == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final difference = endDate.difference(now).inDays;
    
    if (difference < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text('Expired', style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else if (difference == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text('Expires Today', style: TextStyle(color: Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 10, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text('$difference days left', style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
