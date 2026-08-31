import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import 'tri_race_results_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class AllTriRacesScreen extends StatefulWidget {
  const AllTriRacesScreen({super.key});

  @override
  State<AllTriRacesScreen> createState() => _AllTriRacesScreenState();
}

class _AllTriRacesScreenState extends State<AllTriRacesScreen> {
  final _service = TriRaceService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  List<TriRace> _races = const [];

  @override
  void initState() {
    super.initState();
    _loadRaces();
  }

  Future<void> _loadRaces() async {
    final user = _currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final races = await _service.getUserCompletedTriRaces(user.uid, limit: 10);
      if (!mounted) return;
      setState(() {
        _races = races;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _races = const [];
        _isLoading = false;
      });
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'All TriRaces',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _currentUser == null
          ? const Center(
              child: Text('Not logged in', style: TextStyle(color: Colors.white70)),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _races.isEmpty
                  ? const Center(
                      child: Text(
                        'No completed races yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _races.length,
                      itemBuilder: (context, index) => _buildRaceCard(_races[index]),
                    ),
    );
  }

  Widget _buildRaceCard(TriRace race) {
    final isFinished = race.status == TriRaceStatus.finished;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TriRaceResultsScreen(raceId: race.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🏎️', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TriRace: ${race.joinCode}',
                    style: const TextStyle(
                      fontFamily: _fontFamily,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.people, color: Colors.white.withValues(alpha: 0.5), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${race.participantUids.length} player${race.participantUids.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _timeAgo(race.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                race.status.value,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  color: Color(0xFF4ECDC4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
