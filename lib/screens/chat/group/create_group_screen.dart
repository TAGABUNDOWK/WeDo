import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/user_entity.dart';
import '../../../services/group/group_service.dart';
import '../../../services/friends/friend_service.dart';
import '../../../services/direct/direct_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _groupService = GroupService();
  final _friendService = FriendService();
  final _directService = DirectService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  File? _selectedImage;
  List<_FriendItem> _friends = [];
  final Set<String> _selectedFriendUids = {};
  String _searchQuery = '';
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (_currentUser == null) return;
    try {
      final friendships = await _friendService
          .getFriendsStream(_currentUser.uid)
          .first;
      final friends = <_FriendItem>[];
      for (final f in friendships) {
        final otherUid = f.otherUserId(_currentUser.uid);
        if (otherUid.isEmpty) continue;
        final user = await _directService.getUser(otherUid);
        friends.add(_FriendItem(uid: otherUid, user: user));
      }
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  List<_FriendItem> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    final q = _searchQuery.toLowerCase();
    return _friends.where((f) {
      final name = (f.user?.displayName ?? '').toLowerCase();
      final email = (f.user?.email ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group Photo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final groupId = await _groupService.createGroup(
        name: _nameCtrl.text.trim(),
        createdBy: _currentUser.uid,
        displayName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
      );

      if (_selectedImage != null && groupId.isNotEmpty) {
        await _groupService.uploadGroupPhoto(
          groupId: groupId,
          imageFile: _selectedImage!,
        );
      }

      final senderName = _currentUser.displayName ?? _currentUser.email ?? 'Unknown';
      for (final uid in _selectedFriendUids) {
        final friend = _friends.firstWhere((f) => f.uid == uid);
        final name = friend.user?.displayName ?? uid;
        await _groupService.addMember(
          groupId: groupId,
          memberUid: uid,
          displayName: name,
          invitedBy: _currentUser.uid,
        );
        await _groupService.sendSystemMessage(
          groupId: groupId,
          content: '$senderName added $name',
          senderName: senderName,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          if (_selectedFriendUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedFriendUids.length} selected',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : null,
                            child: _selectedImage == null
                                ? const Icon(Icons.group, size: 50, color: Colors.grey)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a group name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.person_add, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Add Friends (${_selectedFriendUids.length} selected)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingFriends)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_filteredFriends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No friends found' : 'No matches',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._filteredFriends.map((friend) {
                      final name = friend.user?.displayName ?? friend.uid;
                      final isSelected = _selectedFriendUids.contains(friend.uid);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedFriendUids.add(friend.uid);
                            } else {
                              _selectedFriendUids.remove(friend.uid);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          child: Text(name[0].toUpperCase()),
                        ),
                        title: Text(name),
                        subtitle: friend.user?.email != null
                            ? Text(
                                friend.user!.email!,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      );
                    }),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _createGroup,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Create Group'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendItem {
  final String uid;
  final UserEntity? user;
  const _FriendItem({required this.uid, required this.user});
}
