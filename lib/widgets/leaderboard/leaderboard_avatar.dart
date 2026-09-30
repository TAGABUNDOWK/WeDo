import 'package:flutter/material.dart';

/// Renders a player as a round mascot blob avatar. Uses the player's preset
/// `avatar_asset` when available and falls back to the app's purple blob with
/// two dot eyes.
class LeaderboardAvatar extends StatelessWidget {
  final String? asset;
  final double size;

  const LeaderboardAvatar({super.key, this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = _blobAvatar(size);
    final path = asset?.trim() ?? '';
    if (path.isEmpty) return fallback;
    return ClipOval(
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
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