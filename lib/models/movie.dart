import '../utils/constants.dart';

class Movie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;

  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    required this.voteAverage,
    required this.releaseDate,
    required this.genreIds,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] as String? ?? '',
      genreIds: (json['genre_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  String? get posterUrl =>
      posterPath != null ? '${AppConstants.tmdbImageBaseUrl}$posterPath' : null;

  String get releaseYear =>
      releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';

  String get formattedRating => voteAverage.toStringAsFixed(1);
}
