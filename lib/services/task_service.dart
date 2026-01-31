import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../config/api_config.dart';
import 'http_service.dart';

class TaskService {
  static const String baseUrl = '${ApiConfig.baseUrl}/task';
  final HttpService _httpService = HttpService();

  Future<Task> createTask({
    required int workspaceId,
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    List<int>? assigneeIds,
    bool isPrivate = false,
  }) async {
    // Returns 201, so use raw http
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: await _httpService.getHeaders(),
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
    } else if (response.statusCode == 401) {
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<List<Task>> getWorkspaceTasks(int workspaceId) async {
    return await _httpService.get(
      '$baseUrl/workspace/$workspaceId',
      (data) => (data as List).map((e) => Task.fromJson(e)).toList(),
    );
  }

  Future<Task> getTaskDetails(int taskId) async {
    return await _httpService.get(
      '$baseUrl/$taskId',
      (data) => Task.fromJson(data),
    );
  }

  Future<Task> updateTask(int taskId, Map<String, dynamic> data) async {
    return await _httpService.put(
      '$baseUrl/$taskId',
      data,
      (data) => Task.fromJson(data),
    );
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

    // Returns 201, so use raw http
    final response = await http.post(
      Uri.parse('$baseUrl/$taskId/comments'),
      headers: await _httpService.getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return Comment.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Map<String, dynamic>> toggleCommentLike(int commentId) async {
    return await _httpService.post(
      '$baseUrl/comments/$commentId/like',
      {},
      (data) => data as Map<String, dynamic>,
    );
  }

  Future<void> respondToTask(
    int taskId,
    String status, {
    String? rejectionReason,
  }) async {
    await _httpService.post('$baseUrl/$taskId/respond', {
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    }, (data) => null);
  }

  Future<void> claimTask(int taskId) async {
    await _httpService.post('$baseUrl/$taskId/claim', {}, (data) => null);
  }

  Future<Map<String, dynamic>> getComments(
    int taskId, {
    int page = 1,
    int limit = 20,
  }) async {
    return await _httpService.get(
      '$baseUrl/$taskId/comments?page=$page&limit=$limit',
      (data) => data as Map<String, dynamic>,
    );
  }

  Future<void> requestContribution(int taskId) async {
    // Returns 201, so use raw http
    final response = await http.post(
      Uri.parse('$baseUrl/$taskId/contribute'),
      headers: await _httpService.getHeaders(),
    );

    if (response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> manageContribution(
    int taskId,
    int contributorId,
    String action,
  ) async {
    await _httpService.post('$baseUrl/$taskId/contribute/manage', {
      'contributorId': contributorId,
      'action': action,
    }, (data) => null);
  }

  Future<SubTask> addSubTask(int taskId, String title) async {
    // Returns 201, so use raw http
    final response = await http.post(
      Uri.parse('$baseUrl/$taskId/subtasks'),
      headers: await _httpService.getHeaders(),
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode == 201) {
      return SubTask.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<SubTask> toggleSubTask(int taskId, int subTaskId) async {
    return await _httpService.put(
      '$baseUrl/$taskId/subtasks/$subTaskId/toggle',
      {},
      (data) => SubTask.fromJson(data),
    );
  }

  Future<void> deleteSubTask(int taskId, int subTaskId) async {
    await _httpService.delete(
      '$baseUrl/$taskId/subtasks/$subTaskId',
      (data) => null,
    );
  }
}
