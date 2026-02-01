import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';

import '../config/api_config.dart';

class AuthException implements Exception {
  final String message;
  final String? code;
  final dynamic data;

  AuthException(this.message, {this.code, this.data});

  @override
  String toString() => message;
}

class AuthService {
  static const String baseUrl = '${ApiConfig.baseUrl}/auth';

  Map<String, String> _getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent':
          'ManagementApp/1.0 (${Platform.operatingSystem}; ${Platform.operatingSystemVersion})',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<AuthResponse> signInWithGoogle(
    String? idToken, {
    bool force = false,
    int? terminateSessionId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/google'),
      headers: _getHeaders(),
      body: jsonEncode({
        'idToken': idToken,
        'force': force,
        'terminateSessionId': terminateSessionId,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _saveToken(authResponse.token);
      await _saveUserId(authResponse.user['id']);
      return authResponse;
    } else {
      final body = jsonDecode(response.body);
      throw AuthException(
        body['message'],
        code: body['code'],
        // sessions takes precedence for MAX_SESSIONS_EXCEEDED
        data: body['sessions'] ?? body['session'],
      );
    }
  }

  Future<AuthResponse> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _saveToken(authResponse.token);
      await _saveUserId(authResponse.user['id']);
      return authResponse;
    } else {
      final body = jsonDecode(response.body);
      throw AuthException(
        body['message'],
        code: body['code'],
        data: body['sessions'] ?? body['session'],
      );
    }
  }

  Future<AuthResponse> login(
    String email,
    String password, {
    bool force = false,
    int? terminateSessionId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _getHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'force': force,
        'terminateSessionId': terminateSessionId,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _saveToken(authResponse.token);
      await _saveUserId(authResponse.user['id']);
      return authResponse;
    } else {
      final body = jsonDecode(response.body);
      throw AuthException(
        body['message'],
        code: body['code'],
        data: body['sessions'] ?? body['session'],
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: _getHeaders(token: token),
        );
      } catch (e) {
        print('Logout error: $e');
      }
    }
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> _saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', id);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }
}
