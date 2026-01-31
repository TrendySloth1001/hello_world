import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workspace.dart';
import '../config/api_config.dart';
import 'http_service.dart';

class WorkspaceService {
  static const String baseUrl = '${ApiConfig.baseUrl}/workspace';
  final HttpService _httpService = HttpService();

  // ==================== WORKSPACE CRUD ====================

  Future<Workspace> createWorkspace(String name, String? description) async {
    // Note: Create returns 201, so we need to use raw http for this one
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: await _httpService.getHeaders(),
      body: jsonEncode({'name': name, 'description': description}),
    );

    if (response.statusCode == 201) {
      return Workspace.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      // Handle token expiration
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<UserWorkspaces> getMyWorkspaces() async {
    return await _httpService.get(
      '$baseUrl/my',
      (data) => UserWorkspaces.fromJson(data),
    );
  }

  Future<Workspace> getWorkspaceByPublicId(String publicId) async {
    return await _httpService.get(
      '$baseUrl/public/$publicId',
      (data) => Workspace.fromJson(data),
    );
  }

  Future<Workspace> updateWorkspace(
    int id, {
    String? name,
    String? description,
  }) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;

    return await _httpService.put(
      '$baseUrl/$id',
      body,
      (data) => Workspace.fromJson(data),
    );
  }

  Future<void> deleteWorkspace(int id) async {
    await _httpService.delete('$baseUrl/$id', (data) => null);
  }

  // ==================== JOIN REQUESTS ====================

  Future<JoinRequest> requestToJoin(String publicId) async {
    // Returns 201, so use raw http
    final response = await http.post(
      Uri.parse('$baseUrl/public/$publicId/request'),
      headers: await _httpService.getHeaders(),
    );

    if (response.statusCode == 201) {
      return JoinRequest.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      throw Exception(jsonDecode(response.body)['message']);
    }
  }

  Future<List<JoinRequest>> getJoinRequests(int workspaceId) async {
    return await _httpService.get(
      '$baseUrl/$workspaceId/requests',
      (data) => (data as List).map((e) => JoinRequest.fromJson(e)).toList(),
    );
  }

  Future<void> acceptJoinRequest(int workspaceId, int requestId) async {
    await _httpService.post(
      '$baseUrl/$workspaceId/requests/$requestId/accept',
      {},
      (data) => null,
    );
  }

  Future<void> rejectJoinRequest(int workspaceId, int requestId) async {
    await _httpService.post(
      '$baseUrl/$workspaceId/requests/$requestId/reject',
      {},
      (data) => null,
    );
  }

  // ==================== MEMBER MANAGEMENT ====================

  Future<List<WorkspaceMember>> getMembers(int workspaceId) async {
    return await _httpService.get(
      '$baseUrl/$workspaceId/members',
      (data) => (data as List).map((e) => WorkspaceMember.fromJson(e)).toList(),
    );
  }

  Future<WorkspaceMember> updateMemberPosition(
    int workspaceId,
    int userId,
    String position,
  ) async {
    return await _httpService.put(
      '$baseUrl/$workspaceId/members/$userId',
      {'position': position},
      (data) => WorkspaceMember.fromJson(data),
    );
  }

  Future<void> kickMember(int workspaceId, int userId) async {
    await _httpService.delete(
      '$baseUrl/$workspaceId/members/$userId',
      (data) => null,
    );
  }

  // ==================== AVATAR MANAGEMENT ====================

  Future<List<String>> getWorkspaceAvatarPresets() async {
    return await _httpService.get(
      '$baseUrl/avatars',
      (data) => List<String>.from(data['avatars']),
    );
  }

  Future<void> updateWorkspaceAvatar(int workspaceId, String avatarUrl) async {
    await _httpService.put('$baseUrl/$workspaceId/avatar', {
      'avatarUrl': avatarUrl,
    }, (data) => null);
  }

  // ==================== INVITE SYSTEM ====================

  Future<InviteUser> searchUserByEmail(String email) async {
    return await _httpService.get(
      '${ApiConfig.baseUrl}/user/search?email=$email',
      (data) => InviteUser.fromJson(data),
    );
  }

  Future<void> inviteUser(int workspaceId, String email) async {
    // Returns 201, so use raw http
    final response = await http.post(
      Uri.parse('$baseUrl/$workspaceId/invite'),
      headers: await _httpService.getHeaders(),
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      await _httpService.handleResponse(response, (data) => data);
      throw Exception('Session expired');
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Unknown error');
      } on FormatException {
        throw Exception(
          'Server returned invalid response: ${response.body.substring(0, 50)}...',
        );
      }
    }
  }

  Future<List<WorkspaceInvite>> getMyInvites() async {
    return await _httpService.get(
      '$baseUrl/user/invites',
      (data) => (data as List).map((e) => WorkspaceInvite.fromJson(e)).toList(),
    );
  }

  Future<void> respondToInvite(int requestId, bool accept) async {
    await _httpService.post('$baseUrl/invites/$requestId/respond', {
      'accept': accept,
    }, (data) => null);
  }
}
