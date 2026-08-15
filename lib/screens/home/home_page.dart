import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../account/account_screen.dart';
import '../friends/friends_page.dart';
import '../session/session_entry_screen.dart';
import '../chat/chat_tab.dart';
import '../../widgets/animated_background.dart';
import '../../services/auth/user_service.dart';

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: Stack(
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
            SafeArea(
              child: IndexedStack(index: _currentIndex, children: _tabs),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomPadding + 20,
              child: BlobNavBar(
                currentIndex: _currentIndex,
                activeColor: _activeColor,
                inactiveColor: _inactiveColor,
                onTap: (index) => setState(() => _currentIndex = index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glassmorphism capsule navigation bar ────────────────────────────────────

class BlobNavBar extends StatelessWidget {
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;

  const BlobNavBar({
    super.key,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  static const _iconColor = Color(0xFF7A4A8A);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        const double padX = 20;
        const double capsuleH = 56;
        const double gap = 14;
        const double centerRaise = 18;
        const double centerDiameter = capsuleH + centerRaise;
        final double sideW = (w - padX * 2 - gap * 2 - centerDiameter) / 2;
        const double barH = capsuleH + 16;

        const double leftX = padX;
        final double centerX = w / 2 - centerDiameter / 2;
        final double rightX = w - padX - sideW;

        return SizedBox(
          height: barH,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Left hourglass connector ──
              Positioned(
                left: leftX + sideW - 21,
                top: (barH - capsuleH) / 2,
                width: centerX - (leftX + sideW) + 39,
                height: capsuleH,
                child: CustomPaint(
                  painter: _HourglassConnectorPainter(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),

              // ── Right hourglass connector ──
              Positioned(
                left: centerX + centerDiameter - 17,
                top: (barH - capsuleH) / 2,
                width: rightX - (centerX + centerDiameter) + 39,
                height: capsuleH,
                child: CustomPaint(
                  painter: _HourglassConnectorPainter(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),

              // ── Left glass capsule ──
              Positioned(
                left: leftX,
                top: (barH - capsuleH) / 2,
                width: sideW,
                height: capsuleH,
                child: _GlassCapsule(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavIconButton(
                        item: const _NavDef(
                          index: 0,
                          asset: 'assets/icons/home.png',
                        ),
                        isActive: currentIndex == 0,
                        activeColor: activeColor,
                        iconColor: _iconColor,
                        onTap: () => onTap(0),
                      ),
                      _NavIconButton(
                        item: const _NavDef(
                          index: 1,
                          asset: 'assets/icons/message.png',
                        ),
                        isActive: currentIndex == 1,
                        activeColor: activeColor,
                        iconColor: _iconColor,
                        onTap: () => onTap(1),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right glass capsule ──
              Positioned(
                left: rightX,
                top: (barH - capsuleH) / 2,
                width: sideW,
                height: capsuleH,
                child: _GlassCapsule(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavIconButton(
                        item: const _NavDef(
                          index: 2,
                          asset: 'assets/icons/friends.png',
                        ),
                        isActive: currentIndex == 2,
                        activeColor: activeColor,
                        iconColor: _iconColor,
                        onTap: () => onTap(2),
                      ),
                      _NavIconButton(
                        item: const _NavDef(
                          index: 4,
                          asset: 'assets/icons/avatar.png',
                          size: 20,
                        ),
                        isActive: currentIndex == 4,
                        activeColor: activeColor,
                        iconColor: _iconColor,
                        onTap: () => onTap(4),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Raised center capsule (hero button) ──
              Positioned(
                left: centerX,
                top: (barH - centerDiameter) / 2,
                width: centerDiameter,
                height: centerDiameter,
                child: _CenterLogoButton(
                  isActive: currentIndex == 3,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => onTap(3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Glassmorphism capsule ───────────────────────────────────────────────────

class _GlassCapsule extends StatelessWidget {
  final Widget child;
  const _GlassCapsule({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Center logo button (raised hero) ────────────────────────────────────────

class _CenterLogoButton extends StatefulWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _CenterLogoButton({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_CenterLogoButton> createState() => _CenterLogoButtonState();
}

class _CenterLogoButtonState extends State<_CenterLogoButton> {
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
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.isActive
                    ? const Color(0xFFFF6BB5)
                    : const Color(0xFF9A5AB0),
                widget.isActive
                    ? const Color(0xFF800DD8)
                    : const Color(0xFF6A3A80),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (widget.isActive
                            ? const Color(0xFFFE4EF0)
                            : const Color(0xFF7A4A8A))
                        .withValues(alpha: widget.isActive ? 0.5 : 0.25),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                padding: const EdgeInsets.all(12),
                child: Opacity(
                  opacity: widget.isActive ? 1.0 : 0.65,
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

class _NavIconButton extends StatefulWidget {
  final _NavDef item;
  final bool isActive;
  final Color activeColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? widget.activeColor : widget.iconColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : (widget.isActive ? 1.12 : 1.0),
        duration: const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: Image.asset(
              widget.item.asset,
              width: widget.item.size ?? 26,
              height: widget.item.size ?? 26,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.circle,
                  color: color,
                  size: widget.item.size ?? 26,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav definition ──────────────────────────────────────────────────────────

class _NavDef {
  final int index;
  final String asset;
  final double? size;

  const _NavDef({required this.index, required this.asset, this.size});
}

// ── Hourglass connector painter ─────────────────────────────────────────────

class _HourglassConnectorPainter extends CustomPainter {
  final Color color;
  const _HourglassConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final double pinch = size.height * 0.5;
    final double bulge = size.height * 0.3;
    final double midY = size.height / 2;
    final double midX = size.width / 2;

    // Start at top-left
    path.moveTo(0, 0);
    // Top edge: bows inward (downward toward center)
    path.quadraticBezierTo(midX, pinch, size.width, 0);
    // Right edge: bows outward (rightward)
    path.quadraticBezierTo(size.width + bulge, midY, size.width, size.height);
    // Bottom edge: bows inward (upward toward center)
    path.quadraticBezierTo(midX, size.height - pinch, 0, size.height);
    // Left edge: bows outward (leftward)
    path.quadraticBezierTo(-bulge, midY, 0, 0);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HourglassConnectorPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Home tab content ────────────────────────────────────────────────────────

class _FeatureCardData {
  final String image;
  final String badge;
  final String title;
  final String description;
  final Color badgeColor;

  const _FeatureCardData({
    required this.image,
    required this.badge,
    required this.title,
    required this.description,
    required this.badgeColor,
  });
}

const _featureCards = [
  _FeatureCardData(
    image: 'assets/images/GameTime.jpg',
    badge: 'NEW UPDATE',
    title: 'GameTime: Activated',
    description: 'Turn any moment into a game night.',
    badgeColor: Color(0xFFFE4EF0),
  ),
  _FeatureCardData(
    image: 'assets/images/Flashcards.png',
    badge: 'TRY NOW',
    title: 'Flashcards Mode',
    description: 'Learn faster, one card at a time.',
    badgeColor: Color(0xFF800DD8),
  ),
  _FeatureCardData(
    image: 'assets/images/SlotMachine.jpg',
    badge: 'HOT',
    title: 'Spin the Slot',
    description: 'Let luck decide what happens next.',
    badgeColor: Color(0xFFFF6BB5),
  ),
  _FeatureCardData(
    image: 'assets/images/RandomChallenge.png',
    badge: 'RANDOM PICK',
    title: "What's the Scene?",
    description: 'Answer the prompt, act it out, keep the night moving.',
    badgeColor: Color(0xFF4ECDC4),
  ),
  _FeatureCardData(
    image: 'assets/images/SpinWheel.png',
    badge: 'SPIN IT',
    title: 'Cyber Spin Wheel',
    description: 'Spin the wheel, let it choose your next move.',
    badgeColor: Color(0xFFFFD93D),
  ),
];

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final user = await _userService.getUserDocument(uid);
    if (user != null && mounted) {
      setState(() => _displayName = user.displayName);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 18) return 'Good Afternoon';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/WeDo-Logo.png',
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.casino,
                      color: Color(0xFFFE4EF0),
                      size: 40,
                    );
                  },
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                  ).createShader(bounds),
                  child: const Text(
                    'WeDo',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_greeting()}, ',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: '$_displayName!',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFE4EF0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _FeatureCarousel(),
            const SizedBox(height: 24),
            const _NowPlayingSection(),
          ],
        ),
      ),
    );
  }
}

// ── Feature carousel ────────────────────────────────────────────────────────

class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel();

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _controller;

  static const _autoScrollInterval = 3;
  static const _animDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _autoScrollInterval),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _advance();
          _controller.reset();
          _controller.forward();
        }
      });
    _controller.forward();
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _featureCards.length;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _featureCards[_currentIndex];

    return GestureDetector(
      onTap: _advance,
      child: AnimatedSwitcher(
        duration: _animDuration,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _FeatureCarouselCard(
          key: ValueKey(_currentIndex),
          data: data,
          showActionIcon: _currentIndex == 0,
        ),
      ),
    );
  }
}

class _FeatureCarouselCard extends StatelessWidget {
  final _FeatureCardData data;
  final bool showActionIcon;

  const _FeatureCarouselCard({
    super.key,
    required this.data,
    this.showActionIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: MediaQuery.of(context).size.width * 0.9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image ──
            Image.asset(
              data.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF1A1025),
                  child: const Icon(
                    Icons.image,
                    color: Colors.white24,
                    size: 48,
                  ),
                );
              },
            ),

            // ── Gradient overlay ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: data.badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data.badge,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),

            // ── Action icon ──
            if (showActionIcon)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Now Playing section ─────────────────────────────────────────────────────

class _NowPlayingCard {
  final String imagePath;
  final String title;
  final String statusLabel;
  final Color statusColor;

  const _NowPlayingCard({
    required this.imagePath,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
  });
}

const _nowPlayingGames = [
  _NowPlayingCard(
    imagePath: 'assets/images/Flashcards.png',
    title: 'Flashcards Mode',
    statusLabel: '856 Online',
    statusColor: Colors.greenAccent,
  ),
  _NowPlayingCard(
    imagePath: 'assets/images/Gaming.jpg',
    title: 'GameTime',
    statusLabel: '1.2k Online',
    statusColor: Colors.greenAccent,
  ),
  _NowPlayingCard(
    imagePath: 'assets/images/RandomChallenge.png',
    title: "What's the Scene?",
    statusLabel: 'Local Match',
    statusColor: Colors.pinkAccent,
  ),
  _NowPlayingCard(
    imagePath: 'assets/images/SpinWheel.png',
    title: 'Spin the Wheel',
    statusLabel: '1.2k Online',
    statusColor: Colors.greenAccent,
  ),
  _NowPlayingCard(
    imagePath: 'assets/images/SlotMachine.jpg',
    title: 'Spin the Slot',
    statusLabel: 'Local Match',
    statusColor: Colors.pinkAccent,
  ),
];

class _NowPlayingSection extends StatelessWidget {
  const _NowPlayingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Now Playing',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A5AB0),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFE4EF0),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _nowPlayingGames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _NowPlayingCardWidget(data: _nowPlayingGames[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _NowPlayingCardWidget extends StatelessWidget {
  final _NowPlayingCard data;

  const _NowPlayingCardWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                data.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1A1025),
                    child: const Icon(
                      Icons.gamepad,
                      color: Colors.white24,
                      size: 40,
                    ),
                  );
                },
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: data.statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          data.statusLabel,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
