import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constants.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

const _bg = Color(0xFFE7ECEF);
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatListTime(dynamic timestamp) {
  if (timestamp == null) return '';
  DateTime dt;
  if (timestamp is Timestamp) {
    dt = timestamp.toDate();
  } else if (timestamp is DateTime) {
    dt = timestamp;
  } else {
    return '';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(dt.year, dt.month, dt.day);
  if (msgDate == today) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
  if (msgDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (dt.year == now.year) return '${_months[dt.month - 1]} ${dt.day}';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class GroupChatsPage extends StatelessWidget {
  const GroupChatsPage({super.key});

  Future<void> _openCreateGroup(BuildContext context) {
    return Navigator.push(
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
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.groupsCollection)
                  .where('members', arrayContains: currentUser.uid)
                  .orderBy('lastMessageAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _EmptyChats(onCreate: () => _openCreateGroup(context));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _ChatTile(
                      name: data['name'] as String? ?? 'Group',
                      lastMessage: data['lastMessage'] as String?,
                      lastMessageAt: data['lastMessageAt'],
                      memberCount: (data['members'] as List?)?.length ?? 0,
                      onTap: () => _openChat(context, doc.id),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyChats({required this.onCreate});

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
              color: _bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.white, offset: Offset(-5, -5), blurRadius: 10),
                BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(5, 5), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.forum_outlined, size: 40, color: Colors.blue),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a group chat with your friends',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.group_add),
            label: const Text('Create group chat'),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final dynamic lastMessageAt;
  final int memberCount;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.memberCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 12),
              BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(6, 6), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage?.isNotEmpty == true ? lastMessage! : 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: lastMessage?.isNotEmpty == true
                                  ? Colors.black54
                                  : Colors.black26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatListTime(lastMessageAt),
                          style: const TextStyle(fontSize: 11, color: Colors.black38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
