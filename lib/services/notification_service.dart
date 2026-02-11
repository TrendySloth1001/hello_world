import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import '../models/notification.dart';

class NotificationService {
  static const String baseUrl = '${ApiConfig.baseUrl}/notifications';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    final headers = await _getHeaders();
    String url = '$baseUrl?page=$page&limit=$limit';
    if (isRead != null) {
      url += '&isRead=$isRead';
    }

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> list = decoded['notifications'];
      return list.map((json) => NotificationModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notifications: ${response.statusCode}');
    }
  }

  Future<NotificationModel> markAsRead(int id) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/$id/read'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return NotificationModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to mark as read: ${response.statusCode}');
    }
  }

  Future<void> markAllAsRead() async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/read-all'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all as read: ${response.statusCode}');
    }
  }

  Future<void> deleteNotification(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete notification: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/unread-count'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get unread count: ${response.statusCode}');
    }
  }
}
