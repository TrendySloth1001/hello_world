import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Service for handling HTTP requests with automatic token validation
/// and logout on token expiration
class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  // Callback for when user needs to be logged out
  static Function()? onUnauthorized;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Handles HTTP response and checks for token expiration
  Future<T> handleResponse<T>(
    http.Response response,
    T Function(dynamic) parser,
  ) async {
    // Check for unauthorized (401) - token expired or invalid
    if (response.statusCode == 401) {
      await _handleUnauthorized();
      throw Exception('Session expired. Please login again.');
    }

    // Check for success status codes
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return parser(data);
    }

    // Handle other error codes
    final errorMessage = _extractErrorMessage(response);
    throw Exception(errorMessage);
  }

  /// Handles unauthorized access - logs user out and navigates to login
  Future<void> _handleUnauthorized() async {
    // Clear stored credentials
    final authService = AuthService();
    await authService.logout();

    // Trigger logout callback (navigates to login screen)
    if (onUnauthorized != null) {
      onUnauthorized!();
    }
  }

  /// Extracts error message from response
  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ??
          'Request failed with status ${response.statusCode}';
    } catch (e) {
      return 'Request failed with status ${response.statusCode}';
    }
  }

  /// GET request with token validation
  Future<T> get<T>(String url, T Function(dynamic) parser) async {
    final response = await http.get(
      Uri.parse(url),
      headers: await getHeaders(),
    );
    return handleResponse(response, parser);
  }

  /// POST request with token validation
  Future<T> post<T>(
    String url,
    Map<String, dynamic> body,
    T Function(dynamic) parser,
  ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: await getHeaders(),
      body: jsonEncode(body),
    );
    return handleResponse(response, parser);
  }

  /// PUT request with token validation
  Future<T> put<T>(
    String url,
    Map<String, dynamic> body,
    T Function(dynamic) parser,
  ) async {
    final response = await http.put(
      Uri.parse(url),
      headers: await getHeaders(),
      body: jsonEncode(body),
    );
    return handleResponse(response, parser);
  }

  /// DELETE request with token validation
  Future<T> delete<T>(String url, T Function(dynamic) parser) async {
    final response = await http.delete(
      Uri.parse(url),
      headers: await getHeaders(),
    );
    return handleResponse(response, parser);
  }
}
