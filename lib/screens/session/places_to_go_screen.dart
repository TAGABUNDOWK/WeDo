import 'package:flutter/material.dart';
import '../../services/location/overpass_service.dart';
import 'nearby_places_screen.dart';
import 'province_picker_screen.dart';

class PlacesToGoScreen extends StatelessWidget {
  const PlacesToGoScreen({super.key});

  static const _bg = Color(0xFF190831);

  static const _categories = [
    _CategoryData(
      title: 'Shopping',
      subtitle: 'Malls, clothing, electronics & more',
      icon: Icons.store,
      category: PlaceCategory.shopping,
    ),
    _CategoryData(
      title: 'Nature & Outdoors',
      subtitle: 'Parks, gardens, viewpoints',
      icon: Icons.park,
      category: PlaceCategory.natureOutdoors,
    ),
    _CategoryData(
      title: 'Entertainment',
      subtitle: 'Cinema, arcade, karaoke',
      icon: Icons.movie,
      category: PlaceCategory.entertainment,
    ),
    _CategoryData(
      title: 'Sports & Fitness',
      subtitle: 'Gym, sports center, skatepark',
      icon: Icons.fitness_center,
      category: PlaceCategory.sportsFitness,
    ),
    _CategoryData(
      title: 'Outing',
      subtitle: 'Resorts, beaches, pool, camp',
      icon: Icons.beach_access,
      category: PlaceCategory.outing,
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
          'Places to go',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: _categories.map((cat) {
            return _CategoryCard(
              icon: cat.icon,
              title: cat.title,
              subtitle: cat.subtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _NearbyOrCityScreen(category: cat.category),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final PlaceCategory category;

  const _CategoryData({
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyOrCityScreen extends StatelessWidget {
  final PlaceCategory category;

  const _NearbyOrCityScreen({required this.category});

  static const _bg = Color(0xFF190831);

  String get _categoryTitle {
    switch (category) {
      case PlaceCategory.shopping:
        return 'Shopping';
      case PlaceCategory.natureOutdoors:
        return 'Nature & Outdoors';
      case PlaceCategory.entertainment:
        return 'Entertainment';
      case PlaceCategory.sportsFitness:
        return 'Sports & Fitness';
      case PlaceCategory.outing:
        return 'Outing';
      case PlaceCategory.food:
        return 'Food & Drinks';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OptionCard(
              icon: Icons.near_me,
              title: 'Places nearby',
              subtitle: 'Find spots within 5km of you',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NearbyPlacesScreen(
                      title: _categoryTitle,
                      category: category,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.location_city,
              title: 'Specify a city',
              subtitle: 'Choose a province, then city to explore',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProvincePickerScreen(category: category),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
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
