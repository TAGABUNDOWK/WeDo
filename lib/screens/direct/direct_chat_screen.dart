import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/message.dart';
import '../../models/user_entity.dart';
import '../../services/direct/direct_service.dart';
import '../../utils/time_format.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/composer_option.dart';
import '../search/direct_chat_search_screen.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _directService = DirectService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String _otherName = '';
  UserEntity? _otherUser;
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
        _otherUser = user;
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
                        const SnackBar(
                          content: Text('Sending photos coming soon'),
                        ),
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
                final messages = await _directService.getMessagesOnce(
                  widget.chatId,
                );
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
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _DirectChatInfoScreen(
                    chatId: widget.chatId,
                    otherUid: widget.otherUid,
                  ),
                ),
              );
              _loadData();
            },
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
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.grey,
                    ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
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

class _DirectChatInfoScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const _DirectChatInfoScreen({required this.chatId, required this.otherUid});

  @override
  State<_DirectChatInfoScreen> createState() => _DirectChatInfoScreenState();
}

class _DirectChatInfoScreenState extends State<_DirectChatInfoScreen> {
  final _directService = DirectService();
  UserEntity? _otherUser;
  Map<String, String> _nicknames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _directService.getUser(widget.otherUid);
    final nicks = await _directService.getNicknames(widget.chatId);
    if (mounted) {
      setState(() {
        _otherUser = user;
        _nicknames = nicks;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeNickname() async {
    final currentUid = _directService.getCurrentUid();
    final currentNickname = currentUid != null
        ? _nicknames[currentUid] ?? ''
        : '';
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && currentUid != null && mounted) {
      await _directService.updateNickname(
        chatId: widget.chatId,
        uid: currentUid,
        nickname: result,
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _otherUser?.displayName ?? widget.otherUid;
    final currentUid = _directService.getCurrentUid();
    final myNickname = currentUid != null ? _nicknames[currentUid] : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Info')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_otherUser?.email != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _otherUser!.email!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Colors.blue),
                  title: const Text('Your Nickname'),
                  subtitle: Text(myNickname ?? 'Tap to set'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changeNickname,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Media',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _MediaSection(chatId: widget.chatId),
              ],
            ),
    );
  }
}

class _MediaSection extends StatefulWidget {
  final String chatId;
  const _MediaSection({required this.chatId});

  @override
  State<_MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<_MediaSection> {
  final _directService = DirectService();
  List<String> _imageUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final messages = await _directService.getMessagesOnce(widget.chatId);
    final images = messages
        .where((m) => m.type == MessageType.image && m.imageUrl != null)
        .map((m) => m.imageUrl!)
        .toList();
    if (mounted) {
      setState(() {
        _imageUrls = images;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_imageUrls.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No media shared yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _imageUrls[index],
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
