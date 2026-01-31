import '../config/api_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'http_service.dart';

class ChatService {
  static const String baseUrl = '${ApiConfig.baseUrl}/chat';
  final HttpService _httpService = HttpService();

  // Get all conversations for the current user
  Future<List<Conversation>> getConversations() async {
    print('ChatService: Fetching conversations from $baseUrl/conversations');
    try {
      return await _httpService.get(
        '$baseUrl/conversations',
        (data) => (data as List).map((json) => Conversation.fromJson(json)).toList(),
      );
    } catch (e) {
      print('ChatService Exception: $e');
      rethrow;
    }
  }

  // Create or get existing direct chat
  Future<Conversation> getOrCreateDirectChat(
    int targetUserId, {
    String? nickname,
  }) async {
    return await _httpService.post(
      '$baseUrl/direct',
      {'targetId': targetUserId, 'nickname': nickname},
      (data) => Conversation.fromJson(data),
    );
  }

  // Create group chat
  Future<Conversation> createGroupChat(String name, List<int> memberIds) async {
    return await _httpService.post(
      '$baseUrl/group',
      {'name': name, 'memberIds': memberIds},
      (data) => Conversation.fromJson(data),
    );
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

    return await _httpService.get(
      url,
      (data) => (data as List).map((json) => Message.fromJson(json)).toList(),
    );
  }

  // Send a message
  Future<Message> sendMessage(int conversationId, String content) async {
    return await _httpService.post(
      '$baseUrl/$conversationId/messages',
      {'content': content},
      (data) => Message.fromJson(data),
    );
  }

  // Toggle pin status
  Future<void> togglePin(int conversationId, bool isPinned) async {
    await _httpService.post(
      '$baseUrl/$conversationId/pin',
      {'isPinned': isPinned},
      (data) => null,
    );
  }

  Future<void> markAsRead(int conversationId, int userId) async {
    await _httpService.post(
      '$baseUrl/$conversationId/read',
      {},
      (data) => null,
    );
  }

  Future<void> renameConversation(int conversationId, String newName) async {
    await _httpService.put(
      '$baseUrl/$conversationId/rename',
      {'name': newName},
      (data) => null,
    );
  }
}
