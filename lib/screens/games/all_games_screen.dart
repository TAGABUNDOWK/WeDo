import 'package:flutter/material.dart';
import '../../widgets/animated_background.dart';
import '../session/session_entry_screen.dart';
import '../../features/spin_wheel/screens/wheel_screen.dart';
import '../tri_race/tri_race_entry_screen.dart';

const _fontFamily = 'PlusJakartaSans';

// -----------------------------------------------------------------------------

class _GameData {
  final String title;
  final String imagePath;
  final String category;
  final IconData categoryIcon;
  final String mode;
  final String shortDescription;
  final String instructions;
  final Widget Function(BuildContext) screenBuilder;

  const _GameData({
    required this.title,
    required this.imagePath,
    required this.category,
    required this.categoryIcon,
    required this.mode,
    required this.shortDescription,
    required this.instructions,
    required this.screenBuilder,
  });
}

final _games = [
  const _GameData(
    title: 'PickFight',
    imagePath: 'assets/images/Flashcards.png',
    category: 'CARD',
    categoryIcon: Icons.style_rounded,
    mode: 'ONLINE',
    shortDescription: 'Swipe to eliminate choices together.',
    instructions:
        'Two choices face off on screen. Swipe up to eliminate the bottom card, '
        'or swipe down to eliminate the top card. Keep swiping through the '
        'choices together until one final pick remains.',
    screenBuilder: _pickFightBuilder,
  ),
  const _GameData(
    title: 'Wheel',
    imagePath: 'assets/images/SpinWheel.png',
    category: 'LUCK',
    categoryIcon: Icons.star_rounded,
    mode: 'LOCAL ONLY',
    shortDescription: 'Spin to choose one of your options.',
    instructions:
        'Add the choices you are deciding between, then spin the wheel. It lands '
        'on one of your options at random to help your group make a decision.',
    screenBuilder: _wheelBuilder,
  ),
  const _GameData(
    title: 'TriRace',
    imagePath: 'assets/images/TriRace.png',
    category: 'RACING',
    categoryIcon: Icons.emoji_events_rounded,
    mode: 'ONLINE',
    shortDescription: 'Race with friends and reach the finish.',
    instructions:
        'Invite friends and watch each racer compete automatically across the '
        'track. The first racer to reach the finish line wins.',
    screenBuilder: _triRaceBuilder,
  ),
];

Widget _pickFightBuilder(BuildContext context) => const SessionEntryScreen();
Widget _wheelBuilder(BuildContext context) => const WheelScreen();
Widget _triRaceBuilder(BuildContext context) => const TriRaceEntryScreen();

// -----------------------------------------------------------------------------

class AllGamesScreen extends StatefulWidget {
  const AllGamesScreen({super.key});

  @override
  State<AllGamesScreen> createState() => _AllGamesScreenState();
}

class _AllGamesScreenState extends State<AllGamesScreen> {
  String _filter = 'ALL GAMES';

  List<_GameData> get _visibleGames => _games
      .where((game) => _filter == 'ALL GAMES' || game.mode == _filter)
      .toList();

  @override
  Widget build(BuildContext context) {
    final games = _visibleGames;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_esports_rounded, color: Color(0xFFD35BFF), size: 19),
                        const SizedBox(width: 8),
                        Container(width: 2, height: 18, color: const Color(0xFFB567FF)),
                        const SizedBox(width: 9),
                        const Text(
                          'PLAY & HAVE FUN',
                          style: TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.5, color: Color(0xFFD58AFF)),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          initialValue: _filter,
                          tooltip: 'Filter games',
                          color: const Color(0xFF281747),
                          onSelected: (value) => setState(() => _filter = value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'ALL GAMES', child: Text('All Games', style: TextStyle(color: Colors.white))),
                            PopupMenuItem(value: 'ONLINE', child: Text('Online', style: TextStyle(color: Colors.white))),
                            PopupMenuItem(value: 'LOCAL ONLY', child: Text('Local Only', style: TextStyle(color: Colors.white))),
                          ],
                          child: const _HeaderActionButton(icon: Icons.tune_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ALL GAMES',
                      style: TextStyle(fontFamily: _fontFamily, fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(colors: [Color(0xFFFF59E7), Color(0xFF783CFF)]),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Explore our games that make deciding more fun and intense.',
                      style: TextStyle(fontFamily: _fontFamily, fontSize: 12, height: 1.4, color: Colors.white.withValues(alpha: 0.70)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: games.isEmpty
                      ? Center(
                          child: Text(
                            'No games in this filter.',
                            style: TextStyle(fontFamily: _fontFamily, color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        )
                      : GridView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      return _GameCard(
                        data: games[index],
                        onTap: () => _showGameDetailPopup(
                          context,
                          games[index],
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

// -----------------------------------------------------------------------------

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;

  const _HeaderActionButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB778FF).withValues(alpha: 0.42)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final _GameData data;
  final VoidCallback onTap;

  const _GameCard({required this.data, required this.onTap});

  Color get _accent => switch (data.category) {
        'CARD' => const Color(0xFFFE4EF0),
        'LUCK' => const Color(0xFF437CFF),
        _ => const Color(0xFF26D7D1),
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF271247), Color(0xFF180B35)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withValues(alpha: 0.7), width: 1),
          boxShadow: [
            BoxShadow(color: _accent.withValues(alpha: 0.10), blurRadius: 16),
          ],
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
                        child: const Icon(Icons.gamepad, color: Colors.white24, size: 40),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _accent.withValues(alpha: 0.75)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(data.categoryIcon, color: _accent, size: 13),
                            const SizedBox(width: 5),
                            Text(data.category, style: TextStyle(fontFamily: _fontFamily, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _accent)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                                  const SizedBox(height: 3),
                                  Text(data.shortDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10, height: 1.3, color: Colors.white.withValues(alpha: 0.72))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF7029D8).withValues(alpha: 0.32),
                                border: Border.all(color: const Color(0xFF974BFF).withValues(alpha: 0.6)),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                fontWeight: FontWeight.w500,
                color: Colors.white,
                decoration: TextDecoration.none,
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
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                decoration: TextDecoration.none,
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
                                decoration: TextDecoration.none,
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
fontWeight: FontWeight.w700,
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
