import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/group/group_service.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _groupService = GroupService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _addMember() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter user UID or email',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final matched = await _groupService.findUserByEmail(result);

      final targetUid = matched?.uid ?? result;
      final targetName = matched?.name ?? result;

      await _groupService.addMember(
        groupId: widget.groupId,
        memberUid: targetUid,
        displayName: targetName,
        invitedBy: _currentUser!.uid,
      );
      setState(() {});
    }
  }

  Future<void> _removeMember(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove $memberId from this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _groupService.removeMember(
        groupId: widget.groupId,
        memberUid: memberId,
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _groupService.getGroupDoc(widget.groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('Group not found'));
          }
          final memberIds = List<String>.from(data['members'] ?? []);
          final createdBy = data['createdBy'] as String? ?? '';
          final isAdmin = createdBy == _currentUser?.uid;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  child: Text(
                    (data['name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  data['name'] ?? 'Untitled',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${memberIds.length} members',
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
              ...memberIds.map((id) => ListTile(
                    leading: CircleAvatar(child: Text(id[0].toUpperCase())),
                    title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: _groupService.getUserDoc(id),
                      builder: (context, userSnap) {
                        final name = userSnap.data?.data()?['displayName'] ?? id;
                        return Text(name);
                      },
                    ),
                    subtitle: id == createdBy ? const Text('Creator', style: TextStyle(fontSize: 12)) : null,
                    trailing: (isAdmin && id != _currentUser?.uid)
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeMember(id),
                          )
                        : null,
                  )),
              const Divider(),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                  onTap: () async {
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
                    if (confirm == true) {
                      await _groupService.deleteGroup(widget.groupId);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
