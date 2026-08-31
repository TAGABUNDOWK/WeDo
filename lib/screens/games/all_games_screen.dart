import 'package:flutter/material.dart';
import '../../widgets/animated_background.dart';
import '../session/session_entry_screen.dart';
import '../../features/spin_wheel/screens/wheel_screen.dart';
import '../tri_race/tri_race_entry_screen.dart';

const _fontFamily = 'PlusJakartaSans';

// ── Game data model ─────────────────────────────────────────────────────────

class _GameData {
  final String title;
  final String imagePath;
  final String instructions;
  final Widget Function(BuildContext) screenBuilder;

  const _GameData({
    required this.title,
    required this.imagePath,
    required this.instructions,
    required this.screenBuilder,
  });
}

final _games = [
  _GameData(
    title: 'PickFight',
    imagePath: 'assets/images/Flashcards.png',
    instructions:
        'Compete head-to-head by swiping through flashcards. Each round, both players '
        'pick their favorite card. The card with the most votes wins the round. '
        'The player who wins the most rounds takes the victory!',
    screenBuilder: _pickFightBuilder,
  ),
  _GameData(
    title: 'Wheel',
    imagePath: 'assets/images/SpinWheel.png',
    instructions:
        'Add your options to the wheel and give it a spin! The wheel will randomly '
        'select one option. Great for making group decisions when you can\'t agree — '
        'let fate decide!',
    screenBuilder: _wheelBuilder,
  ),
  _GameData(
    title: 'TriRace',
    imagePath: 'assets/images/TriRace.png',
    instructions:
        'Race against your friends in a triangular track! Each player controls a '
        'racer and competes to reach the finish line first. Fastest reaction wins!',
    screenBuilder: _triRaceBuilder,
  ),
];

Widget _pickFightBuilder(BuildContext context) => const SessionEntryScreen();
Widget _wheelBuilder(BuildContext context) => const WheelScreen();
Widget _triRaceBuilder(BuildContext context) => const TriRaceEntryScreen();

// ── All Games Screen ────────────────────────────────────────────────────────

class AllGamesScreen extends StatelessWidget {
  const AllGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'ALL GAMES',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _games.length,
                    itemBuilder: (context, index) {
                      return _GameCard(
                        data: _games[index],
                        onTap: () => _showGameDetailPopup(
                          context,
                          _games[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Card ───────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final _GameData data;
  final VoidCallback onTap;

  const _GameCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    data.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF1A1025),
                        child: const Icon(
                          Icons.gamepad,
                          color: Colors.white24,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Detail Popup ───────────────────────────────────────────────────────

void _showGameDetailPopup(BuildContext context, _GameData game) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Game detail',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _GameDetailPopupContent(game: game);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: child,
        ),
      );
    },
  );
}

class _GameDetailPopupContent extends StatelessWidget {
  final _GameData game;

  const _GameDetailPopupContent({required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              game.title,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1233),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button + image
                    Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 180,
                          child: Image.asset(
                            game.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF1A1025),
                                child: const Icon(
                                  Icons.gamepad,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    // Instructions
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Game instructions:',
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              game.instructions,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    // PLAY button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: game.screenBuilder,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFE4EF0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'PLAY',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
