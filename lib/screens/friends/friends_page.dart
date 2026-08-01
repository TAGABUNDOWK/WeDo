import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/friend_entity.dart';
import '../../models/user_entity.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import 'add_friend_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _auth = FirebaseAuth.instance;
  final _friendService = FriendService();
  final _userService = UserService();
  final _bg = const Color(0xFFE7ECEF);

  String get _uid => _auth.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddFriendPage()),
            ),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Incoming Requests'),
          StreamBuilder<List<FriendEntity>>(
            stream: _friendService.getIncomingRequestsStream(_uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorText(snapshot.error);
              final list = snapshot.data ?? const <FriendEntity>[];
              if (list.isEmpty) return const _EmptyText('No pending requests');
              return Column(
                children: list
                    .map((f) => _IncomingTile(
                          friendship: f,
                          otherUid: f.otherUserId(_uid),
                          userService: _userService,
                          onAccept: () => _accept(f),
                          onDecline: () => _decline(f),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Sent Requests'),
          StreamBuilder<List<FriendEntity>>(
            stream: _friendService.getOutgoingRequestsStream(_uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorText(snapshot.error);
              final list = snapshot.data ?? const <FriendEntity>[];
              if (list.isEmpty) return const _EmptyText('No sent requests');
              return Column(
                children: list
                    .map((f) => _SentTile(
                          friendship: f,
                          otherUid: f.otherUserId(_uid),
                          userService: _userService,
                          onCancel: () => _cancel(f),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Your Friends'),
          StreamBuilder<List<FriendEntity>>(
            stream: _friendService.getFriendsStream(_uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorText(snapshot.error);
              final list = snapshot.data ?? const <FriendEntity>[];
              if (list.isEmpty) return const _EmptyText('No friends yet');
              return Column(
                children: list
                    .map((f) => _FriendTile(
                          friendship: f,
                          otherUid: f.otherUserId(_uid),
                          userService: _userService,
                          onRemove: () => _remove(f),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _accept(FriendEntity f) async {
    try {
      await _friendService.acceptRequest(f.friendshipId);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _decline(FriendEntity f) async {
    try {
      await _friendService.declineRequest(f.friendshipId);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _cancel(FriendEntity f) async {
    try {
      await _friendService.cancelRequest(f.friendshipId);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _remove(FriendEntity f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _friendService.removeFriend(f.friendshipId);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String message;
  const _EmptyText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(message, style: const TextStyle(color: Colors.black45)),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final Object? error;
  const _ErrorText(this.error);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Something went wrong: $error',
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}

class _UserName extends StatelessWidget {
  final String uid;
  final UserService userService;
  const _UserName({required this.uid, required this.userService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserEntity?>(
      future: userService.getUserDocument(uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final name =
              user.displayName.isEmpty ? user.username : user.displayName;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'User' : name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (user.username.isNotEmpty && user.username != user.displayName)
                Text(
                  '@${user.username}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        }
        return const Text('Loading...', style: TextStyle(color: Colors.black45));
      },
    );
  }
}

class _NeumorphicTile extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final List<Widget> actions;
  const _NeumorphicTile({
    required this.leading,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECEF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Color(0xFFB8C6CC),
            offset: Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: title),
          ...actions,
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.blue.shade100,
      child: const Icon(Icons.person, color: Colors.blue),
    );
  }
}

class _IncomingTile extends StatelessWidget {
  final FriendEntity friendship;
  final String otherUid;
  final UserService userService;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _IncomingTile({
    required this.friendship,
    required this.otherUid,
    required this.userService,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return _NeumorphicTile(
      leading: const _Avatar(),
      title: _UserName(uid: otherUid, userService: userService),
      actions: [
        IconButton(
          onPressed: onAccept,
          icon: const Icon(Icons.check_circle, color: Colors.green),
          tooltip: 'Accept',
        ),
        IconButton(
          onPressed: onDecline,
          icon: const Icon(Icons.cancel, color: Colors.redAccent),
          tooltip: 'Decline',
        ),
      ],
    );
  }
}

class _SentTile extends StatelessWidget {
  final FriendEntity friendship;
  final String otherUid;
  final UserService userService;
  final VoidCallback onCancel;
  const _SentTile({
    required this.friendship,
    required this.otherUid,
    required this.userService,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _NeumorphicTile(
      leading: const _Avatar(),
      title: _UserName(uid: otherUid, userService: userService),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendEntity friendship;
  final String otherUid;
  final UserService userService;
  final VoidCallback onRemove;
  const _FriendTile({
    required this.friendship,
    required this.otherUid,
    required this.userService,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _NeumorphicTile(
      leading: const _Avatar(),
      title: _UserName(uid: otherUid, userService: userService),
      actions: [
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.person_remove_outlined, color: Colors.black45),
          tooltip: 'Remove friend',
        ),
      ],
    );
  }
}
