import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/workspace_service.dart';
import '../models/workspace.dart';

class WorkspaceDetailScreen extends StatefulWidget {
  final int workspaceId;
  final bool isOwner;
  final String ownerEmail;
  final String? ownerAvatarUrl;

  const WorkspaceDetailScreen({
    super.key,
    required this.workspaceId,
    required this.isOwner,
    required this.ownerEmail,
    this.ownerAvatarUrl,
  });

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends State<WorkspaceDetailScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();

  List<WorkspaceMember> _members = [];
  List<JoinRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _workspaceService.getMembers(widget.workspaceId);
      List<JoinRequest> requests = [];
      if (widget.isOwner) {
        requests = await _workspaceService.getJoinRequests(widget.workspaceId);
      }
      setState(() {
        _members = members;
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    final emailController = TextEditingController();
    InviteUser? foundUser;
    bool isSearching = false;
    bool isInviting = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Add Member',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Enter exact email',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorText: errorMessage,
                        ),
                        onSubmitted: (value) async {
                          if (value.isEmpty) return;
                          setState(() {
                            isSearching = true;
                            errorMessage = null;
                            foundUser = null;
                          });
                          try {
                            final user = await _workspaceService
                                .searchUserByEmail(value.trim());
                            setState(() => foundUser = user);
                          } catch (e) {
                            setState(() {
                              errorMessage = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              );
                              foundUser = null;
                            });
                          } finally {
                            setState(() => isSearching = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final value = emailController.text;
                        if (value.isEmpty) return;
                        setState(() {
                          isSearching = true;
                          errorMessage = null;
                          foundUser = null;
                        });
                        try {
                          final user = await _workspaceService
                              .searchUserByEmail(value.trim());
                          setState(() => foundUser = user);
                        } catch (e) {
                          setState(() {
                            errorMessage = e.toString().replaceAll(
                              'Exception: ',
                              '',
                            );
                            foundUser = null;
                          });
                        } finally {
                          setState(() => isSearching = false);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (foundUser != null) ...[
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
                          radius: 20,
                          backgroundImage: foundUser!.avatarUrl != null
                              ? NetworkImage(foundUser!.avatarUrl!)
                              : null,
                          child: foundUser!.avatarUrl == null
                              ? Text(foundUser!.email[0].toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            foundUser!.email,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isInviting
                              ? null
                              : () async {
                                  setState(() => isInviting = true);
                                  try {
                                    await _workspaceService.inviteUser(
                                      widget.workspaceId,
                                      foundUser!.email,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Invite sent successfully!',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      setState(() => isInviting = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isInviting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Invite'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkspaceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Workspace Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(
                Icons.person_add_outlined,
                color: Colors.white,
              ),
              title: const Text('Add Member'),
              onTap: () {
                Navigator.pop(context);
                _showAddMemberDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text('Rename Workspace'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.white),
              title: const Text('Change Avatar'),
              onTap: () {
                Navigator.pop(context);
                _showAvatarPicker();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog() async {
    // Determine the current name; if unavailable, default to empty.
    // Since we don't store the workspace name in state separately,
    // we might need to fetch it or pass it.
    // For now we'll just start empty or assume updated from loadData.
    // NOTE: Ideally we should store workspace details in state.
    // Assuming workspace name logic needs to be handled.
    // Let's create a controller but we don't have the current name easily accessible
    // unless we store the full workspace object.

    // Simplification: Fetch workspace details first or just prompt.
    // Let's assume user knows the name or we can fetch it.
    // Actually, let's change _loadData to store the workspace object if possible.
    // But for now, we'll just show input.

    final controller = TextEditingController();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Rename Workspace'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new workspace name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.amber),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await _workspaceService.updateWorkspace(
          widget.workspaceId,
          name: newName,
        );
        _loadData(); // Reload to reflect changes if name is displayed anywhere
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workspace renamed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showAvatarPicker() async {
    List<String> avatarPresets = [];
    try {
      avatarPresets = await _workspaceService.getWorkspaceAvatarPresets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;

    final selectedAvatar = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose Avatar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: avatarPresets.length,
                itemBuilder: (context, index) {
                  final avatar = avatarPresets[index];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, avatar),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.group, size: 32),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedAvatar != null) {
      try {
        await _workspaceService.updateWorkspaceAvatar(
          widget.workspaceId,
          selectedAvatar,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workspace avatar updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _acceptRequest(JoinRequest request) async {
    try {
      await _workspaceService.acceptJoinRequest(widget.workspaceId, request.id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.user.email} has been added!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(JoinRequest request) async {
    try {
      await _workspaceService.rejectJoinRequest(widget.workspaceId, request.id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updatePosition(WorkspaceMember member) async {
    final controller = TextEditingController(text: member.position);

    final newPosition = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Edit Position',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                member.user.email,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Position / Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: 'e.g., Manager, Developer, Designer',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (newPosition != null && newPosition.isNotEmpty) {
      try {
        await _workspaceService.updateMemberPosition(
          widget.workspaceId,
          member.userId,
          newPosition,
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Position updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _kickMember(WorkspaceMember member) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remove Member?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove ${member.user.email}?',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _workspaceService.kickMember(widget.workspaceId, member.userId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member removed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Workspace',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.isOwner) ...[
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: _showWorkspaceSettings,
                      tooltip: 'Settings',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Share feature coming soon'),
                          ),
                        );
                      },
                      tooltip: 'Share Invite',
                    ),
                  ],
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: Colors.white,
                      backgroundColor: Colors.black,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Join Requests Section (Owner only)
                          if (widget.isOwner && _requests.isNotEmpty) ...[
                            _buildSectionHeader(
                              'PENDING REQUESTS',
                              Icons.person_add_outlined,
                              _requests.length.toString(),
                            ),
                            const SizedBox(height: 12),
                            ..._requests.map(_buildRequestCard),
                            const SizedBox(height: 24),
                          ],

                          // Owner Section (pinned at top)
                          _buildSectionHeader(
                            'CREATOR',
                            Icons.workspace_premium_outlined,
                            '1',
                          ),
                          const SizedBox(height: 12),
                          _buildOwnerCard(),
                          const SizedBox(height: 24),

                          // Members Section
                          _buildSectionHeader(
                            'MEMBERS',
                            Icons.group_outlined,
                            (_members.length + 1).toString(),
                          ),
                          const SizedBox(height: 12),
                          if (_members.isEmpty)
                            _buildEmptyMembersState()
                          else
                            ..._members.map(_buildMemberCard),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMembersState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_off_outlined, size: 48, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No members yet',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Share your invite ID to add members',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child:
                  widget.ownerAvatarUrl != null &&
                      widget.ownerAvatarUrl!.isNotEmpty
                  ? Image.network(
                      widget.ownerAvatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          widget.ownerEmail.isNotEmpty
                              ? widget.ownerEmail[0].toUpperCase()
                              : 'O',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.ownerEmail.isNotEmpty
                            ? widget.ownerEmail[0].toUpperCase()
                            : 'O',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ownerEmail,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'Creator',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(JoinRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                request.user.email[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.user.email,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(request.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _acceptRequest(request),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _rejectRequest(request),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(WorkspaceMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child:
                  member.user.avatarUrl != null &&
                      member.user.avatarUrl!.isNotEmpty
                  ? Image.network(
                      member.user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          member.user.email[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        member.user.email[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.user.email,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    member.position,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white38),
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'position') {
                  _updatePosition(member);
                } else if (value == 'kick') {
                  _kickMember(member);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'position',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Position'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'kick',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 20,
                        color: Colors.red,
                      ),
                      SizedBox(width: 12),
                      Text('Remove', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
