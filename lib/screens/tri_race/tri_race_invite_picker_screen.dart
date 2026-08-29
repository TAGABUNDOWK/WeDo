import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_chat.dart';
import '../../models/friend_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../services/group/group_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/friends/friend_service.dart';
import '../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class TriRaceInvitePickerScreen extends StatefulWidget {
  final String raceId;
  const TriRaceInvitePickerScreen({super.key, required this.raceId});

  @override
  State<TriRaceInvitePickerScreen> createState() => _TriRaceInvitePickerScreenState();
}

class _TriRaceInvitePickerScreenState extends State<TriRaceInvitePickerScreen> {
  final _triRaceService = TriRaceService();
  final _groupService = GroupService();
  final _directService = DirectService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();

  List<GroupChat> _groups = [];
  List<_FriendUser> _friends = [];
  final Set<String> _selectedGroupIds = {};
  final Set<String> _selectedFriendIds = {};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final groups = await _groupService.getUserGroupsStream(user.uid).first;

      final friendshipsSnap = await FriendService().getFriendsStream(user.uid).first;
      final friends = <_FriendUser>[];
      for (final f in friendshipsSnap) {
        final otherUid = f.otherUserId(user.uid);
        if (otherUid.isNotEmpty) {
          final userData = await _directService.getUser(otherUid);
          if (userData != null) {
            friends.add(_FriendUser(uid: otherUid, name: userData.displayName, friendEntity: f));
          }
        }
      }

      if (mounted) {
        setState(() {
          _groups = groups;
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalSelected => _selectedGroupIds.length + _selectedFriendIds.length;

  Future<void> _sendInvites() async {
    if (_totalSelected == 0) return;
    setState(() => _isSending = true);

    final user = _currentUser;
    if (user == null) return;

    try {
      final race = await _triRaceService.getTriRaceStream(widget.raceId).first;
      if (race == null) return;

      for (final groupId in _selectedGroupIds) {
        await _groupService.sendTriRaceInviteMessage(
          groupId: groupId,
          senderId: user.uid,
          senderName: user.displayName ?? user.email ?? 'Player',
          raceId: widget.raceId,
          hostName: user.displayName ?? user.email ?? 'Player',
        );
      }

      for (final friendId in _selectedFriendIds) {
        final chatId = await _getDirectChatId(user.uid, friendId);
        if (chatId != null) {
          await _directService.sendTriRaceInviteMessage(
            chatId: chatId,
            senderId: user.uid,
            senderName: user.displayName ?? user.email ?? 'Player',
            raceId: widget.raceId,
            hostName: user.displayName ?? user.email ?? 'Player',
          );
        }
      }

      await _triRaceService.markInvited(
        raceId: widget.raceId,
        hostId: user.uid,
        invitedUserIds: _selectedFriendIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invites sent to $_totalSelected chat${_totalSelected > 1 ? 's' : ''}'),
            backgroundColor: const Color(0xFF4ECDC4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invites'), backgroundColor: Color(0xFFEF5350)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<String?> _getDirectChatId(String uid1, String uid2) async {
    try {
      final chats = await FirebaseFirestore.instance
          .collection('direct_chats')
          .where('members', arrayContains: uid1)
          .get();
      for (final doc in chats.docs) {
        final members = (doc.data()['members'] as List?)?.cast<String>() ?? [];
        if (members.contains(uid2)) return doc.id;
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: const Color(0xFF190831),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Invite Friends',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (_totalSelected > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _isSending ? null : _sendInvites,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Send ($_totalSelected)',
                          style: const TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Search ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        fontFamily: _fontFamily,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    children: [
                      // ── Group Chats ──
                      if (_groups.isNotEmpty) ...[
                        const _SectionHeader(title: 'Group Chats'),
                        ..._groups.map((group) => _GroupTile(
                          group: group,
                          isSelected: _selectedGroupIds.contains(group.id),
                          onTap: () {
                            setState(() {
                              if (_selectedGroupIds.contains(group.id)) {
                                _selectedGroupIds.remove(group.id);
                              } else {
                                _selectedGroupIds.add(group.id);
                              }
                            });
                          },
                        )),
                      ],

                      // ── Friends ──
                      if (_friends.isNotEmpty) ...[
                        const _SectionHeader(title: 'Friends'),
                        ..._friends.map((friend) => _FriendTile(
                          friend: friend,
                          isSelected: _selectedFriendIds.contains(friend.uid),
                          onTap: () {
                            setState(() {
                              if (_selectedFriendIds.contains(friend.uid)) {
                                _selectedFriendIds.remove(friend.uid);
                              } else {
                                _selectedFriendIds.add(friend.uid);
                              }
                            });
                          },
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupChat group;
  final bool isSelected;
  final VoidCallback onTap;
  const _GroupTile({required this.group, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
        child: Text(
          group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
          style: const TextStyle(fontFamily: _fontFamily, color: Color(0xFF4ECDC4)),
        ),
      ),
      title: Text(
        group.name,
        style: const TextStyle(fontFamily: _fontFamily, color: Colors.white, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFF4ECDC4) : AppColors.textSecondary,
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final _FriendUser friend;
  final bool isSelected;
  final VoidCallback onTap;
  const _FriendTile({required this.friend, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFDDA0DD).withValues(alpha: 0.2),
        child: Text(
          friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
          style: const TextStyle(fontFamily: _fontFamily, color: Color(0xFFDDA0DD)),
        ),
      ),
      title: Text(
        friend.name,
        style: const TextStyle(fontFamily: _fontFamily, color: Colors.white, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFF4ECDC4) : AppColors.textSecondary,
      ),
    );
  }
}

class _FriendUser {
  final String uid;
  final String name;
  final FriendEntity friendEntity;
  _FriendUser({required this.uid, required this.name, required this.friendEntity});
}
