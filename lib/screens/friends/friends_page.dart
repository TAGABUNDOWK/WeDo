import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../../models/friend_entity.dart';
import '../../models/user_entity.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/location/location_service.dart';
import '../../services/location/overpass_service.dart';
import '../../widgets/animated_background.dart';
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
  final _bg = const Color(0xFF190831);

  String get _uid => _auth.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddFriendPage()),
            ),
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          ),
        ],
      ),
      body: AnimatedBackground(
        showStars: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('People near you'),
            const _PeopleNearYouSection(),
            const SizedBox(height: 16),
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
          color: Colors.white,
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
      child: Text(message, style: const TextStyle(color: Colors.white54)),
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
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
              if (user.username.isNotEmpty && user.username != user.displayName)
                Text(
                  '@${user.username}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        }
        return const Text('Loading...', style: TextStyle(color: Colors.white54));
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
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
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
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      child: const Icon(Icons.person, color: Color(0xFFFE4EF0)),
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
          icon: const Icon(Icons.person_remove_outlined, color: Colors.white54),
          tooltip: 'Remove friend',
        ),
      ],
    );
  }
}

class _PeopleNearYouSection extends StatefulWidget {
  const _PeopleNearYouSection();

  @override
  State<_PeopleNearYouSection> createState() => _PeopleNearYouSectionState();
}

class _PeopleNearYouSectionState extends State<_PeopleNearYouSection> {
  final _auth = FirebaseAuth.instance;
  final _locationService = LocationService();
  final _userService = UserService();
  final _friendService = FriendService();
  final _overpassService = OverpassService();

  bool _isLoading = true;
  bool _permissionDenied = false;
  Position? _position;
  String? _areaLabel;
  List<String> _studyPlaces = const [];
  List<UserEntity> _nearbyUsers = const [];
  Map<String, String> _partners = {};

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    Position? position;
    try {
      position = await _locationService.getCurrentPosition();
    } catch (_) {
      position = null;
    }

    if (position == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }

    final uid = _uid;
    await _userService.updateLocationIfNeeded(
      uid,
      position.latitude,
      position.longitude,
    );

    final label = await _overpassService.labelArea(
      position.latitude,
      position.longitude,
    );
    final places = await _overpassService.nearbyStudyPlaces(
      position.latitude,
      position.longitude,
    );
    final users = await _userService.findNearbyUsers(
      position.latitude,
      position.longitude,
      excludeUid: uid,
    );
    final partners = await _friendService.getPartnerStatusMap(uid);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _position = position;
      _areaLabel = label;
      _studyPlaces = places;
      _nearbyUsers = users;
      _partners = partners;
    });
  }

  Future<void> _openSettings() async {
    await _locationService.openLocationSettings();
    _load();
  }

  Future<void> _onSend(UserEntity user) async {
    try {
      await _friendService.sendRequest(_uid, user.userId);
      if (!mounted) return;
      setState(() => _partners[user.userId] = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to @${user.username}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
  }

  double _distanceTo(Position position, UserEntity user) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      user.latitude!,
      user.longitude!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_permissionDenied) {
      return _NeumorphicTile(
        leading: const Icon(Icons.location_off, color: Colors.white54, size: 32),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location needed',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
            SizedBox(height: 2),
            Text(
              'Allow location access to see people near you.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _openSettings, child: const Text('Settings')),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    final position = _position!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.near_me, color: Color(0xFFFE4EF0), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _areaLabel ?? 'Your area',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        if (_studyPlaces.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionTitle('Study places near you'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _studyPlaces.map((name) {
              return Chip(
                avatar: const Icon(Icons.local_library,
                    size: 18, color: Color(0xFFFE4EF0)),
                label: Text(name, style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.black.withValues(alpha: 0.25),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        const _SectionTitle('People near you'),
        if (_nearbyUsers.isEmpty)
          const _EmptyText('No one nearby yet. Check back later!')
        else
          ..._nearbyUsers.map((user) {
            final status = _partners[user.userId];
            return _NeumorphicTile(
              leading: const _Avatar(),
              title: _NearbyUserInfo(
                user: user,
                distance: _formatDistance(_distanceTo(position, user)),
              ),
              actions: [
                if (status == 'friends')
                  const Text('Friends', style: TextStyle(color: Colors.green))
                else if (status == 'pending')
                  const Text('Sent', style: TextStyle(color: Colors.white54))
                else
                  TextButton(
                    onPressed: () => _onSend(user),
                    child: const Text('Add'),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _NearbyUserInfo extends StatelessWidget {
  final UserEntity user;
  final String distance;
  const _NearbyUserInfo({required this.user, required this.distance});

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'User' : name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        if (user.username.isNotEmpty && user.username != user.displayName)
          Text(
            '@${user.username}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 2),
        Text(
          distance,
          style: const TextStyle(fontSize: 12, color: Colors.blue),
        ),
      ],
    );
  }
}
