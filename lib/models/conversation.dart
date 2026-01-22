import 'user.dart';
import 'message.dart';

class Conversation {
  final int id;
  final String type; // 'DIRECT' or 'GROUP'
  final String? name;
  final List<ConversationMember> members;
  final Message? lastMessage;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    required this.members,
    this.lastMessage,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    var membersList = (json['members'] as List)
        .map((m) => ConversationMember.fromJson(m))
        .toList();

    // The backend returns 'messages' array with 1 item for the last message
    Message? lastMsg;
    if (json['messages'] != null && (json['messages'] as List).isNotEmpty) {
      lastMsg = Message.fromJson(json['messages'][0]);
    }

    return Conversation(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      members: membersList,
      lastMessage: lastMsg,
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Helper to get the other user in a direct chat
  User? getOtherUser(int currentUserId) {
    if (type == 'GROUP') return null;
    try {
      return members.firstWhere((m) => m.userId != currentUserId).user;
    } catch (_) {
      return null;
    }
  }

  // Helper to get display name
  String getDisplayName(int currentUserId) {
    if (type == 'GROUP') return name ?? 'Group Chat';
    final otherUser = getOtherUser(currentUserId);
    return otherUser?.email ?? 'Unknown User';
  }
}

class ConversationMember {
  final int id;
  final int conversationId;
  final int userId;
  final User user;

  ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.user,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    return ConversationMember(
      id: json['id'],
      conversationId: json['conversationId'],
      userId: json['userId'],
      user: User.fromJson(json['user']),
    );
  }
}
