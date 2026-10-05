import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/event_prefill.dart';
import '../../models/group_chat.dart';
import '../../models/user_entity.dart';
import '../../services/direct/direct_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/group/group_service.dart';
import '../chat/event/create_event_screen.dart';

/// Lets any PickFight participant pick ONE chat (group or friend DM) to send
/// the winning-card event to, then hands the prefill to the existing
/// [CreateEventScreen]. Structure mirrors InvitePickerScreen, but selection
/// is single-choice so the existing single-target creation flow runs
/// untouched.
class EventSharePickerScreen extends StatefulWidget {
  final EventPrefill prefill;

  const EventSharePickerScreen({super.key, required this.prefill});

  @override
  State<EventSharePickerScreen> createState() => _EventSharePickerScreenState();
}

class _EventSharePickerScreenState extends State<EventSharePickerScreen> {
  final _groupService = GroupService();
  final _directService = DirectService();
  final _friendService = FriendService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _searchCtrl = TextEditingController();

  String _query = '';
  bool _isContinuing = false;

  String? _selectedGroupId;
  String? _selectedFriendUid;
  String _selectedLabel = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasSelection =>
      _selectedGroupId != null || _selectedFriendUid != null;

  void _selectGroup(GroupChat group) {
    setState(() {
      final already = _selectedGroupId == group.id;
      _selectedGroupId = already ? null : group.id;
      _selectedFriendUid = null;
      _selectedLabel = already ? '' : group.name;
    });
  }

  void _selectFriend(String uid, String name) {
    setState(() {
      final already = _selectedFriendUid == uid;
      _selectedFriendUid = already ? null : uid;
      _selectedGroupId = null;
      _selectedLabel = already ? '' : name;
    });
  }

  Future<void> _continue() async {
    if (!_hasSelection || _isContinuing) return;

    final prefill = widget.prefill;
    if (_selectedGroupId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateEventScreen(
            groupId: _selectedGroupId,
            prefill: prefill,
          ),
        ),
      );
      return;
    }

    setState(() => _isContinuing = true);
    try {
      final chatId = await _directService.getOrCreateChat(
        currentUid: _currentUser!.uid,
        otherUid: _selectedFriendUid!,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateEventScreen(
            chatId: chatId,
            prefill: prefill,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isContinuing = false);
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
        title: const Text(
          'Share as Event',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasSelection && !_isContinuing ? _continue : null,
            child: _isContinuing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(
                      color: Color(0xFFFE4EF0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 8),
                _buildWinnerPreview(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFFE4EF0), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
          if (_hasSelection)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Sending to: $_selectedLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWinnerPreview() {
    final prefill = widget.prefill;
    final hasImage = prefill.imageUrl != null && prefill.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
        color: const Color(0xFFFFD700).withValues(alpha: 0.06),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasImage
                  ? Image.network(
                      prefill.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.emoji_events_rounded,
                            color: Color(0xFFFFD700), size: 28),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD700), size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'PICKFIGHT WINNER',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  prefill.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prefill.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
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
          groups =
              groups.where((g) => g.name.toLowerCase().contains(q)).toList();
        }

        if (groups.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No group chats', style: TextStyle(color: Colors.white54)),
          );
        }

        return Column(
          children: groups.map(_buildGroupTile).toList(),
        );
      },
    );
  }

  Widget _buildGroupTile(GroupChat group) {
    final isSelected = _selectedGroupId == group.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectGroup(group),
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
                  child: const Icon(Icons.group,
                      color: Color(0xFFFE4EF0), size: 18),
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
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFFFE4EF0) : Colors.white38,
                  size: 22,
                ),
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
          future: _friendsFutureFor(friendships),
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
                child:
                    Text('No friends found', style: TextStyle(color: Colors.white54)),
              );
            }

            return Column(
              children: friends.map(_buildFriendTile).toList(),
            );
          },
        );
      },
    );
  }

  // Rebuilds of this screen must not recreate the future — a new future on
  // every build restarts the fetch and flashes the loading spinner.
  List? _cachedFriendships;
  Future<List<_FriendUser>>? _cachedFriendsFuture;

  Future<List<_FriendUser>> _friendsFutureFor(List friendships) {
    if (!identical(_cachedFriendships, friendships) ||
        _cachedFriendsFuture == null) {
      _cachedFriendships = friendships;
      _cachedFriendsFuture = _loadFriends(friendships);
    }
    return _cachedFriendsFuture!;
  }

  Future<List<_FriendUser>> _loadFriends(List friendships) async {
    final uids = <String>[];
    for (final f in friendships) {
      final uid = f.otherUserId(_currentUser!.uid);
      if (uid.isNotEmpty) uids.add(uid);
    }
    final users = await Future.wait(uids.map(_directService.getUser));
    return [
      for (var i = 0; i < uids.length; i++)
        _FriendUser(uid: uids[i], user: users[i]),
    ];
  }

  Widget _buildFriendTile(_FriendUser friend) {
    final isSelected = _selectedFriendUid == friend.uid;
    final name = friend.user?.displayName ?? friend.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectFriend(friend.uid, name),
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
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFFFE4EF0) : Colors.white38,
                  size: 22,
                ),
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
  const _FriendUser({required this.uid, required this.user});
}
