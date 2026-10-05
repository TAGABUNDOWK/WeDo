import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/constants.dart';

const _baseColor = Color(0x14FFFFFF);
const _highlightColor = Color(0x33FFFFFF);

Shimmer _wrap(Widget child) => Shimmer.fromColors(
  baseColor: _baseColor,
  highlightColor: _highlightColor,
  child: child,
);

/// Ghost of the "Recent Races" section: a header row plus three race cards
/// mirroring the loaded layout (emoji tile, race code title, player/time
/// meta, and status pill).
class RecentRacesSkeleton extends StatelessWidget {
  const RecentRacesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Bar(width: 130, height: 14),
              _Bar(width: 55, height: 10, radius: 5),
            ],
          ),
          SizedBox(height: 8),
          _RaceCardSkeleton(),
          _RaceCardSkeleton(),
          _RaceCardSkeleton(),
        ],
      ),
    );
  }
}

class _RaceCardSkeleton extends StatelessWidget {
  const _RaceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: const Row(
        children: [
          _Rect(width: 40, height: 40, radius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(width: 140, height: 12),
                SizedBox(height: 6),
                _Bar(width: 110, height: 10),
              ],
            ),
          ),
          _Bar(width: 54, height: 20, radius: 6),
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

class _Rect extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Rect({
    required this.width,
    required this.height,
    required this.radius,
  });

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
