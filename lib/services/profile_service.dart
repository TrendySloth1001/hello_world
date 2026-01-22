import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ProfileService {
  static const String baseUrl = '${ApiConfig.baseUrl}/profile';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to load profile',
      );
    }
  }

  Future<Map<String, dynamic>> updateAvatar(String avatarUrl) async {
    final response = await http.put(
      Uri.parse('$baseUrl/avatar'),
      headers: await _getHeaders(),
      body: jsonEncode({'avatarUrl': avatarUrl}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to update avatar',
      );
    }
  }

  Future<List<String>> getAvatarPresets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/avatars'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['avatars']);
    } else {
      throw Exception('Failed to load avatars');
    }
  }
}
