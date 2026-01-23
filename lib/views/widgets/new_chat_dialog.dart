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
  final TextEditingController _nicknameController = TextEditingController();

  // Group Chat State
  bool _isGroupMode = false;
  final TextEditingController _groupNameController = TextEditingController();
  final List<InviteUser> _groupMembers = [];

  InviteUser? _foundUser;
  bool _isSearching = false;
  bool _isStartingChat = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _groupNameController.dispose();
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
          // Reset nickname when new user found
          _nicknameController.clear();
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
    if (!_isGroupMode && _foundUser == null) return;
    if (_isGroupMode &&
        (_groupMembers.isEmpty || _groupNameController.text.trim().isEmpty)) {
      setState(() => _errorMessage = 'Please enter a name and add members');
      return;
    }

    setState(() => _isStartingChat = true);

    try {
      if (_isGroupMode) {
        final conversation = await _chatService.createGroupChat(
          _groupNameController.text.trim(),
          _groupMembers.map((u) => u.id).toList(),
        );

        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationScreen(
                conversationId: conversation.id,
                conversationName: conversation.name ?? 'Group Chat',
                currentUserId: widget.currentUserId,
                // No target user ID for groups, or handle logic
                // No avatar for now, backend might provide one
              ),
            ),
          );
        }
      } else {
        // Direct Chat
        final nickname = _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : null;

        final conversation = await _chatService.getOrCreateDirectChat(
          _foundUser!.id,
          nickname: nickname,
        );

        // 2. Auto-send "Hey there!" if new
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
                conversationName: nickname ?? _foundUser!.email,
                currentUserId: widget.currentUserId,
                targetUserId: _foundUser!.id,
                avatarUrl: _foundUser!.avatarUrl,
              ),
            ),
          );
        }
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

  void _addToGroup() {
    if (_foundUser == null) return;
    if (_groupMembers.any((m) => m.id == _foundUser!.id)) {
      setState(() => _errorMessage = 'User already added');
      return;
    }
    setState(() {
      _groupMembers.add(_foundUser!);
      _foundUser = null;
      _emailController.clear();
      _errorMessage = null;
    });
  }

  void _removeFromGroup(InviteUser user) {
    setState(() {
      _groupMembers.removeWhere((m) => m.id == user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildTypeButton('Direct', false),
                      const SizedBox(width: 12),
                      _buildTypeButton('Group', true),
                    ],
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

              // Group Name Input
              if (_isGroupMode) ...[
                TextField(
                  controller: _groupNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Project Team',
                    prefixIcon: const Icon(Icons.group, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_groupMembers.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groupMembers.map((user) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.blue.shade900,
                          child: Text(
                            user.email[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        label: Text(
                          user.email,
                          style: const TextStyle(color: Colors.black),
                        ),
                        backgroundColor: Colors.white,
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.black54,
                        ),
                        onDeleted: () => _removeFromGroup(user),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Search Field
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: _isGroupMode
                      ? 'Add Member (Email)'
                      : 'Enter user email',
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

              // Search Result (Found User)
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
                        backgroundImage: _foundUser!.avatarUrl != null
                            ? NetworkImage(_foundUser!.avatarUrl!)
                            : null,
                        child: _foundUser!.avatarUrl == null
                            ? Text(
                                _foundUser!.email[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundUser!.email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_isGroupMode)
                        IconButton(
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.blue,
                          ),
                          onPressed: _addToGroup,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Nickname Field (Direct Only)
                if (!_isGroupMode)
                  TextField(
                    controller: _nicknameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nickname (Optional)',
                      hintText: 'e.g. Project Manager',
                      prefixIcon: const Icon(Icons.edit, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // Action Button
              // In group mode, button is always visible (even if no user found currently), but disabled if validation fails
              if (!_isGroupMode || (_isGroupMode && _foundUser == null))
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
                      : Icon(
                          _isGroupMode ? Icons.group_add : Icons.send,
                          color: Colors.white,
                        ),
                  label: Text(
                    _isGroupMode ? 'Create Group' : 'Send Message',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, bool isGroup) {
    final isSelected = _isGroupMode == isGroup;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGroupMode = isGroup;
          _errorMessage = null;
          _foundUser = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
