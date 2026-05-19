import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class UserReviewsScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const UserReviewsScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  ConsumerState<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends ConsumerState<UserReviewsScreen> {
  bool _isLoading = true;
  List<dynamic> _reviews = [];
  
  double _averageRating = 0.0;
  int _totalRatings = 0;
  List<int> _starCounts = [0, 0, 0, 0, 0, 0]; // Index 1-5 will hold counts

  // For the current user's review submission
  int _myRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('user_ratings')
          .select('rating, comment, created_at, profiles!rater_id(full_name, avatar_url, id)')
          .eq('target_user_id', widget.targetUserId)
          .order('created_at', ascending: false);

      final List<dynamic> fetchedReviews = res as List<dynamic>;
      
      double sum = 0;
      List<int> counts = [0, 0, 0, 0, 0, 0];
      int myGivenRating = 0;
      String myGivenComment = '';
      
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      for (var r in fetchedReviews) {
        final int rating = (r['rating'] as num).toInt();
        sum += rating;
        if (rating >= 1 && rating <= 5) {
          counts[rating]++;
        }
        
        final profile = r['profiles'];
        if (currentUserId != null && profile != null && profile['id'] == currentUserId) {
          myGivenRating = rating;
          myGivenComment = r['comment'] ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _reviews = fetchedReviews;
          _totalRatings = fetchedReviews.length;
          _averageRating = _totalRatings > 0 ? (sum / _totalRatings) : 0.0;
          _starCounts = counts;
          
          if (_myRating == 0) { // Only set once on initial load
            _myRating = myGivenRating;
            _commentController.text = myGivenComment;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReview() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to submit a review.')));
      return;
    }

    if (_myRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a star rating first.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('user_ratings').upsert({
        'rater_id': currentUserId,
        'target_user_id': widget.targetUserId,
        'rating': _myRating,
        'comment': _commentController.text.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!')));
      _fetchReviews();
    } catch (e) {
      debugPrint('Submit review error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit review. Check database schema.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.targetUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reviews & Ratings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('For ${widget.targetUserName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReviews,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildSummaryCard(),
                    if (!isOwnProfile && currentUserId != null) _buildWriteReviewSection(),
                    _buildReviewsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Big Average
          Column(
            children: [
              Text(
                _averageRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < _averageRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber.shade600,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$_totalRatings Reviews',
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          
          const SizedBox(width: 32),
          
          // Right Side: Progress Bars
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final starNum = 5 - index;
                final count = _starCounts[starNum];
                final percentage = _totalRatings > 0 ? (count / _totalRatings) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('$starNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const Icon(Icons.star_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteReviewSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Write a Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _myRating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starIndex <= _myRating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 40,
                    color: starIndex <= _myRating ? Colors.amber.shade600 : Colors.amber.shade200,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
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
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No reviews yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        final profile = review['profiles'];
        final raterName = profile?['full_name'] ?? 'Unknown User';
        final raterAvatar = profile?['avatar_url'];
        final rating = (review['rating'] as num).toInt();
        final comment = review['comment'] ?? '';
        final createdAtStr = review['created_at'];
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: raterAvatar != null ? NetworkImage(raterAvatar) : null,
                    child: raterAvatar == null ? Text(raterName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(raterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (starIdx) {
                                return Icon(
                                  starIdx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: Colors.amber.shade500,
                                  size: 14,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            if (createdAt != null)
                              Text(DateFormat('dd MMM yyyy').format(createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (comment.toString().trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  comment.toString().trim(),
                  style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 14, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
