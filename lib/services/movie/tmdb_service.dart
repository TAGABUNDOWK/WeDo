import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/movie.dart';
import '../../utils/constants.dart';

class TmdbService {
  final String _proxyUrl = AppConstants.tmdbProxyUrl;

  static const _genreIds = {
    'horror': 27,
    'drama': 18,
    'animation': 16,
    'romance': 10749,
  };

  Future<List<Movie>> getMovies(String category) async {
    final uri = _buildUri(category);
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results
        .take(10)
        .map((json) => Movie.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Uri _buildUri(String category) {
    if (category == 'trending_day' || category == 'trending_week') {
      final timeWindow = category == 'trending_day' ? 'day' : 'week';
      return Uri.parse(_proxyUrl).replace(queryParameters: {
        'path': 'trending/movie/$timeWindow',
        'language': 'en-US',
      });
    }

    final genreId = _genreIds[category];
    if (genreId == null) {
      throw Exception('Unknown category: $category');
    }

    return Uri.parse(_proxyUrl).replace(queryParameters: {
      'path': 'discover/movie',
      'with_genres': genreId.toString(),
      'sort_by': 'popularity.desc',
      'vote_count.gte': '50',
      'language': 'en-US',
      'page': '1',
    });
  }

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['status_message'] ?? 'Request failed (${response.statusCode})';
    } catch (_) {
      return 'TMDB API error (${response.statusCode})';
    }
  }
}
