import 'dart:ui';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/profile/profile_service.dart';
import '../../services/session/session_service.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../models/user_entity.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/arc_avatar_picker.dart';
import '../../widgets/terms_agreement_dialog.dart';
import 'edit_profile_page.dart';

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
  final _profileService = ProfileService();
  final _sessionService = SessionService();
  final _triRaceService = TriRaceService();
  final _imagePicker = ImagePicker();
  UserEntity? _user;
  bool _loading = true;
  int _totalMatches = 0;
  int _pickFightWins = 0;
  int _triRaceWins = 0;
  double _wedoThumbRatio = 0.5;
  bool _wedoDragging = false;
  late final AnimationController _arcRevealCtrl;
  late final AnimationController _frameRevealCtrl;
  bool _isAutoHiding = false;
  bool _isFrameAutoHiding = false;

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
    _loadUser();
    _loadStats();
  }

  @override
  void dispose() {
    _arcRevealCtrl.dispose();
    _frameRevealCtrl.dispose();
    super.dispose();
  }

  void _closeArcImmediately() {
    if (_arcRevealCtrl.isDismissed) return;
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
  }

  void _hideBothArcs() {
    _arcRevealCtrl.reverse();
    _frameRevealCtrl.reverse();
    setState(() => _wedoThumbRatio = 0.5);
  }

  void _syncArcReveal() {
    if (_wedoThumbRatio < 0.45) {
      _arcRevealCtrl.forward();
      _frameRevealCtrl.reverse();
    } else if (_wedoThumbRatio > 0.55) {
      _frameRevealCtrl.forward();
      _arcRevealCtrl.reverse();
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

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final user = await _userService.getUserDocument(uid);

    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
      });
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

  void _closeIfBothVisible() {
    if (!_arcRevealCtrl.isDismissed && !_frameRevealCtrl.isDismissed) {
      _hideBothArcs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeIfBothVisible,
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
                  ..scale(-1.0, 1.0)
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
                ? const Center(
                    child: Text(
                      'No user data found',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  )
                : SafeArea(
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
                            _buildTopBar(),
                            const SizedBox(height: 24),
                            _buildProfileHeader(),
                            const SizedBox(height: 12),
                            _buildWeDoSlider(),
                            const SizedBox(height: 20),
                            _buildGameMatchStatsCard(context),
                            const SizedBox(height: 16),
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
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3 * blurValue),
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

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Image.asset(
                'assets/icons/create.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.add, color: Colors.white70, size: 26),
              ),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Image.asset(
                'assets/icons/menu.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.menu, color: Colors.white70, size: 30),
              ),
            ),
          ),
        ),
      ],
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
    return StreamBuilder<List>(
      stream: _friendService.getFriendsStream(_uid),
      builder: (context, snapshot) {
        final friendsCount = snapshot.data?.length ?? 0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                  _buildStatItem(count: friendsCount, label: 'Friends'),
                  _buildStatItem(count: 0, label: 'Following'),
                  _buildStatItem(count: 0, label: 'Decisions'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({required int count, required String label}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFFE4EF0),
              fontFamily: 'Poppins',
            ),
          ),
        ],
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
    final winRate = totalPlayed > 0 
        ? ((pfWins + trWins) / totalPlayed * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
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
          SizedBox(height: 16 * s),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  context: context,
                  label: 'Total Matches',
                  value: '$totalPlayed',
                  valueColor: Colors.white,
                  caption: 'Played',
                ),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: _buildWinnerStatBox(context: context, wins: pfWins, winRate: winRate),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: _buildStatBox(
                  context: context,
                  label: 'TriRace Wins',
                  value: '$trWins',
                  valueColor: const Color(0xFF00E5FF),
                  caption: 'Top Podium',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required String label,
    required String value,
    required Color valueColor,
    required String caption,
  }) {
    final s = _rs(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 8 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10 * s,
              color: Colors.white70,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6 * s),
          Text(
            value,
            style: TextStyle(
              fontSize: 22 * s,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            caption,
            style: TextStyle(
              fontSize: 9 * s,
              color: const Color(0xFFFE4EF0),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerStatBox({
    required BuildContext context,
    required int wins,
    required String winRate,
  }) {
    final s = _rs(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12 * s, horizontal: 8 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFE4EF0).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 2 * s),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'WINNER',
              style: TextStyle(
                fontSize: 8 * s,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Poppins',
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Pick Fight Wins',
            style: TextStyle(
              fontSize: 10 * s,
              color: Colors.white70,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * s),
          Text(
            '$wins',
            style: TextStyle(
              fontSize: 24 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFD600),
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 2 * s),
          Text(
            '$winRate% Win Rate',
            style: TextStyle(
              fontSize: 9 * s,
              color: const Color(0xFFFE4EF0),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context: context,
            icon: Icons.credit_card,
            title: 'Account Info',
            subtitle: 'Manage email, security & IDs',
            onTap: () {},
            showDivider: true,
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.shield,
            title: 'Terms & Agreement',
            subtitle: 'Privacy policy, terms of service',
            onTap: () => showTermsAgreementDialog(context),
            showDivider: true,
          ),
          _buildLogoutItem(context: context),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    final s = _rs(context);
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 14 * s),
            child: Row(
              children: [
                Container(
                  width: 40 * s,
                  height: 40 * s,
                  decoration: BoxDecoration(
                    color: const Color(0xFF800DD8).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFFE4EF0),
                    size: 20 * s,
                  ),
                ),
                SizedBox(width: 12 * s),
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
                Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                  size: 20 * s,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 68 * s,
            color: Colors.white.withValues(alpha: 0.08),
          ),
      ],
    );
  }

  Widget _buildLogoutItem({required BuildContext context}) {
    final s = _rs(context);
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1233),
            title: const Text('Log out',
                style: TextStyle(color: Colors.white)),
            content: const Text('Are you sure you want to log out?',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log out',
                    style: TextStyle(color: Color(0xFFFF6B6B))),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _auth.signOut();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 14 * s),
        child: Row(
          children: [
            Container(
              width: 40 * s,
              height: 40 * s,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.logout,
                color: const Color(0xFFFF6B6B),
                size: 20 * s,
              ),
            ),
            SizedBox(width: 12 * s),
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
              padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                'Exit',
                style: TextStyle(
                  fontSize: 12 * s,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6B6B),
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
