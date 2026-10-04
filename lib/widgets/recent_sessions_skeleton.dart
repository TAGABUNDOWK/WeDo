import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const _baseColor = Color(0x14FFFFFF);
const _highlightColor = Color(0x33FFFFFF);

Shimmer _wrap(Widget child) => Shimmer.fromColors(
  baseColor: _baseColor,
  highlightColor: _highlightColor,
  child: child,
);

/// Ghost of the "Recent PickFight Sessions" section: a header row plus three
/// session cards mirroring the loaded layout (topic emoji, title, player/time
/// meta, winner line, status badge, and session code).
class RecentSessionsSkeleton extends StatelessWidget {
  const RecentSessionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Circle(size: 20),
              SizedBox(width: 8),
              _Bar(width: 190, height: 14),
              Spacer(),
              _Bar(width: 60, height: 10, radius: 5),
            ],
          ),
          SizedBox(height: 12),
          _SessionCardSkeleton(),
          _SessionCardSkeleton(),
          _SessionCardSkeleton(),
        ],
      ),
    );
  }
}

class _SessionCardSkeleton extends StatelessWidget {
  const _SessionCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: const Row(
        children: [
          _Circle(size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(width: 140, height: 14),
                SizedBox(height: 6),
                Row(
                  children: [
                    _Bar(width: 80, height: 10),
                    SizedBox(width: 10),
                    _Bar(width: 48, height: 10),
                  ],
                ),
                SizedBox(height: 6),
                _Bar(width: 110, height: 10),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Bar(width: 64, height: 18, radius: 6),
              SizedBox(height: 6),
              _Bar(width: 48, height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _Bar({this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;

  const _Circle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
