/// OpenStreetMap tag filter used to build Overpass fallback queries.
class OsmTagFilter {
  final String key;
  final String values;

  const OsmTagFilter(this.key, this.values);
}

/// PickFight place categories — single source of truth for the display
/// label, the Google Places API (New) `includedTypes` values (Table A of
/// Place Types), and the OSM tag filters used by the free Overpass
/// fallback.
enum PlaceCategory {
  mall(
    'Mall',
    [OsmTagFilter('shop', 'mall|department_store')],
    ['shopping_mall', 'department_store'],
  ),
  natureOutdoor(
    'Nature & Outdoor',
    [
      OsmTagFilter('leisure', 'park|garden|nature_reserve'),
      OsmTagFilter('tourism', 'viewpoint'),
    ],
    ['park', 'garden', 'botanical_garden', 'nature_preserve', 'scenic_spot'],
  ),
  karaoke(
    'Karaoke',
    [OsmTagFilter('amenity', 'karaoke')],
    ['karaoke'],
  ),
  fastFood(
    'FastFood',
    [OsmTagFilter('amenity', 'fast_food')],
    ['fast_food_restaurant', 'hamburger_restaurant', 'meal_takeaway'],
  ),
  restaurant(
    'Restaurant',
    [OsmTagFilter('amenity', 'restaurant')],
    ['restaurant'],
  ),
  pool(
    'Pool',
    [OsmTagFilter('leisure', 'swimming_pool')],
    ['swimming_pool', 'water_park'],
  ),
  hotel(
    'Hotel',
    [OsmTagFilter('tourism', 'hotel|motel|hostel|guest_house')],
    ['hotel', 'motel', 'hostel', 'resort_hotel'],
  ),
  cafe(
    'Cafe',
    [OsmTagFilter('amenity', 'cafe')],
    ['cafe', 'coffee_shop'],
  ),
  gym(
    'Gym',
    [OsmTagFilter('leisure', 'fitness_centre')],
    ['fitness_center'],
  ),
  bar(
    'Bar',
    [OsmTagFilter('amenity', 'bar|pub')],
    ['bar', 'pub', 'cocktail_bar'],
  ),
  sports(
    'Sports',
    [OsmTagFilter('leisure', 'sports_centre|stadium')],
    [
      'sports_club',
      'stadium',
      'sports_complex',
      'sports_activity_location',
      'arena',
    ],
  ),
  salon(
    'Salon',
    [OsmTagFilter('shop', 'hairdresser|beauty')],
    ['hair_care', 'hair_salon', 'beauty_salon', 'barber_shop', 'nail_salon'],
  );

  const PlaceCategory(this.label, this.osmTags, this.googleTypes);

  final String label;
  final List<OsmTagFilter> osmTags;
  final List<String> googleTypes;
}
