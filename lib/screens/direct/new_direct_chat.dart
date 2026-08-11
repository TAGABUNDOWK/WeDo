import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_entity.dart';
import '../../services/friends/friend_service.dart';
import '../../services/direct/direct_service.dart';
import 'direct_chat_screen.dart';

class NewDirectChatScreen extends StatefulWidget {
  const NewDirectChatScreen({super.key});

  @override
  State<NewDirectChatScreen> createState() => _NewDirectChatScreenState();
}

class _NewDirectChatScreenState extends State<NewDirectChatScreen> {
  final _friendService = FriendService();
  final _directService = DirectService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  List<_FriendUser> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (_currentUser == null) return;

    final friendships = await _friendService.getFriendsStream(_currentUser.uid).first;
    final friendUids = friendships
        .map((f) => f.otherUserId(_currentUser.uid))
        .toList();

    final friends = <_FriendUser>[];
    for (final uid in friendUids) {
      final user = await _directService.getUser(uid);
      friends.add(_FriendUser(uid: uid, user: user));
    }

    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    }
  }

  bool _isStarting = false;

  Future<void> _startChat(String otherUid) async {
    if (_currentUser == null || _isStarting) return;

    setState(() => _isStarting = true);

    try {
      final chatId = await _directService.getOrCreateChat(
        currentUid: _currentUser.uid,
        otherUid: otherUid,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DirectChatScreen(chatId: chatId, otherUid: otherUid),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Message')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No friends yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Add friends to start chatting', style: TextStyle(color: Colors.black38)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _friends.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final name = friend.user?.displayName ?? friend.uid;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name[0].toUpperCase()),
                      ),
                      title: Text(name),
                      subtitle: friend.user?.email != null
                          ? Text(friend.user!.email!, style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: _isStarting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _isStarting ? null : () => _startChat(friend.uid),
                    );
                  },
                ),
    );
  }
}

class _FriendUser {
  final String uid;
  final UserEntity? user;
  const _FriendUser({required this.uid, required this.user});
}
