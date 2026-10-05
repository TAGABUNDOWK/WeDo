/// Data carried from the PickFight ResultsScreen through the chat target
/// picker into the existing CreateEventScreen. Pure data — no behaviour.
class EventPrefill {
  final String title;
  final String description;
  final String? location;
  final String? imageUrl;
  final String? cardType;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? placeId;
  final String? tag;
  final String? rating;
  final String? distanceSnapshot;
  final String? sessionId;

  const EventPrefill({
    required this.title,
    required this.description,
    this.location,
    this.imageUrl,
    this.cardType,
    this.latitude,
    this.longitude,
    this.address,
    this.placeId,
    this.tag,
    this.rating,
    this.distanceSnapshot,
    this.sessionId,
  });
}
