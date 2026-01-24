import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class WebSocketService {
  late IO.Socket socket;
  Function(int, bool)? onUserStatusChange;
  Function(int, int, bool)? onTypingStatusChange;
  Set<int> _onlineUsers = {};

  void initSocket(
    int userId, {
    Function(int, bool)? onUserStatus,
    Function(int, int, bool)? onTyping,
  }) {
    onUserStatusChange = onUserStatus;
    onTypingStatusChange = onTyping;

    socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setQuery({'userId': userId})
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to WebSocket');
    });

    socket.on('initial_online_users', (data) {
      if (data is List) {
        _onlineUsers = data.map((e) => e as int).toSet();
        // Since we don't have a direct "bulk update" callback in the plan,
        // we can iterate or just rely on individual updates.
        // For now, let's just log or maybe trigger a refresh if we had a stream.
        // Ideally we should expose this set.
        print('Initial online users: $_onlineUsers');
      }
    });

    socket.on('user_status', (data) {
      print('WebSocket: Received user_status: $data');
      final targetUserId = data['userId'];
      final status = data['status'];
      final isOnline = status == 'online';

      if (isOnline) {
        _onlineUsers.add(targetUserId);
      } else {
        _onlineUsers.remove(targetUserId);
      }

      onUserStatusChange?.call(targetUserId, isOnline);
    });

    socket.on('typing_status', (data) {
      print('WebSocket: Received typing_status: $data');
      final conversationId = data['conversationId'];
      final targetUserId = data['userId'];
      final isTyping = data['isTyping'];
      onTypingStatusChange?.call(conversationId, targetUserId, isTyping);
    });

    socket.onConnectError((data) => print('Connect Error: $data'));
    socket.onError((data) => print('Error: $data'));
    socket.onDisconnect((_) => print('Disconnected from WebSocket'));
  }

  bool isUserOnline(int userId) {
    return _onlineUsers.contains(userId);
  }

  void joinConversation(String conversationId) {
    if (socket.connected) {
      socket.emit('join_conversation', conversationId);
    } else {
      socket.onConnect((_) {
        socket.emit('join_conversation', conversationId);
      });
    }
  }

  void listenToMessages(
    Function(dynamic) onMessage, {
    Function(dynamic)? onDelete,
    Function(dynamic)? onReactionAdd,
    Function(dynamic)? onReactionRemove,
  }) {
    socket.on('new_message', (data) => onMessage(data));
    if (onDelete != null) {
      socket.on('message_deleted', (data) => onDelete(data));
    }
    if (onReactionAdd != null) {
      socket.on('reaction_added', (data) => onReactionAdd(data));
    }
    if (onReactionRemove != null) {
      socket.on('reaction_removed', (data) => onReactionRemove(data));
    }
  }

  void sendTyping(int conversationId, int userId) {
    socket.emit('typing_start', {
      'conversationId': conversationId,
      'userId': userId,
    });
  }

  void sendStopTyping(int conversationId, int userId) {
    socket.emit('typing_stop', {
      'conversationId': conversationId,
      'userId': userId,
    });
  }

  void sendMessage(
    int conversationId,
    int senderId,
    String content, {
    int? replyToId,
  }) {
    socket.emit('send_message', {
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'replyToId': replyToId,
    });
  }

  void deleteMessage(int messageId, int userId, bool forEveryone) {
    socket.emit('delete_message', {
      'messageId': messageId,
      'userId': userId,
      'forEveryone': forEveryone,
    });
  }

  void addReaction(int messageId, int userId, String emoji) {
    socket.emit('add_reaction', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
    });
  }

  void removeReaction(int messageId, int userId, String emoji) {
    socket.emit('remove_reaction', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
    });
  }

  void dispose() {
    socket.disconnect();
    socket.dispose();
  }
}
