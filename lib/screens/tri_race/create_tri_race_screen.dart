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
  String _colorTheme = 'solid';
  bool _isCreating = false;

  static const _solidPalette = [
    '#FF4444', '#3366FF', '#33AA33', '#FF8800',
    '#9933FF', '#FFD700', '#FF3399', '#00BBDD',
  ];

  static const _neonPalette = [
    '#00FFFF', '#FF00FF', '#39FF14', '#FFFF00',
    '#FF6600', '#FF1493', '#BF00FF', '#FF0733',
  ];

  Color _hexColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));

  Future<void> _createRace() async {
    final user = _currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);

    try {
      final joinCode = await _service.createTriRace(
        hostId: user.uid,
        hostName: user.displayName ?? user.email ?? 'Player',
        maxPlayers: _maxPlayers,
        colorTheme: _colorTheme,
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
            _sectionLabel(Icons.people_alt_rounded, 'Max Players'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (i) {
                  final count = i + 2;
                  final isSelected = count == _maxPlayers;
                  return GestureDetector(
                    onTap: () => setState(() => _maxPlayers = count),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF23C9C1)
                            : const Color(0xFF21143A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF23C9C1)
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: const Color(0xFF23C9C1).withValues(alpha: 0.20), blurRadius: 12)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'TriRace supports up to 8 players',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.48),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(Icons.palette_outlined, 'Color Theme'),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildThemeOption(
                  label: 'Solid',
                  subtitle: 'Clean & vibrant colors',
                  isSelected: _colorTheme == 'solid',
                  onTap: () => setState(() => _colorTheme = 'solid'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _solidPalette.map((hex) {
                      return Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: _hexColor(hex),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                _buildThemeOption(
                  label: 'Neon',
                  subtitle: 'Glowing neon effect',
                  isSelected: _colorTheme == 'neon',
                  onTap: () => setState(() => _colorTheme = 'neon'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _neonPalette.map((hex) {
                      final color = _hexColor(hex);
                      return Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.7),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF21143A).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF4ECDC4), size: 23),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How TriRace works', style: TextStyle(fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 7),
                        Text(
                          'TriRace supports up to 8 players. Set your player limit above, then watch racers compete automatically to the finish.',
                          style: TextStyle(fontFamily: _fontFamily, fontSize: 12, height: 1.5, color: Colors.white.withValues(alpha: 0.68)),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD290FF), size: 15),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _buildThemeOption({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 17),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4ECDC4).withValues(alpha: 0.11)
              : const Color(0xFF21143A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4ECDC4)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? const Color(0xFF4ECDC4) : Colors.white))),
                if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 16),
              ],
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontFamily: _fontFamily, fontSize: 9, color: Colors.white.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    ));
  }
}
