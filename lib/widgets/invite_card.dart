import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class InviteCardBottomSheet extends StatelessWidget {
  final String groupId;
  final String groupName;
  final List<Map<String, dynamic>> members;

  const InviteCardBottomSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.members,
  });

  String get _inviteLink => 'wedo://group/$groupId';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.midnightBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _buildInviteCard(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.midnightBg,
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -0.9),
                      radius: 1.2,
                      colors: [
                        const Color(0xFF3A1078).withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.6, -0.5),
                      radius: 0.9,
                      colors: [
                        const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, 0.1),
                      radius: 1.1,
                      colors: [
                        const Color(0xFF800DD8).withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _InviteGridPainter(),
                ),
              ),
              _buildCardContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeaderSection(),
        Transform.translate(
          offset: const Offset(0, -20),
          child: _buildGlassCard(context),
        ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_rounded,
              size: 32,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            groupName,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF211635).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarRow(),
          const SizedBox(height: 16),
          Text(
            'Join this group chat and be part of the conversation',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildLinkDisplay(context),
          const SizedBox(height: 20),
          _buildCopyButton(context),
        ],
      ),
    );
  }

  Widget _buildAvatarRow() {
    final displayNames = <String>[
      for (final m in members) (m['displayName'] as String? ?? '?'),
    ];

    final visibleCount = displayNames.length.clamp(0, 5);
    final overflow = displayNames.length - visibleCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: visibleCount * 26.0,
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(visibleCount, (i) {
              return Positioned(
                left: i * 20.0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1A45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.midnightBg,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayNames[i].isNotEmpty
                          ? displayNames[i][0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lavenderAccent,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (overflow > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.lavenderAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              '+$overflow',
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.lavenderAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLinkDisplay(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.midnightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: 16,
            color: AppColors.lavenderAccent.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _inviteLink,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.lavenderAccent,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _inviteLink));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Invite link copied!',
                    style: TextStyle(fontFamily: _fontFamily),
                  ),
                  backgroundColor: const Color(0xFF211635),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.lavenderAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.copy_rounded,
                size: 14,
                color: AppColors.lavenderAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: _inviteLink));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Invite link copied! Share it with friends.',
              style: TextStyle(fontFamily: _fontFamily),
            ),
            backgroundColor: const Color(0xFF211635),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Copy Invite Link',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const spacingX = 28.0;
    const spacingY = 28.0;
    const dotRadius = 1.5;

    for (double x = spacingX / 2; x < size.width; x += spacingX) {
      for (double y = spacingY / 2; y < size.height; y += spacingY) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
