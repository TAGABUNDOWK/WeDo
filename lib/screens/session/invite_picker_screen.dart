import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_chat.dart';
import '../../models/user_entity.dart';
import '../../services/group/group_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/session/session_service.dart';

class InvitePickerScreen extends StatefulWidget {
  final String sessionId;
  final String hostId;
  final String topic;

  const InvitePickerScreen({
    super.key,
    required this.sessionId,
    required this.hostId,
    required this.topic,
  });

  @override
  State<InvitePickerScreen> createState() => _InvitePickerScreenState();
}

class _InvitePickerScreenState extends State<InvitePickerScreen> {
  final _groupService = GroupService();
  final _directService = DirectService();
  final _friendService = FriendService();
  final _sessionService = SessionService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _searchCtrl = TextEditingController();

  String _query = '';
  bool _isSending = false;

  final Set<String> _selectedGroupIds = {};
  final Set<String> _selectedFriendUids = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _totalSelected => _selectedGroupIds.length + _selectedFriendUids.length;

  Future<void> _sendInvites() async {
    if (_currentUser == null || _totalSelected == 0 || _isSending) return;

    setState(() => _isSending = true);

    try {
      final hostName = _currentUser.displayName ?? _currentUser.email ?? 'Host';

      for (final groupId in _selectedGroupIds) {
        await _groupService.sendInviteMessage(
          groupId: groupId,
          senderId: _currentUser.uid,
          senderName: hostName,
          sessionId: widget.sessionId,
          topic: widget.topic,
          hostName: hostName,
        );
      }

      for (final friendUid in _selectedFriendUids) {
        final chatId = await _directService.getOrCreateChat(
          currentUid: _currentUser.uid,
          otherUid: friendUid,
        );
        await _directService.sendInviteMessage(
          chatId: chatId,
          senderId: _currentUser.uid,
          senderName: hostName,
          sessionId: widget.sessionId,
          topic: widget.topic,
          hostName: hostName,
        );
      }

      await _sessionService.markInvited(
        sessionId: widget.sessionId,
        hostId: widget.hostId,
        invitedUserIds: _selectedFriendUids.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invites sent to $_totalSelected chat${_totalSelected == 1 ? '' : 's'}!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF190831);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'Invite to ${widget.topic}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (_totalSelected > 0)
            TextButton(
              onPressed: _isSending ? null : _sendInvites,
              child: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Send ($_totalSelected)',
                      style: const TextStyle(
                        color: Color(0xFFFE4EF0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSection(
                  title: 'Group Chats',
                  child: _buildGroupChatsList(),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Friends',
                  child: _buildFriendsList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildGroupChatsList() {
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<List<GroupChat>>(
      stream: _groupService.getUserGroupsStream(_currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var groups = snapshot.data ?? [];

        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          groups = groups.where((g) => g.name.toLowerCase().contains(q)).toList();
        }

        if (groups.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No group chats', style: TextStyle(color: Colors.white54)),
          );
        }

        return Column(
          children: groups.map((group) => _buildGroupTile(group)).toList(),
        );
      },
    );
  }

  Widget _buildGroupTile(GroupChat group) {
    final isSelected = _selectedGroupIds.contains(group.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedGroupIds.remove(group.id);
              } else {
                _selectedGroupIds.add(group.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFE4EF0).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFE4EF0).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group, color: Color(0xFFFE4EF0), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${group.memberCount} members',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFFFE4EF0), size: 22)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<List>(
      stream: _friendService.getFriendsStream(_currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final friendships = snapshot.data ?? [];

        if (friendships.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No friends yet', style: TextStyle(color: Colors.white54)),
          );
        }

        return FutureBuilder<List<_FriendUser>>(
          future: _loadFriends(friendships),
          builder: (context, friendSnapshot) {
            if (friendSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            var friends = friendSnapshot.data ?? [];

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              friends = friends.where((f) {
                final name = (f.user?.displayName ?? '').toLowerCase();
                final email = (f.user?.email ?? '').toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList();
            }

            if (friends.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No friends found', style: TextStyle(color: Colors.white54)),
              );
            }

            return Column(
              children: friends.map((f) => _buildFriendTile(f)).toList(),
            );
          },
        );
      },
    );
  }

  Future<List<_FriendUser>> _loadFriends(List friendships) async {
    final results = <_FriendUser>[];
    for (final f in friendships) {
      final uid = f.otherUserId(_currentUser!.uid);
      if (uid.isEmpty) continue;
      final user = await _directService.getUser(uid);
      results.add(_FriendUser(uid: uid, user: user));
    }
    return results;
  }

  Widget _buildFriendTile(_FriendUser friend) {
    final isSelected = _selectedFriendUids.contains(friend.uid);
    final name = friend.user?.displayName ?? friend.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFriendUids.remove(friend.uid);
              } else {
                _selectedFriendUids.add(friend.uid);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFE4EF0).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFE4EF0).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFFFE4EF0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (friend.user?.email != null)
                        Text(
                          friend.user!.email!,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFFFE4EF0), size: 22)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendUser {
  final String uid;
  final UserEntity? user;
  const _FriendUser({required this.uid, this.user});
}
