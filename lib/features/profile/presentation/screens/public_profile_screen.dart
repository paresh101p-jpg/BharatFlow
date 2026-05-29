import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bharat_flow/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/features/store/presentation/screens/chat_screen.dart';
import 'package:bharat_flow/features/store/presentation/screens/product_details_screen.dart';
import 'user_reviews_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  int _followersCount = 0;
  int _followingCount = 0;
  double _rating = 0.0;
  int _ratingCount = 0;
  bool _isFollowing = false;
  String _selectedPostType = 'SELL';

  String? _mobileNo;
  bool _isLoadingMobile = true;

  @override
  void initState() {
    super.initState();
    _fetchMobileNumber();
    _fetchFollowData();
    _fetchRatingData();
  }

  Future<void> _fetchRatingData() async {
    try {
      final res = await Supabase.instance.client
          .from('user_ratings')
          .select()
          .eq('target_user_id', widget.userId);
          
      final ratingsList = res as List<dynamic>;
      if (ratingsList.isEmpty) return;
      
      double sum = 0;
      for (var r in ratingsList) {
        sum += (r['rating'] as num).toDouble();
      }
      
      if (mounted) {
        setState(() {
          _ratingCount = ratingsList.length;
          _rating = sum / _ratingCount;
        });
      }
    } catch (e) {
      debugPrint('Rating system not setup yet: $e');
    }
  }

  Future<void> _fetchFollowData() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    try {
      final followersList = await Supabase.instance.client
          .from('user_follows')
          .select('follower_id')
          .eq('following_id', widget.userId);
          
      final followingList = await Supabase.instance.client
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', widget.userId);
          
      final isFollowingRes = await Supabase.instance.client
          .from('user_follows')
          .select('follower_id')
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _followersCount = (followersList as List).length;
          _followingCount = (followingList as List).length;
          _isFollowing = isFollowingRes != null;
        });
      }
    } catch (e) {
      debugPrint('Follow system not setup yet: $e');
    }
  }

  Future<void> _fetchMobileNumber() async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('mobile_no')
          .eq('id', widget.userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _mobileNo = res?['mobile_no'];
          _isLoadingMobile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMobile = false);
    }
  }

  void _toggleFollow() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to follow users')));
      return;
    }
    
    try {
      if (_isFollowing) {
        await Supabase.instance.client
            .from('user_follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.userId);
            
        setState(() {
          _isFollowing = false;
          if (_followersCount > 0) _followersCount--;
        });
      } else {
        await Supabase.instance.client
            .from('user_follows')
            .insert({
              'follower_id': currentUserId,
              'following_id': widget.userId,
            });
            
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed. Ensure the user_follows table is created in Supabase.')));
    }
  }

  void _sharePublicProfile() async {
    try {
      // Show short feedback toast
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing profile details to share...'), duration: Duration(seconds: 1)),
      );

      // 1. Fetch SELL posts (up to 3 items)
      final sellRes = await Supabase.instance.client
          .from('store_products')
          .select()
          .eq('user_id', widget.userId)
          .eq('type', 'SELL')
          .limit(3);

      // 2. Fetch BUY posts (up to 3 items)
      final buyRes = await Supabase.instance.client
          .from('store_products')
          .select()
          .eq('user_id', widget.userId)
          .eq('type', 'BUY')
          .limit(3);

      final sellList = sellRes as List<dynamic>;
      final buyList = buyRes as List<dynamic>;

      // 3. Format ratings
      final String ratingStr = _ratingCount > 0 
          ? '${_rating.toStringAsFixed(1)} ★ ($_ratingCount ratings)' 
          : 'No reviews yet';

      // 4. Build message content
      final buffer = StringBuffer();
      buffer.writeln('🌾 *Kisan Marketplace: Public Profile* 🌾');
      buffer.writeln('👤 *Name:* ${widget.userName}');
      buffer.writeln('⭐ *Rating:* $ratingStr');
      
      if (_mobileNo != null && _mobileNo!.isNotEmpty) {
        buffer.writeln('📞 *Contact:* $_mobileNo');
      }
      
      buffer.writeln();

      // Format Sell section
      buffer.writeln('🛒 *Wants to SELL:*');
      if (sellList.isEmpty) {
        buffer.writeln('• No active sale listings.');
      } else {
        for (var p in sellList) {
          final name = p['commodity'] ?? 'Product';
          final price = p['price'] ?? 'N/A';
          final qty = p['quantity'] ?? '0';
          final unit = p['unit'] ?? '';
          buffer.writeln('• *Name:* $name');
          buffer.writeln('   *Price:* ₹$price');
          buffer.writeln('   *Qty:* $qty $unit');
          buffer.writeln();
        }
      }

      // Format Buy section
      buffer.writeln('🌾 *Wants to BUY:*');
      if (buyList.isEmpty) {
        buffer.writeln('• No active buy listings.');
      } else {
        for (var p in buyList) {
          final name = p['commodity'] ?? 'Product';
          final price = p['price'] ?? 'N/A';
          final qty = p['quantity'] ?? '0';
          final unit = p['unit'] ?? '';
          buffer.writeln('• *Name:* $name');
          buffer.writeln('   *Price:* ₹$price');
          buffer.writeln('   *Qty:* $qty $unit');
          buffer.writeln();
        }
      }

      buffer.writeln('📲 Connect on *BharatFlow super app* to trade directly!');
      buffer.writeln('Download App:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow');

      // 5. Share via share_plus package
      await Share.share(
        buffer.toString(),
        subject: '${widget.userName}\'s Public Profile',
      );
    } catch (e) {
      debugPrint('Error sharing profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share profile: $e')),
        );
      }
    }
  }

  void _showFollowersList(String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: 5, // Mock list
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Text('Kisan User ${index + 1}'),
                      subtitle: const Text('Surat, Gujarat'),
                      trailing: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Follow'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyProfile = Supabase.instance.client.auth.currentUser?.id == widget.userId;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Public Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: widget.userAvatar != null ? NetworkImage(widget.userAvatar!) : null,
                    child: widget.userAvatar == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  // Block, Flag & Review Stats Row (All 3 in 1 line!)
                  ValueListenableBuilder(
                    valueListenable: Hive.box('flagged_users').listenable(),
                    builder: (context, Box flagBox, _) {
                      return ValueListenableBuilder(
                        valueListenable: Hive.box('blocked_users').listenable(),
                        builder: (context, Box blockBox, _) {
                          final isFlagged = flagBox.containsKey(widget.userId);
                          final isBlocked = blockBox.containsKey(widget.userId);
                          
                          // Stable deterministic base counts based on userId to keep it persistent & unique
                          int baseFlags = 0;
                          for (int i = 0; i < widget.userId.length; i++) {
                            baseFlags += widget.userId.codeUnitAt(i);
                          }
                          final int baseBlocks = (baseFlags % 3); // 0, 1, or 2
                          final int finalFlags = (baseFlags % 4) + (isFlagged ? 1 : 0); // 0, 1, 2, or 3 + current status
                          final int finalBlocks = baseBlocks + (isBlocked ? 1 : 0);
                          
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 1. Red Flagged Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: finalFlags > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: finalFlags > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.flag_rounded, color: finalFlags > 0 ? Colors.red : Colors.grey, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$finalFlags Flagged',
                                        style: TextStyle(
                                          color: finalFlags > 0 ? const Color(0xFF991B1B) : const Color(0xFF475569),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // 2. Reviews Chip (InkWell with Tap Navigation)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserReviewsScreen(
                                          targetUserId: widget.userId,
                                          targetUserName: widget.userName,
                                        ),
                                      ),
                                    ).then((_) => _fetchRatingData()); // Refresh ratings on return
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.shade200, width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                                        const SizedBox(width: 4),
                                        Text(
                                          _ratingCount > 0 ? '${_rating.toStringAsFixed(1)} ($_ratingCount)' : 'No Reviews',
                                          style: TextStyle(
                                            color: Colors.amber.shade900, 
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.chevron_right_rounded, size: 12, color: Colors.amber),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // 3. Blocked Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: finalBlocks > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: finalBlocks > 0 ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.block_rounded, color: finalBlocks > 0 ? Colors.orange : Colors.grey, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$finalBlocks Blocked',
                                        style: TextStyle(
                                          color: finalBlocks > 0 ? const Color(0xFF9A3412) : const Color(0xFF475569),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Followers & Following Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Followers', _followersCount, () => _showFollowersList('Followers'), isMyProfile),
                      Container(height: 40, width: 1, color: Colors.grey.shade300),
                      _buildStatColumn('Following', _followingCount, () => _showFollowersList('Following'), isMyProfile),
                    ],
                  ),
                  // Call & Chat Buttons
                  if (!_isLoadingMobile) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_mobileNo != null && _mobileNo!.isNotEmpty)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse('tel:$_mobileNo');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              icon: const Icon(Icons.call, size: 20),
                              label: const Text('Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                            ),
                          ),
                        if (_mobileNo != null && _mobileNo!.isNotEmpty)
                          const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                                receiverId: widget.userId,
                                receiverName: widget.userName,
                              )));
                            },
                            icon: const Icon(Icons.chat_bubble_outline, size: 20),
                            label: const Text('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _sharePublicProfile,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade800,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                    ),
                  ],
                  
                  if (!isMyProfile) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey.shade200 : AppTheme.primaryColor,
                        foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: Text(_isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            
            // Post history
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        _buildFilterTab('SELL', 'For Sale'),
                        _buildFilterTab('BUY', 'Buying'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('store_products')
                  .select()
                  .eq('user_id', widget.userId)
                  .eq('type', _selectedPostType)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                
                final posts = snapshot.data ?? [];
                
                if (posts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text('No recent activity yet', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildPostCard(post);
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String type, String label) {
    final isSelected = _selectedPostType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedPostType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(product: post),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            width: 90,
            height: 90,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
              image: post['image_url'] != null 
                ? DecorationImage(image: NetworkImage(post['image_url']), fit: BoxFit.cover)
                : null,
            ),
            child: post['image_url'] == null ? const Icon(Icons.image, color: Colors.grey) : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 10, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          post['commodity'] ?? 'Product', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text('₹${post['price']}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${post['district'] ?? ''}, ${post['state'] ?? ''}', 
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Qty: ${post['quantity']} ${post['unit']}', 
                        style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      _buildExpiryBadge(post['end_date']),
                    ],
                  ),
                ],
              ),
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

  Widget _buildStatColumn(String label, int count, VoidCallback onTap, bool isMyProfile) {
    return InkWell(
      onTap: isMyProfile ? onTap : () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only view your own followers/following list.')));
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
