import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/topic_entity.dart';
import '../../services/session/session_service.dart';
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
  final _bg = const Color(0xFF190831);
  final _currentUser = FirebaseAuth.instance.currentUser;

  List<TopicEntity> _topics = [];
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;

  static const _hardcodedTopics = [
    _HardcodedTopic(title: 'Where should we eat?', icon: Icons.restaurant),
    _HardcodedTopic(title: 'Places to go', icon: Icons.location_on),
    _HardcodedTopic(title: 'Movies to watch', icon: Icons.movie),
  ];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _service.getTopics();
      if (!mounted) return;
      setState(() {
        _topics = topics;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Choose a Topic',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOwnTopicScreen()));
            },
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _isCreating
                  ? _buildCreatingState()
                  : _buildTopicGrid(),
    );
  }

  Widget _buildTopicGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ..._topics.map((topic) {
            return GestureDetector(
              onTap: () => _createSession(topic),
              child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.casino_outlined, size: 28, color: Color(0xFFFE4EF0)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      topic.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }),
          ..._hardcodedTopics.map((topic) {
            return GestureDetector(
              onTap: () {
                if (topic.title == 'Where should we eat?') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WhereToEatScreen()));
                } else if (topic.title == 'Places to go') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesToGoScreen()));
                } else if (topic.title == 'Movies to watch') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieCategoryScreen()));
                }
              },
              child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(topic.icon, size: 28, color: const Color(0xFFFE4EF0)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      topic.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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
          Text(
            'Creating session...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
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

class _HardcodedTopic {
  final String title;
  final IconData icon;
  const _HardcodedTopic({required this.title, required this.icon});
}
