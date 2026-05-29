import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/general_providers.dart';
import '../../../../core/providers/auth_providers.dart';
import 'new_post_screen.dart';

class MyPostScreen extends ConsumerStatefulWidget {
  const MyPostScreen({super.key});

  @override
  ConsumerState<MyPostScreen> createState() => _MyPostScreenState();
}

class _MyPostScreenState extends ConsumerState<MyPostScreen> {
  bool _isDeleting = false;

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      final success = await ref.read(generalRepositoryProvider).deleteData('store_products', 'id', post['id']);
      if (mounted) {
        setState(() => _isDeleting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted successfully')));
          ref.invalidate(tableDataProvider('store_products')); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete post')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final googleUser = googleUserAsync.value;
    final authUser = Supabase.instance.client.auth.currentUser;
    final box = Hive.box('settings');
    final isLoggedIn = box.get('isLoggedIn') == true;
    final String? uid = authUser?.id ?? googleUser?.id ?? (isLoggedIn ? 'reviewer_id' : null);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('My Posts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
        ? const Center(child: Text('Please login to see your posts'))
        : ref.watch(tableDataProvider('store_products')).when(
            data: (products) {
              final myProducts = products.where((p) {
                final String? pUserId = p['user_id']?.toString();
                return pUserId == uid;
              }).toList();
              
              if (myProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.post_add, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No posts found', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPostScreen())),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
                        child: const Text('Create Your First Post'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(tableDataProvider('store_products'));
                  await ref.read(tableDataProvider('store_products').future);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: myProducts.length,
                  itemBuilder: (context, index) {
                    final post = myProducts[index];
                    return _buildPostCard(post);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final endDate = DateTime.tryParse(post['end_date'] ?? '') ?? DateTime.now();
    final isExpired = endDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade200,
                  image: post['image_url'] != null 
                    ? DecorationImage(image: NetworkImage(post['image_url']), fit: BoxFit.cover)
                    : null,
                ),
                child: post['image_url'] == null ? const Icon(Icons.image, color: Colors.grey) : null,
              ),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: post['type'] == 'SELL' ? Colors.green.shade100 : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(post['type'] ?? 'SELL', style: TextStyle(color: post['type'] == 'SELL' ? Colors.green.shade800 : Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (isExpired)
                            const Text('EXPIRED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(post['commodity'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('₹${post['price']} / ${post['unit']}', style: const TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('${post['district']}, ${post['state']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStatusBadge(post),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewPostScreen(editData: post))),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0D47A1)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deletePost(post),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> post) {
    final String status = post['status'] ?? 'pending';
    final String? rejectionReason = post['rejection_reason'];

    Color statusBgColor = Colors.orange.shade50;
    Color statusTextColor = Colors.orange.shade800;
    String statusText = 'Pending - Will go live after approval';
    IconData statusIcon = Icons.hourglass_empty;

    if (status == 'approved') {
      statusBgColor = Colors.green.shade50;
      statusTextColor = Colors.green.shade800;
      statusText = 'Approved - Live';
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'rejected') {
      statusBgColor = Colors.red.shade50;
      statusTextColor = Colors.red.shade800;
      statusText = 'Rejected${rejectionReason != null && rejectionReason.isNotEmpty ? ": $rejectionReason" : ""}';
      statusIcon = Icons.cancel_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusTextColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, color: statusTextColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
