import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';

class ConversationScreen extends StatefulWidget {
  final int conversationId;
  final String conversationName;
  final int currentUserId;
  final int? targetUserId;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
    required this.currentUserId,
    this.targetUserId,
  });

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

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<int> _selectedMessageIds = {};

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
              if (data['forEveryone'] == true) {
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
                // Deleted for me
                _messages.removeAt(index);
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

  // --- Multi-select Logic ---

  void _toggleSelectionMode(Message message) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.add(message.id);
    });
  }

  void _toggleSelection(int messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _deleteSelectedMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages?'),
        content: Text('Delete ${_selectedMessageIds.length} messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performBulkDelete(false); // Default to delete for me for bulk
            },
            child: const Text(
              'Delete for Me',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkDelete(bool forEveryone) async {
    for (final id in _selectedMessageIds) {
      _webSocketService.deleteMessage(id, widget.currentUserId, forEveryone);
    }
    setState(() {
      // Optimistically remove/update
      if (!forEveryone) {
        _messages.removeWhere((m) => _selectedMessageIds.contains(m.id));
      }
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Row(
          children: [
            if (!_isSelectionMode) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade800,
                child: Text(
                  _displayConversationName.isNotEmpty
                      ? _displayConversationName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSelectionMode
                        ? '${_selectedMessageIds.length} Selected'
                        : _displayConversationName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isSelectionMode && widget.targetUserId != null)
                    const Text(
                      'Online',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedMessageIds.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedMessages,
            )
          else
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

  Widget _buildMessageBubble(Message message, bool isMe) {
    final isDeleted = message.isDeleted;
    final isSelected = _selectedMessageIds.contains(message.id);

    Widget bubbleContent = GestureDetector(
      onLongPress: () {
        if (_isSelectionMode) return;
        _showMessageOptions(message, isMe);
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(message.id);
        } else {
          // Tap action (e.g., toggle timestamp or message details)
        }
      },
      child: Container(
        color: isSelected ? Colors.blue.withValues(alpha: 0.2) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (val) => _toggleSelection(message.id),
                activeColor: Colors.blue,
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              const SizedBox(width: 8),
            ],
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
                  // Reply Preview
                  if (message.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
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

                  // Message Text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDeleted
                          ? Colors.grey.withValues(alpha: 0.2)
                          : (isMe
                                ? Colors.blue
                                : Colors.white.withValues(alpha: 0.1)),
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

                  // Reactions
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
                        message.reactions.map((r) => r.emoji).toSet().join(' '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
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

    // Disable swipe in selection mode
    if (_isSelectionMode || isDeleted) {
      return bubbleContent;
    }

    return Dismissible(
      key: ValueKey(message.id),
      // If isMe (Right aligned): Swipe Left (EndToStart) to reply
      // If !isMe (Left aligned): Swipe Right (StartToEnd) to reply
      direction: isMe
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      background: Container(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        padding: EdgeInsets.only(left: isMe ? 0 : 20, right: isMe ? 20 : 0),
        color: Colors.transparent,
        child: const Icon(Icons.reply, color: Colors.white70),
      ),
      confirmDismiss: (direction) async {
        setState(() {
          _replyingTo = message;
        });
        return false;
      },
      child: bubbleContent,
    );
  }

  void _showMessageOptions(Message message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Placeholder for Reactions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _webSocketService.addReaction(
                        message.id,
                        widget.currentUserId,
                        emoji,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white12, height: 32),
          ListTile(
            leading: const Icon(Icons.reply, color: Colors.white),
            title: const Text('Reply', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyingTo = message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white),
            title: const Text('Copy', style: TextStyle(color: Colors.white)),
            onTap: () {
              // TODO: Implement Copy
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
            ),
            title: const Text('Select', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _toggleSelectionMode(message);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                // Simple delete confirmation for single message
                _webSocketService.deleteMessage(
                  message.id,
                  widget.currentUserId,
                  true, // Default to forEveryone for single delete? Or ask?
                  // For now, let's just do bulk logic or ask
                );
                // Optimistic removal for now or wait for socket
              },
            ),
          const SizedBox(height: 20),
        ],
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
                color: Colors.white.withValues(alpha: 0.1),
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
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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
}
