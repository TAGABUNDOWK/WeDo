import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/direct_chat.dart';
import '../../models/user_entity.dart';
import '../../services/direct/direct_service.dart';
import '../../widgets/chat_tile.dart';
import 'direct_chat_screen.dart';
import 'new_direct_chat.dart';

const _bg = Color(0xFF190831);

class DirectChatsPage extends StatefulWidget {
  const DirectChatsPage({super.key});

  @override
  State<DirectChatsPage> createState() => _DirectChatsPageState();
}

class _DirectChatsPageState extends State<DirectChatsPage> {
  final _directService = DirectService();

  void _openChat(BuildContext context, String chatId, String otherUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(chatId: chatId, otherUid: otherUid),
      ),
    );
  }

  void _openNewChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewDirectChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: () => _openNewChat(context),
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Sign in to view your chats'))
          : StreamBuilder<List<DirectChat>>(
              stream: _directService.getUserChatsStream(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chats = snapshot.data ?? [];
                if (chats.isEmpty) {
                  return _EmptyDirectChats(onCreate: () => _openNewChat(context));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: chats.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final otherUid = chat.otherUserId(currentUser.uid);
                    return FutureBuilder<UserEntity?>(
                      future: _directService.getUser(otherUid),
                      builder: (context, userSnap) {
                        final user = userSnap.data;
                        return ChatTile(
                          name: user?.displayName ?? otherUid,
                          lastMessage: chat.lastMessage,
                          lastMessageAt: chat.lastMessageAt,
                          memberCount: 2,
                          onTap: () => _openChat(context, chat.id, otherUid),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _EmptyDirectChats extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyDirectChats({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 40, color: Color(0xFFFE4EF0)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No messages yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a conversation with a friend',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.edit_square),
            label: const Text('New message'),
          ),
        ],
      ),
    );
  }
}
