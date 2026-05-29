import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsWidget extends StatefulWidget {
  final String leaderId;
  const CommentsWidget({super.key, required this.leaderId});

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final res = await _supabase
          .from('leader_comments')
          .select('*, profiles(full_name, avatar_url)')
          .eq('leader_id', widget.leaderId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to join the Charcha!')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _supabase.from('leader_comments').insert({
        'leader_id': widget.leaderId,
        'user_id': user.id,
        'comment_text': text,
      });
      _commentController.clear();
      await _fetchComments();
    } catch (e) {
      debugPrint('Error submitting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Janta ki Charcha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
              const Spacer(),
              Text('${_comments.length} Comments', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const Divider(height: 24),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No comments yet. Be the first to share your opinion!', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length > 5 ? 5 : _comments.length, // Show top 5
              itemBuilder: (context, index) {
                final comment = _comments[index];
                final profile = comment['profiles'] as Map<String, dynamic>?;
                final authorName = profile?['full_name'] ?? 'Citizen';
                final avatarUrl = profile?['avatar_url'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.blue) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(comment['comment_text'] ?? '', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          
          if (_comments.length > 5)
            TextButton(
              onPressed: () {
                // Future enhancement: show full dialog
              }, 
              child: const Text('View all comments')
            ),
            
          const SizedBox(height: 8),
          
          // Input Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isSubmitting
                  ? const CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.green),
                      onPressed: _submitComment,
                    )
            ],
          )
        ],
      ),
    );
  }
}
