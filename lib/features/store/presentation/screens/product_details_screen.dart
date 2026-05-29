import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import 'chat_screen.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  final GlobalKey _ratingKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _getAvatarUrl(String userId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        final metaAvatar = currentUser.userMetadata?['avatar_url'];
        if (metaAvatar != null) return metaAvatar.toString();
      }
      final res = await Supabase.instance.client.from('profiles').select('avatar_url').eq('id', userId).maybeSingle();
      return res?['avatar_url']?.toString();
    } catch (_) {
      return null;
    }
  }

  void _shareProduct() {
    final name = widget.product['commodity'] ?? 'Agricultural Product';
    final price = '₹${widget.product['price']}';
    final unit = '/ ${widget.product['unit'] ?? 'Unit'}';
    final location = '${widget.product['district'] ?? ''}, ${widget.product['state'] ?? ''}';

    final text = '''
🌾 *BharatFlow - Kisan Market* 🌾

📦 *Commodity:* $name
💰 *Price:* $price $unit
📍 *Location:* $location
👤 *Seller:* ${widget.product['user_name'] ?? 'Kisan User'}
⭐ *Quality:* ${widget.product['quality'] ?? 'Good'}

👉 Download *BharatFlow App* for more deals:
https://play.google.com/store/apps/details?id=com.BharatFlow
''';
    Share.share(text, subject: 'Check out this agricultural product on BharatFlow');
  }

  void _scrollToRating() {
    if (_ratingKey.currentContext != null) {
      Scrollable.ensureVisible(
        _ratingKey.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final name = widget.product['commodity'] ?? 'Agricultural Product';
    final price = '₹${widget.product['price']}';
    final unit = '/ ${widget.product['unit'] ?? 'Unit'}';
    final location = '${widget.product['district'] ?? ''}, ${widget.product['state'] ?? ''}';
    final description = widget.product['description'] ?? 'No description provided for this listing.';
    final imageUrl = widget.product['image_url'] ?? 'https://images.unsplash.com/photo-1595246140625-573b715d11dc?q=80&w=800&auto=format&fit=crop';
    final type = widget.product['type'] ?? 'SELL';
    final endDateStr = widget.product['end_date'];
    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Hero Image Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(imageUrl, fit: BoxFit.cover),
                  // Dark gradient for better readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.5)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.arrow_back, color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.share, color: Colors.white, size: 20)),
                onPressed: _shareProduct,
              ),
              const SizedBox(width: 8),
            ],
          ),          // 2. Product Details
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Profile Section (Avatar and Name)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder<String?>(
                        future: _getAvatarUrl(widget.product['user_id']),
                        builder: (context, snapshot) {
                          final avatarUrl = snapshot.data;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => PublicProfileScreen(
                                      userId: widget.product['user_id'],
                                      userName: widget.product['user_name'] ?? 'Kisan User',
                                      userAvatar: avatarUrl,
                                    )
                                  )
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  ValueListenableBuilder(
                                    valueListenable: Hive.box('flagged_users').listenable(),
                                    builder: (context, Box flagBox, _) {
                                      final isFlagged = flagBox.containsKey(widget.product['user_id']?.toString() ?? '');
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            widget.product['user_name'] ?? 'Kisan User',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                                          ),
                                          if (isFlagged) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.flag, color: Colors.red, size: 20),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (widget.product['user_id'] != null)
                        UserRatingBadge(targetUserId: widget.product['user_id'], onTap: _scrollToRating),
                    ],
                  ),

                  // Badge and Type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildChip(
                        type == 'SELL' ? (t['sell'] ?? 'FOR SALE') : (t['buy'] ?? 'BUY REQUEST'), 
                        type == 'SELL' ? Colors.green : Colors.blue
                      ),
                      if (widget.product['is_organic'] == true)
                        _buildChip(t['organic'] ?? 'ORGANIC', Colors.orange, icon: Icons.eco),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title and Location
                  Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(location, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Compact Price Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['selling_price'] ?? 'Expected Price', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(width: 6),
                                Text(unit, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(t['specs'] ?? 'Specifications', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statusBadge(t['processed'] ?? 'Processed', widget.product['is_processed'] == true, Colors.indigo),
                      _statusBadge(t['graded'] ?? 'Graded', widget.product['is_graded'] == true, Colors.teal),
                      _statusBadge(t['packed'] ?? 'Packed', widget.product['is_packed'] == true, Colors.brown),
                      _statusBadge(t['ac_storage'] ?? 'AC Storage', widget.product['is_ac_stored'] == true, Colors.cyan),
                    ],
                  ),

                  const SizedBox(height: 40),
                  Text(t['description'] ?? 'Description', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Text(
                      widget.product['comments'] ?? 'No description provided for this listing.',
                      style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade800, height: 1.6),
                    ),
                  ),

                  const SizedBox(height: 40),
                  Text(t['additional_info'] ?? 'Additional Information', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 20),
                  
                  // Premium Info Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.6,
                    children: [
                      _infoCard(Icons.person_rounded, t['seller_name'] ?? 'Seller Name', widget.product['user_name'] ?? 'Kisan User', Colors.blue),
                      _infoCard(Icons.inventory_2_rounded, t['items'] ?? 'Quantity', widget.product['quantity'] ?? 'N/A', Colors.purple),
                      _infoCard(Icons.star_rounded, t['quality'] ?? 'Quality', widget.product['quality'] ?? 'Good', Colors.amber),
                      _infoCard(Icons.translate_rounded, t['language'] ?? 'Language', widget.product['language'] ?? 'Hindi', Colors.orange),
                      _infoCard(Icons.calendar_today_rounded, t['posted'] ?? 'Posted', DateFormat('dd MMM').format(DateTime.tryParse(widget.product['created_at'] ?? '') ?? DateTime.now()), Colors.teal),
                      _infoCard(Icons.timer_rounded, t['expiry'] ?? 'Expiry', endDate != null ? DateFormat('dd MMM').format(endDate) : 'N/A', Colors.red),
                    ],
                  ),
                  
                  if (widget.product['user_id'] != null)
                    UserRatingSection(key: _ratingKey, targetUserId: widget.product['user_id']),
                    
                  
                  const SizedBox(height: 120), // Bottom space for actions
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildChip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: color, size: 16), const SizedBox(width: 6)],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? color.withOpacity(0.2) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, 
            size: 16, 
            color: isActive ? color : Colors.grey.shade400
          ),
          const SizedBox(width: 8),
          Text(
            label, 
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.bold, 
              color: isActive ? color : Colors.grey.shade500
            )
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final t = ref.read(translationsProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final phone = widget.product['mobile_no'];
                  if (phone != null && phone.toString().isNotEmpty) {
                    launchUrl(Uri.parse('tel:$phone'));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['phone_not_available'] ?? 'Phone number not available')));
                  }
                },
                icon: const Icon(Icons.call_rounded, size: 20),
                label: Text(t['call'] ?? 'Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.product['user_id'] != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                      receiverId: widget.product['user_id'],
                      receiverName: widget.product['user_name'] ?? 'Kisan User',
                    )));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['cannot_chat'] ?? 'Cannot chat: User ID missing')));
                  }
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                label: Text(t['message'] ?? 'Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserRatingSection extends StatefulWidget {
  final String targetUserId;
  const UserRatingSection({super.key, required this.targetUserId});

  @override
  State<UserRatingSection> createState() => _UserRatingSectionState();
}

class _UserRatingSectionState extends State<UserRatingSection> {
  int _userRating = 0;
  double _averageRating = 0.0;
  int _totalRatings = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Future<void> _fetchRatings() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final res = await Supabase.instance.client
          .from('user_ratings')
          .select()
          .eq('target_user_id', widget.targetUserId);
          
      final ratingsList = res as List<dynamic>;
      
      int myRating = 0;
      String myComment = '';
      double sum = 0;
      for (var r in ratingsList) {
        sum += (r['rating'] as num).toDouble();
        if (currentUserId != null && r['rater_id'] == currentUserId) {
          myRating = (r['rating'] as num).toInt();
          myComment = r['comment'] ?? '';
        }
      }
      
      if (mounted) {
        setState(() {
          _totalRatings = ratingsList.length;
          _averageRating = _totalRatings > 0 ? (sum / _totalRatings) : 0.0;
          if (_userRating == 0) { // Set only on initial load
            _userRating = myRating;
            _commentController.text = myComment;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReview() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to rate this user.')));
      return;
    }
    
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a star rating first.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('user_ratings').upsert({
        'rater_id': currentUserId,
        'target_user_id': widget.targetUserId,
        'rating': _userRating,
        'comment': _commentController.text.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!')));
      _fetchRatings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed. Ensure user_ratings table has comment column.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnPost = currentUserId == widget.targetUserId;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isOwnPost ? 'Your Rating Profile' : 'Rate this User', 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))
          ),
          const SizedBox(height: 8),
          Text(
            _totalRatings > 0 
                ? 'Average: ${_averageRating.toStringAsFixed(1)} ★ ($_totalRatings ratings)'
                : 'No ratings yet. Be the first!',
            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: isOwnPost ? () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot rate your own profile.')));
                } : () => setState(() => _userRating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= (isOwnPost ? _averageRating.round() : _userRating) ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 44,
                    color: starIndex <= (isOwnPost ? _averageRating.round() : _userRating) ? Colors.amber.shade600 : Colors.amber.shade200,
                  ),
                ),
              );
            }),
          ),
          if (!isOwnPost) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Share your experience (Optional)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class UserRatingBadge extends StatefulWidget {
  final String targetUserId;
  final VoidCallback onTap;
  const UserRatingBadge({super.key, required this.targetUserId, required this.onTap});

  @override
  State<UserRatingBadge> createState() => _UserRatingBadgeState();
}

class _UserRatingBadgeState extends State<UserRatingBadge> {
  double _averageRating = 0.0;
  int _totalRatings = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Future<void> _fetchRatings() async {
    try {
      final res = await Supabase.instance.client
          .from('user_ratings')
          .select()
          .eq('target_user_id', widget.targetUserId);
          
      final ratingsList = res as List<dynamic>;
      if (ratingsList.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      double sum = 0;
      for (var r in ratingsList) {
        sum += (r['rating'] as num).toDouble();
      }
      
      if (mounted) {
        setState(() {
          _totalRatings = ratingsList.length;
          _averageRating = sum / _totalRatings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              _totalRatings > 0 ? _averageRating.toStringAsFixed(1) : 'New',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
