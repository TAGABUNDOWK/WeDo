import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/group/group_service.dart';
import '../../widgets/chat_tile.dart';
import '../../widgets/empty_chats.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

const _bg = Color(0xFF190831);

class GroupChatsPage extends StatefulWidget {
  const GroupChatsPage({super.key});

  @override
  State<GroupChatsPage> createState() => _GroupChatsPageState();
}

class _GroupChatsPageState extends State<GroupChatsPage> {
  final _groupService = GroupService();

  void _openCreateGroup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
  }

  void _openChat(BuildContext context, String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId)),
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
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'New group chat',
            onPressed: () => _openCreateGroup(context),
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Sign in to view your chats'))
          : StreamBuilder<List>(
              stream: _groupService.getUserGroupsStream(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups = snapshot.data ?? [];
                if (groups.isEmpty) {
                  return EmptyChats(onCreate: () => _openCreateGroup(context));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ChatTile(
                      name: group.name,
                      lastMessage: group.lastMessage,
                      lastMessageAt: group.lastMessageAt,
                      memberCount: group.memberCount,
                      onTap: () => _openChat(context, group.id),
                    );
                  },
                );
              },
            ),
    );
  }
}
