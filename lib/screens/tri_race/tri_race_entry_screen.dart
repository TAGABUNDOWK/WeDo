import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../services/tri_race/tri_race_refresh_notifier.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_background.dart';
import 'create_tri_race_screen.dart';
import 'waiting_lobby_screen.dart';
import 'tri_race_results_screen.dart';
import 'all_tri_races_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class TriRaceEntryScreen extends StatefulWidget {
  const TriRaceEntryScreen({super.key});

  @override
  State<TriRaceEntryScreen> createState() => _TriRaceEntryScreenState();
}

class _TriRaceEntryScreenState extends State<TriRaceEntryScreen> {
  final _service = TriRaceService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool _isJoining = false;
  String? _error;
  List<TriRace> _recentRaces = const [];
  late final StreamSubscription<void> _refreshSub;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _refreshSub = TriRaceRefreshNotifier.instance.onRefresh.listen((_) {
      if (mounted) _loadSessions();
    });
  }

  Future<void> _loadSessions() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final races = await _service.getUserCompletedTriRaces(user.uid, limit: 3);
      if (!mounted) return;
      setState(() {
        _recentRaces = races;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentRaces = const [];
      });
    }
  }

  @override
  void dispose() {
    _refreshSub.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Future<void> _joinRace() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final race = await _service.validateJoinCode(code);
      final user = _currentUser;
      if (user == null) return;

      final displayName = user.displayName ?? user.email ?? 'Player';
      await _service.joinTriRace(
        raceId: race.id,
        userId: user.uid,
        userName: displayName,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(raceId: race.id, isHost: false),
        ),
      );
    } on TriRaceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: const Color(0xFF190831),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'TriRace',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: AnimatedBackground(
        showStars: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Race to the finish, triangle style!',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Create Card ──
                _GlassCard(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateTriRaceScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create a TriRace',
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Start a new race and invite friends',
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Join Card ──
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Join a TriRace',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              focusNode: _codeFocusNode,
                              style: const TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                hintText: 'ENTER CODE',
                                hintStyle: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 14,
                                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                                  letterSpacing: 2,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.glassBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.glassBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _isJoining ? null : _joinRace,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isJoining
                                      ? [Colors.grey, Colors.grey]
                                      : [const Color(0xFF4ECDC4), const Color(0xFF45B7D1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _isJoining
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Join',
                                      style: TextStyle(
                                        fontFamily: _fontFamily,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 13,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── How it works ──
                const Text(
                  'How it works',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _HowItWorkStep(number: '1', title: 'Create or Join', subtitle: 'Start a race or enter a 6-digit code'),
                const SizedBox(height: 8),
                _HowItWorkStep(number: '2', title: 'Invite Friends', subtitle: 'Share the code or send invites via chat'),
                const SizedBox(height: 8),
                _HowItWorkStep(number: '3', title: 'Race!', subtitle: 'Watch your triangles race to the finish'),
                const SizedBox(height: 24),

                // ── Recent Races ──
                if (_recentRaces.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Races',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_recentRaces.length >= 3)
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllTriRacesScreen(),
                              ),
                            );
                            _loadSessions();
                          },
                          child: const Text(
                            'View all',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 13,
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._recentRaces.map((race) => _RecentRaceCard(
                    race: race,
                    timeAgo: _timeAgo(race.createdAt),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TriRaceResultsScreen(raceId: race.id),
                        ),
                      );
                    },
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: child,
    );
  }
}

class _HowItWorkStep extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  const _HowItWorkStep({required this.number, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4ECDC4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentRaceCard extends StatelessWidget {
  final TriRace race;
  final String timeAgo;
  final VoidCallback onTap;
  const _RecentRaceCard({required this.race, required this.timeAgo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 1),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${race.participantUids.length} players • $timeAgo',
                    style: const TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                race.status.value,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4ECDC4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
