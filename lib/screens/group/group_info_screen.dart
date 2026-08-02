import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_chat.dart';
import '../../models/user_entity.dart';
import '../../services/group/group_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/direct/direct_service.dart';

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
    final members = await _groupService.getGroupMembersWithNames(widget.groupId);
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
        title: const Text('Rename Group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Group name',
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

    if (result != null && result.isNotEmpty && mounted) {
      await _groupService.updateGroupName(groupId: widget.groupId, name: result);
      _loadData();
    }
  }

  Future<void> _changeGroupPhoto() async {
    final ctrl = TextEditingController(text: _group?.photoUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Group Photo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste image URL',
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

    if (result != null && result.isNotEmpty && mounted) {
      await _groupService.updateGroupPhoto(groupId: widget.groupId, photoUrl: result);
      _loadData();
    }
  }

  Future<void> _changeNickname(String memberUid) async {
    final currentName = _getMemberName(memberUid);
    final ctrl = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Nickname'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nickname',
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

    if (result != null && result.isNotEmpty && mounted) {
      final senderName = _currentUser?.displayName ?? _currentUser?.email ?? 'Someone';
      await _groupService.updateMemberNickname(
        groupId: widget.groupId,
        memberUid: memberUid,
        displayName: result,
      );
      await _groupService.sendSystemMessage(
        groupId: widget.groupId,
        content: '$senderName changed ${_getMemberName(memberUid)}\'s nickname to "$result"',
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
      MaterialPageRoute(
        builder: (_) => _AddMemberScreen(friends: friends),
      ),
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      final senderName = _currentUser?.displayName ?? _currentUser?.email ?? 'Someone';
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
        title: const Text('Remove Member?'),
        content: Text('Remove $memberName from this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final senderName = _currentUser?.displayName ?? _currentUser?.email ?? 'Someone';
      await _groupService.removeMember(groupId: widget.groupId, memberUid: memberId);
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
        title: const Text('Delete Group?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _groupService.deleteGroup(widget.groupId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final isAdmin = group?.isAdmin(_currentUser?.uid ?? '') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: group == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GestureDetector(
                  onTap: isAdmin ? _changeGroupPhoto : null,
                  child: Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: group.photoUrl != null && group.photoUrl!.isNotEmpty
                              ? NetworkImage(group.photoUrl!)
                              : null,
                          child: group.photoUrl == null || group.photoUrl!.isEmpty
                              ? Text(
                                  group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 32),
                                )
                              : null,
                        ),
                        if (isAdmin)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: isAdmin ? _renameGroup : null,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        if (isAdmin) const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${group.memberCount} members',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.person_add, color: Colors.blue),
                    title: const Text('Add Members'),
                    onTap: _addMember,
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Members', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ...group.members.map((id) {
                  final isMe = id == _currentUser?.uid;
                  return ListTile(
                    leading: CircleAvatar(child: Text(id[0].toUpperCase())),
                    title: Text(_getMemberName(id)),
                    subtitle: id == group.createdBy
                        ? const Text('Creator', style: TextStyle(fontSize: 12))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          onPressed: () => _changeNickname(id),
                          tooltip: 'Change nickname',
                        ),
                        if (isAdmin && !isMe)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeMember(id),
                          ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                    onTap: _deleteGroup,
                  ),
              ],
            ),
    );
  }
}

class _FriendUser {
  final String uid;
  final UserEntity? user;
  const _FriendUser({required this.uid, required this.user});
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
      appBar: AppBar(
        title: const Text('Add Members'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: Text(
                'Add (${_selected.length})',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
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
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No friends found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final friend = _filtered[index];
                      final name = friend.user?.displayName ?? friend.uid;
                      final isSelected = _selected.contains(friend.uid);
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(name[0].toUpperCase()),
                        ),
                        title: Text(name),
                        subtitle: friend.user?.email != null
                            ? Text(friend.user!.email!,
                                style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: Checkbox(
                          value: isSelected,
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
