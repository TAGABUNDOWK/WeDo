import 'package:flutter/material.dart';
import '../../models/topic_entity.dart';
import '../../services/session/session_service.dart';
import 'create_session_screen.dart';
import 'join_session_screen.dart';
import 'session_game_screen.dart';
import 'places_to_go_screen.dart';
import 'where_to_eat_screen.dart';
import 'movie_category_screen.dart';

class SessionEntryScreen extends StatefulWidget {
  const SessionEntryScreen({super.key});

  @override
  State<SessionEntryScreen> createState() => _SessionEntryScreenState();
}

class _SessionEntryScreenState extends State<SessionEntryScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFFE7ECEF);

  List<TopicEntity> _topics = [];
  bool _isLoading = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Sessions',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCreateButton(),
                      const SizedBox(height: 12),
                      _buildJoinButton(),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Solo Play'),
                      const SizedBox(height: 4),
                      _buildSoloTopicGrid(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateSessionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF2A6FD6),
              offset: Offset(0, 6),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Host a game with friends',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JoinSessionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 12),
            BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(6, 6), blurRadius: 12),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.login, color: Colors.blue, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enter a session code to join',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSoloTopicGrid() {
    final allTopics = [
      ..._topics.map((topic) => _SoloTopic(
            title: topic.title,
            icon: Icons.casino_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionGameScreen(
                    topicId: topic.id,
                    topicTitle: topic.title,
                  ),
                ),
              );
            },
          )),
      ..._hardcodedTopics.map((topic) => _SoloTopic(
            title: topic.title,
            icon: topic.icon,
            onTap: () {
              if (topic.title == 'Places to go') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesToGoScreen()));
              } else if (topic.title == 'Where should we eat?') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WhereToEatScreen()));
              } else if (topic.title == 'Movies to watch') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieCategoryScreen()));
              }
            },
          )),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: allTopics
          .map((topic) => _TopicCard(title: topic.title, icon: topic.icon, onTap: topic.onTap))
          .toList(),
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

class _SoloTopic {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _SoloTopic({required this.title, required this.icon, required this.onTap});
}

class _TopicCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _TopicCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE7ECEF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 12),
            BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(6, 6), blurRadius: 12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.blue),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
