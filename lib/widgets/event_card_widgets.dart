import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

/// Short event date, e.g. `Jan 5, 2026`.
String formatEventDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Clock time, e.g. `3:45 PM`.
String formatEventTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:$minute $period';
}

/// e.g. `Jan 5, 2026 at 3:45 PM`.
String formatEventFullDateTime(DateTime dt) =>
    '${formatEventDate(dt)} at ${formatEventTime(dt)}';

/// Compact countdown label: `5m 30s`, `2h 5m`, `1d 3h`.
String eventDurationLabel(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inDays}d ${d.inHours % 24}h';
}

// ── Card header: centered EVENT label + info action ─────────────────────────

class EventCardHeaderStrip extends StatelessWidget {
  final VoidCallback? onInfoTap;

  const EventCardHeaderStrip({super.key, this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'EVENT',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 2.2,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onInfoTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/icons/info.png',
                  width: 16,
                  height: 16,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass info chips: date / location / attire ─────────────────────────────

class EventInfoChips extends StatelessWidget {
  final ChatEvent event;

  const EventInfoChips({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _ImageInfoChip(
        iconAsset: 'assets/icons/calendar.png',
        fallbackIcon: Icons.calendar_today_outlined,
        text: event.endDate != null
            ? '${formatEventFullDateTime(event.date)} · Ends ${formatEventTime(event.endDate!)}'
            : formatEventFullDateTime(event.date),
      ),
      if (event.location != null && event.location!.isNotEmpty)
        _ImageInfoChip(
          iconAsset: 'assets/icons/location.png',
          fallbackIcon: Icons.location_on_outlined,
          text: event.location!,
        ),
      if (event.dressCode != null && event.dressCode!.isNotEmpty)
        _ImageInfoChip(
          iconAsset: 'assets/icons/outfit.png',
          fallbackIcon: Icons.checkroom_outlined,
          text: event.dressCode!,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }
}

class _ImageInfoChip extends StatelessWidget {
  final String iconAsset;
  final IconData fallbackIcon;
  final String text;

  const _ImageInfoChip({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Image.asset(
                    iconAsset,
                    width: 18,
                    height: 18,
                    errorBuilder: (_, __, ___) => Icon(
                      fallbackIcon,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status bar: happening now / starts in / ended ──────────────────────────

class EventStatusBar extends StatelessWidget {
  final DateTime eventDate;
  final DateTime? endDate;

  const EventStatusBar({super.key, required this.eventDate, this.endDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isStarted = now.isAfter(eventDate);
    final isEnded = endDate != null && now.isAfter(endDate!);
    final isLive = isStarted && !isEnded;

    if (isLive) {
      final endsIn = endDate?.difference(now);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.neonMagenta.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonMagenta.withValues(alpha: 0.35),
              offset: const Offset(0, 0),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            const _PulsingDot(),
            const SizedBox(width: 10),
            const Text(
              'HAPPENING NOW',
              style: TextStyle(
                color: AppColors.neonMagenta,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            if (endsIn != null) ...[
              const Spacer(),
              Text(
                'Ends in ${eventDurationLabel(endsIn)}',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final String text;
    final IconData icon;
    if (isEnded) {
      text = 'Event ended';
      icon = Icons.check_circle_outline;
    } else {
      final diff = eventDate.difference(now);
      text = 'Starts in ${eventDurationLabel(diff)}';
      icon = Icons.access_time;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Looping heartbeat pulse for the live status ────────────────────────────

class _PulsingDot extends StatefulWidget {
  final double size = 12;
  final Color color = AppColors.neonMagenta;

  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: widget.size * 2.4,
          height: widget.size * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + t,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.3 * (1 - t)),
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Voting option with proportional fill + voter avatars ───────────────────

class EventVoteOption extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final List<String> voters;
  final Widget Function(String uid, double size) avatarBuilder;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const EventVoteOption({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    required this.voters,
    required this.avatarBuilder,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final factor = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final percent = total > 0 ? (count / total * 100).round() : 0;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.lavenderAccent
                    : AppColors.glassBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: factor),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      builder: (context, value, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: ColoredBox(
                            color: AppColors.neonMagenta.withValues(
                              alpha: isSelected ? 0.45 : 0.26,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final rowWidth = constraints.maxWidth;
                        final gapsAndIcon =
                            (isSelected ? 24.0 : 0.0) + 16.0;
                        final desiredAvatarWidth =
                            EventVoteAvatarStack.widthFor(voters.length);
                        final pillCap = rowWidth.isFinite
                            ? math.min(
                                110.0,
                                math.max(0.0, rowWidth - gapsAndIcon),
                              )
                            : 110.0;
                        final avatarCap = rowWidth.isFinite
                            ? math.min(
                                desiredAvatarWidth,
                                math.max(
                                  0.0,
                                  rowWidth - gapsAndIcon - pillCap,
                                ),
                              )
                            : desiredAvatarWidth;

                        return Row(
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: AppColors.lavenderAccent,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.textPrimary
                                          .withValues(alpha: 0.9),
                                  fontFamily: _fontFamily,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: pillCap),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$count · $percent%',
                                    style: TextStyle(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.9),
                                      fontFamily: _fontFamily,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            EventVoteAvatarStack(
                              voters: voters,
                              avatarBuilder: avatarBuilder,
                              maxWidth: avatarCap,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EventVoteAvatarStack extends StatelessWidget {
  final List<String> voters;
  final Widget Function(String uid, double size) avatarBuilder;

  /// Width budget the stack must never exceed. Avatars (and finally the
  /// "+N" chip) are dropped when they don't fit.
  final double maxWidth;

  static const int _maxVisible = 4;
  static const double _avatarSize = 24;
  static const double _avatarStride = 16; // 24px avatar with 8px overlap
  static const double _chipWidth = 27; // 3px gap + 24px pill

  const EventVoteAvatarStack({
    super.key,
    required this.voters,
    required this.avatarBuilder,
    this.maxWidth = double.infinity,
  });

  /// Full rendered width for [count] voters (capped at 4 avatars + "+N").
  static double widthFor(int count) {
    final visible = math.min(count, _maxVisible);
    final avatars = visible == 0
        ? 0.0
        : _avatarSize + (visible - 1) * _avatarStride;
    final chip = count > visible ? _chipWidth : 0.0;
    return avatars + chip;
  }

  double _widthOf(int shown, int hidden) {
    final avatars =
        shown == 0 ? 0.0 : _avatarSize + (shown - 1) * _avatarStride;
    return avatars + (hidden > 0 ? _chipWidth : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (voters.isEmpty || maxWidth <= 0) return const SizedBox.shrink();

    var shown = math.min(voters.length, _maxVisible);
    while (shown > 0 && _widthOf(shown, voters.length - shown) > maxWidth) {
      shown--;
    }

    final hidden = voters.length - shown;
    final showChip = hidden > 0 && maxWidth >= _widthOf(shown, hidden);
    if (shown == 0 && !showChip) return const SizedBox.shrink();

    final avatarWidth =
        shown == 0 ? 0.0 : _avatarSize + (shown - 1) * _avatarStride;

    return SizedBox(
      width: avatarWidth + (showChip ? _chipWidth : 0),
      height: _avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < shown; i++)
            Positioned(
              left: i * _avatarStride,
              child: avatarBuilder(voters[i], _avatarSize),
            ),
          if (showChip)
            Positioned(
              left: avatarWidth + 3,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lavenderAccent.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.lavenderAccent.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$hidden',
                    style: const TextStyle(
                      color: AppColors.lavenderAccent,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Lock notice shown under the options when RSVPs are closed ──────────────

class EventRsvpLockRow extends StatelessWidget {
  final bool ended;

  const EventRsvpLockRow({super.key, required this.ended});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            size: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Responses closed — event has ${ended ? "ended" : "not started"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontFamily: _fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
