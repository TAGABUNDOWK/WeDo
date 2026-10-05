import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/topic_entity.dart';
import '../../services/session/session_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/topic_card.dart';
import 'waiting_lobby_screen.dart';
import 'places/places_to_go_screen.dart';
import 'movie/movie_category_screen.dart';
import 'create_own_topic_screen.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _service = SessionService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late final PageController _pageController;

  List<TopicEntity> _topics = [];
  List<_TopicEntry> _allTopics = [];
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  int _currentPage = 0;

  static const _hardcodedTopics = [
    _HardcodedTopic(
      title: 'Random Challenge',
      iconAsset: 'assets/icons/bolt.png',
      description: 'Get a surprise challenge and see what you get!',
      buttonText: 'START CHALLENGE',
    ),
    _HardcodedTopic(
      title: 'Nearby Go to Places',
      iconAsset: 'assets/icons/nearby.png',
      description: 'Discover fun spots, hangouts, and exciting activities nearby.',
      buttonText: 'EXPLORE PLACES',
    ),
    _HardcodedTopic(
      title: 'Movies to watch',
      iconAsset: 'assets/icons/cards.png',
      description: 'Settle the movie night debate and find the ultimate watch.',
      buttonText: 'PICK MOVIES',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
    _loadTopics();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _service.getTopics();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _buildAllTopics();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createSession(TopicEntity topic) async {
    if (_currentUser == null || _isCreating) return;

    setState(() => _isCreating = true);

    try {
      final allCards = await _service.getCards(topic.id);
      final picked = _service.pickRandomCards(allCards);

      final cardMaps = picked
          .map((c) => {
                'id': c.id,
                'title': c.name,
                'description': '',
              })
          .toList();

      final code = await _service.createSession(
        hostId: _currentUser.uid,
        topic: topic.title,
        cards: cardMaps,
      );

      await _service.joinSession(
        sessionId: code,
        userId: _currentUser.uid,
        userName: _currentUser.displayName ?? _currentUser.email ?? 'Host',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(sessionId: code, isHost: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ── Combined topic list ────────────────────────────────────────────────

  void _buildAllTopics() {
    _allTopics = [
      ..._hardcodedTopics.map(
        (t) => _TopicEntry(
          title: t.title,
          description: t.description,
          buttonText: t.buttonText,
          icon: Image.asset(
            t.iconAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.casino_outlined,
              color: Color(0xFFFE4EF0),
              size: 32,
            ),
          ),
          onTap: () => _navigateHardcoded(t.title),
        ),
      ),
      ..._topics.map(
        (t) => _TopicEntry(
          title: t.title,
          description: (t.description != null && t.description!.isNotEmpty)
              ? t.description!
              : _topicDefaultDescription(t.title),
          buttonText: 'START PICKFIGHT',
          icon: Image.asset(
            _topicIconAsset(t.title),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.casino_outlined,
              color: Color(0xFFFE4EF0),
              size: 32,
            ),
          ),
          onTap: () => _createSession(t),
        ),
      ),
    ];
  }

  String _topicDefaultDescription(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('eat') || lower.contains('food') || lower.contains('restaurant')) {
      return 'Swipe through tasty spots and decide what to eat together!';
    }
    if (lower.contains('movie') || lower.contains('watch') || lower.contains('film')) {
      return 'Settle the debate and find the best film to stream.';
    }
    if (lower.contains('place') || lower.contains('go') || lower.contains('visit')) {
      return 'Discover top hangouts and pick the ultimate destination.';
    }
    if (lower.contains('game') || lower.contains('play')) {
      return 'Vote on the next game to play with your squad.';
    }
    return 'Swipe and eliminate cards together to decide the winning choice!';
  }

  String _topicIconAsset(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('place') || lower.contains('go') || lower.contains('visit')) {
      return 'assets/icons/nearby.png';
    }
    if (lower.contains('movie') || lower.contains('watch')) {
      return 'assets/icons/cards.png';
    }
    if (lower.contains('random') || lower.contains('challenge')) {
      return 'assets/icons/bolt.png';
    }
    return 'assets/icons/decision.png';
  }

  void _navigateHardcoded(String title) {
    if (title == 'Random Challenge') {
      _handleRandomChallenge();
    } else if (title == 'Nearby Go to Places') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesToGoScreen()));
    } else if (title == 'Movies to watch') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieCategoryScreen()));
    }
  }

  Future<void> _handleRandomChallenge() async {
    if (_topics.isNotEmpty) {
      final randomTopic = (List<TopicEntity>.from(_topics)..shuffle()).first;
      await _createSession(randomTopic);
    } else {
      final options = ['Nearby Go to Places', 'Movies to watch']..shuffle();
      _navigateHardcoded(options.first);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: SafeArea(
          child: Stack(
            children: [
              // Cosmic background ear overlay
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

              // Main layout
              Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? _buildError()
                            : _isCreating
                                ? _buildCreatingState()
                                : _buildMainContent(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Custom App Bar ─────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final iconSize = Responsive.appBarIconSize(context);
    final logoW = Responsive.logoWidth(context);
    final s = Responsive.scale(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: (56 - iconSize) / 2,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image.asset(
                  'assets/icons/back-nav.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.arrow_back,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: iconSize,
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/WeDo-Logo.png',
                    width: logoW,
                    height: logoW,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.casino,
                      color: const Color(0xFFFE4EF0),
                      size: logoW,
                    ),
                  ),
                  SizedBox(width: 8 * s),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                    ).createShader(bounds),
                    child: Text(
                      'WeDo',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: (26 * s).clamp(14.0, 26.0),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: (56 - iconSize) / 2,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateOwnTopicScreen(),
                    ),
                  );
                },
                child: Image.asset(
                  'assets/icons/create-topic.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.edit,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: iconSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Content Area ─────────────────────────────────────────────────

  Widget _buildMainContent() {
    final itemCount = _allTopics.length;
    if (itemCount == 0) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 6),
        _buildHeaderPrompt(),
        const SizedBox(height: 10),
        Expanded(
          child: _buildHorizontalTopics(),
        ),
        const SizedBox(height: 10),
        _buildDotIndicators(itemCount),
        const SizedBox(height: 18),
        _buildInviteBanner(),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── Header prompt with celestial decorations ──────────────────────────

  Widget _buildHeaderPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _PlanetDecoration(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'What topic',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    children: [
                      TextSpan(
                        text: 'are we ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'talking about?',
                        style: TextStyle(color: Color(0xFFFE4EF0)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: _SparkleDecoration(),
          ),
        ],
      ),
    );
  }

  // ── Horizontal Page View ──────────────────────────────────────────────

  Widget _buildHorizontalTopics() {
    final itemCount = _allTopics.length;
    final cardW = Responsive.cardWidth(context);
    final cardH = Responsive.cardHeight(context);

    return PageView.builder(
      controller: _pageController,
      itemCount: itemCount,
      onPageChanged: (i) => setState(() => _currentPage = i),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final entry = _allTopics[index];
        return Center(
          child: TopicCard(
            label: entry.title,
            description: entry.description,
            icon: entry.icon,
            buttonText: entry.buttonText,
            onTap: () => entry.onTap?.call(),
            width: cardW,
            height: cardH,
          ),
        );
      },
    );
  }

  Widget _buildDotIndicators(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFE4EF0)
                : Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ── Invite Friends Banner ─────────────────────────────────────────────

  Widget _buildInviteBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.40),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.18),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/friends.png',
                width: 24,
                height: 24,
                color: const Color(0xFFFE4EF0),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.people_outline,
                  color: Color(0xFFFE4EF0),
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    "Don't forget to invite your friends!",
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'The more, the merrier.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Creating / Error states ────────────────────────────────────────────

  Widget _buildCreatingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFE4EF0)),
          ),
          SizedBox(height: 20),
          Text(
            'Creating PickFight...',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fetching cards and generating code',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadTopics();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE4EF0),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Decorative Celestial Widgets ──────────────────────────────────────────

class _PlanetDecoration extends StatelessWidget {
  const _PlanetDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(
        painter: _PlanetPainter(),
      ),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.28;

    final ringPaint = Paint()
      ..color = const Color(0xFFC742FF).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.45); // ~26 deg tilt

    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 3.4,
      height: radius * 0.95,
    );

    // Glow for ring
    final glowPaint = Paint()
      ..color = const Color(0xFFFE4EF0).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(ringRect, glowPaint);
    canvas.drawOval(ringRect, ringPaint);

    // Planet body
    final planetPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFFE056FD), Color(0xFF680BA6), Color(0xFF320857)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

    canvas.drawCircle(Offset.zero, radius, planetPaint);

    // Front half of ring
    final frontRingPath = Path()..addArc(ringRect, 0, 3.14159);
    canvas.drawPath(frontRingPath, ringPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparkleDecoration extends StatelessWidget {
  const _SparkleDecoration();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Color(0xFFF3A6FF),
        size: 18,
      ),
    );
  }
}

// ── Internal data classes ─────────────────────────────────────────────────

class _HardcodedTopic {
  final String title;
  final String iconAsset;
  final String description;
  final String buttonText;

  const _HardcodedTopic({
    required this.title,
    required this.iconAsset,
    required this.description,
    required this.buttonText,
  });
}

class _TopicEntry {
  final String title;
  final String description;
  final String buttonText;
  final Widget icon;
  final VoidCallback? onTap;

  const _TopicEntry({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.icon,
    this.onTap,
  });
}
