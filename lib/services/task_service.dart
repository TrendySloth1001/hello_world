import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

import '../config/api_config.dart';

class TaskService {
  static const String baseUrl = '${ApiConfig.baseUrl}/task';

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

  Future<Task> createTask({
    required int workspaceId,
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    List<int>? assigneeIds,
    bool isPrivate = false,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: await _getHeaders(),
      body: jsonEncode({
        'workspaceId': workspaceId,
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'assigneeIds': assigneeIds,
        'isPrivate': isPrivate,
      }),
    );

    if (response.statusCode == 201) {
      return Task.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<List<Task>> getWorkspaceTasks(int workspaceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/workspace/$workspaceId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Task.fromJson(e))
          .toList();
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Task> getTaskDetails(int taskId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$taskId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Task.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Task> updateTask(int taskId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$taskId'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return Task.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Comment> addComment(
    int taskId,
    String content, {
    int? parentId,
  }) async {
    final Map<String, dynamic> body = {'content': content};
    if (parentId != null) {
      body['parentId'] = parentId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/$taskId/comments'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return Comment.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Map<String, dynamic>> toggleCommentLike(int commentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/comments/$commentId/like'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> respondToTask(
    int taskId,
    String status, {
    String? rejectionReason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$taskId/respond'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'status': status,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> claimTask(int taskId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$taskId/claim'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Map<String, dynamic>> getComments(
    int taskId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$taskId/comments?page=$page&limit=$limit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }
}
