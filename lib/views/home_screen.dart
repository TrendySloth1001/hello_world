import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notifications_screen.dart';
import '../services/workspace_service.dart';

import '../models/workspace.dart';
import '../config/onboarding_config.dart';
import 'workspace_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();

  UserWorkspaces? _workspaces;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final workspaces = await _workspaceService.getMyWorkspaces();
      setState(() {
        _workspaces = workspaces;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _createWorkspace() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
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
                'Create Workspace',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a new workspace to collaborate with your team.',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Workspace Name',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Create Workspace'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await _workspaceService.createWorkspace(
          nameController.text,
          descController.text.isEmpty ? null : descController.text,
        );
        _loadWorkspaces();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workspace created successfully!'),
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

  Future<void> _joinWorkspace() async {
    final publicIdController = TextEditingController();

    final result = await showModalBottomSheet<String>(
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
                'Join Workspace',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the invite ID shared with you.',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: publicIdController,
                decoration: const InputDecoration(
                  labelText: 'Invite ID',
                  prefixIcon: Icon(Icons.link),
                  hintText: 'e.g., abc123-def456-...',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, publicIdController.text),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Request to Join'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _workspaceService.requestToJoin(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request sent! Waiting for approval.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TaskFlow',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage your workspaces',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: Stream.fromFuture(
                      _workspaceService.getMyInvites().then(
                        (invites) => invites.length,
                      ),
                    ),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              ).then((_) {
                                // Refresh count when returning
                                setState(() {});
                              });
                            },
                            tooltip: 'Notifications',
                          ),
                          if (count > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.group_add_outlined),
                    onPressed: _joinWorkspace,
                    tooltip: 'Join Workspace',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _loadWorkspaces,
                      color: Colors.white,
                      backgroundColor: Colors.black,
                      child: _buildWorkspaceList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_fab',
        onPressed: _createWorkspace,
        backgroundColor: Colors.transparent.withOpacity(0.4),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadWorkspaces,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceList() {
    final owned = _workspaces?.owned ?? [];
    final memberOf = _workspaces?.memberOf ?? [];

    if (owned.isEmpty && memberOf.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (owned.isNotEmpty) ...[
          _buildSectionHeader('MY WORKSPACES', '${owned.length}'),
          const SizedBox(height: 12),
          ...owned.map((w) => _buildWorkspaceCard(w, isOwner: true)),
          const SizedBox(height: 24),
        ],
        if (memberOf.isNotEmpty) ...[
          _buildSectionHeader('JOINED', '${memberOf.length}'),
          const SizedBox(height: 12),
          ...memberOf.map((w) => _buildWorkspaceCard(w, isOwner: false)),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AppAssets.welcome, height: 180, fit: BoxFit.contain),
            const SizedBox(height: 32),
            const Text(
              'No Workspaces Yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first workspace or join one\nusing an invite link.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createWorkspace,
              icon: const Icon(Icons.add),
              label: const Text('Create Workspace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String count) {
    return Row(
      children: [
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

  Widget _buildWorkspaceCard(Workspace workspace, {required bool isOwner}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkspaceDetailScreen(
              workspaceId: workspace.id,
              isOwner: isOwner,
              ownerEmail: workspace.owner.email,
              ownerAvatarUrl: workspace.owner.avatarUrl,
              workspaceName: workspace.name,
            ),
          ),
        ).then((_) => _loadWorkspaces());
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar + Title + Role + Chevron
                Row(
                  children: [
                    // Workspace Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child:
                            workspace.avatarUrl != null &&
                                workspace.avatarUrl!.isNotEmpty
                            ? Image.network(
                                workspace.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    workspace.name.isNotEmpty
                                        ? workspace.name[0].toUpperCase()
                                        : 'W',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  workspace.name.isNotEmpty
                                      ? workspace.name[0].toUpperCase()
                                      : 'W',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white38,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title & Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workspace.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOwner
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isOwner
                                    ? Colors.blue.withOpacity(0.3)
                                    : Colors.transparent,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              isOwner ? 'Owner' : 'Member',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isOwner
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: isOwner
                                    ? Colors.blue[200]
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 18,
                        color: Colors.white38,
                      ),
                      tooltip: 'Copy Workspace ID',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: workspace.publicId),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Workspace ID copied: ${workspace.publicId}',
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),

                // Description
                if (workspace.description != null &&
                    workspace.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 56,
                    ), // Align with text start
                    child: Text(
                      workspace.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Footer: Avatars
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _calculateStackWidth(workspace.memberCount),
                        height: 28,
                        child: Stack(children: _buildStackedAvatars(workspace)),
                      ),
                      if (workspace.memberCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${workspace.memberCount} members',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withOpacity(0.06),
          ),
        ],
      ),
    );
  }

  double _calculateStackWidth(int memberCount) {
    final displayCount = memberCount.clamp(0, 4);
    final hasMore = memberCount > 4;
    // Each avatar is 28px, overlap by 10px
    final avatarWidth =
        displayCount * 28.0 -
        (displayCount > 1 ? (displayCount - 1) * 10.0 : 0);
    return hasMore
        ? avatarWidth + 18
        : avatarWidth; // +18 for the "+n" indicator
  }

  List<Widget> _buildStackedAvatars(Workspace workspace) {
    final memberCount = workspace.memberCount;
    if (memberCount == 0) {
      return [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 16,
            color: Colors.white38,
          ),
        ),
      ];
    }

    final displayCount = memberCount.clamp(0, 4);
    final hasMore = memberCount > 4;
    final remaining = memberCount - 4;

    List<Widget> avatars = [];

    // Generate avatar circles using actual member avatars
    for (int i = 0; i < displayCount; i++) {
      // First avatar is owner, rest are from members list
      String? avatarUrl;
      String fallbackLetter;

      if (i == 0) {
        // Owner avatar
        avatarUrl = workspace.owner.avatarUrl;
        fallbackLetter = workspace.owner.email.isNotEmpty
            ? workspace.owner.email[0].toUpperCase()
            : 'O';
      } else if (i - 1 < workspace.members.length) {
        // Member avatar (offset by 1 since owner is first)
        avatarUrl = workspace.members[i - 1].user.avatarUrl;
        fallbackLetter = workspace.members[i - 1].user.email.isNotEmpty
            ? workspace.members[i - 1].user.email[0].toUpperCase()
            : 'M';
      } else {
        avatarUrl = null;
        fallbackLetter = '${i + 1}';
      }

      avatars.add(
        Positioned(
          left: i * 18.0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: i == 0 ? Colors.amber.withOpacity(0.3) : Colors.white12,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF111111), width: 2),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          fallbackLetter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: i == 0 ? Colors.amber : Colors.white54,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        fallbackLetter,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: i == 0 ? Colors.amber : Colors.white54,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    // Add "+n" indicator if more than 4 members
    if (hasMore) {
      avatars.add(
        Positioned(
          left: displayCount * 18.0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF111111), width: 2),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return avatars;
  }
}
