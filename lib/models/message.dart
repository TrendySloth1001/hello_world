import 'user.dart';

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final DateTime createdAt;
  final User? sender;

  // Advanced Features
  final int? replyToId;
  final Message? replyTo;
  final bool isDeleted;
  final List<MessageReaction> reactions;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.sender,
    this.replyToId,
    this.replyTo,
    this.isDeleted = false,
    this.reactions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      replyToId: json['replyToId'],
      replyTo: json['replyTo'] != null
          ? Message.fromJson(json['replyTo'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      reactions:
          (json['reactions'] as List?)
              ?.map((e) => MessageReaction.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MessageReaction {
  final int id;
  final String emoji;
  final int userId;
  final int messageId;
  final User? user;

  MessageReaction({
    required this.id,
    required this.emoji,
    required this.userId,
    required this.messageId,
    this.user,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'],
      emoji: json['emoji'],
      userId: json['userId'],
      messageId: json['messageId'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}
