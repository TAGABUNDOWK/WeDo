import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/topic_entity.dart';
import '../../services/session/session_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/topic_card.dart';
import 'waiting_lobby_screen.dart';
import 'places/places_to_go_screen.dart';
import 'places/where_to_eat_screen.dart';
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
  final _scrollController = ScrollController();

  List<TopicEntity> _topics = [];
  List<_TopicEntry> _allTopics = [];
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isAnimating = false;
  String? _error;

  final List<GlobalKey> _itemKeys = List.generate(20, (_) => GlobalKey());
  final List<double> _scaleValues = List.filled(20, 1.0);
  final List<double> _opacityValues = List.filled(20, 1.0);
  final List<double> _translateYValues = List.filled(20, 0.0);

  static const _hardcodedTopics = [
    _HardcodedTopic(
      title: 'Where should we eat?',
      iconAsset: 'assets/icons/location.png',
    ),
    _HardcodedTopic(
      title: 'Places to go',
      iconAsset: 'assets/icons/nearby.png',
    ),
    _HardcodedTopic(
      title: 'Movies to watch',
      iconAsset: 'assets/icons/cards.png',
    ),
  ];

  bool _hasPrecached = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTopics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrecached) {
      _hasPrecached = true;
      precacheImage(const AssetImage('assets/images/frame.png'), context);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
          icon: Image.asset(
            t.iconAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.casino_outlined,
              color: Color(0xFFFE4EF0),
            ),
          ),
          onTap: () => _navigateHardcoded(t.title),
        ),
      ),
      ..._topics.map(
        (t) => _TopicEntry(
          title: t.title,
          icon: Image.asset(
            _topicIconAsset(t.title),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.casino_outlined,
              color: Color(0xFFFE4EF0),
            ),
          ),
          onTap: () => _createSession(t),
        ),
      ),
    ];
  }

  String _topicIconAsset(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('eat') || lower.contains('food') || lower.contains('restaurant')) {
      return 'assets/icons/location.png';
    }
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
    if (title == 'Where should we eat?') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WhereToEatScreen()));
    } else if (title == 'Places to go') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesToGoScreen()));
    } else if (title == 'Movies to watch') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieCategoryScreen()));
    }
  }

  // ── Coverflow scroll tracking ──────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenCenter = screenHeight / 2;

    for (int i = 0; i < _allTopics.length; i++) {
      final key = _itemKeys[i];
      if (key.currentContext == null) continue;

      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final cardCenter = box.size.height / 2;
      final cardTopLeft = box.localToGlobal(Offset.zero);
      final cardCenterY = cardTopLeft.dy + cardCenter;
      final signedOffset = cardCenterY - screenCenter;
      final distance = signedOffset.abs();

      final scale = (1.0 - (distance / screenCenter) * 1.0).clamp(0.35, 1.0);
      final opacity = (1.0 - (distance / screenCenter) * 0.6).clamp(0.30, 1.0);
      final translateY = -signedOffset * 0.1;

      _scaleValues[i] = scale;
      _opacityValues[i] = opacity;
      _translateYValues[i] = translateY;
    }
    setState(() {});
  }

  // ── Tap-to-center ──────────────────────────────────────────────────────

  void _onCardTap(int index) {
    if (_isAnimating || !_scrollController.hasClients) return;

    final key = _itemKeys[index];
    if (key.currentContext == null) return;

    final box = key.currentContext!.findRenderObject() as RenderBox?;
    if (box == null) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenCenter = screenHeight / 2;
    final cardCenterY = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
    final distance = (cardCenterY - screenCenter).abs();

    if (distance <= Responsive.centerThreshold(context)) {
      _allTopics[index].onTap?.call();
    } else {
      _isAnimating = true;
      final currentOffset = _scrollController.offset;
      final delta = cardCenterY - screenCenter;
      final target = (currentOffset + delta).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          )
          .then((_) => _isAnimating = false);
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
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                _buildError()
              else if (_isCreating)
                _buildCreatingState()
              else
                _buildCoverflowList(),
              _buildAppBar(),
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

    return SafeArea(
      child: Padding(
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
      ),
    );
  }

  // ── Coverflow List ─────────────────────────────────────────────────────

  Widget _buildCoverflowList() {
    final itemCount = _allTopics.length;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        vertical: Responsive.coverflowPadding(context),
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final entry = _allTopics[index];
        final scale = _scaleValues[index];
        final opacity = _opacityValues[index];
        final translateY = _translateYValues[index];

        return Padding(
          padding: EdgeInsets.zero,
          child: Center(
            child: GestureDetector(
              onTap: () => _onCardTap(index),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: opacity,
                    child: TopicCard(
                      key: _itemKeys[index],
                      label: entry.title,
                      icon: entry.icon,
                      onTap: null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Creating / Error states ────────────────────────────────────────────

  Widget _buildCreatingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Creating PickFight...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Fetching cards and generating code',
            style: TextStyle(color: Colors.white54, fontSize: 13),
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
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadTopics();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Internal data classes ─────────────────────────────────────────────────

class _HardcodedTopic {
  final String title;
  final String iconAsset;
  const _HardcodedTopic({required this.title, required this.iconAsset});
}

class _TopicEntry {
  final String title;
  final Widget icon;
  final VoidCallback? onTap;
  const _TopicEntry({required this.title, required this.icon, this.onTap});
}
