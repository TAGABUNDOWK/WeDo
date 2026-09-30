import 'package:flutter/material.dart';

/// Renders a player as a round mascot blob avatar. Priority: the player's
/// custom profile photo (`photo_url`) when available, then their preset
/// `avatar_asset`, then the app's purple blob with two dot eyes.
class LeaderboardAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? asset;
  final String? frameAsset;
  final double size;

  const LeaderboardAvatar({
    super.key,
    this.photoUrl,
    this.asset,
    this.frameAsset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    final avatar = url.isNotEmpty
        ? ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _assetOrBlob(),
            ),
          )
        : _assetOrBlob();

    final frame = frameAsset?.trim() ?? '';
    if (frame.isEmpty) return avatar;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          avatar,
          IgnorePointer(
            child: Transform.scale(
              scale: frame.contains('Frame-4') ? 1.2 : 1,
              child: Image.asset(
                frame,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetOrBlob() {
    final path = asset?.trim() ?? '';
    if (path.isEmpty) return _blobAvatar(size);
    return ClipOval(
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _blobAvatar(size),
      ),
    );
  }

  Widget _blobAvatar(double s) {
    return Container(
      width: s,
      height: s,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B4DFF), Color(0xFF5E1FB8)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Positioned(
                left: w * 0.26,
                top: w * 0.30,
                child: _eye(w),
              ),
              Positioned(
                left: w * 0.52,
                top: w * 0.30,
                child: _eye(w),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _eye(double w) {
    return Container(
      width: w * 0.18,
      height: w * 0.18,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: w * 0.09,
          height: w * 0.09,
          decoration: const BoxDecoration(
            color: Color(0xFF1A0A2E),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
