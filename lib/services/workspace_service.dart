import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workspace.dart';

class WorkspaceService {
  static const String baseUrl =
      'https://qjhcp0ph-3005.inc1.devtunnels.ms/workspace';

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

  // ==================== WORKSPACE CRUD ====================

  Future<Workspace> createWorkspace(String name, String? description) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: await _getHeaders(),
      body: jsonEncode({'name': name, 'description': description}),
    );

    if (response.statusCode == 201) {
      return Workspace.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<UserWorkspaces> getMyWorkspaces() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return UserWorkspaces.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Workspace> getWorkspaceByPublicId(String publicId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/public/$publicId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Workspace.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<Workspace> updateWorkspace(
    int id, {
    String? name,
    String? description,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: await _getHeaders(),
      body: jsonEncode({'name': name, 'description': description}),
    );

    if (response.statusCode == 200) {
      return Workspace.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> deleteWorkspace(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  // ==================== JOIN REQUESTS ====================

  Future<JoinRequest> requestToJoin(String publicId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/public/$publicId/request'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 201) {
      return JoinRequest.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<List<JoinRequest>> getJoinRequests(int workspaceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$workspaceId/requests'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => JoinRequest.fromJson(e))
          .toList();
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> acceptJoinRequest(int workspaceId, int requestId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$workspaceId/requests/$requestId/accept'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> rejectJoinRequest(int workspaceId, int requestId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$workspaceId/requests/$requestId/reject'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  // ==================== MEMBER MANAGEMENT ====================

  Future<List<WorkspaceMember>> getMembers(int workspaceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$workspaceId/members'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => WorkspaceMember.fromJson(e))
          .toList();
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<WorkspaceMember> updateMemberPosition(
    int workspaceId,
    int userId,
    String position,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$workspaceId/members/$userId'),
      headers: await _getHeaders(),
      body: jsonEncode({'position': position}),
    );

    if (response.statusCode == 200) {
      return WorkspaceMember.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<void> kickMember(int workspaceId, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$workspaceId/members/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }
}
