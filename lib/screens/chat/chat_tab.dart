import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/direct_chat.dart';
import '../../models/group_chat.dart';
import '../../models/user_entity.dart';
import '../../services/group/group_service.dart';
import '../../services/direct/direct_service.dart';
import '../../widgets/chat_tile.dart';
import 'group/group_chat_screen.dart';
import 'group/create_group_screen.dart';
import 'direct/direct_chat_screen.dart';
import 'direct/new_direct_chat.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _groupService = GroupService();
  final _directService = DirectService();
  final Map<String, UserEntity?> _userCache = {};

  Future<UserEntity?> _getCachedUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final user = await _directService.getUser(uid);
    if (mounted) _userCache[uid] = user;
    return user;
  }

  void _showNewChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1045),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add, color: Color(0xFFFE4EF0)),
              ),
              title: const Text(
                'Create group chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Chat with multiple people',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFE4EF0)),
              ),
              title: const Text(
                'New message',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Start a direct conversation',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewDirectChatScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupChat(String groupId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => GroupChatScreen(groupId: groupId),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ).then((_) {
      if (uid != null) _groupService.markMessagesAsRead(groupId, uid);
    });
  }

  void _openDirectChat(String chatId, String otherUid) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => DirectChatScreen(chatId: chatId, otherUid: otherUid),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ).then((_) {
      if (uid != null) _directService.markMessagesAsRead(chatId, uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: const Color(0x80190831),
        elevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _showNewChatMenu,
            icon: const Icon(Icons.message, color: Colors.white70),
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                'Sign in to view your chats',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : StreamBuilder<List<GroupChat>>(
              stream: _groupService.getUserGroupsStream(currentUser.uid),
              builder: (context, groupSnap) {
                if (groupSnap.hasError) {
                  return Center(child: Text('Error: ${groupSnap.error}', style: const TextStyle(color: Colors.white54)));
                }
                if (groupSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFE4EF0)));
                }
                final groups = groupSnap.data ?? [];
                return StreamBuilder<List<DirectChat>>(
                  stream: _directService.getUserChatsStream(currentUser.uid),
                  builder: (context, dmSnap) {
                    if (dmSnap.hasError) {
                      return Center(child: Text('Error: ${dmSnap.error}', style: const TextStyle(color: Colors.white54)));
                    }
                    if (dmSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFE4EF0)));
                    }
                    final directChats = dmSnap.data ?? [];

                    if (groups.isEmpty && directChats.isEmpty) {
                      return _EmptyChats(onCreate: _showNewChatMenu);
                    }

                    final allChats = <_ChatItem>[];
                    for (final g in groups) {
                      allChats.add(_ChatItem.group(g));
                    }
                    for (final d in directChats) {
                      allChats.add(_ChatItem.direct(d));
                    }
                    allChats.sort((a, b) {
                      final aTime = a.lastMessageAt ?? DateTime(0);
                      final bTime = b.lastMessageAt ?? DateTime(0);
                      return bTime.compareTo(aTime);
                    });

                    return ListView.separated(
                      itemCount: allChats.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 76,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, index) {
                        final item = allChats[index];
                        if (item.isGroup) {
                          final group = item.group!;
                          final hasUnread = group.lastMessage != null &&
                              group.lastMessageSenderId != null &&
                              group.lastMessageSenderId != currentUser.uid &&
                              !group.lastMessageReadBy.contains(currentUser.uid);
                          return ChatTile(
                            name: group.name,
                            lastMessage: group.lastMessage,
                            lastMessageAt: group.lastMessageAt,
                            memberCount: group.memberCount,
                            isGroup: true,
                            hasUnread: hasUnread,
                            lastSenderId: group.lastMessageSenderId,
                            currentUserId: currentUser.uid,
                            avatarUrl: group.photoUrl,
                            onTap: () => _openGroupChat(group.id),
                          );
                        } else {
                          final chat = item.direct!;
                          final otherUid = chat.otherUserId(currentUser.uid);
                          final hasUnread = chat.lastMessage != null &&
                              chat.lastMessageSenderId != null &&
                              chat.lastMessageSenderId != currentUser.uid &&
                              !chat.lastMessageReadBy.contains(currentUser.uid);
                          return FutureBuilder<UserEntity?>(
                            future: _getCachedUser(otherUid),
                            builder: (context, userSnap) {
                              final user = userSnap.data;
                              return ChatTile(
                                name: user?.displayName ?? otherUid,
                                lastMessage: chat.lastMessage,
                                lastMessageAt: chat.lastMessageAt,
                                memberCount: 2,
                                isGroup: false,
                                hasUnread: hasUnread,
                                lastSenderId: chat.lastMessageSenderId,
                                currentUserId: currentUser.uid,
                                avatarUrl: user?.photoUrl,
                                avatarAsset: user?.avatarAsset,
                                onTap: () => _openDirectChat(chat.id, otherUid),
                              );
                            },
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ChatItem {
  final GroupChat? group;
  final DirectChat? direct;
  final bool isGroup;

  _ChatItem.group(this.group) : direct = null, isGroup = true;
  _ChatItem.direct(this.direct) : group = null, isGroup = false;

  DateTime? get lastMessageAt =>
      isGroup ? group?.lastMessageAt : direct?.lastMessageAt;
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
            decoration: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, size: 40, color: Color(0xFFFE4EF0)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a conversation with friends',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE4EF0),
            ),
            icon: const Icon(Icons.message),
            label: const Text('New chat'),
          ),
        ],
      ),
    );
  }
}
