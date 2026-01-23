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
  final String? avatarUrl;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
    required this.currentUserId,
    this.targetUserId,
    this.avatarUrl,
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

  void _showRenameDialog() {
    final TextEditingController renameController = TextEditingController(
      text: _displayConversationName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text(
          'Rename Conversation',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: renameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00A884)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00A884)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF00A884)),
            ),
          ),
          TextButton(
            onPressed: () {
              final newName = renameController.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _displayConversationName = newName;
                });
                // TODO: Call API to persist rename
              }
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF00A884)),
            ),
          ),
        ],
      ),
    );
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
            InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white),
                  const SizedBox(width: 4),
                  if (!_isSelectionMode) ...[
                    if (widget.avatarUrl != null)
                      CachedNetworkImage(
                        imageUrl: widget.avatarUrl!,
                        imageBuilder: (context, imageProvider) => CircleAvatar(
                          radius: 18,
                          backgroundImage: imageProvider,
                          backgroundColor: Colors.blue.shade800,
                        ),
                        placeholder: (context, url) => const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.transparent,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        ),
                        errorWidget: (context, url, error) => CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blue.shade800,
                          child: Text(
                            _displayConversationName.isNotEmpty
                                ? _displayConversationName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade800,
                        child: Text(
                          _displayConversationName.isNotEmpty
                              ? _displayConversationName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isSelectionMode && widget.targetUserId != null)
                    const Text(
                      'Online',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
        leading: null, // Custom leading inside title
        automaticallyImplyLeading: false,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedMessages,
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1F2C34),
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameDialog();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Text('Rename', style: TextStyle(color: Colors.white)),
                ),
              ],
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

                        // Grouping Logic (Reverse list: compare with NEXT item for "previous" message in chronological order)
                        // In reverse list: index + 1 is the OLDER message
                        final prevMessage = (index + 1 < _messages.length)
                            ? _messages[index + 1]
                            : null;
                        final nextMessage = (index - 1 >= 0)
                            ? _messages[index - 1]
                            : null;

                        final bool isFirstInGroup =
                            prevMessage == null ||
                            prevMessage.senderId != message.senderId;
                        final bool isLastInGroup =
                            nextMessage == null ||
                            nextMessage.senderId != message.senderId;

                        // Spacing
                        final double topSpacing = isFirstInGroup ? 8.0 : 2.0;

                        return Padding(
                          padding: EdgeInsets.only(top: topSpacing),
                          child: _buildMessageBubble(
                            message,
                            isMe,
                            showAvatar:
                                !isMe &&
                                isLastInGroup, // Show avatar only at the bottom of the group for incoming
                            isLastInGroup: isLastInGroup,
                            isFirstInGroup: isFirstInGroup,
                          ),
                        );
                      },
                    ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Message message,
    bool isMe, {
    required bool showAvatar,
    required bool isLastInGroup,
    required bool isFirstInGroup,
  }) {
    final isDeleted = message.isDeleted;
    final isSelected = _selectedMessageIds.contains(message.id);

    // Principle #3: Kill noisy deleted messages
    if (isDeleted) {
      if (_isSelectionMode)
        return const SizedBox.shrink(); // Hide deleted in selection mode if unwanted, or keep simple

      return Container(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        margin: EdgeInsets.symmetric(
          vertical: 2,
          horizontal: isMe ? 0 : 40,
        ), // Indent to align with text
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: Colors.white.withOpacity(0.4)),
            const SizedBox(width: 6),
            Text(
              "Message deleted",
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Principle #4: Emoji = message, not decoration
    final bool isEmojiOnly = _isEmojiOnly(message.content);

    Widget bubbleContent = GestureDetector(
      onLongPress: () {
        if (_isSelectionMode) return;
        _showMessageOptions(message, isMe);
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(message.id);
        }
      },
      child: Container(
        color: isSelected ? Colors.blue.withOpacity(0.2) : null,
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Checkbox for selection
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (val) => _toggleSelection(message.id),
                activeColor: Color(0xFF00A884),
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.white54),
              ),
              const SizedBox(width: 8),
            ],

            // Avatar Logic (Principle #2)
            if (!isMe) ...[
              if (showAvatar)
                _buildAvatar(message.sender)
              else
                const SizedBox(width: 32), // Preserve space for alignment
              const SizedBox(width: 8),
            ],

            // Bubble
            Flexible(
              child: isEmojiOnly
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        message.content,
                        style: const TextStyle(fontSize: 40),
                      ),
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: message.reactions.isNotEmpty && !isDeleted
                                ? 12.0
                                : 0,
                          ),

                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              // Principle #7: Colors & Contrast
                              color: isMe
                                  ? const Color(0xFF005C4B)
                                  : const Color(0xFF202C33),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                // Principle #1: Fewer visual rules
                                bottomLeft: isMe
                                    ? const Radius.circular(12)
                                    : const Radius.circular(0),
                                bottomRight: isMe
                                    ? const Radius.circular(0)
                                    : const Radius.circular(12),
                              ),
                            ),
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Reply Preview
                                if (message.replyTo != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: const Border(
                                        left: BorderSide(
                                          color: Color(0xFF00A884),
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.replyTo?.sender?.email ??
                                              'Sender',
                                          style: const TextStyle(
                                            color: Color(0xFF00A884),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          message.replyTo!.content,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        message.content,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Principle #6: Timestamps = subtle
                                    Text(
                                      _formatMessageTime(message.createdAt),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Floating Reactions Pill
                        if (message.reactions.isNotEmpty && !isDeleted)
                          Positioned(
                            bottom: -4,
                            left: !isMe ? 4 : null,
                            right: isMe ? 4 : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2C34),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ), // Cutout overlap
                              ),
                              child: Text(
                                message.reactions
                                    .map((r) => r.emoji)
                                    .toSet()
                                    .join(' '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

    if (_isSelectionMode) return bubbleContent;

    return Dismissible(
      key: ValueKey(message.id),
      direction: isMe
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      background: Container(
        color: Colors.transparent,
      ), // Invisible swipe background
      confirmDismiss: (direction) async {
        setState(() {
          _replyingTo = message;
        });
        return false; // Don't actually dismiss
      },
      child: bubbleContent,
    );
  }

  bool _isEmojiOnly(String text) {
    // Basic regex for emoji checking (simplified)
    final RegExp emojiRegex = RegExp(
      r'^(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])+$',
    );
    return text.isNotEmpty &&
        emojiRegex.hasMatch(text) &&
        text.trim().length < 10;
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
                final hasReacted = message.reactions.any(
                  (r) => r.userId == widget.currentUserId && r.emoji == emoji,
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (hasReacted) {
                        _webSocketService.removeReaction(
                          message.id,
                          widget.currentUserId,
                          emoji,
                        );
                      } else {
                        _webSocketService.addReaction(
                          message.id,
                          widget.currentUserId,
                          emoji,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasReacted
                            ? Colors.blue.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: hasReacted
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black, // Ensure background matches
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null) ...[
            // ... keys reply logic same, just ensure dark theme
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: Color(0xFF00A884), width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF00A884)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo?.sender?.email ?? 'Sender',
                          style: const TextStyle(
                            color: Color(0xFF00A884),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyingTo?.content ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF2A3942,
                    ), // Lighter gray for better contrast
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 6,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal:
                            20, // Add padding so text doesn't touch edge
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF00A884), // WhatsApp Green
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          _messageController.text.trim().isEmpty
                              ? Icons.mic
                              : Icons.send,
                          color: Colors.white,
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
