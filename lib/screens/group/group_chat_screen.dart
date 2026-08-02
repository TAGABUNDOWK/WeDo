import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/message.dart';
import '../../services/group/group_service.dart';
import '../../utils/time_format.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/composer_option.dart';
import '../search/chat_search_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _groupService = GroupService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String _groupName = '';
  Map<String, String> _nicknames = {};

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
    if (_currentUser != null) {
      _groupService.markMessagesAsRead(widget.groupId, _currentUser.uid);
    }
  }

  Future<void> _loadGroupInfo() async {
    final group = await _groupService.getGroup(widget.groupId);
    final nicknames = await _groupService.getMemberNicknames(widget.groupId);
    if (group != null && mounted) {
      setState(() {
        _groupName = group.name;
        _nicknames = nicknames;
      });
    }
  }

  String _getDisplayName(String uid, String fallback) {
    return _nicknames[uid] ?? fallback;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    _groupService.sendMessage(
      groupId: widget.groupId,
      senderId: _currentUser.uid,
      senderName: _getDisplayName(_currentUser.uid, _currentUser.displayName ?? _currentUser.email ?? 'Unknown'),
      text: text,
    );

    _messageCtrl.clear();
  }

  void _showComposerMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  ComposerOption(
                    icon: Icons.photo_outlined,
                    label: 'Photo',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sending photos coming soon')),
                      );
                    },
                  ),
                  ComposerOption(
                    icon: Icons.poll_outlined,
                    label: 'Poll',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Creating polls coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<dynamic>(
          stream: _groupService.getGroupStream(widget.groupId),
          builder: (context, snapshot) {
            final group = snapshot.data;
            if (group != null) {
              _groupName = group.name;
            }
            return Text(_groupName);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final messageId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatSearchScreen(groupId: widget.groupId),
                ),
              );
              if (messageId != null && _scrollCtrl.hasClients) {
                final messages = await _groupService.getMessagesOnce(widget.groupId);
                final index = messages.indexWhere((m) => m.id == messageId);
                if (index != -1 && _scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    index * 80.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              await Navigator.pushNamed(context, '/group-info', arguments: widget.groupId);
              _loadGroupInfo();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _groupService.getMessagesStream(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUser?.uid;
                    final isSystem = msg.type == MessageType.system;

                    if (isSystem) {
                      return MessageBubble(
                        content: msg.content,
                        isMe: false,
                        senderName: msg.senderName.isNotEmpty ? msg.senderName : null,
                        time: formatChatTime(msg.createdAt),
                        isSystem: true,
                      );
                    }

                    final displayName = _getDisplayName(
                      msg.senderId,
                      msg.senderName,
                    );

                    if (msg.type == MessageType.image && msg.imageUrl != null) {
                      return MessageBubble(
                        content: msg.content,
                        imageUrl: msg.imageUrl,
                        isMe: isMe,
                        senderName: isMe ? null : displayName,
                        time: formatChatTime(msg.createdAt),
                      );
                    }

                    return MessageBubble(
                      content: msg.content,
                      isMe: isMe,
                      senderName: isMe ? null : displayName,
                      time: formatChatTime(msg.createdAt),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                    onPressed: _showComposerMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
