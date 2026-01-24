import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class WebSocketService {
  late IO.Socket socket;

  void initSocket() {
    socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to WebSocket');
    });

    socket.onConnectError((data) => print('Connect Error: $data'));
    socket.onError((data) => print('Error: $data'));
    socket.onDisconnect((_) => print('Disconnected from WebSocket'));
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
