import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session/session_service.dart';
import 'results_screen.dart';
import 'round_result_screen.dart';

class SwipingScreen extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>> cards;

  const SwipingScreen({
    super.key,
    required this.sessionId,
    required this.cards,
  });

  @override
  State<SwipingScreen> createState() => _SwipingScreenState();
}

class _SwipingScreenState extends State<SwipingScreen>
    with TickerProviderStateMixin {
  final _service = SessionService();
  final _bg = const Color(0xFF190831);
  final _currentUser = FirebaseAuth.instance.currentUser;

  late List<Map<String, dynamic>> _remainingCards;
  int _championIndex = 0;
  int _deckIndex = 1;
  int _round = 0;
  int _timeoutCount = 0;
  final List<String> _eliminatedCardIds = [];
  String? _survivorId;

  Timer? _roundTimer;
  int _timeRemaining = 15;
  bool _gameFinished = false;
  DateTime? _gameStartTime;

  // Swipe animation state
  late AnimationController _flyOffController;
  late AnimationController _springController;
  late AnimationController _pulseController;
  Offset _dragOffset = Offset.zero;
  bool _isAnimating = false;
  bool _showEliminationOverlay = false;

  static const double _swipeThreshold = 120.0;
  static const double _maxRotation = 0.15; // ~8.6 degrees

  @override
  void initState() {
    super.initState();
    _remainingCards = List<Map<String, dynamic>>.from(widget.cards);
    _gameStartTime = DateTime.now();
    _flyOffController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _flyOffController.dispose();
    _springController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRound() {
    if (_remainingCards.length <= 1 || _gameFinished) {
      _finishGame();
      return;
    }

    if (_deckIndex >= _remainingCards.length) {
      _finishGame();
      return;
    }

    _timeRemaining = 15;
    _pulseController.stop();
    _pulseController.reset();
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 5 && _timeRemaining > 0) {
          _pulseController.repeat(reverse: true);
        }
        if (_timeRemaining <= 0) {
          _pulseController.stop();
          timer.cancel();
          _onTimeout();
        }
      });
    });
  }

  void _eliminateCard(int eliminateIndex, int survivorIndex) {
    if (_gameFinished || _isAnimating) return;
    _roundTimer?.cancel();
    setState(() {
      _isAnimating = true;
      _showEliminationOverlay = true;
    });

    final eliminatedCard = _remainingCards[eliminateIndex];
    _eliminatedCardIds.add(eliminatedCard['id'] as String);
    _survivorId = _remainingCards[survivorIndex]['id'] as String;

    // Fly-off animation
    _flyOffController.forward(from: 0).then((_) {
      if (!mounted) return;

      setState(() {
        _remainingCards.removeAt(eliminateIndex);

        if (eliminateIndex < _championIndex) {
          _championIndex--;
        } else if (eliminateIndex == _championIndex) {
          _championIndex = survivorIndex > eliminateIndex
              ? survivorIndex - 1
              : survivorIndex;
        }

        _deckIndex = _championIndex + 1;
        if (_deckIndex >= _remainingCards.length) {
          _deckIndex = 0;
          _championIndex = 0;
        }

        _round++;
        _isAnimating = false;
        _showEliminationOverlay = false;
        _dragOffset = Offset.zero;
      });

      _showRoundResult(
        survivor: _remainingCards.isNotEmpty
            ? _remainingCards[_championIndex > 0 ? _championIndex : 0]
            : eliminatedCard,
        eliminated: eliminatedCard,
      );
    });
  }

  void _showRoundResult({
    required Map<String, dynamic> survivor,
    required Map<String, dynamic> eliminated,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoundResultScreen(
          survivor: survivor,
          eliminated: eliminated,
          round: _round,
          totalRounds: widget.cards.length - 1,
        ),
      ),
    ).then((_) {
      if (mounted && !_gameFinished) {
        _startRound();
      }
    });
  }

  void _onTimeout() {
    if (_gameFinished) return;
    _timeoutCount++;

    // Deterministic: always eliminate the challenger (bottom card)
    _eliminateCard(_deckIndex, _championIndex);
  }

  void _onSwipeUp() {
    _eliminateCard(_deckIndex, _championIndex);
  }

  void _onSwipeDown() {
    _eliminateCard(_championIndex, _deckIndex);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final dy = _dragOffset.dy;
    final velocity = details.primaryVelocity ?? 0;

    // Commit if dragged past threshold or released with sufficient velocity
    if (dy.abs() > _swipeThreshold || velocity.abs() > 500) {
      if (dy < 0 || velocity < -500) {
        // Swiped up → eliminate bottom card (challenger)
        _onSwipeUp();
      } else {
        // Swiped down → eliminate top card (champion)
        _onSwipeDown();
      }
    } else {
      // Spring back
      _springBack();
    }
  }

  void _springBack() {
    final startOffset = _dragOffset;
    final anim = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.elasticOut,
    ));

    _springController.forward(from: 0).then((_) {
      if (mounted) setState(() => _dragOffset = Offset.zero);
    });

    _springController.addListener(() {
      if (mounted) {
        setState(() => _dragOffset = anim.value);
      }
    });
  }

  Future<void> _finishGame() async {
    if (_gameFinished) return;
    _gameFinished = true;
    _roundTimer?.cancel();

    final elapsed = DateTime.now().difference(_gameStartTime!).inMilliseconds;
    final winnerId = _remainingCards.isNotEmpty
        ? _remainingCards.first['id'] as String
        : _survivorId ?? '';

    if (_currentUser != null) {
      try {
        await _service.updateParticipantResult(
          sessionId: widget.sessionId,
          userId: _currentUser.uid,
          elapsedTimeMs: elapsed,
          chosenWinnerCardId: winnerId,
          eliminatedCardIds: _eliminatedCardIds,
          timeoutCount: _timeoutCount,
        );

        await _service.aggregateResults(widget.sessionId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving result: $e')),
          );
        }
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(sessionId: widget.sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingCards.length <= 1 || _gameFinished) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_deckIndex >= _remainingCards.length) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final championCard = _remainingCards[_championIndex];
    final challengerCard = _remainingCards[_deckIndex];
    final totalRounds = widget.cards.length - 1;
    final cardsLeft = _remainingCards.length - 1;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(totalRounds),
            _buildProgressIndicator(totalRounds),
            const SizedBox(height: 8),
            Text(
              '$cardsLeft elimination${cardsLeft == 1 ? '' : 's'} to go',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackHeight = constraints.maxHeight;
                  return GestureDetector(
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildDraggableCard(
                          card: challengerCard,
                          isTop: false,
                          offset: _dragOffset,
                          stackHeight: stackHeight,
                        ),
                        _buildStaticCard(
                          card: championCard,
                          isTop: true,
                          stackHeight: stackHeight,
                        ),
                        _buildVsMarker(stackHeight: stackHeight),
                        if (_showEliminationOverlay)
                          _buildEliminationOverlay(),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalRounds) {
    final isWarning = _timeRemaining <= 5;
    final isCritical = _timeRemaining <= 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Round indicator
          Expanded(
            child: Text(
              'ROUND ${_round + 1} / $totalRounds',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Timer
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isCritical
                  ? Colors.redAccent
                  : isWarning
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFF2D5AA0),
              borderRadius: BorderRadius.circular(10),
              boxShadow: isWarning
                  ? [
                      BoxShadow(
                        color: (isCritical ? Colors.redAccent : const Color(0xFFFF6B35))
                            .withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: _pulseController.value * 2,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: isCritical ? 18 : 15,
              ),
              child: Text('$_timeRemaining s'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int totalRounds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(totalRounds, (index) {
          final isCompleted = index < _round;
          final isCurrent = index == _round;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF4CAF50)
                    : isCurrent
                        ? const Color(0xFF2196F3)
                        : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStaticCard({
    required Map<String, dynamic> card,
    required bool isTop,
    required double stackHeight,
  }) {
    final swipeDown = _dragOffset.dy > 0 ? _dragOffset.dy : 0.0;
    final dragFraction = (swipeDown / _swipeThreshold).clamp(0.0, 1.0);
    final showCommitHint = swipeDown > _swipeThreshold * 0.6;
    const halfGap = 20.0;

    return AnimatedPositioned(
      duration: _isAnimating ? Duration.zero : const Duration(milliseconds: 50),
      top: swipeDown,
      left: 20,
      right: 20,
      bottom: stackHeight / 2 + halfGap - swipeDown,
      child: Transform.rotate(
        angle: -dragFraction * _maxRotation,
        child: _buildCardContent(
          card: card,
          isTop: isTop,
          offset: Offset(0, swipeDown),
          showCommitHint: showCommitHint,
        ),
      ),
    );
  }

  Widget _buildDraggableCard({
    required Map<String, dynamic> card,
    required bool isTop,
    required Offset offset,
    required double stackHeight,
  }) {
    final swipeUp = offset.dy < 0 ? offset.dy : 0.0;
    final dragFraction = (swipeUp / _swipeThreshold).clamp(-1.0, 0.0);
    final rotation = dragFraction * _maxRotation;
    final showCommitHint = swipeUp.abs() > _swipeThreshold * 0.6;
    const halfGap = 20.0;

    return AnimatedPositioned(
      duration: _isAnimating ? Duration.zero : const Duration(milliseconds: 50),
      top: stackHeight / 2 + halfGap + swipeUp,
      left: 20,
      right: 20,
      bottom: -swipeUp,
      child: Transform.rotate(
        angle: rotation,
        child: _buildCardContent(
          card: card,
          isTop: isTop,
          offset: offset,
          showCommitHint: showCommitHint,
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required Map<String, dynamic> card,
    required bool isTop,
    required Offset offset,
    bool showCommitHint = false,
  }) {
    final accentColor = isTop
        ? const Color(0xFF1A6B5A) // Teal for top
        : const Color(0xFF6B2D5A); // Mauve for bottom
    final accentGlow = isTop
        ? const Color(0xFF00E5A0)
        : const Color(0xFFFE4EF0);
    final isPlaceCard = card.containsKey('tag');
    final isMovieCard = card.containsKey('posterUrl') &&
        (card['posterUrl'] as String? ?? '').isNotEmpty;
    final emoji = card['emoji'] as String? ?? '';
    final title = card['title'] as String? ?? 'Card';
    final description = card['description'] as String? ?? '';
    final distance = card['distance'] as String? ?? '';

    // ELIMINATE label intensification
    final eliminateIntensity = (offset.dy.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final eliminateOpacity = isTop
        ? (offset.dy > 0 ? eliminateIntensity : 0.0)
        : (offset.dy < 0 ? eliminateIntensity : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: showCommitHint
              ? accentGlow.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: showCommitHint ? 2 : 1,
        ),
        boxShadow: showCommitHint
            ? [
                BoxShadow(
                  color: accentGlow.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: isMovieCard
          ? _buildMovieCardContent(
              card: card,
              title: title,
              description: description,
              isTop: isTop,
              eliminateOpacity: eliminateOpacity,
              accentGlow: accentGlow,
            )
          : _buildTextCardContent(
              title: title,
              description: description,
              distance: distance,
              emoji: emoji,
              isPlaceCard: isPlaceCard,
              isTop: isTop,
              eliminateOpacity: eliminateOpacity,
              accentGlow: accentGlow,
            ),
    );
  }

  Widget _buildTextCardContent({
    required String title,
    required String description,
    required String distance,
    required String emoji,
    required bool isPlaceCard,
    required bool isTop,
    required double eliminateOpacity,
    required Color accentGlow,
  }) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            color: Colors.black.withValues(alpha: 0.15),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (emoji.isNotEmpty)
                      Text(emoji, style: const TextStyle(fontSize: 48))
                    else
                      Icon(
                        isPlaceCard ? Icons.place_rounded : Icons.style_rounded,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (distance.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          distance,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 6),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: eliminateOpacity > 0 ? eliminateOpacity : 0.7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 100),
                        style: TextStyle(
                          fontSize: eliminateOpacity > 0.5 ? 13 : 11,
                          fontWeight: FontWeight.w700,
                          color: eliminateOpacity > 0.5
                              ? accentGlow
                              : Colors.white54,
                          letterSpacing: 1,
                        ),
                        child: Text(
                          isTop ? '↑ ELIMINATE' : '↓ ELIMINATE',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCardContent({
    required Map<String, dynamic> card,
    required String title,
    required String description,
    required bool isTop,
    required double eliminateOpacity,
    required Color accentGlow,
  }) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _buildMovieArt(card),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 6),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: eliminateOpacity > 0 ? eliminateOpacity : 0.7,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 100),
                        style: TextStyle(
                          fontSize: eliminateOpacity > 0.5 ? 13 : 11,
                          fontWeight: FontWeight.w700,
                          color: eliminateOpacity > 0.5
                              ? accentGlow
                              : Colors.white54,
                          letterSpacing: 1,
                        ),
                        child: Text(
                          isTop ? '↑ ELIMINATE' : '↓ ELIMINATE',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieArt(Map<String, dynamic> card) {
    final posterUrl = card['posterUrl'] as String? ?? '';
    final rating = card['rating'] as String? ?? '';
    final year = card['year'] as String? ?? '';

    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl.isNotEmpty)
            Image.network(
              posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 48),
              ),
            )
          else
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 48),
            ),
          // Gradient overlay at bottom for text legibility
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  if (rating.isNotEmpty) ...[
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      rating,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  if (year.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      year,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsMarker({required double stackHeight}) {
    return Positioned(
      top: stackHeight / 2 - 17,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'VS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEliminationOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'ELIMINATED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
