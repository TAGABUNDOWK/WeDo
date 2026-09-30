import 'dart:math' as math;
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
import '../../utils/nav_bar_controller.dart';
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
  final _locationService = LocationService();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();

  late final Stream<List<FriendEntity>> _incomingRequestsStream;
  late final Stream<List<FriendEntity>> _outgoingRequestsStream;
  late final Stream<List<FriendEntity>> _friendsStream;

  // Full-screen map
  bool _mapLoading = true;
  Position? _position;
  Map<String, String> _partners = {};
  List<Marker> _markers = [];

  // Floating search
  bool _searching = false;
  bool _searchActive = false;
  bool _hasSearched = false;
  List<UserEntity> _searchResults = [];

  // Swipeable glass panel
  bool _panelOpen = false;
  int _activeTab = 0;
  double _edgeDrag = 0;
  double _panelDrag = 0;

  static const _pink = Color(0xFFFE4EF0);
  static const _tabLabels = [
    'Nearby',
    'Incoming Request',
    'Sent Request',
    'Friends',
  ];

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _incomingRequestsStream = _friendService.getIncomingRequestsStream(_uid);
    _outgoingRequestsStream = _friendService.getOutgoingRequestsStream(_uid);
    _friendsStream = _friendService.getFriendsStream(_uid);
    _loadMap();
  }

  @override
  void dispose() {
    navBarHidden.value = false;
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final topInset = padding.top;
    final panelHeight = (size.height * 0.65).clamp(360.0, 720.0);
    // Bottom edge of the floating search bar: top inset + 10 pad + 52 height.
    final chromeBottom = topInset + 62;
    final showResults = _hasSearched || (_searching && _searchActive);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Full-screen map (base layer) ──────────────────────────────
          Positioned.fill(child: _buildMapLayer()),

          // ── Bottom edge swipe zone (reveals the glass panel) ──────────
          if (!_panelOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: math.max(24.0, padding.bottom + 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => _edgeDrag = 0,
                onVerticalDragUpdate: (d) => _edgeDrag += d.delta.dy,
                onVerticalDragEnd: (_) {
                  final shouldOpen = _edgeDrag < -50;
                  _edgeDrag = 0;
                  if (shouldOpen) _openPanel();
                },
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

          // ── Floating glass search bar ─────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _buildSearchBar(),
              ),
            ),
          ),

          // ── Search results overlay ────────────────────────────────────
          if (showResults)
            Positioned(
              top: chromeBottom + 10,
              left: 16,
              right: 16,
              child: _buildSearchResults(size),
            ),

          // ── Floating map action buttons ───────────────────────────────
          if (!showResults)
            Positioned(
              top: chromeBottom + 10,
              right: 16,
              child: Column(
                children: [
                  _buildMapButton('assets/icons/refresh.png', _loadMap),
                  const SizedBox(height: 8),
                  _buildMapButton('assets/icons/zoom-out.png', _zoomOut),
                ],
              ),
            ),

          // ── Swipeable glass panel ─────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            left: 8,
            right: 8,
            bottom: _panelOpen ? 0 : -(panelHeight + padding.bottom + 40),
            height: panelHeight,
            child: _buildPanel(),
          ),
        ],
      ),
    );
  }

  // ── Map layer ──────────────────────────────────────────────────────────────

  Widget _buildMapLayer() {
    if (_position == null) {
      return Container(
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
          child: _mapLoading
              ? const CircularProgressIndicator(
                  color: AppColors.electricViolet,
                  strokeWidth: 2,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 32,
                    ),
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
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_position!.latitude, _position!.longitude),
            initialZoom: 15,
            onTap: (_, __) => _dismissSearch(),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
        if (_mapLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.electricViolet,
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }

  // ── Floating search bar & results ─────────────────────────────────────────

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: _pink, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _onSearch(),
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search Friends...',
                    hintStyle: TextStyle(
                      fontFamily: _font,
                      fontSize: 14,
                      color: _pink,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: _clearSearch,
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 18),
                  );
                },
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _onSearch,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: _searching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _pink,
                          ),
                        )
                      : Image.asset(
                          'assets/icons/send-request.png',
                          width: 24,
                          height: 24,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(Size size) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: size.height * 0.42),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: _searching
                ? const SizedBox(
                    height: 64,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.electricViolet,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _searchResults.isEmpty
                    ? SizedBox(
                        height: 64,
                        child: Center(
                          child: Text(
                            'No user found with that username',
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) =>
                            _buildSearchResult(_searchResults[index]),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResult(UserEntity user) {
    final status = _partners[user.userId];
    final name = user.displayName.isEmpty ? user.username : user.displayName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _UserAvatar(user: user, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'User' : name,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.username.isNotEmpty &&
                    user.username != user.displayName) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 11,
                      color: AppColors.softLavender,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (status == 'friends')
            _statusChip('Friends', Colors.green)
          else if (status == 'pending')
            _statusChip('Sent', Colors.orange)
          else
            GestureDetector(
              onTap: () => _sendRequest(user),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.electricViolet, Color(0xFF5A3AD4)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: _font,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMapButton(String asset, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Image.asset(asset, width: 20, height: 20),
        ),
      ),
    );
  }

  Widget _friendSection({
    required Stream<List<FriendEntity>> stream,
    required String emptyMessage,
    required Widget Function(FriendEntity) itemBuilder,
  }) {
    return StreamBuilder<List<FriendEntity>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyState(
              'Something went wrong. Pull to refresh and try again.');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: AppColors.electricViolet,
                strokeWidth: 2,
              ),
            ),
          );
        }
        final list = snapshot.data ?? const <FriendEntity>[];
        if (list.isEmpty) return _EmptyState(emptyMessage);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: list.map(itemBuilder).toList(),
        );
      },
    );
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

  // ── Map logic ──────────────────────────────────────────────────────────────

  Future<void> _loadMap() async {
    setState(() => _mapLoading = true);
    try {
      Position? position;
      try {
        position = await _locationService.getCurrentPosition();
      } catch (_) {
        position = null;
      }

      if (position == null) {
        if (!mounted) return;
        setState(() => _mapLoading = false);
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
      final hadMap = _position != null;
      setState(() {
        _mapLoading = false;
        _position = position;
        _partners = partners;
        _markers = markers;
      });
      if (hadMap) {
        // Re-center on the freshly obtained position (the map stays mounted).
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _mapLoading = false);
    }
  }

  void _zoomOut() {
    if (_position == null) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, math.max(3, camera.zoom - 2));
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

  // ── Floating search logic (relocated from AddFriendPage) ──────────────────

  Future<void> _onSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    _searchActive = true;
    setState(() => _searching = true);
    try {
      final results = await _friendService.searchUsers(query, excludeUid: _uid);
      final partners = await _friendService.getPartnerStatusMap(_uid);
      if (!mounted || !_searchActive) return;
      setState(() {
        _partners = partners;
        _searchResults = results;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchActive = false;
    setState(() {
      _hasSearched = false;
      _searchResults = [];
    });
  }

  void _dismissSearch() {
    FocusScope.of(context).unfocus();
    if (_hasSearched || _searching || _searchActive) {
      _searchActive = false;
      setState(() {
        _hasSearched = false;
        _searchResults = [];
      });
    }
  }

  // ── Swipeable glass panel ─────────────────────────────────────────────────

  void _openPanel() {
    if (_panelOpen) return;
    _dismissSearch();
    setState(() => _panelOpen = true);
    navBarHidden.value = true;
  }

  void _closePanel() {
    if (!_panelOpen) return;
    setState(() => _panelOpen = false);
    navBarHidden.value = false;
  }

  Widget _buildPanel() {
    final padding = MediaQuery.paddingOf(context);

    return IgnorePointer(
      ignoring: !_panelOpen,
      child: AnimatedOpacity(
        opacity: _panelOpen ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A0F2E).withValues(alpha: 0.55),
                    const Color(0xFF120A20).withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildPanelHeader(),
                  Expanded(
                    child: IndexedStack(
                      index: _activeTab,
                      children: [
                        _buildTabBody(0),
                        _buildTabBody(1),
                        _buildTabBody(2),
                        _buildTabBody(3),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: padding.bottom > 0 ? padding.bottom : 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _panelDrag = 0,
      onVerticalDragUpdate: (d) => _panelDrag += d.delta.dy,
      onVerticalDragEnd: (_) {
        final shouldClose = _panelDrag > 50;
        _panelDrag = 0;
        if (shouldClose) _closePanel();
      },
      child: Container(
        color: Colors.transparent,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            // Grabber — also tappable to close.
            GestureDetector(
              onTap: _closePanel,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTab(0, null),
                _buildTab(1, _incomingRequestsStream),
                _buildTab(2, _outgoingRequestsStream),
                _buildTab(3, _friendsStream),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, Stream<List<FriendEntity>>? countStream) {
    final active = _activeTab == index;
    final style = TextStyle(
      fontFamily: _font,
      fontSize: 11,
      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
      color: active ? Colors.white : Colors.white60,
    );

    final Widget label;
    if (countStream == null) {
      label = Text(_tabLabels[index], style: style, maxLines: 1);
    } else {
      label = StreamBuilder<List<FriendEntity>>(
        stream: countStream,
        builder: (context, snapshot) {
          final n = snapshot.data?.length ?? 0;
          return Text(
            n > 0 ? '${_tabLabels[index]} ($n)' : _tabLabels[index],
            style: style,
            maxLines: 1,
          );
        },
      );
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!active) setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? _pink.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? _pink.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: label),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 16 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: _pink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(int index) {
    const listPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);

    switch (index) {
      case 0:
        return ListView(
          padding: listPadding,
          children: const [_NearbySection(showHeader: false)],
        );
      case 1:
        return ListView(
          padding: listPadding,
          children: [
            _friendSection(
              stream: _incomingRequestsStream,
              emptyMessage: 'No pending requests',
              itemBuilder: (f) => _IncomingRequestTile(
                friendship: f,
                otherUid: f.otherUserId(_uid),
                userService: _userService,
                onAccept: () => _accept(f),
                onDecline: () => _decline(f),
              ),
            ),
          ],
        );
      case 2:
        return ListView(
          padding: listPadding,
          children: [
            _friendSection(
              stream: _outgoingRequestsStream,
              emptyMessage: 'No sent requests',
              itemBuilder: (f) => _SentRequestTile(
                friendship: f,
                otherUid: f.otherUserId(_uid),
                userService: _userService,
                onCancel: () => _cancel(f),
              ),
            ),
          ],
        );
      default:
        return ListView(
          padding: listPadding,
          children: [
            _friendSection(
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
          ],
        );
    }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
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

// ── Nearby Section ──────────────────────────────────────────────────────────

class _NearbySection extends StatefulWidget {
  /// When `false` the section title is omitted (the enclosing panel tab
  /// provides it) and only a compact rescan button is shown above the card.
  final bool showHeader;

  const _NearbySection({this.showHeader = true});

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
    // Card
    final card = ClipRRect(
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
    );

    if (!widget.showHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildScanButton(),
          ),
          card,
        ],
      );
    }

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
              _buildScanButton(),
            ],
          ),
        ),
        card,
      ],
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          _UserAvatar(user: user, size: 40),
          const SizedBox(width: 12),
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
                _UserAvatar(user: user, size: 40),
                const SizedBox(width: 12),
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
                      if (user != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.latitude != null ? 'Active nearby' : 'Online',
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 11,
                            color: AppColors.softLavender,
                          ),
                        ),
                      ],
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
