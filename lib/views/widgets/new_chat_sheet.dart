import 'package:flutter/material.dart';
import 'dart:ui' as dart_ui;
import '../../services/workspace_service.dart';
import '../../services/chat_service.dart';
import '../../models/workspace.dart';
import '../conversation_screen.dart';

class NewChatSheet extends StatefulWidget {
  final int currentUserId;

  const NewChatSheet({super.key, required this.currentUserId});

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
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
      return;
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
          Navigator.pop(context); // Close sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationScreen(
                conversationId: conversation.id,
                conversationName: conversation.name ?? 'Group Chat',
                currentUserId: widget.currentUserId,
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

        if (conversation.lastMessage == null) {
          await _chatService.sendMessage(conversation.id, "Hey there!");
        }

        if (mounted) {
          Navigator.pop(context); // Close sheet
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
        // Show error in a clean way, maybe snackbar or text
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: bottomInset > 0 ? bottomInset + 20 : 40,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Indicator Pill
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Segmented Tabs with Glow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        'Direct Message',
                        !_isGroupMode,
                        () => setState(() => _isGroupMode = false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModeTab(
                        'Group Chat',
                        _isGroupMode,
                        () => setState(() => _isGroupMode = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // GROUP MODE INPUTS
              if (_isGroupMode) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildPremiumInput(
                    controller: _groupNameController,
                    hintText: 'Group Name',
                    icon: Icons.group_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                // Selected Members
                if (_groupMembers.isNotEmpty)
                  Container(
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: _groupMembers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final user = _groupMembers[index];
                        return Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blueAccent.shade400,
                                child: Text(
                                  user.email[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.email.split('@')[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeFromGroup(user),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],

              // USER SEARCH INPUT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildPremiumInput(
                  controller: _emailController,
                  hintText: _isGroupMode
                      ? 'Add Member by Email'
                      : 'Enter User Email',
                  icon: Icons.search,
                  onSubmitted: (_) => _searchUser(),
                  isSearchAction: true,
                  isLoading: _isSearching,
                  onActionPressed: _searchUser,
                ),
              ),

              const SizedBox(height: 20),

              // SEARCH RESULT PREVIEW (Glassmorphic Card)
              if (_foundUser != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      //color: Colors.white.withOpacity(0.08),

                      ///borderRadius: BorderRadius.circular(20),
                      //border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blueAccent.shade400,
                        backgroundImage: _foundUser!.avatarUrl != null
                            ? NetworkImage(_foundUser!.avatarUrl!)
                            : null,
                        child: _foundUser!.avatarUrl == null
                            ? Text(
                                _foundUser!.email[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        _foundUser!.email,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tap to ${_isGroupMode ? 'add' : 'start conversation'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      trailing: _isGroupMode
                          ? IconButton.filledTonal(
                              onPressed: _addToGroup,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                foregroundColor: Colors.blueAccent,
                              ),
                              icon: const Icon(Icons.add),
                            )
                          : IconButton.filled(
                              onPressed: _startChat,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ),
                  ),
                ),

              // GROUP CREATE BUTTON
              if (_isGroupMode && _groupMembers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isStartingChat ? null : _startChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.blueAccent.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      child: _isStartingChat
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Create Group (${_groupMembers.length})'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isSearchAction = false,
    bool isLoading = false,
    VoidCallback? onActionPressed,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onSubmitted: onSubmitted,
              textInputAction: isSearchAction
                  ? TextInputAction.search
                  : TextInputAction.next,
            ),
          ),
          if (isSearchAction)
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white30,
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                  onPressed: onActionPressed,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 0,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
