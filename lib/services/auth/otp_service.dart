import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpService {
  final String _baseUrl = 'https://wedo-api.vercel.app';

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['error'] ?? 'Request failed (${response.statusCode})';
    } catch (_) {
      if (response.statusCode == 404) {
        return 'API endpoint not found. Please check the server configuration.';
      }
      return 'Server error (${response.statusCode}). Please try again later.';
    }
  }

  Future<void> generateOTP(String userId, String email, {bool resend = false}) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/generate-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'email': email, 'resend': resend}),
        )
        .timeout(const Duration(seconds: 20));

    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Failed to send OTP (${response.statusCode})');
    }
  }

  Future<void> verifyOTP(String userId, String code) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/verify-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'code': code}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }
}
