import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/friend_entity.dart';
import '../../models/user_entity.dart';
import '../../services/auth/user_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/friends/friend_service.dart';
import '../chat/direct/direct_chat_screen.dart';

const _font = 'PlusJakartaSans';
const _bg = Color(0xFF1A0A2E);
const _accent = Color(0xFFFE4EF0);
const _violet = Color(0xFF800DD8);

/// Lists the current user's accepted friends.
///
/// Opened from the Friends counter in [AccountScreen]. Reads the same
/// `friends` query the counter uses, so the list can never disagree with the
/// number shown on the profile header.
class ProfileFriendsScreen extends StatefulWidget {
  const ProfileFriendsScreen({super.key});

  @override
  State<ProfileFriendsScreen> createState() => _ProfileFriendsScreenState();
}

class _ProfileFriendsScreenState extends State<ProfileFriendsScreen> {
  final _auth = FirebaseAuth.instance;
  final _friendService = FriendService();
  final _userService = UserService();
  final _directService = DirectService();

  bool _loading = true;
  bool _openingChat = false;
  String? _error;
  List<FriendEntity> _friends = const [];
  final Map<String, UserEntity> _users = {};
  StreamSubscription<List<FriendEntity>>? _friendsSub;

  /// True once a direct server read has completed, so an empty list can be
  /// trusted as real rather than as a cold cache.
  bool _serverChecked = false;

  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _subscribe();
    _fetchFromServer();
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    super.dispose();
  }

  /// Reads the query directly from the server.
  ///
  /// `getFriendsStream` is backed by Firestore `snapshots()`, which serves a
  /// cache-first result. On a cold start that cache is empty, so relying on it
  /// alone left the list at 0 while the profile counter — subscribed far longer —
  /// showed the real count. This bypasses the cache for the initial load;
  /// [_subscribe] then keeps the list live for later changes.
  Future<void> _fetchFromServer() async {
    if (_uid.isEmpty) {
      debugPrint('[ProfileFriends] no uid — signed out');
      return;
    }

    try {
      var friends = await _friendService.fetchFriends(_uid);
      debugPrint('[ProfileFriends] uid=$_uid server returned '
          '${friends.length} accepted friend docs');

      // Self-heal: an empty result almost always means the documents store an
      // accepted status under a different spelling. Normalise them to
      // 'friends' and read again rather than showing a permanent 0.
      if (friends.isEmpty) {
        final repaired = await _friendService.normalizeAcceptedStatuses(_uid);
        debugPrint('[ProfileFriends] repaired $repaired stale status values');
        if (repaired > 0) {
          friends = await _friendService.fetchFriends(_uid);
          debugPrint('[ProfileFriends] after repair: ${friends.length}');
        }
      }

      if (!mounted) return;
      await _applyFriends(friends);
      if (mounted) setState(() => _serverChecked = true);
    } catch (e) {
      debugPrint('[ProfileFriends] server read failed: $e');
      if (!mounted) return;
      // The live subscription surfaces its own error state; only fall back to
      // this one if nothing has loaded yet.
      if (_friends.isEmpty) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _applyFriends(List<FriendEntity> friends) async {
    final resolved = await _resolveUsers(
      friends.map((f) => f.otherUserId(_uid)).toSet(),
    );
    if (!mounted) return;
    setState(() {
      _friends = _sorted(friends, resolved);
      _users
        ..clear()
        ..addAll(resolved);
      _loading = false;
      _error = null;
    });
  }

  /// Stays subscribed so the list reflects later friend changes.
  void _subscribe() {
    if (!mounted) return;

    if (_uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _friendsSub?.cancel();
    _friendsSub = _friendService.getFriendsStream(_uid).listen(
      (friends) {
        debugPrint('[ProfileFriends] stream emitted ${friends.length}');
        // An empty cache-first emission must not overwrite a real result the
        // direct server read already delivered.
        if (friends.isEmpty && _serverChecked) return;
        _applyFriends(friends);
      },
      onError: (Object e) {
        debugPrint('[ProfileFriends] stream error: $e');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      },
    );
  }

  /// Pull-to-refresh. Re-reads from the server so a stale cache cannot be
  /// re-applied, then resubscribes.
  Future<void> _load() async {
    await _fetchFromServer();
    _subscribe();
  }

  /// Fetches every referenced user doc in one parallel fan-out and drops the
  /// ones that no longer resolve (deleted accounts).
  ///
  /// Each lookup is isolated: a single unparseable document used to fail the
  /// whole `Future.wait` and blank the list. `toSet` collapses the empty ids
  /// that `otherUserId` returns for rows the current user is not part of.
  Future<Map<String, UserEntity>> _resolveUsers(Iterable<String> uids) async {
    final ids = uids.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};

    final users = await Future.wait(
      ids.map((id) async {
        try {
          return _userService.getUserDocument(id);
        } catch (_) {
          return null;
        }
      }),
    );

    final map = <String, UserEntity>{};
    for (final user in users) {
      if (user != null) map[user.userId] = user;
    }
    return map;
  }

  List<FriendEntity> _sorted(
    List<FriendEntity> friends,
    Map<String, UserEntity> users,
  ) {
    final copy = List<FriendEntity>.from(friends);
    copy.sort((a, b) {
      final nameA = _nameFor(a.otherUserId(_uid), users).toLowerCase();
      final nameB = _nameFor(b.otherUserId(_uid), users).toLowerCase();
      return nameA.compareTo(nameB);
    });
    return copy;
  }

  String _nameFor(String uid, Map<String, UserEntity> users) {
    final user = users[uid];
    if (user == null) return 'User';
    if (user.displayName.isNotEmpty) return user.displayName;
    if (user.username.isNotEmpty) return user.username;
    return 'User';
  }

  Future<void> _openChat(String otherUid) async {
    if (otherUid.isEmpty || _openingChat) return;
    setState(() => _openingChat = true);
    try {
      final chatId = await _directService.getOrCreateChat(
        currentUid: _uid,
        otherUid: otherUid,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatScreen(chatId: chatId, otherUid: otherUid),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        ),
        title: Text(
          'Friends${_loading ? '' : ' (${_friends.length})'}',
          style: const TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accent),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _friends.isEmpty
                  // No accepted friends, but the profile header may still be
                  // counting cached data. Say so instead of claiming zero.
                  ? _EmptyState(
                      message: _serverChecked
                          ? 'No friends yet'
                          : 'No friends yet (checking...)',
                    )
                  : RefreshIndicator(
                      color: _accent,
                      backgroundColor: _bg,
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: _friends.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final friendship = _friends[index];
                          final otherUid = friendship.otherUserId(_uid);
                          return _FriendRow(
                            user: _users[otherUid],
                            fallbackName: _nameFor(otherUid, _users),
                            onTap: () => _openChat(otherUid),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final UserEntity? user;
  final String fallbackName;
  final VoidCallback onTap;

  const _FriendRow({
    required this.user,
    required this.fallbackName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = user == null
        ? fallbackName
        : (user!.displayName.isNotEmpty
            ? user!.displayName
            : (user!.username.isNotEmpty ? user!.username : 'User'));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _ProfileAvatar(user: user, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user != null && user!.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${user!.username}',
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 12,
                        color: _accent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserEntity? user;
  final double size;

  const _ProfileAvatar({this.user, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final hasAvatarAsset =
        user?.avatarAsset != null && user!.avatarAsset!.isNotEmpty;
    final hasPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

    Widget image;
    if (hasAvatarAsset) {
      image = Image.asset(
        user!.avatarAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (hasPhoto) {
      image = Image.network(
        user!.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: _violet.withValues(alpha: 0.25),
        child: ClipOval(
          child: SizedBox(width: size, height: size, child: image),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: _violet.withValues(alpha: 0.25),
      child: Icon(Icons.person, color: Colors.white, size: size * 0.5),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 12,
                color: Colors.white38,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: _font,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
