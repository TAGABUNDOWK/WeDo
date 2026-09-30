import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/friend_entity.dart';
import '../../models/user_entity.dart';
import '../../services/auth/user_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/location/location_service.dart';
import '../../utils/constants.dart';
import '../account/account_screen.dart';
import 'add_friend_page.dart';
import '../chat/direct/direct_chat_screen.dart';

const _font = 'PlusJakartaSans';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _auth = FirebaseAuth.instance;
  final _friendService = FriendService();
  final _userService = UserService();
  final _directService = DirectService();
  UserEntity? _currentUser;

  late final Stream<List<FriendEntity>> _incomingRequestsStream;
  late final Stream<List<FriendEntity>> _outgoingRequestsStream;
  late final Stream<List<FriendEntity>> _friendsStream;

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _incomingRequestsStream = _friendService.getIncomingRequestsStream(_uid);
    _outgoingRequestsStream = _friendService.getOutgoingRequestsStream(_uid);
    _friendsStream = _friendService.getFriendsStream(_uid);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userService.getUserDocument(_uid);
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddFriendPage()),
          ).then((_) => _loadCurrentUser()),
          tooltip: 'Search friends',
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
        ),
        title: const Text(
          'Friends',
          style: TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ).then((_) => _loadCurrentUser()),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _UserAvatar(user: _currentUser, size: 32),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const _FriendsMapSection(),
          const SizedBox(height: 14),
          const _NearbySection(),
          const SizedBox(height: 14),
          _friendSection(
            title: 'Friend Requests',
            stream: _incomingRequestsStream,
            emptyMessage: 'No pending requests',
            emptyState: _RequestEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'You’re all caught up',
              message: 'New friend requests will show up here so you can decide who to connect with.',
              actionLabel: 'Find friends',
              onAction: _openFriendSearch,
            ),
            itemBuilder: (f) => _IncomingRequestTile(
              friendship: f,
              otherUid: f.otherUserId(_uid),
              userService: _userService,
              onAccept: () => _accept(f),
              onDecline: () => _decline(f),
            ),
          ),
          const SizedBox(height: 14),
          _friendSection(
            title: 'Sent Requests',
            stream: _outgoingRequestsStream,
            emptyMessage: 'No sent requests',
            emptyState: _RequestEmptyState(
              icon: Icons.send_outlined,
              title: 'No requests on the way',
              message: 'When you invite someone, you can track your pending requests here.',
              actionLabel: 'Find people',
              onAction: _openFriendSearch,
            ),
            itemBuilder: (f) => _SentRequestTile(
              friendship: f,
              otherUid: f.otherUserId(_uid),
              userService: _userService,
              onCancel: () => _cancel(f),
            ),
          ),
          const SizedBox(height: 14),
          _friendSection(
            title: 'Friends',
            stream: _friendsStream,
            emptyMessage: 'No friends yet',
            itemBuilder: (f) => _ActiveFriendTile(
              friendship: f,
              otherUid: f.otherUserId(_uid),
              userService: _userService,
              onChat: () => _openChat(f.otherUserId(_uid)),
              onRemove: () => _remove(f),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _friendSection({
    required String title,
    required Stream<List<FriendEntity>> stream,
    required String emptyMessage,
    Widget? emptyState,
    required Widget Function(FriendEntity) itemBuilder,
  }) {
    return StreamBuilder<List<FriendEntity>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title),
              const _EmptyState('Something went wrong. Pull to refresh and try again.'),
            ],
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppColors.electricViolet,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          );
        }
        final list = snapshot.data ?? const <FriendEntity>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              list.isNotEmpty ? '$title (${list.length})' : title,
            ),
            if (list.isEmpty)
              emptyState ?? _EmptyState(emptyMessage)
            else
              ...list.map(itemBuilder),
          ],
        );
      },
    );
  }

  void _openFriendSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendPage()),
    ).then((_) => _loadCurrentUser());
  }

  Future<void> _openChat(String otherUid) async {
    if (otherUid.isEmpty) return;
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
    }
  }

  Future<void> _accept(FriendEntity f) async {
    try {
      await _friendService.acceptRequest(f.friendshipId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _decline(FriendEntity f) async {
    try {
      await _friendService.declineRequest(f.friendshipId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _cancel(FriendEntity f) async {
    try {
      await _friendService.cancelRequest(f.friendshipId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _remove(FriendEntity f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1233),
        title: const Text('Remove friend', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this friend?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _friendService.removeFriend(f.friendshipId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  IconData get _icon {
    if (title.startsWith('Friend Requests')) return Icons.person_add_alt_1_rounded;
    if (title.startsWith('Sent Requests')) return Icons.send_rounded;
    return Icons.people_alt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final countStart = title.lastIndexOf(' (');
    final hasCount = countStart >= 0 && title.endsWith(')');
    final label = hasCount ? title.substring(0, countStart) : title;
    final count = hasCount ? title.substring(countStart + 2, title.length - 1) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(_icon, color: AppColors.electricViolet, size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.electricViolet.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count, style: const TextStyle(fontFamily: _font, fontSize: 10, color: Color(0xFFD6B4FF), fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.35), size: 18),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: _font,
          color: Colors.white38,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RequestEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _RequestEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF160D27).withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.electricViolet.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.electricViolet.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: const Color(0xFFD291FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontFamily: _font, fontSize: 10, height: 1.35, color: Colors.white60)),
                const SizedBox(height: 9),
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.electricViolet.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(actionLabel, style: const TextStyle(fontFamily: _font, fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFE0B9FF))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nearby Section ──────────────────────────────────────────────────────────

class _NearbySection extends StatefulWidget {
  const _NearbySection();

  @override
  State<_NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends State<_NearbySection> {
  final _auth = FirebaseAuth.instance;
  final _locationService = LocationService();
  final _userService = UserService();
  final _friendService = FriendService();

  bool _isLoading = true;
  bool _scanning = false;
  Position? _position;
  List<UserEntity> _nearbyUsers = [];
  Map<String, String> _partners = {};

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
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
          _position = null;
        });
        return;
      }

      await _userService.updateLocationIfNeeded(
        _uid,
        position.latitude,
        position.longitude,
      );

      final users = await _userService.findNearbyUsers(
        position.latitude,
        position.longitude,
        excludeUid: _uid,
      );
      final partners = await _friendService.getPartnerStatusMap(_uid);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _position = position;
        _nearbyUsers = users;
        _partners = partners;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanSurroundings() async {
    setState(() => _scanning = true);
    try {
      await _load();
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)}km';
  }

  double _distanceTo(UserEntity user) {
    if (_position == null || user.latitude == null || user.longitude == null) {
      return 0;
    }
    return Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      user.latitude!,
      user.longitude!,
    );
  }

  Future<void> _sendRequest(UserEntity user) async {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.people, color: AppColors.electricViolet, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Nearby',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _scanning ? null : _scanSurroundings,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.electricViolet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _scanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: AppColors.electricViolet,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: AppColors.electricViolet,
                          size: 14,
                        ),
                ),
              ),
            ],
          ),
        ),
        // Card
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A0F2E).withValues(alpha: 0.4),
                    AppColors.electricViolet.withValues(alpha: 0.08),
                    const Color(0xFF120A20).withValues(alpha: 0.4),
                  ],
                ),
              ),
              child: _buildContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.electricViolet,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_position == null) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Location unavailable',
            style: TextStyle(
              fontFamily: _font,
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    if (_nearbyUsers.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No one nearby yet',
            style: TextStyle(
              fontFamily: _font,
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _nearbyUsers.take(5).map((user) {
        return _NearbyUserTile(
          user: user,
          distance: _distanceTo(user),
          formatDistance: _formatDistance,
          status: _partners[user.userId],
          onAdd: () => _sendRequest(user),
        );
      }).toList(),
    );
  }
}

// ── Nearby User Tile ─────────────────────────────────────────────────────────

class _NearbyUserTile extends StatelessWidget {
  final UserEntity user;
  final double distance;
  final String Function(double) formatDistance;
  final String? status;
  final VoidCallback onAdd;

  const _NearbyUserTile({
    required this.user,
    required this.distance,
    required this.formatDistance,
    required this.status,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isNotEmpty
        ? user.displayName
        : (user.username.isNotEmpty ? user.username : 'User');
    final isActive = user.lastActiveAt.isAfter(
      DateTime.now().subtract(const Duration(minutes: 5)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _UserAvatar(user: user, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? Colors.green : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isActive ? "Active now" : "Offline"} \u2022 ${formatDistance(distance)}',
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 11,
                        color: AppColors.softLavender,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status == 'friends')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Friends',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            )
          else if (status == 'pending')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Sent',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.electricViolet.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.electricViolet.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: AppColors.electricViolet,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Glass Card ───────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Friends Map Section ──────────────────────────────────────────────────────

class _FriendsMapSection extends StatefulWidget {
  const _FriendsMapSection();

  @override
  State<_FriendsMapSection> createState() => _FriendsMapSectionState();
}

class _FriendsMapSectionState extends State<_FriendsMapSection> {
  final _auth = FirebaseAuth.instance;
  final _locationService = LocationService();
  final _userService = UserService();
  final _friendService = FriendService();

  bool _isLoading = true;
  bool _expanded = false;
  Position? _position;
  Map<String, String> _partners = {};
  List<Marker> _markers = [];

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      Position? position;
      try {
        position = await _locationService.getCurrentPosition();
      } catch (_) {
        position = null;
      }

      if (position == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      await _userService.updateLocationIfNeeded(
        _uid,
        position.latitude,
        position.longitude,
      );

      final users = await _userService.findNearbyUsers(
        position.latitude,
        position.longitude,
        excludeUid: _uid,
      );
      final partners = await _friendService.getPartnerStatusMap(_uid);

      final markers = <Marker>[];
      for (final user in users) {
        if (user.latitude != null && user.longitude != null) {
          markers.add(
            Marker(
              point: LatLng(user.latitude!, user.longitude!),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showUserSheet(user, partners[user.userId]),
                child: _UserAvatar(user: user, size: 32),
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _position = position;
        _partners = partners;
        _markers = markers;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest(UserEntity user) async {
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _expanded ? MediaQuery.of(context).size.height * 0.7 : 190,
        width: double.infinity,
        child: _isLoading
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A0F2E),
                      AppColors.electricViolet.withValues(alpha: 0.25),
                      const Color(0xFF120A20),
                    ],
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.electricViolet,
                    strokeWidth: 2,
                  ),
                ),
              )
            : _position == null
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1A0F2E),
                          AppColors.electricViolet.withValues(alpha: 0.25),
                          const Color(0xFF120A20),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off,
                              color: Colors.white.withValues(alpha: 0.4), size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Location unavailable',
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_position!.latitude, _position!.longitude),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.wedo',
                          ),
                          MarkerLayer(markers: _markers),
                          // User location marker
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_position!.latitude, _position!.longitude),
                                width: 80,
                                height: 54,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Me',
                                        style: TextStyle(
                                          fontFamily: _font,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xE6100825),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFFFF70E8), size: 13),
                              const SizedBox(width: 5),
                              Text(
                                '${_markers.length} people nearby',
                                style: const TextStyle(fontFamily: _font, fontSize: 10, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Map controls
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _expanded = !_expanded),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _expanded ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: AppColors.electricViolet,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _load,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.refresh,
                                  color: AppColors.electricViolet,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showUserSheet(UserEntity user, String? status) {
    final name = user.displayName.isNotEmpty
        ? user.displayName
        : (user.username.isNotEmpty ? user.username : 'User');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1233),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UserAvatar(user: user, size: 56),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (user.username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '@${user.username}',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (status == 'friends')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Friends',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              )
            else if (status == 'pending')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Request Sent',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _sendRequest(user);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.electricViolet, Color(0xFF5A3AD4)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Add Friend',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── User Avatar ──────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final UserEntity? user;
  final double size;

  const _UserAvatar({this.user, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final hasAvatarAsset =
        user?.avatarAsset != null && user!.avatarAsset!.isNotEmpty;
    final hasPhoto =
        user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

    Widget avatar;
    if (hasAvatarAsset) {
      avatar = Image.asset(
        user!.avatarAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultIcon(),
      );
    } else if (hasPhoto) {
      avatar = Image.network(
        user!.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultIcon(),
      );
    } else {
      avatar = _buildDefaultIcon();
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.electricViolet.withValues(alpha: 0.25),
        child: ClipOval(
          child: SizedBox(width: size, height: size, child: avatar),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      color: AppColors.electricViolet.withValues(alpha: 0.25),
      child: Icon(Icons.person, color: AppColors.softLavender, size: size * 0.5),
    );
  }
}

// ── Incoming Request Tile ────────────────────────────────────────────────────

class _IncomingRequestTile extends StatelessWidget {
  final FriendEntity friendship;
  final String otherUid;
  final UserService userService;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingRequestTile({
    required this.friendship,
    required this.otherUid,
    required this.userService,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _GlassCard(
        child: Row(
          children: [
            _FutureUserAvatar(uid: otherUid, userService: userService, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: _FutureUserName(
                uid: otherUid,
                userService: userService,
              ),
            ),
            GestureDetector(
              onTap: onAccept,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDecline,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.close,
                  color: Color(0xFFFF6B6B),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sent Request Tile ────────────────────────────────────────────────────────

class _SentRequestTile extends StatelessWidget {
  final FriendEntity friendship;
  final String otherUid;
  final UserService userService;
  final VoidCallback onCancel;

  const _SentRequestTile({
    required this.friendship,
    required this.otherUid,
    required this.userService,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _GlassCard(
        child: Row(
          children: [
            _FutureUserAvatar(uid: otherUid, userService: userService, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: _FutureUserName(
                uid: otherUid,
                userService: userService,
              ),
            ),
            GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF6B6B),
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

// ── Active Friend Tile ───────────────────────────────────────────────────────

class _ActiveFriendTile extends StatefulWidget {
  final FriendEntity friendship;
  final String otherUid;
  final UserService userService;
  final VoidCallback onChat;
  final VoidCallback onRemove;

  const _ActiveFriendTile({
    required this.friendship,
    required this.otherUid,
    required this.userService,
    required this.onChat,
    required this.onRemove,
  });

  @override
  State<_ActiveFriendTile> createState() => _ActiveFriendTileState();
}

class _ActiveFriendTileState extends State<_ActiveFriendTile> {
  late Future<UserEntity?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.userService.getUserDocument(widget.otherUid);
  }

  @override
  void didUpdateWidget(covariant _ActiveFriendTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUid != widget.otherUid) {
      _future = widget.userService.getUserDocument(widget.otherUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _GlassCard(
        child: FutureBuilder<UserEntity?>(
          future: _future,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final name = user == null
                ? 'Loading...'
                : (user.displayName.isNotEmpty
                    ? user.displayName
                    : (user.username.isNotEmpty ? user.username : 'User'));

            return Row(
              children: [
                _UserAvatar(user: user, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user == null
                                  ? Colors.white38
                                  : user.lastActiveAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))
                                      ? Colors.greenAccent
                                      : Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            user == null
                                ? 'Loading status'
                                : user.lastActiveAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))
                                    ? 'Active nearby'
                                    : 'Offline',
                            style: const TextStyle(fontFamily: _font, fontSize: 10, color: AppColors.softLavender),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onChat,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.electricViolet.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.electricViolet,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_remove_outlined,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Future User Name ─────────────────────────────────────────────────────────

class _FutureUserName extends StatefulWidget {
  final String uid;
  final UserService userService;
  const _FutureUserName({required this.uid, required this.userService});

  @override
  State<_FutureUserName> createState() => _FutureUserNameState();
}

class _FutureUserNameState extends State<_FutureUserName> {
  late Future<UserEntity?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.userService.getUserDocument(widget.uid);
  }

  @override
  void didUpdateWidget(covariant _FutureUserName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _future = widget.userService.getUserDocument(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserEntity?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final name =
              user.displayName.isEmpty ? user.username : user.displayName;
          return Text(
            name.isEmpty ? 'User' : name,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          );
        }
        return const Text(
          'Loading...',
          style: TextStyle(
            fontFamily: _font,
            fontSize: 13,
            color: Colors.white38,
          ),
        );
      },
    );
  }
}

// ── Future User Avatar ───────────────────────────────────────────────────────

class _FutureUserAvatar extends StatefulWidget {
  final String uid;
  final UserService userService;
  final double size;

  const _FutureUserAvatar({
    required this.uid,
    required this.userService,
    this.size = 40,
  });

  @override
  State<_FutureUserAvatar> createState() => _FutureUserAvatarState();
}

class _FutureUserAvatarState extends State<_FutureUserAvatar> {
  late Future<UserEntity?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.userService.getUserDocument(widget.uid);
  }

  @override
  void didUpdateWidget(covariant _FutureUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _future = widget.userService.getUserDocument(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserEntity?>(
      future: _future,
      builder: (context, snapshot) {
        final user = snapshot.hasData ? snapshot.data : null;
        return _UserAvatar(user: user, size: widget.size);
      },
    );
  }
}
