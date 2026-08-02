import 'package:flutter/material.dart';
import '../../models/topic_entity.dart';
import '../../services/session/session_service.dart';
import 'session_game_screen.dart';
import 'places_to_go_screen.dart';
import 'where_to_eat_screen.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
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
              ? Center(
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
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      ..._topics.map((topic) => _TopicCard(
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
                      ..._hardcodedTopics.map((topic) => _TopicCard(
                            title: topic.title,
                            icon: topic.icon,
                            onTap: () {
                              if (topic.title == 'Places to go') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PlacesToGoScreen(),
                                  ),
                                );
                              } else if (topic.title == 'Where should we eat?') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WhereToEatScreen(),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Coming soon')),
                                );
                              }
                            },
                          )),
                    ],
                  ),
                ),
    );
  }
}

class _HardcodedTopic {
  final String title;
  final IconData icon;
  const _HardcodedTopic({required this.title, required this.icon});
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

  static const _bg = Color(0xFFE7ECEF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFFFFFFF),
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Color(0xFFB8C6CC),
              offset: Offset(6, 6),
              blurRadius: 12,
            ),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
