import 'package:flutter/material.dart';
import '../../services/workspace_service.dart';
import '../../services/chat_service.dart';
import '../../models/workspace.dart'; // For InviteUser
import '../conversation_screen.dart';

class NewChatDialog extends StatefulWidget {
  final int currentUserId;

  const NewChatDialog({super.key, required this.currentUserId});

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final WorkspaceService _workspaceService = WorkspaceService();
  final ChatService _chatService = ChatService();
  final TextEditingController _emailController = TextEditingController();

  InviteUser? _foundUser;
  bool _isSearching = false;
  bool _isStartingChat = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    if (email.toLowerCase() == 'me' ||
        email == widget.currentUserId.toString()) {
      // Prevent chatting with self if needed, or handle gracefully
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundUser = null;
    });

    try {
      final user = await _workspaceService.searchUserByEmail(email);
      if (user.id == widget.currentUserId) {
        throw Exception("You cannot chat with yourself.");
      }

      if (mounted) {
        setState(() {
          _foundUser = user;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _startChat() async {
    if (_foundUser == null) return;

    setState(() => _isStartingChat = true);

    try {
      // 1. Create/Get Direct Chat
      final conversation = await _chatService.getOrCreateDirectChat(
        _foundUser!.id,
      );

      // 2. Auto-send "Hey there!"
      // Check if it's a new chat or existing?
      // The requirement says "automatically sends hey there! and build a communication bridge".
      // We can check if messages exist, or just send it if it's a fresh intent.
      // For simplicity/robustness, we'll send it. Ideally we might want to check if the conversation is empty.
      // But "getOrCreate" returns the conversation. We can check if it has a lastMessage?
      // The current model 'Conversation' has 'lastMessage'.

      if (conversation.lastMessage == null) {
        await _chatService.sendMessage(conversation.id, "Hey there!");
      }

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationScreen(
              conversationId: conversation.id,
              conversationName: _foundUser!.email,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStartingChat = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Field
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Enter user email',
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.blue,
                        ),
                        onPressed: _searchUser,
                      ),
              ),
              onSubmitted: (_) => _searchUser(),
              textInputAction: TextInputAction.search,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],

            // Search Result
            if (_foundUser != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade900,
                      child: Text(
                        _foundUser!.email[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _foundUser!.email,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isStartingChat ? null : _startChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isStartingChat
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  'Send Message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
