import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/group_chat.dart';
import '../../../models/message.dart';
import '../../../models/user_entity.dart';
import '../../../services/group/group_service.dart';
import '../../../services/friends/friend_service.dart';
import '../../../services/direct/direct_service.dart';
import '../image_viewer_screen.dart';
import '../../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _groupService = GroupService();
  final _friendService = FriendService();
  final _directService = DirectService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _members = [];
  GroupChat? _group;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final group = await _groupService.getGroup(widget.groupId);
    final members = await _groupService.getGroupMembersWithNames(
      widget.groupId,
    );
    if (mounted) {
      setState(() {
        _group = group;
        _members = members;
      });
    }
  }

  String _getMemberName(String uid) {
    for (final m in _members) {
      if (m['uid'] == uid) return m['displayName'] as String;
    }
    return uid;
  }

  Future<void> _renameGroup() async {
    final ctrl = TextEditingController(text: _group?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Rename Group',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: _fontFamily, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Group name',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.midnightBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lavenderAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(fontFamily: _fontFamily, color: AppColors.lavenderAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

            if (result != null && result.isNotEmpty && mounted) {
              await _groupService.updateGroupName(
                groupId: widget.groupId,
                name: result,
              );
              _loadData();
            }
          }

  Future<void> _changeGroupPhoto() async {
    final ctrl = TextEditingController(text: _group?.photoUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Change Group Photo',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: _fontFamily, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste image URL',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.midnightBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lavenderAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(fontFamily: _fontFamily, color: AppColors.lavenderAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

            if (result != null && result.isNotEmpty && mounted) {
              await _groupService.updateGroupPhoto(
                groupId: widget.groupId,
                photoUrl: result,
              );
              _loadData();
            }
          }

  Future<void> _changeNickname(String memberUid) async {
    final currentName = _getMemberName(memberUid);
    final ctrl = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Change Nickname',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: _fontFamily, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nickname',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.midnightBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lavenderAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(fontFamily: _fontFamily, color: AppColors.lavenderAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final senderName =
          _currentUser?.displayName ?? _currentUser?.email ?? 'Someone';
      await _groupService.updateMemberNickname(
        groupId: widget.groupId,
        memberUid: memberUid,
        displayName: result,
      );
      await _groupService.sendSystemMessage(
        groupId: widget.groupId,
        content:
            '$senderName changed ${_getMemberName(memberUid)}\'s nickname to "$result"',
        senderName: senderName,
      );
      _loadData();
    }
  }

  Future<void> _addMember() async {
    if (_currentUser == null) return;

    final friendships = await _friendService
        .getFriendsStream(_currentUser.uid)
        .first;

    final memberUids = _members.map((m) => m['uid'] as String).toSet();

    final friendUids = friendships
        .map((f) => f.otherUserId(_currentUser.uid))
        .where((uid) => uid.isNotEmpty && !memberUids.contains(uid))
        .toList();

    final friends = <_FriendUser>[];
    for (final uid in friendUids) {
      final user = await _directService.getUser(uid);
      friends.add(_FriendUser(uid: uid, user: user));
    }

    if (!mounted) return;

    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => _AddMemberScreen(friends: friends)),
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      final senderName =
          _currentUser.displayName ?? _currentUser.email ?? 'Someone';
      for (final uid in selected) {
        final friend = friends.firstWhere((f) => f.uid == uid);
        final name = friend.user?.displayName ?? uid;
        await _groupService.addMember(
          groupId: widget.groupId,
          memberUid: uid,
          displayName: name,
          invitedBy: _currentUser.uid,
        );
        await _groupService.sendSystemMessage(
          groupId: widget.groupId,
          content: '$senderName added $name',
          senderName: senderName,
        );
      }
      _loadData();
    }
  }

  Future<void> _removeMember(String memberId) async {
    final memberName = _getMemberName(memberId);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Remove Member?',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Remove $memberName from this group?',
          style: const TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(fontFamily: _fontFamily, color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final senderName =
          _currentUser?.displayName ?? _currentUser?.email ?? 'Someone';
      await _groupService.removeMember(
        groupId: widget.groupId,
        memberUid: memberId,
      );
      await _groupService.sendSystemMessage(
        groupId: widget.groupId,
        content: '$senderName removed $memberName',
        senderName: senderName,
      );
      _loadData();
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Delete Group?',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: _fontFamily, color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _groupService.deleteGroup(widget.groupId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Leave Group?',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'You will no longer be a member of this group.',
          style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(fontFamily: _fontFamily, color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final senderName = _currentUser?.displayName ?? _currentUser?.email ?? 'Someone';
      await _groupService.removeMember(
        groupId: widget.groupId,
        memberUid: _currentUser!.uid,
      );
      await _groupService.sendSystemMessage(
        groupId: widget.groupId,
        content: '$senderName left the group',
        senderName: senderName,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleMute() async {
    final user = _currentUser;
    if (user == null || _group == null) return;
    await _groupService.toggleMute(
      groupId: widget.groupId,
      uid: user.uid,
    );
    _loadData();
  }

  void _showInviteLink() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        title: const Text(
          'Invite to Group',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this Group ID with friends to invite them:',
              style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.midnightBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                widget.groupId,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  color: AppColors.lavenderAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showSearchMembers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF211635),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchCtrl.text.toLowerCase();
            final filtered = query.isEmpty
                ? _members
                : _members.where((m) {
                    final name = (m['displayName'] as String? ?? '').toLowerCase();
                    return name.contains(query);
                  }).toList();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(fontFamily: _fontFamily, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.midnightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lavenderAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final name = m['displayName'] as String? ?? '';
                        final uid = m['uid'] as String;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.lavenderAccent.withValues(alpha: 0.15),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 13,
                                color: AppColors.lavenderAccent,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontFamily: _fontFamily,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: uid == _group?.createdBy
                              ? const Text('Creator', style: TextStyle(fontFamily: _fontFamily, fontSize: 11, color: AppColors.lavenderAccent))
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final isAdmin = group?.isAdmin(_currentUser?.uid ?? '') ?? false;

    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      appBar: AppBar(
        backgroundColor: AppColors.midnightBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Group Info',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.glassBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
            onSelected: (value) {
              switch (value) {
                case 'leave':
                  _leaveGroup();
                  break;
                case 'mute':
                  _toggleMute();
                  break;
                case 'search':
                  _showSearchMembers();
                  break;
                case 'invite':
                  _showInviteLink();
                  break;
              }
            },
            itemBuilder: (context) {
              final isMuted = _group?.mutedBy.contains(_currentUser?.uid) ?? false;
              return [
                PopupMenuItem<String>(
                  value: 'leave',
                  child: Row(
                    children: [
                      const Icon(Icons.exit_to_app, size: 20, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      const Text(
                        'Leave Group',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(
                        isMuted ? Icons.notifications : Icons.notifications_off,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                        style: const TextStyle(
                          fontFamily: _fontFamily,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'search',
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      const Text(
                        'Search Members',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'invite',
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      const Text(
                        'Invite via Link',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: group == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.lavenderAccent),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                const SizedBox(height: 12),

                // ── Profile Section ──
                Center(
                  child: GestureDetector(
                    onTap: isAdmin ? _changeGroupPhoto : null,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lavenderAccent.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: const Color(0xFF211635),
                            backgroundImage:
                                group.photoUrl != null &&
                                    group.photoUrl!.isNotEmpty
                                ? NetworkImage(group.photoUrl!)
                                : null,
                            child:
                                group.photoUrl == null || group.photoUrl!.isEmpty
                                ? Text(
                                    group.name.isNotEmpty
                                        ? group.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontFamily: _fontFamily,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lavenderAccent,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (isAdmin)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.lavenderAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: AppColors.midnightBg,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: isAdmin ? _renameGroup : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.lavenderAccent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '${group.memberCount} members',
                    style: const TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Members Card ──
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Members',
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            GestureDetector(
                              onTap: _addMember,
                              child: const Icon(
                                Icons.person_add,
                                size: 20,
                                color: AppColors.lavenderAccent,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...group.members.map((id) {
                        final isMe = id == _currentUser?.uid;
                        final isCreator = id == group.createdBy;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.lavenderAccent.withValues(alpha: 0.15),
                                child: Text(
                                  _getMemberName(id).isNotEmpty
                                      ? _getMemberName(id)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lavenderAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getMemberName(id),
                                      style: const TextStyle(
                                        fontFamily: _fontFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isCreator)
                                      Container(
                                        margin: const EdgeInsets.only(top: 3),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.lavenderAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          'Creator',
                                          style: TextStyle(
                                            fontFamily: _fontFamily,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.lavenderAccent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _changeNickname(id),
                                child: const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: AppColors.lavenderAccent,
                                ),
                              ),
                              if (isAdmin && !isMe) ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _removeMember(id),
                                  child: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Media Card ──
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Media',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GroupMediaSection(groupId: widget.groupId),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Delete Group ──
                if (isAdmin)
                  _GlassCard(
                    child: GestureDetector(
                      onTap: _deleteGroup,
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Delete Group',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: child,
    );
  }
}

class _FriendUser {
  final String uid;
  final UserEntity? user;
  const _FriendUser({required this.uid, required this.user});
}

class _GroupMediaSection extends StatefulWidget {
  final String groupId;
  const _GroupMediaSection({required this.groupId});

  @override
  State<_GroupMediaSection> createState() => _GroupMediaSectionState();
}

class _GroupMediaSectionState extends State<_GroupMediaSection> {
  final _groupService = GroupService();
  List<String> _imageUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final messages = await _groupService.getMessagesOnce(widget.groupId);
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.lavenderAccent, strokeWidth: 2),
        ),
      );
    }
    if (_imageUrls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'No media shared yet',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(
                  imageUrl: _imageUrls[index],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddMemberScreen extends StatefulWidget {
  final List<_FriendUser> friends;
  const _AddMemberScreen({required this.friends});

  @override
  State<_AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<_AddMemberScreen> {
  final _searchCtrl = TextEditingController();
  final _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_FriendUser> get _filtered {
    if (_query.isEmpty) return widget.friends;
    final q = _query.toLowerCase();
    return widget.friends.where((f) {
      final name = (f.user?.displayName ?? '').toLowerCase();
      final email = (f.user?.email ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      appBar: AppBar(
        backgroundColor: AppColors.midnightBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Members',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: Text(
                'Add (${_selected.length})',
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  color: AppColors.lavenderAccent,
                  fontWeight: FontWeight.w600,
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
              style: const TextStyle(fontFamily: _fontFamily, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.glassBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.lavenderAccent),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No friends found',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final friend = _filtered[index];
                      final name = friend.user?.displayName ?? friend.uid;
                      final isSelected = _selected.contains(friend.uid);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.lavenderAccent.withValues(alpha: 0.15),
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lavenderAccent,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: _fontFamily,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: friend.user?.email != null
                            ? Text(
                                friend.user!.email!,
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: AppColors.lavenderAccent,
                          checkColor: AppColors.midnightBg,
                          side: const BorderSide(color: AppColors.glassBorder),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(friend.uid);
                              } else {
                                _selected.remove(friend.uid);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(friend.uid);
                            } else {
                              _selected.add(friend.uid);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
