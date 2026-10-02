import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const _baseColor = Color(0x14FFFFFF);
const _highlightColor = Color(0x33FFFFFF);

Shimmer _wrap(Widget child) => Shimmer.fromColors(
  baseColor: _baseColor,
  highlightColor: _highlightColor,
  child: child,
);

/// Ghost block that mirrors the loaded summary card layout: a 52px icon,
/// location/temperature/condition bars, and the right-hand rain/forecast
/// column. Meant to be placed inside the card's `_Shell`.
class WeatherSummaryCardSkeleton extends StatelessWidget {
  const WeatherSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: _wrap(
        const Row(
          children: [
            _Circle(size: 52),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Bar(width: 90, height: 10),
                  SizedBox(height: 6),
                  _Bar(width: 70, height: 22),
                  SizedBox(height: 6),
                  _Bar(width: 110, height: 10),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Bar(width: 62, height: 10),
                SizedBox(height: 8),
                _Bar(width: 16, height: 16, radius: 8),
                SizedBox(height: 4),
                _Bar(width: 52, height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-body skeleton for the forecast screen: three glass panels mirroring
/// the current conditions card, hourly strip, and 10-day list. Panels keep
/// the app's purple styling; only their ghost content shimmers.
class WeatherForecastSkeleton extends StatelessWidget {
  const WeatherForecastSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: const [
        _CurrentPanel(),
        SizedBox(height: 16),
        _HourlyPanel(),
        SizedBox(height: 16),
        _DailyPanel(),
      ],
    );
  }
}

class _CurrentPanel extends StatelessWidget {
  const _CurrentPanel();

  @override
  Widget build(BuildContext context) {
    return _SkeletonPanel(
      padding: const EdgeInsets.all(18),
      child: _wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _Bar(width: 18, height: 18, radius: 6),
                SizedBox(width: 6),
                _Bar(width: 110, height: 12),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Circle(size: 58),
                SizedBox(width: 14),
                _Bar(width: 120, height: 30),
                Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Bar(width: 100, height: 14),
                    SizedBox(height: 6),
                    _Bar(width: 70, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: List.generate(4, (_) => const _MetricGhost()),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGhost extends StatelessWidget {
  const _MetricGhost();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Circle(size: 18),
        SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bar(width: 46, height: 9),
            SizedBox(height: 4),
            _Bar(width: 60, height: 8),
          ],
        ),
      ],
    );
  }
}

class _HourlyPanel extends StatelessWidget {
  const _HourlyPanel();

  @override
  Widget build(BuildContext context) {
    return _SkeletonPanel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: _wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _Circle(size: 20),
                SizedBox(width: 8),
                _Bar(width: 140, height: 14),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < 8; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      const _Bar(width: 72, height: 104, radius: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyPanel extends StatelessWidget {
  const _DailyPanel();

  @override
  Widget build(BuildContext context) {
    return _SkeletonPanel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: _wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _Circle(size: 20),
                SizedBox(width: 8),
                _Bar(width: 130, height: 14),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < 5; i++) const _DailyRowGhost(),
          ],
        ),
      ),
    );
  }
}

class _DailyRowGhost extends StatelessWidget {
  const _DailyRowGhost();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _Bar(width: 44, height: 10),
          SizedBox(width: 14),
          _Circle(size: 28),
          SizedBox(width: 10),
          Expanded(child: _Bar(height: 10)),
          SizedBox(width: 12),
          _Bar(width: 56, height: 10),
          SizedBox(width: 10),
          _Bar(width: 26, height: 10),
        ],
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _SkeletonPanel({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1464), Color(0xFF171044)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF9A4CFF).withValues(alpha: 0.75),
        ),
      ),
      child: child,
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
