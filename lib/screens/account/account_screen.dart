import 'dart:ui';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/profile/profile_service.dart';
import '../../models/user_entity.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/arc_avatar_picker.dart';

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
  final _imagePicker = ImagePicker();
  UserEntity? _user;
  bool _loading = true;
  double _wedoThumbRatio = 0.5;
  bool _wedoDragging = false;
  late final AnimationController _arcRevealCtrl;
  late final AnimationController _frameRevealCtrl;
  bool _isAutoHiding = false;
  bool _isFrameAutoHiding = false;

  String get _uid => _auth.currentUser?.uid ?? '';

  // Mock gamified status — TODO: replace with UserEntity.wedoExp when available
  int get _mockExp => 12;
  int get _mockLevel => (_mockExp ~/ 10) + 1;

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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 24),
                          _buildProfileHeader(),
                          const SizedBox(height: 12),
                          _buildWeDoSlider(),
                          const SizedBox(height: 10),
                          _buildTopDecisionsCard(context),
                          const SizedBox(height: 12),
                          _buildAchievementsCard(context),
                        ],
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
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/energy.png',
                  width: 25,
                  height: 25,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.bolt, color: Color(0xFFFE4EF0), size: 25),
                ),
                const SizedBox(width: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Lv. ',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      TextSpan(
                        text: '$_mockLevel',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFE4EF0),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      TextSpan(
                        text: ' · $_mockExp EXP',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
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
              Text(
                _user!.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
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
                  _buildStatItem(count: 0, label: 'Mutuals'),
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

  Widget _buildGlassCard({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    final s = _rs(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16 * s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 15 * s),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16 * s,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFE4EF0),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32 * s,
                    height: 32 * s,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18 * s,
                      onPressed: () {},
                      icon: Image.asset(
                        'assets/icons/right-up.png',
                        width: 18 * s,
                        height: 18 * s,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.north_east,
                                color: Colors.white70, size: 18 * s),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12 * s),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankRow({
    required BuildContext context,
    required String iconAsset,
    required Widget label,
  }) {
    final s = _rs(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * s),
      child: Row(
        children: [
          Image.asset(
            iconAsset,
            width: 26 * s,
            height: 26 * s,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.emoji_events,
              color: const Color(0xFFFE4EF0),
              size: 26 * s,
            ),
          ),
          SizedBox(width: 10 * s),
          Expanded(child: label),
        ],
      ),
    );
  }

  Widget _buildTopDecisionsCard(BuildContext context) {
    final s = _rs(context);
    return _buildGlassCard(
      context: context,
      title: 'Top Decisions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 40 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRankRow(
                  context: context,
                  iconAsset: 'assets/icons/Trophy-1.png',
                  label: Text(
                    'Choose dinner spot fastest',
                    style: TextStyle(
                      fontSize: 13.5 * s,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                _buildRankRow(
                  context: context,
                  iconAsset: 'assets/icons/Trophy-2.png',
                  label: Text(
                    'Pick weekend movie',
                    style: TextStyle(
                      fontSize: 13.5 * s,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                _buildRankRow(
                  context: context,
                  iconAsset: 'assets/icons/Trophy-3.png',
                  label: Text(
                    'Plan Friday hangout',
                    style: TextStyle(
                      fontSize: 13.5 * s,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 15 * s, top: 6 * s),
            child: Text.rich(
              TextSpan(
                text: '0',
                style: TextStyle(
                  fontSize: 17 * s,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
                children: [
                  TextSpan(
                    text: '  Daily Decisions',
                    style: TextStyle(
                      fontSize: 14.5 * s,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFE4EF0),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard(BuildContext context) {
    final s = _rs(context);
    return _buildGlassCard(
      context: context,
      title: 'Achievements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 40 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRankRow(
                  context: context,
                  iconAsset: 'assets/icons/Achievement-1.png',
                  label:
                      _achievementLabel(context, 'Decide ', '100', ' in a day'),
                ),
                _buildRankRow(
                  context: context,
                  iconAsset: 'assets/icons/Achievement-2.png',
                  label: _achievementLabel(
                      context, 'Reach a ', '7', '-day streak'),
                ),
                _buildRankRow(
                  context: context,
                  iconAsset: 'assets/icons/Achievement-3.png',
                  label: _achievementLabel(
                      context, 'Make ', '50', ' group decisions'),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 15 * s, top: 6 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+12 WeDo Exp',
                  style: TextStyle(
                    fontSize: 12.5 * s,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFE4EF0),
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 6 * s),
                _buildProgressBar(context, 0.45),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementLabel(
      BuildContext context, String before, String value, String after) {
    final s = _rs(context);
    return Text.rich(
      TextSpan(
        text: before,
        style: TextStyle(
          fontSize: 13.5 * s,
          color: Colors.white,
          fontFamily: 'Poppins',
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFE4EF0),
              fontFamily: 'Poppins',
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double fraction) {
    final s = _rs(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 280 * s,
        height: 20 * s,
        color: Colors.white.withValues(alpha: 0.12),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFFFE4EF0),
            ),
          ),
        ),
      ),
    );
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
}
