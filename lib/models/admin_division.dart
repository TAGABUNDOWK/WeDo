class AdminDivision {
  final String name;
  final double latitude;
  final double longitude;

  const AdminDivision({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory AdminDivision.fromJson(Map<String, dynamic> json) {
    return AdminDivision(
      name: json['name'] as String? ?? '',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminDivision &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;
}
