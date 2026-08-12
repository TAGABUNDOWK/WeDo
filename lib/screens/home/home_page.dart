import 'dart:ui';
import 'package:flutter/material.dart';
import '../account/account_screen.dart';
import '../friends/friends_page.dart';
import '../session/session_entry_screen.dart';
import '../chat/chat_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const _tabs = [
    _HomeTab(),
    ChatTab(),
    FriendsPage(),
    SessionEntryScreen(),
    AccountScreen(),
  ];

  static const _activeColor = Color(0xFFFE4EF0);
  static const _inactiveColor = Color(0x80FFFFFF);

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF190831);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 16,
            child: _GlassNavBar(
              currentIndex: _currentIndex,
              activeColor: _activeColor,
              inactiveColor: _inactiveColor,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glassmorphic navigation bar ─────────────────────────────────────────────

class _GlassNavBar extends StatefulWidget {
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;

  const _GlassNavBar({
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar> {
  final _leftCapsuleKey = GlobalKey();
  final _rightCapsuleKey = GlobalKey();

  static const _centerLogoSize = 60.0;
  static const _centerLogoTop = 1.0;
  static const _capsuleTop = 4.0;
  static const _connectorTop = 4.0;
  static const _capsuleHeight = 54.0;
  static const _sideMargin = 16.0;
  static const _connectorWidth = 45.0;

  double? _cachedLeftCapRight;
  double? _cachedRightCapLeft;
  double _lastMeasuredWidth = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final centerX = w / 2;
          final centerLeft = centerX - _centerLogoSize / 2;
          final centerRight = centerX + _centerLogoSize / 2;

          // Only re-measure when parent width changes (not on tab switch)
          if (_lastMeasuredWidth != w) {
            _lastMeasuredWidth = w;

            final leftBox = _leftCapsuleKey.currentContext?.findRenderObject();
            if (leftBox is RenderBox && leftBox.hasSize) {
              final pos = leftBox.localToGlobal(Offset.zero);
              _cachedLeftCapRight = pos.dx + leftBox.size.width;
            }
            final rightBox = _rightCapsuleKey.currentContext
                ?.findRenderObject();
            if (rightBox is RenderBox && rightBox.hasSize) {
              final pos = rightBox.localToGlobal(Offset.zero);
              _cachedRightCapLeft = pos.dx;
            }
          }

          final leftCapRight = _cachedLeftCapRight ?? (centerLeft - 20);
          final rightCapLeft = _cachedRightCapLeft ?? (centerRight + 20);

          // Left connector: biased toward center logo
          final leftGapCenter =
              leftCapRight + (centerLeft - leftCapRight) * 0.50;
          // Right connector: biased toward center logo
          final rightGapCenter =
              centerRight + (rightCapLeft - centerRight) * 0.50;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Connector between left capsule and center logo
              Positioned(
                left: leftGapCenter - _connectorWidth / 2,
                top: _connectorTop,
                child: _ConnectorShape(
                  width: _connectorWidth,
                  height: _capsuleHeight,
                ),
              ),
              // Connector between center logo and right capsule
              Positioned(
                left: rightGapCenter - _connectorWidth / 2,
                top: _connectorTop,
                child: _ConnectorShape(
                  width: _connectorWidth,
                  height: _capsuleHeight,
                ),
              ),
              // Left + Right capsules (on top of connectors)
              Positioned(
                left: _sideMargin,
                right: _sideMargin,
                top: _capsuleTop,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassCapsule(
                        key: _leftCapsuleKey,
                        items: const [
                          _NavDef(index: 0, asset: 'assets/icons/home.png'),
                          _NavDef(index: 1, asset: 'assets/icons/message.png'),
                        ],
                        currentIndex: widget.currentIndex,
                        activeColor: widget.activeColor,
                        inactiveColor: widget.inactiveColor,
                        onTap: widget.onTap,
                      ),
                      _GlassCapsule(
                        key: _rightCapsuleKey,
                        items: const [
                          _NavDef(index: 2, asset: 'assets/icons/friends.png'),
                          _NavDef(index: 4, asset: 'assets/icons/avatar.png'),
                        ],
                        currentIndex: widget.currentIndex,
                        activeColor: widget.activeColor,
                        inactiveColor: widget.inactiveColor,
                        onTap: widget.onTap,
                      ),
                    ],
                  ),
                ),
              ),
              // Center logo (on top of everything)
              Positioned(
                left: 0,
                right: 0,
                top: _centerLogoTop,
                child: Center(
                  child: _CenterLogo(
                    isActive: widget.currentIndex == 3,
                    activeColor: widget.activeColor,
                    inactiveColor: widget.inactiveColor,
                    onTap: () => widget.onTap(3),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Connector shape (glassmorphic bridge between capsules) ──────────────────

class _ConnectorShape extends StatelessWidget {
  final double width;
  final double height;

  const _ConnectorShape({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    if (width <= 0) return const SizedBox.shrink();

    return SizedBox(
      width: width,
      height: height,
      child: ClipPath(
        clipper: _ConnectorClipper(height: height),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: CustomPaint(
            painter: _ConnectorPainter(height: height),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ConnectorClipper extends CustomClipper<Path> {
  final double height;

  const _ConnectorClipper({required this.height});

  @override
  Path getClip(Size size) {
    final h = height;
    final cpOffset = h * 0.4;

    return Path()
      ..moveTo(0, 0)
      ..cubicTo(0, cpOffset, size.width, cpOffset, size.width, 0)
      ..lineTo(size.width, h)
      ..cubicTo(size.width, h - cpOffset, 0, h - cpOffset, 0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ConnectorClipper oldClipper) =>
      oldClipper.height != height;
}

class _ConnectorPainter extends CustomPainter {
  final double height;

  const _ConnectorPainter({required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final h = height;
    final cpOffset = h * 0.4;

    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(0, cpOffset, size.width, cpOffset, size.width, 0)
      ..lineTo(size.width, h)
      ..cubicTo(size.width, h - cpOffset, 0, h - cpOffset, 0, h)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldPainter) =>
      oldPainter.height != height;
}

// ── Left / Right capsule ────────────────────────────────────────────────────

class _GlassCapsule extends StatelessWidget {
  final List<_NavDef> items;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;

  const _GlassCapsule({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              return _NavIconButton(
                item: item,
                isActive: currentIndex == item.index,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(item.index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Center logo capsule ─────────────────────────────────────────────────────

class _CenterLogo extends StatefulWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _CenterLogo({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_CenterLogo> createState() => _CenterLogoState();
}

class _CenterLogoState extends State<_CenterLogo> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.isActive
                    ? widget.activeColor.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: widget.isActive ? 24 : 12,
                spreadRadius: widget.isActive ? 2 : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.35),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Opacity(
                  opacity: widget.isActive ? 1.0 : 0.5,
                  child: Image.asset(
                    'assets/images/WeDo-Logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.casino,
                        color: widget.isActive
                            ? widget.activeColor
                            : widget.inactiveColor,
                        size: 28,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav icon button ─────────────────────────────────────────────────────────

class _NavDef {
  final int index;
  final String asset;

  const _NavDef({required this.index, required this.asset});
}

class _NavIconButton extends StatefulWidget {
  final _NavDef item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? widget.activeColor : widget.inactiveColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : (widget.isActive ? 1.1 : 1.0),
        duration: const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: Image.asset(
              widget.item.asset,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.circle, color: color, size: 24);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Home tab content ────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WeDo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Welcome back!',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE4EF0),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFFE4EF0),
                        offset: Offset(0, 6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.casino,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Flip the dice to decide',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create a topic and let fate decide',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Start a decision',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.casino_outlined,
                      color: Color(0xFFFE4EF0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Decision #$i',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Placeholder topic',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
