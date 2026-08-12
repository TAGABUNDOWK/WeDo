import 'package:flutter/material.dart';
import 'movie_results_screen.dart';

class MovieCategoryScreen extends StatelessWidget {
  const MovieCategoryScreen({super.key});

  static const _bg = Color(0xFF190831);

  static const _categories = [
    _Category(
      title: 'Trending Today',
      subtitle: 'Top trending movies right now',
      icon: Icons.trending_up,
      category: 'trending_day',
    ),
    _Category(
      title: 'Trending This Week',
      subtitle: 'Most popular movies this week',
      icon: Icons.date_range,
      category: 'trending_week',
    ),
    _Category(
      title: 'Horror',
      subtitle: 'Scariest trending horror films',
      icon: Icons.bolt,
      category: 'horror',
    ),
    _Category(
      title: 'Drama',
      subtitle: 'Top trending dramas',
      icon: Icons.theater_comedy,
      category: 'drama',
    ),
    _Category(
      title: 'Animation',
      subtitle: 'Best animated movies trending',
      icon: Icons.animation,
      category: 'animation',
    ),
    _Category(
      title: 'Romance',
      subtitle: 'Trending romance films',
      icon: Icons.favorite,
      category: 'romance',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Movies to watch',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return _CategoryCard(
            icon: cat.icon,
            title: cat.title,
            subtitle: cat.subtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieResultsScreen(
                    category: cat.category,
                    title: cat.title,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Category {
  final String title;
  final String subtitle;
  final IconData icon;
  final String category;

  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
  });
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: const Color(0xFFFE4EF0)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.54)),
          ],
        ),
      ),
    );
  }
}
