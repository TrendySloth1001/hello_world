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

  void listenToMessages(Function(dynamic) onMessage) {
    socket.on('new_message', (data) {
      onMessage(data);
    });
  }

  void sendMessage(int conversationId, int senderId, String content) {
    socket.emit('send_message', {
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
    });
  }

  void dispose() {
    socket.disconnect();
    socket.dispose();
  }
}
