import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/group/group_service.dart';
import '../../services/profile/profile_service.dart';
import '../../services/session/session_service.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../models/friend_entity.dart';
import '../../models/group_chat.dart';
import '../../models/user_entity.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/arc_avatar_picker.dart';
import '../../widgets/terms_agreement_dialog.dart';
import 'edit_profile_page.dart';
import 'account_info_screen.dart';
import 'profile_friends_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin {
  static final List<String> _avatars =
      List.generate(9, (i) => 'assets/icons/Avatar-${i + 1}.png');
  // 10 frames — Frame-6..10 are duplicates of 1..5, replace after design is done
  static final List<String> _frames =
      List.generate(10, (i) => 'assets/icons/Frame-${i + 1}.png');

  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  final _friendService = FriendService();
  final _groupService = GroupService();
  final _profileService = ProfileService();
  final _sessionService = SessionService();
  final _triRaceService = TriRaceService();
  final _imagePicker = ImagePicker();
  UserEntity? _user;
  bool _loading = true;
  StreamSubscription<UserEntity?>? _userSub;

  /// Counters for the friends/groups queries.
  ///
  /// Memoized so both StreamBuilders below keep the same stream instance across
  /// rebuilds. Building these inline in build() would hand StreamBuilder a new
  /// object on every setState (including every WeDo-slider drag frame),
  /// forcing an unsubscribe/resubscribe of both queries and blanking the
  /// counts to 0.
  ///
  /// Deliberately nullable rather than `late final`: a `late` field is not
  /// initialized by the constructor, so a hot reload that introduces it would
  /// throw LateInitializationError on the next build (initState does not re-run
  /// on reload). Created on first use instead.
  String? _streamUid;
  Stream<List<FriendEntity>>? _cachedFriendsStream;
  Stream<List<GroupChat>>? _cachedGroupsStream;

  /// (Re)creates the counter queries if they have not been built yet, or if the
  /// signed-in uid changed since they were built.
  void _ensureStreams() {
    final uid = _uid;
    if (_streamUid == uid && _cachedFriendsStream != null) return;
    _streamUid = uid;
    _cachedFriendsStream = _friendService.getFriendsStream(uid);
    _cachedGroupsStream = _groupService.getUserGroupsStream(uid);
  }

  int _totalMatches = 0;
  int _pickFightWins = 0;
  int _triRaceWins = 0;
  double _wedoThumbRatio = 0.5;
  bool _wedoDragging = false;
  late final AnimationController _arcRevealCtrl;
  late final AnimationController _frameRevealCtrl;
  bool _isAutoHiding = false;
  bool _isFrameAutoHiding = false;
  bool _showDismissHint = false;
  Timer? _dismissHintTimer;

  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _arcRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      value: 0,
    );
    _frameRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      value: 0,
    );
    _listenToUser();
    _loadStats();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _dismissHintTimer?.cancel();
    _arcRevealCtrl.dispose();
    _frameRevealCtrl.dispose();
    super.dispose();
  }

  /// Hides the backdrop-dismiss hint immediately, so it never lingers after
  /// the arcs have already closed by some other route.
  void _dismissHint() {
    _dismissHintTimer?.cancel();
    if (!_showDismissHint || !mounted) return;
    setState(() => _showDismissHint = false);
  }

  /// Shows the backdrop-dismiss hint for a moment. Idempotent, so it is safe to
  /// call on every slider drag frame.
  void _maybeShowDismissHint() {
    if (_showDismissHint) return;
    setState(() => _showDismissHint = true);
    _dismissHintTimer?.cancel();
    _dismissHintTimer =
        Timer(const Duration(milliseconds: 1800), _dismissHint);
  }

  void _closeArcImmediately() {
    if (_arcRevealCtrl.isDismissed) return;
    _dismissHint();
    _isAutoHiding = true;
    setState(() => _wedoThumbRatio = 0.5);
    _frameRevealCtrl.reverse();
    _arcRevealCtrl
        .animateTo(0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (mounted) setState(() => _isAutoHiding = false);
    });
  }

  void _closeFrameImmediately() {
    if (_frameRevealCtrl.isDismissed) return;
    _dismissHint();
    _isFrameAutoHiding = true;
    setState(() => _wedoThumbRatio = 0.5);
    _arcRevealCtrl.reverse();
    _frameRevealCtrl
        .animateTo(0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (mounted) setState(() => _isFrameAutoHiding = false);
    });
  }

  void _showBothArcs() {
    _arcRevealCtrl.forward();
    _frameRevealCtrl.forward();
    _maybeShowDismissHint();
  }

  void _hideBothArcs() {
    _arcRevealCtrl.reverse();
    _frameRevealCtrl.reverse();
    _dismissHint();
    setState(() => _wedoThumbRatio = 0.5);
  }

  void _syncArcReveal() {
    if (_wedoThumbRatio < 0.45) {
      _arcRevealCtrl.forward();
      _frameRevealCtrl.reverse();
      _maybeShowDismissHint();
    } else if (_wedoThumbRatio > 0.55) {
      _frameRevealCtrl.forward();
      _arcRevealCtrl.reverse();
      _maybeShowDismissHint();
    } else {
      _arcRevealCtrl.reverse();
      _frameRevealCtrl.reverse();
    }
  }

  Future<void> _selectPresetAvatar(String asset) async {
    if (_user == null || asset == _user!.avatarAsset) return;
    setState(() => _user = _user!.copyWith(avatarAsset: asset));
    try {
      await _profileService.setPresetAvatar(uid: _uid, asset: asset);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
      }
      await _loadUser();
    }
  }

  Future<void> _selectFrame(String asset) async {
    if (_user == null || asset == _user!.frameAsset) return;
    setState(() => _user = _user!.copyWith(frameAsset: asset));
    try {
      await _profileService.setFrameAsset(uid: _uid, asset: asset);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update frame: $e')),
        );
      }
      await _loadUser();
    }
  }

  void _listenToUser() {
    _userSub?.cancel();
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _user = null;
          _loading = false;
        });
      }
      return;
    }
    _userSub = _userService.userDocumentStream(uid).listen(
      (user) {
        if (mounted) {
          setState(() {
            _user = user;
            _loading = false;
          });
        }
      },
      onError: (Object e) {
        debugPrint('user stream error: $e');
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final user = await _userService.getUserDocument(uid);
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('_loadUser error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final totalMatches = await _sessionService.getUserTotalMatches(uid);
      final pickFightWins = await _sessionService.getUserPickFightWins(uid);
      final triRaceTotal = await _triRaceService.getUserTotalTriRaces(uid);
      final triRaceWins = await _triRaceService.getUserTriRaceWins(uid);

      if (mounted) {
        setState(() {
          _totalMatches = totalMatches + triRaceTotal;
          _pickFightWins = pickFightWins;
          _triRaceWins = triRaceWins;
        });
      }
    } catch (e) {
      debugPrint('_loadStats error: $e');
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadUser(),
      _loadStats(),
    ]);
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF2A1450),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Gallery', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text('Camera', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white54),
              title: const Text('Cancel', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins')),
              onTap: () => Navigator.pop(c),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUploadPhoto(source);
  }

  Future<void> _pickAndUploadPhoto([ImageSource source = ImageSource.gallery]) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      await _profileService.uploadAvatar(uid: _uid, file: picked);
      await _loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated — will be checked for policy violation')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Closes whichever arcs are currently open.
  ///
  /// Previously required *both* arcs to be visible, which left the one-arc
  /// states reachable by dragging the WeDo slider to either side with no
  /// working backdrop exit at all.
  void _closeIfAnyVisible() {
    if (_arcRevealCtrl.isDismissed && _frameRevealCtrl.isDismissed) return;
    _hideBothArcs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Account',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeIfAnyVisible,
        child: AnimatedBackground(
          showStars: false,
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 100,
              left: -150,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(-1.0, 1.0, 1.0, 1.0)
                  ..rotateZ(-0.55),
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    'assets/images/Ears-overlay1.png',
                    width: 900,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFE4EF0)),
                  )
                : _user == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No user data found',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _listenToUser();
                            _loadUser();
                          },
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: Color(0xFFFE4EF0),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    top: false,
                    child: RefreshIndicator(
                      color: const Color(0xFFFE4EF0),
                      backgroundColor: const Color(0xFF1A0A2E),
                      onRefresh: _onRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 16),
                            _buildWeDoSlider(),
                            const SizedBox(height: 24),
                            _buildGameMatchStatsCard(context),
                            const SizedBox(height: 24),
                            _buildAccountMenu(context),
                          ],
                        ),
                      ),
                    ),
                  ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_arcRevealCtrl, _frameRevealCtrl]),
                builder: (context, _) {
                  final blurValue = math.max(
                      _arcRevealCtrl.value, _frameRevealCtrl.value);
                  if (blurValue <= 0.01) return const SizedBox.shrink();
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5 * blurValue,
                      sigmaY: 5 * blurValue,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.black.withValues(alpha: 0.3 * blurValue),
                        ),
                        if (_showDismissHint)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Tap anywhere to close',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 190,
              child: RepaintBoundary(
                child: ArcAvatarPicker(
                  avatars: _avatars,
                  reveal: _arcRevealCtrl,
                  onAvatarSelected: _selectPresetAvatar,
                  onCloseRequested: _closeArcImmediately,
                  side: ArcSide.left,
                  initialIndex: 4,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 215,
              child: RepaintBoundary(
                child: ArcAvatarPicker(
                  avatars: _frames,
                  reveal: _frameRevealCtrl,
                  onAvatarSelected: _selectFrame,
                  onCloseRequested: _closeFrameImmediately,
                  side: ArcSide.right,
                  initialIndex: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildProfileHeader() {
    final hasPhoto = _user!.photoUrl != null && _user!.photoUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Transform.translate(
              offset: const Offset(0, -6),
              child: SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildAvatarImage(hasPhoto: hasPhoto),
                    ),
                  ),
                  if (_user!.frameAsset != null &&
                      _user!.frameAsset!.isNotEmpty)
                    Positioned.fill(
                      child: Transform.scale(
                        scale: _user!.frameAsset!.contains('Frame-4') ? 1.2 : 1.0,
                        child: Image.asset(
                          _user!.frameAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _user!.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfilePage(),
                        ),
                      );
                      if (updated == true) _loadUser();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFFFE4EF0),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (_user!.username.isNotEmpty) ...[
                const SizedBox(height: 0),
                Text(
                  '@${_user!.username}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFE4EF0),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildStatsPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage({required bool hasPhoto}) {
    final presetAsset = _user!.avatarAsset;
    if (presetAsset != null && presetAsset.isNotEmpty) {
      return Image.asset(
        presetAsset,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    }
    if (hasPhoto) {
      return Image.network(
        _user!.photoUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 36),
      ),
    );
  }

  Widget _buildStatsPanel() {
    _ensureStreams();
    return StreamBuilder<List>(
      stream: _cachedFriendsStream,
      builder: (context, friendsSnap) {
        // An errored query must not masquerade as "0 friends" — that silently
        // hid a crashing friends query behind a plausible-looking count.
        final friendsCount =
            friendsSnap.hasError ? 0 : friendsSnap.data?.length ?? 0;
        return StreamBuilder<List>(
          stream: _cachedGroupsStream,
          builder: (context, groupsSnap) {
            final groupsCount = groupsSnap.data?.length ?? 0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        count: friendsCount,
                        label: 'Friends',
                        onTap: () => _openFriends(),
                      ),
                      // Hairline between the two counters. Fixed height keeps
                      // it clear of the panel's top and bottom borders, and a
                      // plain Container avoids VerticalDivider's themed
                      // indent and colour.
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      _buildStatItem(
                        count: groupsCount,
                        label: 'Groups',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileFriendsScreen()),
    );
  }

  Widget _buildStatItem({
    required int count,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Poppins',
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFE4EF0),
                fontFamily: 'Poppins',
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _rs(BuildContext context) {
    final scale = MediaQuery.of(context).size.width / 390;
    return scale.clamp(0.85, 1.4);
  }

  Widget _buildWeDoSlider() {
    const double trackHeight = 64;
    const double thumbSize = 52;
    const double horizontalPadding = 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxSlide = trackWidth - thumbSize - horizontalPadding * 2;

        final thumbLeft = _wedoThumbRatio * maxSlide + horizontalPadding;
        final bool isLeft = _wedoThumbRatio < 0.4;
        final bool isRight = _wedoThumbRatio > 0.6;
        final bool isSelected = isLeft || isRight;

        return GestureDetector(
          onHorizontalDragStart: (_) {
            setState(() => _wedoDragging = true);
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _wedoDragging = true;
              final ratio = details.localPosition.dx / trackWidth;
              _wedoThumbRatio = ratio.clamp(0.0, 1.0);
            });
            _syncArcReveal();
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              _wedoDragging = false;
              if (_wedoThumbRatio < 0.4) {
                _wedoThumbRatio = 0.0;
              } else if (_wedoThumbRatio > 0.6) {
                _wedoThumbRatio = 1.0;
              } else {
                _wedoThumbRatio = 0.5;
              }
            });
            _syncArcReveal();
          },
          child: AnimatedContainer(
            duration: Duration(
                milliseconds: (_isAutoHiding || _isFrameAutoHiding) ? 220 : 300),
            curve: Curves.easeInOut,
            height: trackHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(trackHeight / 2),
              gradient: LinearGradient(
                colors: isLeft
                    ? [
                        const Color(0xFFFE4EF0).withValues(alpha: 0.5),
                        const Color(0xFF800DD8).withValues(alpha: 0.5),
                      ]
                    : isRight
                    ? [
                        const Color(0xFF800DD8).withValues(alpha: 0.5),
                        const Color(0xFFFE4EF0).withValues(alpha: 0.5),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
              ),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFE4EF0).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isLeft ? 1.0 : 0.5,
                      child: Image.asset(
                        'assets/icons/Avatar-4.png',
                        width: 42,
                        height: 42,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isRight ? 1.0 : 0.5,
                      child: Image.asset(
                        'assets/icons/Frame-3.png',
                        width: 42,
                        height: 42,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.crop_square,
                              color: Colors.white,
                              size: 20,
                            ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _wedoDragging
                      ? Duration.zero
                      : Duration(
                          milliseconds: (_isAutoHiding || _isFrameAutoHiding) ? 220 : 300),
                  curve: Curves.easeOutBack,
                  top: (trackHeight - thumbSize) / 2,
                  left: thumbLeft,
                  child: GestureDetector(
                    onLongPressStart: (_) => _showBothArcs(),
                    onTap: () {
                      if (!_arcRevealCtrl.isDismissed &&
                          !_frameRevealCtrl.isDismissed) {
                        _hideBothArcs();
                      }
                    },
                    child: SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                      child: Center(
                        child: Image.asset(
                          'assets/images/WeDo-Logo.png',
                          width: 50,
                          height: 50,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.bolt,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameMatchStatsCard(BuildContext context) {
    final s = _rs(context);
    final totalPlayed = _totalMatches;
    final pfWins = _pickFightWins;
    final trWins = _triRaceWins;
    final totalWins = pfWins + trWins;
    final winRateRatio = totalPlayed > 0 ? (totalWins / totalPlayed).clamp(0.0, 1.0) : 0.0;
    final winRate = totalPlayed > 0 
        ? (winRateRatio * 100).toStringAsFixed(1)
        : '0.0';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16 * s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8 * s,
                        height: 8 * s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFE4EF0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFE4EF0).withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Text(
                        'Game & Match Stats',
                        style: TextStyle(
                          fontSize: 16 * s,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 14 * s,
                          color: const Color(0xFFFE4EF0),
                        ),
                        SizedBox(width: 3 * s),
                        Text(
                          '$winRate% Win Rate',
                          style: TextStyle(
                            fontSize: 11 * s,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16 * s),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedStatBox(
                        context: context,
                        iconAsset: 'assets/icons/controller.png',
                        fallbackIcon: Icons.sports_esports_rounded,
                        accentColor: const Color(0xFFB388FF),
                        label: 'Matches',
                        value: '$totalPlayed',
                        caption: 'PLAYED',
                      ),
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: _buildEnhancedStatBox(
                        context: context,
                        iconAsset: 'assets/icons/punch.png',
                        fallbackIcon: Icons.local_fire_department_rounded,
                        accentColor: const Color(0xFFFE4EF0),
                        label: 'PickFight',
                        value: '$pfWins',
                        caption: 'WINS',
                      ),
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: _buildEnhancedStatBox(
                        context: context,
                        iconAsset: 'assets/icons/racing-flag.png',
                        fallbackIcon: Icons.emoji_events_rounded,
                        accentColor: const Color(0xFF00E5FF),
                        label: 'TriRace',
                        value: '$trWins',
                        caption: 'PODIUM',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14 * s),
              ClipRRect(
                borderRadius: BorderRadius.circular(4 * s),
                child: Container(
                  height: 5 * s,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: winRateRatio,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF800DD8),
                            Color(0xFFFE4EF0),
                            Color(0xFF00E5FF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6 * s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Performance',
                    style: TextStyle(
                      fontSize: 10 * s,
                      color: Colors.white54,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '$totalWins of $totalPlayed won',
                    style: TextStyle(
                      fontSize: 10 * s,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStatBox({
    required BuildContext context,
    required String iconAsset,
    required IconData fallbackIcon,
    required Color accentColor,
    required String label,
    required String value,
    required String caption,
  }) {
    final s = _rs(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 6 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36 * s,
            height: 36 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 20 * s,
                height: 20 * s,
                child: Image.asset(
                  iconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    fallbackIcon,
                    size: 18 * s,
                    color: accentColor,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            value,
            style: TextStyle(
              fontSize: 22 * s,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Poppins',
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * s),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5 * s,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              fontFamily: 'Poppins',
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2.5 * s),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6 * s),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 8.5 * s,
                fontWeight: FontWeight.w700,
                color: accentColor,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMenu(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                context: context,
                icon: Icons.manage_accounts_rounded,
                accentColor: const Color(0xFFFE4EF0),
                title: 'Account Info',
                subtitle: 'Email, password & security',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
                ),
                showDivider: true,
              ),
              _buildMenuItem(
                context: context,
                icon: Icons.verified_user_rounded,
                accentColor: const Color(0xFF00E5FF),
                title: 'Terms & Agreement',
                subtitle: 'Privacy policy & terms of service',
                onTap: () => showTermsAgreementDialog(context),
                showDivider: true,
              ),
              _buildLogoutItem(context: context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    final s = _rs(context);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: accentColor.withValues(alpha: 0.12),
            highlightColor: accentColor.withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 13 * s),
              child: Row(
                children: [
                  Container(
                    width: 42 * s,
                    height: 42 * s,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12 * s),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.12),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 20 * s,
                    ),
                  ),
                  SizedBox(width: 14 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14 * s,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: 2 * s),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11 * s,
                            color: Colors.white54,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28 * s,
                    height: 28 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white60,
                      size: 18 * s,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72 * s,
            endIndent: 16 * s,
            color: Colors.white.withValues(alpha: 0.08),
          ),
      ],
    );
  }

  Widget _buildLogoutItem({required BuildContext context}) {
    final s = _rs(context);
    const accentColor = Color(0xFFFF5252);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        splashColor: accentColor.withValues(alpha: 0.12),
        highlightColor: accentColor.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 13 * s),
          child: Row(
            children: [
              Container(
                width: 42 * s,
                height: 42 * s,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12 * s),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 14 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 14 * s,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2 * s),
                    Text(
                      'Sign out from this device',
                      style: TextStyle(
                        fontSize: 11 * s,
                        color: Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16 * s),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exit',
                      style: TextStyle(
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(width: 3 * s),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: accentColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final s = _rs(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 28 * s),
          child: Container(
            padding: EdgeInsets.all(22 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF1F0F35).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22 * s),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54 * s,
                  height: 54 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFF5252),
                      size: 26,
                    ),
                  ),
                ),
                SizedBox(height: 16 * s),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 18 * s,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  'Are you sure you want to log out from this device?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5 * s,
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 22 * s),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12 * s),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12 * s),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * s),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12 * s),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                            ),
                            borderRadius: BorderRadius.circular(12 * s),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 13 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await _auth.signOut();
    }
  }
}
