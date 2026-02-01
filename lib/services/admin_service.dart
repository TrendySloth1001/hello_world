import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class AdminService {
  static const String baseUrl = '${ApiConfig.baseUrl}/admin';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/stats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getActivityLogs({
    int page = 1,
    int? userId,
    int limit = 20,
  }) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/logs?page=$page&limit=$limit';
    if (userId != null) {
      url += '&userId=$userId';
    }

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load logs: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getUsers({int page = 1}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/users?page=$page&limit=20'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Defensive coding: Handle both List (legacy) and Map (new with pagination)
      if (decoded is List) {
        return {
          'users': decoded,
          'pagination': {'page': 1, 'pages': 1, 'total': decoded.length},
        };
      } else if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw Exception('Unexpected response format');
      } // Now always returns {users: [], pagination: {}}
    } else {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
  }
}
