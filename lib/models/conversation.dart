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
    try {
      final myMember = members.firstWhere((m) => m.userId == currentUserId);
      if (myMember.nickname != null && myMember.nickname!.isNotEmpty) {
        return myMember.nickname!;
      }
    } catch (_) {}

    if (type == 'GROUP') return name ?? 'Group Chat';
    final otherUser = getOtherUser(currentUserId);
    return otherUser?.email ?? 'Unknown User';
  }

  // Helper to get display avatar
  String? getDisplayAvatarUrl(int currentUserId) {
    if (type == 'GROUP') return null; // Use default group icon
    final otherUser = getOtherUser(currentUserId);
    return otherUser?.avatarUrl;
  }
}

class ConversationMember {
  final int id;
  final int conversationId;
  final int userId;
  final String? nickname;
  final User user;

  ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.nickname,
    required this.user,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    return ConversationMember(
      id: json['id'],
      conversationId: json['conversationId'],
      userId: json['userId'],
      nickname: json['nickname'],
      user: User.fromJson(json['user']),
    );
  }
}
