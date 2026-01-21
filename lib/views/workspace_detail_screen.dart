import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/workspace_service.dart';
import '../services/task_service.dart';
import '../models/workspace.dart';
import '../models/task.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

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
  final TaskService _taskService = TaskService();

  List<WorkspaceMember> _members = [];
  List<JoinRequest> _requests = [];
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load Members
    try {
      final members = await _workspaceService.getMembers(widget.workspaceId);
      if (mounted) {
        setState(() => _members = members);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading members: $e');
        // We might not want to show a snackbar for every partial failure to avoid spamming the user
        // but since they complained about visibility, maybe logging is enough or a specific error message.
        // Let's rely on the lists being empty visually or just log.
      }
    }

    // Load Tasks
    try {
      final tasks = await _taskService.getWorkspaceTasks(widget.workspaceId);
      if (mounted) {
        setState(() => _tasks = tasks);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading tasks: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Load Requests
    if (widget.isOwner) {
      try {
        final requests = await _workspaceService.getJoinRequests(
          widget.workspaceId,
        );
        if (mounted) {
          setState(() => _requests = requests);
        }
      } catch (e) {
        debugPrint('Error loading join requests: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showMembersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Members',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.isOwner)
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.amber),
                        onPressed: () {
                          Navigator.pop(
                            context,
                          ); // Close sheet first? Or stack?
                          _showAddMemberDialog();
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (widget.isOwner && _requests.isNotEmpty) ...[
                      const Text(
                        'Join Requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._requests.map((request) => _buildRequestCard(request)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Colors.white24),
                      ),
                    ],
                    ..._members.map((member) => _buildMemberCard(member)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(JoinRequest request) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.user?.avatarUrl != null
              ? NetworkImage(request.user!.avatarUrl!)
              : null,
          child: request.user?.avatarUrl == null
              ? Text(request.user?.email[0].toUpperCase() ?? '?')
              : null,
        ),
        title: Text(
          request.user?.email ?? 'Unknown User',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: const Text(
          'Requested to join',
          style: TextStyle(color: Colors.white54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                Navigator.pop(context); // Close sheet
                await _workspaceService.acceptJoinRequest(
                  widget.workspaceId,
                  request.id,
                );
                _loadData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await _workspaceService.rejectJoinRequest(
                  widget.workspaceId,
                  request.id,
                );
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(WorkspaceMember member) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: member.user.avatarUrl != null
              ? NetworkImage(member.user.avatarUrl!)
              : null,
          child: member.user.avatarUrl == null
              ? Text(member.user.email[0].toUpperCase())
              : null,
        ),
        title: Text(
          member.user.email,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          member.position,
          style: const TextStyle(color: Colors.amber, fontSize: 12),
        ),
        trailing:
            widget.isOwner &&
                member.userId !=
                    0 // Assuming we can identify owner safely
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                onSelected: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Action $value not implemented on backend yet',
                      ),
                    ),
                  );
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'CHANGE_POSITION',
                    child: Text('Change Position'),
                  ),
                  const PopupMenuItem(
                    value: 'KICK',
                    child: Text(
                      'Kick Member',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('Workspace Details'),
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline),
                onPressed: _showMembersSheet,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: _showWorkspaceSettings,
              ),
            ],
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildTasksList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CreateTaskScreen(
              workspaceId: widget.workspaceId,
              currentUserId: 0,
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildTasksList() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No tasks yet', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              task.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description != null && task.description!.isNotEmpty)
                  Text(
                    task.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          task.status,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(task.status),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(task.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (task.assignments != null &&
                        task.assignments!.isNotEmpty)
                      SizedBox(
                        height: 20,
                        width: 60, // Limit width for stack
                        child: Stack(
                          children: List.generate(
                            task.assignments!.length > 3
                                ? 3
                                : task.assignments!.length,
                            (i) {
                              final user = task.assignments![i].user;
                              return Positioned(
                                left: i * 14.0,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundImage: user?.avatarUrl != null
                                      ? NetworkImage(user!.avatarUrl!)
                                      : null,
                                  child: user?.avatarUrl == null
                                      ? Text(
                                          user?.email[0].toUpperCase() ?? 'U',
                                          style: const TextStyle(fontSize: 8),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(
                    taskId: task.id,
                    currentUserId: 0, // Placeholder
                  ),
                ),
              );
              _loadData(); // Refresh on return
            },
          ),
        );
      },
    );
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
            color: Color(0xFF1E1E1E),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter exact email',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorText: errorMessage,
                        ),
                        onSubmitted: (value) async {
                          if (value.isEmpty || isSearching) return;
                          setState(() {
                            isSearching = true;
                            errorMessage = null;
                            foundUser = null;
                          });
                          try {
                            final user = await _workspaceService
                                .searchUserByEmail(value.trim());
                            if (context.mounted) {
                              setState(() => foundUser = user);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() {
                                errorMessage = e.toString().replaceAll(
                                  'Exception: ',
                                  '',
                                );
                                foundUser = null;
                              });
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isSearching = false);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: isSearching
                            ? null
                            : () async {
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
                                  if (context.mounted) {
                                    setState(() => foundUser = user);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setState(() {
                                      errorMessage = e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      );
                                      foundUser = null;
                                    });
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isSearching = false);
                                  }
                                }
                              },
                        icon: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
                if (foundUser != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: foundUser!.avatarUrl != null
                                  ? NetworkImage(foundUser!.avatarUrl!)
                                  : null,
                              child: foundUser!.avatarUrl == null
                                  ? Text(foundUser!.email[0].toUpperCase())
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foundUser!.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    'User found',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isInviting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Invite User to Workspace'),
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
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Workspace Name'),
              onTap: () {
                Navigator.pop(context);
                _showEditNameDialog();
              },
            ),
            if (widget.isOwner) ...[
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Change Avatar'),
                onTap: () {
                  Navigator.pop(context);
                  _showAvatarPicker();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Invite Member'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddMemberDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Workspace',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // _confirmDelete();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAvatarPicker() async {
    try {
      final avatars = await _workspaceService.getWorkspaceAvatarPresets();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      try {
                        await _workspaceService.updateWorkspaceAvatar(
                          widget.workspaceId,
                          avatars[index],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Avatar updated')),
                          );
                        }
                        // Notify parent? We might need to refresh parent or pass avatar back.
                        // But this screen doesn't show workspace avatar in app bar yet?
                        // Actually the parent (Home) shows it. We might need to invoke callback or just refresh logic.
                        // The user didn't ask to fix header avatar, but I should probably make sure it updates.
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update avatar: $e'),
                            ),
                          );
                        }
                      }
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(avatars[index]),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load avatars: $e')));
      }
    }
  }

  Future<void> _showEditNameDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Edit Workspace Name',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'New workspace name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                // TODO: Implement update workspace in service if not already, or simulate
                await _workspaceService.updateWorkspace(
                  widget.workspaceId,
                  name: nameController.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workspace name updated')),
                );
                // Note: Title in app bar is 'Workspace Details' static.
                // We should probably pass name to screen or fetch it.
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DONE':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.blue;
      default:
        return Colors.amber;
    }
  }
}
