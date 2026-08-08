import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session/session_service.dart';
import 'results_screen.dart';

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

class _SwipingScreenState extends State<SwipingScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFFE7ECEF);
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

  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _remainingCards = List<Map<String, dynamic>>.from(widget.cards);
    _gameStartTime = DateTime.now();
    _startRound();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
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
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) {
          timer.cancel();
          _onTimeout();
        }
      });
    });
  }

  void _eliminateCard(int eliminateIndex, int survivorIndex) {
    if (_gameFinished || _isAnimating) return;
    _roundTimer?.cancel();
    setState(() => _isAnimating = true);

    final eliminatedCard = _remainingCards[eliminateIndex];
    _eliminatedCardIds.add(eliminatedCard['id'] as String);
    _survivorId = _remainingCards[survivorIndex]['id'] as String;

    Future.delayed(const Duration(milliseconds: 350), () {
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
      });

      _startRound();
    });
  }

  void _onTimeout() {
    if (_gameFinished) return;
    _timeoutCount++;

    final eliminateTop = DateTime.now().millisecond % 2 == 0;
    if (eliminateTop) {
      _eliminateCard(_championIndex, _deckIndex);
    } else {
      _eliminateCard(_deckIndex, _championIndex);
    }
  }

  void _onSwipeUp() {
    _eliminateCard(_deckIndex, _championIndex);
  }

  void _onSwipeDown() {
    _eliminateCard(_championIndex, _deckIndex);
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
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Round $_round / $totalRounds',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildTimer(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            _buildProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              '$cardsLeft elimination${cardsLeft == 1 ? '' : 's'} left',
              style: const TextStyle(color: Colors.black38, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < 0) {
                      _onSwipeUp();
                    } else {
                      _onSwipeDown();
                    }
                  }
                },
                child: Column(
                  children: [
                    Expanded(
                      child: _buildGameCard(
                        card: championCard,
                        label: 'Swipe ↓ to eliminate',
                        isChampion: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVsBadge(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildGameCard(
                        card: challengerCard,
                        label: 'Swipe ↑ to eliminate',
                        isChampion: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Timeouts: $_timeoutCount',
              style: TextStyle(
                color: _timeoutCount > 0 ? Colors.redAccent : Colors.black38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    final isWarning = _timeRemaining <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning ? Colors.redAccent : Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$_timeRemaining s',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalRounds = widget.cards.length - 1;
    final progress = totalRounds > 0 ? _round / totalRounds : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: Colors.black12,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }

  Widget _buildVsBadge() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required Map<String, dynamic> card,
    required String label,
    required bool isChampion,
  }) {
    final color = isChampion ? Colors.blue.shade50 : Colors.orange.shade50;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isAnimating ? 0.3 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10),
            BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(4, 4), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isChampion) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CHAMPION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                isChampion ? Icons.emoji_events : Icons.casino_outlined,
                size: 28,
                color: isChampion ? Colors.amber : Colors.blue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              card['title'] as String? ?? 'Card',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (card['description'] != null &&
                (card['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                card['description'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isChampion ? Colors.blue : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
