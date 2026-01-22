import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  static const String baseUrl = '${ApiConfig.baseUrl}/chat';

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

  // Get all conversations for the current user
  Future<List<Conversation>> getConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load conversations: ${response.statusCode}');
    }
  }

  // Create or get existing direct chat
  Future<Conversation> getOrCreateDirectChat(
    int targetUserId, {
    String? nickname,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/direct'),
      headers: await _getHeaders(),
      body: jsonEncode({'targetId': targetUserId, 'nickname': nickname}),
    );

    if (response.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create chat: ${response.body}');
    }
  }

  // Create group chat
  Future<Conversation> createGroupChat(String name, List<int> memberIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/group'),
      headers: await _getHeaders(),
      body: jsonEncode({'name': name, 'memberIds': memberIds}),
    );

    if (response.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create group chat: ${response.body}');
    }
  }

  // Get messages for a conversation
  Future<List<Message>> getMessages(
    int conversationId, {
    int limit = 50,
    int? cursor,
  }) async {
    String url = '$baseUrl/$conversationId/messages?limit=$limit';
    if (cursor != null) {
      url += '&cursor=$cursor';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages: ${response.statusCode}');
    }
  }

  // Send a message
  Future<Message> sendMessage(int conversationId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$conversationId/messages'),
      headers: await _getHeaders(),
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 200) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }
}
