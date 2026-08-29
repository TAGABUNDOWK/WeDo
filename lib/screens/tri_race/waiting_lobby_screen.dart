import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../utils/constants.dart';
import 'race_screen.dart';
import 'tri_race_results_screen.dart';
import 'tri_race_invite_picker_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class WaitingLobbyScreen extends StatefulWidget {
  final String raceId;
  final bool isHost;

  const WaitingLobbyScreen({
    super.key,
    required this.raceId,
    required this.isHost,
  });

  @override
  State<WaitingLobbyScreen> createState() => _WaitingLobbyScreenState();
}

class _WaitingLobbyScreenState extends State<WaitingLobbyScreen> {
  final _service = TriRaceService();
  final _bg = const Color(0xFF190831);
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isConfirmingLeave = false;
  bool _cancelledDialogShown = false;
  final Map<String, String> _displayNames = {};
  final Set<String> _nameQueued = {};

  Future<void> _onPopInvoked(bool didPop, dynamic result) async {
    if (didPop || _isConfirmingLeave) return;

    _isConfirmingLeave = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text('Leave Lobby?', style: TextStyle(color: Colors.white)),
        content: Text(
          widget.isHost
              ? 'This will cancel the TriRace for all players.'
              : 'Are you sure you want to leave?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.isHost ? 'Cancel Race' : 'Leave',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        if (widget.isHost) {
          await _service.cancelTriRace(widget.raceId, _currentUser!.uid);
        } else {
          await _service.removeParticipant(widget.raceId, _currentUser!.uid);
        }
      } catch (_) {}

      if (mounted) Navigator.of(context).pop();
    }

    _isConfirmingLeave = false;
  }

  void _showCancelledDialog() {
    if (!mounted || _cancelledDialogShown) return;
    _cancelledDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        title: const Text('Race Cancelled', style: TextStyle(color: Colors.white)),
        content: const Text(
          'The host cancelled the TriRace.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4ECDC4))),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // Resolve real profile display names (users/{id}.display_name) once per uid
  // so gmail fallbacks never show in the lobby grid.
  void _resolveNames(List<TriRaceParticipant> participants) {
    final missing = participants
        .map((p) => p.userId)
        .where((id) => !_nameQueued.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _nameQueued.addAll(missing);
    _service.fetchDisplayNames(missing).then((names) {
      if (!mounted) return;
      setState(() => _displayNames.addAll(names));
    });
  }

  String _participantName(TriRaceParticipant p) =>
      _displayNames[p.userId] ?? p.username;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onPopInvoked(false, null),
          ),
          title: const Text(
            'TriRace Lobby',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        body: StreamBuilder<TriRace?>(
          stream: _service.getTriRaceStream(widget.raceId),
          builder: (context, raceSnapshot) {
            if (raceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final race = raceSnapshot.data;
            if (race == null) {
              return const Center(child: Text('Race not found', style: TextStyle(color: Colors.white)));
            }

            if (race.status == TriRaceStatus.cancelled) {
              if (!widget.isHost) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _showCancelledDialog());
              }
              return const Center(
                child: Text('Race was cancelled', style: TextStyle(color: Colors.white)),
              );
            }

            if (race.status == TriRaceStatus.started) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RaceScreen(raceId: widget.raceId, isHost: widget.isHost),
                  ),
                );
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (race.status == TriRaceStatus.finished) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TriRaceResultsScreen(raceId: widget.raceId),
                  ),
                );
              });
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<TriRaceParticipant>>(
              stream: _service.getParticipantsStream(widget.raceId),
              builder: (context, participantSnapshot) {
                final participants = participantSnapshot.data ?? [];
                _resolveNames(participants);

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Join Code ──
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: race.joinCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Code "${race.joinCode}" copied!'),
                                backgroundColor: const Color(0xFF4ECDC4),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              const Text(
                                'Share this code with friends',
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      race.joinCode,
                                      style: const TextStyle(
                                        fontFamily: _fontFamily,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 6,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.copy_rounded,
                                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${participants.length}/${race.maxPlayers} players',
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Participants Grid ──
                      const Text(
                        'Players',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: race.maxPlayers,
                          itemBuilder: (context, index) {
                            if (index < participants.length) {
                              final p = participants[index];
                              final isMe = p.userId == _currentUser?.uid;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(p.avatarColor.replaceFirst('#', '0xFF')),
                                      ),
                                      shape: BoxShape.circle,
                                      border: isMe
                                          ? Border.all(color: Colors.white, width: 2)
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _participantName(p).isNotEmpty
                                          ? _participantName(p)[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontFamily: _fontFamily,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isMe ? '${_participantName(p)} (you)' : _participantName(p),
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              );
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.glassBorder,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Empty',
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 10,
                                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // ── Action Buttons ──
                      if (widget.isHost) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TriRaceInvitePickerScreen(raceId: widget.raceId),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_outlined, size: 18),
                            label: const Text(
                              'Invite Friends',
                              style: TextStyle(fontFamily: _fontFamily, fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4ECDC4),
                              side: const BorderSide(color: Color(0xFF4ECDC4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: participants.length < race.maxPlayers
                                ? () async {
                                    try {
                                      await _service.addBot(widget.raceId);
                                    } on TriRaceException catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.message),
                                            backgroundColor: const Color(0xFFEF5350),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.smart_toy_outlined, size: 18),
                            label: const Text(
                              'Add Bot',
                              style: TextStyle(fontFamily: _fontFamily, fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDDA0DD),
                              side: const BorderSide(color: Color(0xFFDDA0DD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: participants.length >= 2
                                ? () async {
                                    try {
                                      await _service.startTriRace(widget.raceId, _currentUser!.uid);
                                    } on TriRaceException catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.message),
                                            backgroundColor: const Color(0xFFEF5350),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              participants.length < 2
                                  ? 'Need ${2 - participants.length} more player${2 - participants.length == 1 ? '' : 's'}'
                                  : 'Start TriRace',
                              style: const TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Waiting for host to start...',
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
