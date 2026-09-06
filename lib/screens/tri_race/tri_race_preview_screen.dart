import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../utils/constants.dart';
import 'waiting_lobby_screen.dart';
import 'tri_race_results_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class TriRacePreviewScreen extends StatefulWidget {
  final String raceId;
  const TriRacePreviewScreen({super.key, required this.raceId});

  @override
  State<TriRacePreviewScreen> createState() => _TriRacePreviewScreenState();
}

class _TriRacePreviewScreenState extends State<TriRacePreviewScreen> {
  final _service = TriRaceService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: const Color(0xFF190831),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<TriRace?>(
        stream: _service.getTriRaceStream(widget.raceId),
        builder: (context, raceSnapshot) {
          if (raceSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final race = raceSnapshot.data;

          if (race == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('Race not found', style: TextStyle(color: Colors.white54, fontFamily: _fontFamily)),
                ],
              ),
            );
          }

          if (race.status == TriRaceStatus.cancelled) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, color: Color(0xFFEF5350), size: 48),
                  SizedBox(height: 12),
                  Text('Race was cancelled', style: TextStyle(color: Color(0xFFEF5350), fontFamily: _fontFamily)),
                ],
              ),
            );
          }

          if (race.status == TriRaceStatus.finished) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏁', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Race ended',
                    style: TextStyle(color: Colors.white, fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TriRaceResultsScreen(raceId: widget.raceId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View Results', style: TextStyle(fontFamily: _fontFamily, color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          if (race.status == TriRaceStatus.started) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(height: 12),
                  Text(
                    'Race in progress...',
                    style: TextStyle(color: Colors.white54, fontFamily: _fontFamily),
                  ),
                ],
              ),
            );
          }

          // Status is lobby
          final isParticipant = race.participantUids.contains(_currentUser?.uid);
          if (isParticipant) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => WaitingLobbyScreen(raceId: widget.raceId, isHost: race.hostId == _currentUser?.uid),
                ),
              );
            });
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<TriRaceParticipant>>(
            stream: _service.getParticipantsStream(widget.raceId),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('🏎️', style: TextStyle(fontSize: 36))),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'TriRace',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${participants.length}/${race.maxPlayers} players',
                      style: const TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        race.joinCode,
                        style: const TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final user = _currentUser;
                          if (user == null) return;
                          try {
                            await _service.joinTriRace(
                              raceId: widget.raceId,
                              userId: user.uid,
                              userName: user.displayName ?? user.email ?? 'Player',
                            );
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WaitingLobbyScreen(
                                    raceId: widget.raceId,
                                    isHost: false,
                                  ),
                                ),
                              );
                            }
                          } on TriRaceException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFEF5350)),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Join TriRace',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: _fontFamily, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
