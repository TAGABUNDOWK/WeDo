import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session/session_service.dart';
import 'waiting_lobby_screen.dart';

class CreateOwnTopicScreen extends StatefulWidget {
  const CreateOwnTopicScreen({super.key});

  @override
  State<CreateOwnTopicScreen> createState() => _CreateOwnTopicScreenState();
}

class _CreateOwnTopicScreenState extends State<CreateOwnTopicScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFF190831);
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _topicController = TextEditingController();

  final List<_CardEntry> _cards = [
    _CardEntry(),
    _CardEntry(),
  ];

  bool _isCreating = false;

  static const int _minCards = 2;
  static const int _maxCards = 10;

  bool get _canSubmit {
    if (_topicController.text.trim().isEmpty) return false;
    if (_cards.length < _minCards || _cards.length > _maxCards) return false;
    return _cards.every((c) => c.titleController.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _topicController.dispose();
    for (final c in _cards) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCard() {
    if (_cards.length >= _maxCards) return;
    setState(() => _cards.add(_CardEntry()));
  }

  void _removeCard(int index) {
    if (_cards.length <= _minCards) return;
    setState(() {
      _cards[index].dispose();
      _cards.removeAt(index);
    });
  }

  Future<void> _startSession() async {
    if (!_canSubmit || _currentUser == null || _isCreating) return;

    setState(() => _isCreating = true);

    try {
      final cardMaps = <Map<String, dynamic>>[];
      for (int i = 0; i < _cards.length; i++) {
        final c = _cards[i];
        cardMaps.add({
          'id': 'custom_$i',
          'title': c.titleController.text.trim(),
          'description': c.descController.text.trim(),
        });
      }

      final code = await _service.createSession(
        hostId: _currentUser.uid,
        topic: _topicController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Create Your Own Topic',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: _isCreating
          ? _buildCreatingState()
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopicField(),
                    const SizedBox(height: 28),
                    _buildCardsHeader(),
                    const SizedBox(height: 12),
                    _buildCardsList(),
                    const SizedBox(height: 16),
                    if (_cards.length < _maxCards) _buildAddCardButton(),
                    const SizedBox(height: 32),
                    _buildStartButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopicField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topic',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'What should players decide on?',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _topicController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Best weekend activity?',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFE4EF0),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardsHeader() {
    return Row(
      children: [
        const Text(
          'Cards',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_cards.length}/$_maxCards',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _cards.length < _minCards
                  ? Colors.redAccent
                  : Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildCardEntry(index),
    );
  }

  Widget _buildCardEntry(int index) {
    final card = _cards[index];
    final canRemove = _cards.length > _minCards;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFE4EF0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: card.titleController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Card title *',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFFE4EF0),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeCard(index),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: card.descController,
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'Description (optional)',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCardButton() {
    return GestureDetector(
      onTap: _addCard,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              'Add Card (${_cards.length}/$_maxCards)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final enabled = _canSubmit && !_isCreating;
    return GestureDetector(
      onTap: enabled ? _startSession : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                    const Color(0xFF800DD8).withValues(alpha: 0.4),
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            enabled
                ? 'Start Session (${_cards.length} card${_cards.length == 1 ? '' : 's'})'
                : _topicController.text.trim().isEmpty
                    ? 'Enter a topic to continue'
                    : _cards.length < _minCards
                        ? 'Add at least $_minCards cards'
                        : 'Start Session',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Creating session...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up ${_cards.length} custom cards',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CardEntry {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  void dispose() {
    titleController.dispose();
    descController.dispose();
  }
}
