import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/message.dart';
import '../../services/direct/direct_service.dart';
import '../../utils/time_format.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/composer_option.dart';
import '../search/direct_chat_search_screen.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const DirectChatScreen({super.key, required this.chatId, required this.otherUid});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _directService = DirectService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String _otherName = '';
  Map<String, String> _nicknames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    if (_currentUser != null) {
      _directService.markMessagesAsRead(widget.chatId, _currentUser.uid);
    }
  }

  Future<void> _loadData() async {
    final user = await _directService.getUser(widget.otherUid);
    final nicknames = await _directService.getNicknames(widget.chatId);
    if (mounted) {
      setState(() {
        _otherName = user?.displayName ?? widget.otherUid;
        _nicknames = nicknames;
      });
    }
  }

  String _getDisplayName() {
    if (_currentUser == null) return _otherName;
    return _nicknames[_currentUser.uid] ?? _otherName;
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

    _directService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUser.uid,
      senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
      text: text,
    );

    _messageCtrl.clear();
  }

  void _showAttachMenu() {
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
                'Attach',
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
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE7ECEF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              margin: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE7ECEF),
                boxShadow: [
                  BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 8),
                  BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(4, 4), blurRadius: 8),
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                child: Text(
                  _otherName.isNotEmpty ? _otherName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _otherName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.badge_outlined, color: Colors.blue),
              title: const Text('Change Nickname'),
              subtitle: Text(
                'Set how you appear in this chat',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context);
                _changeNickname();
              },
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }

  Future<void> _changeNickname() async {
    final currentNickname = _nicknames[_currentUser?.uid] ?? '';
    final ctrl = TextEditingController(text: currentNickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Nickname'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nickname for yourself',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && _currentUser != null && mounted) {
      await _directService.updateNickname(
        chatId: widget.chatId,
        uid: _currentUser.uid,
        nickname: result,
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getDisplayName()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final messageId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => DirectChatSearchScreen(chatId: widget.chatId),
                ),
              );
              if (messageId != null && _scrollCtrl.hasClients) {
                final messages = await _directService.getMessagesOnce(widget.chatId);
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
            onPressed: _showChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _directService.getMessagesStream(widget.chatId),
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

                    if (msg.type == MessageType.image && msg.imageUrl != null) {
                      return MessageBubble(
                        content: msg.content,
                        imageUrl: msg.imageUrl,
                        isMe: isMe,
                        senderName: null,
                        time: formatChatTime(msg.createdAt),
                      );
                    }

                    return MessageBubble(
                      content: msg.content,
                      isMe: isMe,
                      senderName: null,
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
                    onPressed: _showAttachMenu,
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
