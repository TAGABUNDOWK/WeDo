import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../account/account_screen.dart';
import '../friends/friends_page.dart';
import '../session/session_entry_screen.dart';
import '../session/create_session_screen.dart';
import '../../features/spin_wheel/screens/wheel_screen.dart';
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
                  ..scaleByDouble(-1.0, 1.0, 1.0, 1.0)
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
              child: Column(
                children: [
                  Expanded(
                    child: IndexedStack(index: _currentIndex, children: _tabs),
                  ),
                ],
              ),
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

class BlobNavBar extends StatefulWidget {
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
  State<BlobNavBar> createState() => _BlobNavBarState();
}

class _BlobNavBarState extends State<BlobNavBar>
    with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  late final AnimationController _menuCtrl;
  late final Animation<double> _menuScale;
  late final Animation<double> _menuFade;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuScale = CurvedAnimation(parent: _menuCtrl, curve: Curves.easeOutBack);
    _menuFade = CurvedAnimation(
      parent: _menuCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _menuCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
    if (_isMenuOpen) {
      _menuCtrl.forward();
    } else {
      _menuCtrl.reverse();
    }
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() => _isMenuOpen = false);
      _menuCtrl.reverse();
    }
  }

  void _onChoiceTap(VoidCallback? navigation) {
    _closeMenu();
    if (navigation != null) {
      Future.delayed(const Duration(milliseconds: 200), navigation);
    }
  }

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
        const double popupSpace = 120;

        const double leftX = padX;
        final double centerX = w / 2 - centerDiameter / 2;
        final double rightX = w - padX - sideW;

        return SizedBox(
          height: barH + popupSpace,
          width: w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Left hourglass connector ──
              Positioned(
                left: leftX + sideW - 21,
                top: popupSpace + (barH - capsuleH) / 2,
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
                top: popupSpace + (barH - capsuleH) / 2,
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
                top: popupSpace + (barH - capsuleH) / 2,
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
                        isActive: widget.currentIndex == 0,
                        activeColor: widget.activeColor,
                        iconColor: BlobNavBar._iconColor,
                        onTap: () => widget.onTap(0),
                      ),
                      _NavIconButton(
                        item: const _NavDef(
                          index: 1,
                          asset: 'assets/icons/message.png',
                        ),
                        isActive: widget.currentIndex == 1,
                        activeColor: widget.activeColor,
                        iconColor: BlobNavBar._iconColor,
                        onTap: () => widget.onTap(1),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right glass capsule ──
              Positioned(
                left: rightX,
                top: popupSpace + (barH - capsuleH) / 2,
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
                        isActive: widget.currentIndex == 2,
                        activeColor: widget.activeColor,
                        iconColor: BlobNavBar._iconColor,
                        onTap: () => widget.onTap(2),
                      ),
                      _NavIconButton(
                        item: const _NavDef(
                          index: 4,
                          asset: 'assets/icons/avatar.png',
                          size: 20,
                        ),
                        isActive: widget.currentIndex == 4,
                        activeColor: widget.activeColor,
                        iconColor: BlobNavBar._iconColor,
                        onTap: () => widget.onTap(4),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Raised center capsule (hero button) ──
              Positioned(
                left: centerX,
                top: popupSpace + (barH - centerDiameter) / 2,
                width: centerDiameter,
                height: centerDiameter,
                child: _CenterLogoButton(
                  isActive: widget.currentIndex == 3,
                  isMenuOpen: _isMenuOpen,
                  activeColor: widget.activeColor,
                  inactiveColor: widget.inactiveColor,
                  onTap: () => widget.onTap(3),
                  onLongPress: _toggleMenu,
                ),
              ),

              Positioned(
                bottom: 54,
                left: centerX + centerDiameter / 2 - 90,
                width: 180,
                child: AnimatedBuilder(
                  animation: _menuCtrl,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _menuFade.value,
                      child: SizedBox(
                        height: 110,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 14,
                              bottom: 20 * _menuScale.value,
                              child: Transform.translate(
                                offset: Offset(0, 30 * (1 - _menuScale.value)),
                                child: _PopupCircle(
                                  icon: 'assets/icons/bolt.png',
                                  onTap: () => _onChoiceTap(null),
                                ),
                              ),
                            ),
                            Positioned(
                              left: (180 - 52) / 2,
                              bottom: 40 * _menuScale.value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - _menuScale.value)),
                                child: _PopupCircle(
                                  icon: 'assets/icons/punch.png',
                                  onTap: () => _onChoiceTap(() {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateSessionScreen(),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 14,
                              bottom: 20 * _menuScale.value,
                              child: Transform.translate(
                                offset: Offset(0, 30 * (1 - _menuScale.value)),
                                child: _PopupCircle(
                                  icon: 'assets/icons/spinning-wheel.png',
                                  onTap: () => _onChoiceTap(() {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const WheelScreen(),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
  final bool isMenuOpen;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CenterLogoButton({
    required this.isActive,
    required this.isMenuOpen,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_CenterLogoButton> createState() => _CenterLogoButtonState();
}

class _CenterLogoButtonState extends State<_CenterLogoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Center capsule button (painted first = lower hit-test priority) ──
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: () {
              if (!widget.isMenuOpen) {
                widget.onTap();
              }
            },
            onLongPress: widget.onLongPress,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.isMenuOpen
                          ? const Color(0xFFFF6BB5)
                          : widget.isActive
                          ? const Color(0xFFFF6BB5)
                          : const Color(0xFF9A5AB0),
                      widget.isMenuOpen
                          ? const Color(0xFF800DD8)
                          : widget.isActive
                          ? const Color(0xFF800DD8)
                          : const Color(0xFF6A3A80),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.isMenuOpen
                                  ? const Color(0xFFFE4EF0)
                                  : widget.isActive
                                  ? const Color(0xFFFE4EF0)
                                  : const Color(0xFF7A4A8A))
                              .withValues(
                                alpha: widget.isMenuOpen
                                    ? 0.6
                                    : widget.isActive
                                    ? 0.5
                                    : 0.25,
                              ),
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
                      child: AnimatedRotation(
                        turns: widget.isMenuOpen ? 0.125 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Opacity(
                          opacity: widget.isMenuOpen || widget.isActive
                              ? 1.0
                              : 0.65,
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
            ),
          ),
        ),
      ],
    );
  }
}

// ── Popup circle button ────────────────────────────────────────────────────

class _PopupCircle extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;

  const _PopupCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: Image.asset(
                icon,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.circle,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 12,
                  );
                },
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
      child: SingleChildScrollView(
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
              const SizedBox(height: 28),
              const _StackedCards(),
            ],
          ),
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
    _controller =
        AnimationController(
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
      onTap: () {
        if (_currentIndex == 4) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WheelScreen()));
        } else {
          _advance();
        }
      },
      child: AnimatedSwitcher(
        duration: _animDuration,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
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
                    colors: [Colors.transparent, Colors.black87],
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

// ── Stacked slanted cards ──────────────────────────────────────────────────

Path _slantedCardPath(Size size, double slant, double radius) {
  final w = size.width;
  final h = size.height;
  final path = Path();

  path.moveTo(radius, slant * radius / w);
  path.lineTo(w - radius, slant * (w - radius) / w);
  path.quadraticBezierTo(w, slant, w, slant + radius);
  path.lineTo(w, h + slant - radius);
  path.quadraticBezierTo(w, h + slant, w - radius, h + slant);
  path.lineTo(radius, h + slant * radius / w);
  path.quadraticBezierTo(0, h, 0, h - radius);
  path.lineTo(0, radius);
  path.quadraticBezierTo(0, 0, radius, slant * radius / w);
  path.close();
  return path;
}

class _StackedCards extends StatefulWidget {
  const _StackedCards();

  @override
  State<_StackedCards> createState() => _StackedCardsState();
}

class _StackedCardsState extends State<_StackedCards>
    with SingleTickerProviderStateMixin {
  int _userCount = 0;
  late final AnimationController _swapCtrl;
  late Animation<double> _leftOffsetX;
  late Animation<double> _leftAngle;
  late Animation<double> _rightOffsetX;
  late Animation<double> _rightAngle;
  bool _isLeftFront = true;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _fetchUserCount();

    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initAnimations();

    _swapCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isLeftFront = !_isLeftFront;
          _animating = false;
        });
      }
    });
  }

  void _initAnimations() {
    _leftOffsetX = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -60.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -60.0, end: 0.0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _swapCtrl, curve: Curves.easeInOutCubic));

    _leftAngle = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: -0.03, end: -0.78), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -0.78, end: -0.03), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _swapCtrl, curve: Curves.easeInOutCubic));

    _rightOffsetX = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 30.0, end: 90.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 90.0, end: 30.0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _swapCtrl, curve: Curves.easeInOutCubic));

    _rightAngle = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: -0.04, end: -0.78), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -0.78, end: -0.04), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _swapCtrl, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _swapCtrl.dispose();
    super.dispose();
  }

  void _onSwapTap() {
    if (_animating) return;
    _animating = true;
    _swapCtrl.forward(from: 0.0);
  }

  Future<void> _fetchUserCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .count()
        .get();
    if (mounted) {
      setState(() => _userCount = snapshot.count ?? 0);
    }
  }

  // ── Card builders ───────────────────────────────────────────────

  Widget _buildLeftCard(double slant, double cornerR, Size cardSize) {
    return ClipPath(
      clipper: _SlantedCardClipper(slant: slant, cornerRadius: cornerR),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Stack(
          children: [
            CustomPaint(
              size: cardSize,
              painter: _GlassCardPainter(slant: slant),
            ),
            Positioned(
              left: 21,
              top: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE4EF0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "LET'S WEDO",
                  style: TextStyle(
                    fontFamily: 'ArialNBI',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 21,
              top: 66,
              child: Text(
                'Make Every Choice\nMore Fun!',
                style: TextStyle(
                  fontFamily: 'ArialNBI',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
            Positioned(
              left: 21,
              top: 116,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_userCount active players',
                    style: const TextStyle(
                      fontFamily: 'ArialNBI',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 21,
              top: 138,
              right: 130,
              child: Text(
                "WeDo makes everyday decisions easier and more exciting. Whether you're choosing what to eat, what movie to watch, where to go, or what to do next, WeDo helps you decide with a little more fun and a lot less overthinking.",
                style: TextStyle(
                  fontFamily: 'ArialNBI',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4,
                ),
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              right: 15,
              top: 120,
              child: Image.asset(
                'assets/images/WeDo-Logo.png',
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.casino,
                    color: Color(0xFFFE4EF0),
                    size: 60,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightCard(double slant, double cornerR, Size cardSize) {
    return ClipPath(
      clipper: _SlantedCardClipper(slant: slant, cornerRadius: cornerR),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: CustomPaint(
          size: cardSize,
          painter: _BackGlassCardPainter(slant: slant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardW = 300.0;
    const cardH = 300.0;
    const slant = 30.0;
    const cornerR = 28.0;

    const cardSize = Size(cardW, cardH);

    return AnimatedBuilder(
      animation: _swapCtrl,
      builder: (context, _) {
        final leftOffset = _leftOffsetX.value;
        final leftAng = _leftAngle.value;
        final rightOffset = _rightOffsetX.value;
        final rightAng = _rightAngle.value;

        final leftCard = Transform.translate(
          offset: Offset(leftOffset, 0),
          child: Transform.rotate(
            angle: leftAng,
            alignment: Alignment.bottomCenter,
            child: _buildLeftCard(slant, cornerR, cardSize),
          ),
        );

        final rightCard = Transform.translate(
          offset: Offset(rightOffset, 0),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..scaleByDouble(-1.0, 1.0, 1.0, 1.0)
              ..rotateZ(rightAng),
            child: _buildRightCard(slant, cornerR, cardSize),
          ),
        );

        final frontCard = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onSwapTap,
          child: _isLeftFront ? leftCard : rightCard,
        );

        final backCard = _isLeftFront ? rightCard : leftCard;

        return SizedBox(
          width: cardW + 40,
          height: cardH + 50,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [backCard, frontCard],
          ),
        );
      },
    );
  }
}

// ── Clipper for the slanted card shape ─────────────────────────────────────

class _SlantedCardClipper extends CustomClipper<Path> {
  final double slant;
  final double cornerRadius;

  const _SlantedCardClipper({required this.slant, required this.cornerRadius});

  @override
  Path getClip(Size size) => _slantedCardPath(size, slant, cornerRadius);

  @override
  bool shouldReclip(covariant _SlantedCardClipper old) =>
      old.slant != slant || old.cornerRadius != cornerRadius;
}

// ── Glassmorphism fill painter (front card) ────────────────────────────────

class _GlassCardPainter extends CustomPainter {
  final double slant;

  const _GlassCardPainter({required this.slant});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _slantedCardPath(size, slant, 28);

    // Frosted fill: semi-transparent white
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Subtle light border
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);

    // Inner highlight along top edge
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassCardPainter old) => old.slant != slant;
}

// ── Gradient glassmorphism painter (back card) ─────────────────────────────

class _BackGlassCardPainter extends CustomPainter {
  final double slant;

  const _BackGlassCardPainter({required this.slant});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _slantedCardPath(size, slant, 28);

    // Gradient fill: #FE4EF0 → #800DD8 at 30% opacity
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x4DFE4EF0), Color(0x4D800DD8)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Subtle light border
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);

    // Inner highlight along top edge
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BackGlassCardPainter old) => old.slant != slant;
}
