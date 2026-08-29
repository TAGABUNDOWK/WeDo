import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../utils/constants.dart';
import 'waiting_lobby_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class CreateTriRaceScreen extends StatefulWidget {
  const CreateTriRaceScreen({super.key});

  @override
  State<CreateTriRaceScreen> createState() => _CreateTriRaceScreenState();
}

class _CreateTriRaceScreenState extends State<CreateTriRaceScreen> {
  final _service = TriRaceService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  int _maxPlayers = 4;
  bool _isCreating = false;

  Future<void> _createRace() async {
    final user = _currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);

    try {
      final joinCode = await _service.createTriRace(
        hostId: user.uid,
        hostName: user.displayName ?? user.email ?? 'Player',
        maxPlayers: _maxPlayers,
      );

      await _service.joinTriRace(
        raceId: joinCode,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Player',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(raceId: joinCode, isHost: true),
        ),
      );
    } on TriRaceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFEF5350)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong'), backgroundColor: Color(0xFFEF5350)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
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
          'Create TriRace',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Max Players',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (i) {
                  final count = i + 2;
                  final isSelected = count == _maxPlayers;
                  return GestureDetector(
                    onTap: () => setState(() => _maxPlayers = count),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4ECDC4)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4ECDC4)
                              : AppColors.glassBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_maxPlayers players max',
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createRace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create Race',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
