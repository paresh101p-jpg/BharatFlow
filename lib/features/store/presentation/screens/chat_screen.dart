import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../features/profile/presentation/screens/public_profile_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  String? _receiverImageUrl;
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    _initUser();
    _fetchReceiverPhoto();
  }

  void _initUser() async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser != null) {
      setState(() => _currentUserId = supabaseUser.id);
    } else {
      final googleUser = await ref.read(googleUserProvider.future);
      setState(() => _currentUserId = googleUser?.id);
    }
  }

  void _fetchReceiverPhoto() async {
    try {
      debugPrint('Fetching photo for Receiver ID: ${widget.receiverId}');
      final response = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', widget.receiverId)
          .maybeSingle();
      
      if (response != null && response['avatar_url'] != null) {
        debugPrint('Found Receiver Photo: ${response['avatar_url']}');
        setState(() => _receiverImageUrl = response['avatar_url']);
      } else {
        debugPrint('No photo found for receiver in profiles table.');
      }
    } catch (e) {
      debugPrint('Error fetching receiver photo: $e');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) {
      debugPrint('Cannot send message: text empty or userId null');
      return;
    }

    final isBlocked = Hive.box('blocked_users').containsKey(widget.receiverId);
    if (isBlocked) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot send messages to a blocked user.')));
      return;
    }

    _messageController.clear();

    try {
      debugPrint('Sending message from $_currentUserId to ${widget.receiverId}');
      await Supabase.instance.client.from('chat_messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.receiverId,
        'message': text,
      });
      if (mounted) {
        setState(() {
          _streamKey++;
        });
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicProfileScreen(
                  userId: widget.receiverId,
                  userName: widget.receiverName,
                  userAvatar: _receiverImageUrl,
                ),
              ),
            );
          },
          child: ValueListenableBuilder(
            valueListenable: Hive.box('flagged_users').listenable(),
            builder: (context, Box flagBox, _) {
              final isFlagged = flagBox.containsKey(widget.receiverId);
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: _receiverImageUrl != null && _receiverImageUrl!.isNotEmpty ? NetworkImage(_receiverImageUrl!) : null,
                    child: _receiverImageUrl == null || _receiverImageUrl!.isEmpty
                      ? Text(
                          widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        )
                      : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.receiverName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFlagged) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.flag, color: Colors.red, size: 18),
                            ],
                          ],
                        ),
                        const Text(
                          'Online',
                          style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: Hive.box('blocked_users').listenable(),
            builder: (context, Box blockBox, _) {
              final isBlocked = blockBox.containsKey(widget.receiverId);
              return ValueListenableBuilder(
                valueListenable: Hive.box('flagged_users').listenable(),
                builder: (context, Box flagBox, _) {
                  final isFlagged = flagBox.containsKey(widget.receiverId);
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    onSelected: (value) async {
                      if (value == 'block') {
                        await blockBox.put(widget.receiverId, true);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked. Their products will no longer be visible.')));
                      } else if (value == 'unblock') {
                        await blockBox.delete(widget.receiverId);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked.')));
                      } else if (value == 'flag') {
                        await flagBox.put(widget.receiverId, true);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User flagged with a red flag.')));
                      } else if (value == 'unflag') {
                        await flagBox.delete(widget.receiverId);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Red flag removed from user.')));
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isBlocked)
                        const PopupMenuItem(
                          value: 'block',
                          child: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('Block User', style: TextStyle(color: Colors.red))]),
                        )
                      else
                        const PopupMenuItem(
                          value: 'unblock',
                          child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Unblock User', style: TextStyle(color: Colors.green))]),
                        ),
                      if (!isFlagged)
                        const PopupMenuItem(
                          value: 'flag',
                          child: Row(children: [Icon(Icons.flag, color: Colors.red), SizedBox(width: 8), Text('Red Flag User', style: TextStyle(color: Colors.red))]),
                        )
                      else
                        const PopupMenuItem(
                          value: 'unflag',
                          child: Row(children: [Icon(Icons.flag_outlined, color: Colors.grey), SizedBox(width: 8), Text('Remove Red Flag', style: TextStyle(color: Colors.grey))]),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_streamKey),
              stream: Supabase.instance.client
                  .from('chat_messages')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                
                final rawMessages = snapshot.data ?? [];
                
                final messages = rawMessages.where((m) {
                  final sId = m['sender_id'].toString();
                  final rId = m['receiver_id'].toString();
                  
                  if (_currentUserId == widget.receiverId) {
                    return sId == _currentUserId && rId == _currentUserId;
                  }
                  return (sId == _currentUserId && rId == widget.receiverId) ||
                         (sId == widget.receiverId && rId == _currentUserId);
                }).toList();

                if (messages.isEmpty && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'].toString() == _currentUserId;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final time = DateFormat('hh:mm a').format(DateTime.tryParse(msg['created_at']) ?? DateTime.now());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['message'],
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: const CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
