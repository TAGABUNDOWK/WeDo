import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place_entity.dart';

/// Lightweight transfer object for the place detail sheet — built either
/// from a full [PlaceEntity] (list screens) or from a card map stored in
/// Firestore (swipe cards).
class PlaceDetailData {
  final String title;
  final String tag;
  final String summary;
  final String rating;
  final String distance;
  final String? address;
  final String? coverUrl;
  final double? latitude;
  final double? longitude;
  final String? placeId;

  const PlaceDetailData({
    required this.title,
    required this.tag,
    required this.summary,
    required this.rating,
    required this.distance,
    this.address,
    this.coverUrl,
    this.latitude,
    this.longitude,
    this.placeId,
  });

  factory PlaceDetailData.fromPlace(PlaceEntity p) => PlaceDetailData(
        title: p.name,
        tag: PlaceEntity.friendlyAmenity(p.amenity),
        summary: p.summary ?? '',
        rating: p.ratingLabel,
        distance: p.formattedDistance,
        address: p.address,
        coverUrl: p.coverUrl,
        latitude: p.latitude,
        longitude: p.longitude,
        placeId: p.id.isEmpty ? null : p.id,
      );

  factory PlaceDetailData.fromCard(Map<String, dynamic> card) {
    final tag = card['tag'] as String? ?? '';
    final cover = card['posterUrl'] as String?;
    final address = card['address'] as String?;
    final id = card['id'] as String? ?? '';
    return PlaceDetailData(
      title: card['title'] as String? ?? 'Place',
      tag: tag.isEmpty ? '' : PlaceEntity.friendlyAmenity(tag),
      summary: card['description'] as String? ?? '',
      rating: card['rating'] as String? ?? '',
      distance: card['distance'] as String? ?? '',
      address: (address == null || address.isEmpty) ? null : address,
      coverUrl: (cover == null || cover.isEmpty) ? null : cover,
      latitude: (card['latitude'] as num?)?.toDouble(),
      longitude: (card['longitude'] as num?)?.toDouble(),
      placeId: id.isEmpty ? null : id,
    );
  }

  Uri? get mapsUri {
    if (placeId != null) {
      return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query_place_id=$placeId');
    }
    if (latitude != null && longitude != null) {
      return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    }
    return null;
  }
}

Future<void> showPlaceDetailSheet(BuildContext context, PlaceDetailData data) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PlaceDetailSheet(data: data),
  );
}

class PlaceDetailSheet extends StatelessWidget {
  final PlaceDetailData data;

  const PlaceDetailSheet({super.key, required this.data});

  static const _bg = Color(0xFF190831);
  static const _accent = Color(0xFFFE4EF0);

  @override
  Widget build(BuildContext context) {
    final mapsUri = data.mapsUri;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _CoverHeader(data: data),
              const SizedBox(height: 16),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (data.tag.isNotEmpty)
                    _chip(label: data.tag, color: _accent),
                  if (data.rating.isNotEmpty)
                    _chip(
                      label: data.rating,
                      color: const Color(0xFFFFD54F),
                      icon: Icons.star_rounded,
                    ),
                  if (data.distance.isNotEmpty)
                    _chip(label: data.distance, color: Colors.white70),
                ],
              ),
              if (data.address != null && data.address!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.address!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
              if (data.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  data.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
              if (mapsUri != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        launchUrl(mapsUri, mode: LaunchMode.externalApplication),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text(
                      'Open in Google Maps',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: icon != null ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  final PlaceDetailData data;

  const _CoverHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final url = data.coverUrl;
    return GestureDetector(
      onTap: url == null ? null : () => _openFullscreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: 200,
          child: url == null
              ? Container(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: const Icon(Icons.place_rounded,
                      size: 56, color: Colors.white24),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          color: Colors.white.withValues(alpha: 0.06),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _accentLoader),
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const Icon(Icons.place_rounded,
                        size: 56, color: Colors.white24),
                  ),
                ),
        ),
      ),
    );
  }

  static const _accentLoader = Color(0xFFFE4EF0);

  void _openFullscreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullscreenPhoto(url: url)),
    );
  }
}

class _FullscreenPhoto extends StatelessWidget {
  final String url;

  const _FullscreenPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
