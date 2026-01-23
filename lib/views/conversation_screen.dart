import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';

import 'package:cached_network_image/cached_network_image.dart';

class ConversationScreen extends StatefulWidget {
  final int conversationId;
  final String conversationName;
  final int currentUserId;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
    required this.currentUserId,
    this.targetUserId,
  });

  final int? targetUserId;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ChatService _chatService = ChatService();
  final WebSocketService _webSocketService = WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _displayConversationName;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _displayConversationName = widget.conversationName;
    _loadMessages();

    _webSocketService.initSocket();
    _webSocketService.joinConversation(widget.conversationId.toString());

    _webSocketService.listenToMessages((data) {
      if (mounted) {
        // Convert dynamic map to Message object
        try {
          // The data might be a JSON Map from the socket event
          final newMessage = Message.fromJson(data);
          if (!_messages.any((m) => m.id == newMessage.id)) {
            setState(() {
              _messages.insert(0, newMessage);
            });
          }
          // Scroll if needed, but since it's at the bottom (index 0 for reverse list), it should be fine.
          // However, if the user scrolled up, we might not want to jump.
          // For now, simple insertion is fine.
        } catch (e) {
          print('Error parsing message: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final messages = await _chatService.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        // Scroll to bottom on initial load
        if (showLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
        // Only show error on initial load to avoid spamming toast
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading messages: $e')),
        // );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      // Optimistic UI Update
      // We don't have the real ID yet, but we can generate a temporary one or rely on the socket event to update it.
      // Ideally, the socket event comes back quickly.
      // For now, let's just send it and let the socket listener handle the insertion.
      // OR, we can insert a 'pending' message.

      // Let's rely on the socket event for simplicity and avoiding ID collisions with the 'pending' approach for now,
      // as the user is on a "Potato PC", simpler logic is better.
      // The socket event usually arrives in <100ms.

      _webSocketService.sendMessage(
        widget.conversationId,
        widget.currentUserId,
        content,
      );

      if (mounted) {
        _messageController.clear();
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  Future<void> _showChangeNicknameDialog() async {
    final TextEditingController nicknameController = TextEditingController(
      text:
          _displayConversationName, // Use current display name as initial value
    );

    // Safety check: nickname update only works for direct chats where we identified the target user
    if (widget.targetUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot change nickname for this conversation type.'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Change Nickname',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nicknameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new nickname',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNickname = nicknameController.text.trim();
              if (newNickname.isNotEmpty) {
                try {
                  // Call service to update nickname
                  await _chatService.getOrCreateDirectChat(
                    widget.targetUserId!,
                    nickname: newNickname,
                  );

                  if (mounted) {
                    setState(() {
                      _displayConversationName = newNickname;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Nickname updated to $newNickname'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update nickname: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _displayConversationName, // Use local state
          style: const TextStyle(
            fontSize: 16,
          ), // Reduced font size as requested
        ),
        backgroundColor: const Color(0xFF0A0A0A), // Consistent dark header
        elevation: 0,
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'nickname') {
                _showChangeNicknameDialog();
              }
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E1E1E),
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'nickname',
                  child: Text(
                    'Change Nickname',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Show latest messages at the bottom
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == widget.currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (message.sender?.avatarUrl != null)
              CachedNetworkImage(
                imageUrl: message.sender!.avatarUrl!,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: 16,
                  backgroundImage: imageProvider,
                  backgroundColor: Colors.blue.shade900,
                ),
                placeholder: (context, url) {
                  // print('Loading avatar: $url');
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade900,
                    child: const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  print('Error loading avatar ($url): $error');
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade900,
                    child: Text(
                      (message.sender?.email ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              )
            else
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade900,
                child: Text(
                  (message.sender?.email ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                ),
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  message.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMessageTime(message.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
