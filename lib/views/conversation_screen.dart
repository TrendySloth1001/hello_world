import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/user.dart';
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

  Message? _replyingTo;

  @override
  void initState() {
    super.initState();
    _displayConversationName = widget.conversationName;
    _loadMessages();

    _webSocketService.initSocket();
    _webSocketService.joinConversation(widget.conversationId.toString());

    _webSocketService.listenToMessages(
      (data) {
        if (mounted) {
          try {
            final newMessage = Message.fromJson(data);
            if (!_messages.any((m) => m.id == newMessage.id)) {
              setState(() {
                _messages.insert(0, newMessage);
              });
            }
          } catch (e) {
            print('Error parsing message: $e');
          }
        }
      },
      onDelete: (data) {
        if (mounted) {
          final messageId = data['messageId'];
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              // If deleted for everyone, we might want to replace content or mark as deleted
              // Check payload structure.
              if (data['forEveryone'] == true) {
                // Create a copy with isDeleted = true
                // Limitations of simple copyWith? We need to construct new Message.
                // For now, let's just reload messages or try to patch.
                // Ideally Message model has copyWith.
                // Making a quick new object:
                final old = _messages[index];
                _messages[index] = Message(
                  id: old.id,
                  conversationId: old.conversationId,
                  senderId: old.senderId,
                  content: "This message was deleted",
                  createdAt: old.createdAt,
                  sender: old.sender,
                  replyToId: old.replyToId,
                  replyTo: old.replyTo,
                  isDeleted: true,
                  reactions: old.reactions,
                );
              } else {
                // Deleted for me - usually we'd remove it from list
                // _messages.removeAt(index);
                // But wait, the socket event comes to everyone? NO.
                // delete_message for 'me' shouldn't be broadcasted to room if we can help it,
                // BUT my backend logic emits to 'conversationId' room for "deleted for everyone".
                // "deleted for me" logic in backend does NOT emit to room currently (good).
                // So this callback is mostly for "deleted for everyone".
              }
            }
          });
        }
      },
      onReactionAdd: (data) {
        if (mounted) {
          final reaction = MessageReaction.fromJson(data);
          setState(() {
            final index = _messages.indexWhere(
              (m) => m.id == reaction.messageId,
            );
            if (index != -1) {
              // Create a modified message with the new reaction
              final oldMessage = _messages[index];
              _messages[index] = Message(
                id: oldMessage.id,
                conversationId: oldMessage.conversationId,
                senderId: oldMessage.senderId,
                content: oldMessage.content,
                createdAt: oldMessage.createdAt,
                sender: oldMessage.sender,
                replyToId: oldMessage.replyToId,
                replyTo: oldMessage.replyTo,
                isDeleted: oldMessage.isDeleted,
                reactions: [...oldMessage.reactions, reaction],
              );
            }
          });
          // Re-fetching might be safer to ensure consistency until we have robust state management
          _loadMessages(showLoading: false);
        }
      },
      onReactionRemove: (data) {
        if (mounted) _loadMessages(showLoading: false);
      },
    );
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _displayConversationName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.targetUserId !=
                null) // Only show status for direct chats if we had presence
              const Text(
                'Online', // Placeholder or use real presence
                style: TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Conversation details / settings
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
      ),
    );
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
        if (showLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
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
      _webSocketService.sendMessage(
        widget.conversationId,
        widget.currentUserId,
        content,
        replyToId: _replyingTo?.id,
      );

      if (mounted) {
        _messageController.clear();
        setState(() {
          _isSending = false;
          _replyingTo = null; // Clear reply state
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

  void _showMessageOptions(Message message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reactions
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _webSocketService.addReaction(
                      message.id,
                      widget.currentUserId,
                      emoji,
                    );
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.reply, color: Colors.white),
            title: const Text('Reply', style: TextStyle(color: Colors.white)),
            onTap: () {
              setState(() => _replyingTo = message);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white),
            title: const Text('Copy', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Clipboard.setData(ClipboardData(text: message.content)); // Needs service
              Navigator.pop(context);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete for everyone',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                _webSocketService.deleteMessage(
                  message.id,
                  widget.currentUserId,
                  true,
                );
                Navigator.pop(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete for me',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              _webSocketService.deleteMessage(
                message.id,
                widget.currentUserId,
                false,
              );
              Navigator.pop(context);
              // Manually remove from local list since no socket event for "me"
              setState(() {
                _messages.removeWhere((m) => m.id == message.id);
              });
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Build Helpers

  Widget _buildMessageBubble(Message message, bool isMe) {
    final isDeleted = message.isDeleted;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isMe),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _buildAvatar(message.sender),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Reply Preview Bubble
                  if (message.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(color: Colors.grey, width: 3),
                        ),
                      ),
                      child: Text(
                        message.replyTo!.content,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  // Message Bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDeleted
                          ? Colors.grey.withOpacity(0.2)
                          : (isMe
                                ? Colors.blue
                                : Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottomRight: isMe
                            ? Radius.zero
                            : const Radius.circular(16),
                      ),
                    ),
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      isDeleted
                          ? "🚫 This message was deleted"
                          : message.content,
                      style: TextStyle(
                        color: isDeleted ? Colors.white54 : Colors.white,
                        fontSize: 15,
                        fontStyle: isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),

                  // Reactions Pill
                  if (message.reactions.isNotEmpty && !isDeleted)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.reactions
                            .map((r) => r.emoji)
                            .toSet()
                            .join(' '), // simple unique display
                        style: const TextStyle(fontSize: 12),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(User? sender) {
    if (sender?.avatarUrl != null) {
      return CachedNetworkImage(
        imageUrl: sender!.avatarUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 16,
          backgroundImage: imageProvider,
          backgroundColor: Colors.blue.shade900,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: 16,
          backgroundColor: Colors.transparent,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blue.shade900,
          child: Text((sender!.email ?? '?')[0].toUpperCase()),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue.shade900,
      child: Text(
        (sender?.email ?? '?')[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: Colors.blue, width: 3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Replying to: ${_replyingTo!.content}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          Row(
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
                    fillColor: Colors.white.withValues(alpha: 0.05),
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
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
