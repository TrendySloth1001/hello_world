import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import '../services/notification_service.dart';
import '../models/workspace.dart';
import '../models/notification.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();
  final NotificationService _notificationService = NotificationService();

  List<WorkspaceInvite> _invites = [];
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _workspaceService.getMyInvites(),
        _notificationService.getNotifications(),
      ]);

      if (mounted) {
        setState(() {
          _invites = results[0] as List<WorkspaceInvite>;
          _notifications = results[1] as List<NotificationModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Don't show error snackbar immediately on load to avoid spam if one service fails
        print('Error loading notifications: $e');
      }
    }
  }

  Future<void> _respondToInvite(int requestId, bool accept) async {
    try {
      await _workspaceService.respondToInvite(requestId, accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Invite accepted!' : 'Invite declined'),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _notificationService.markAsRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          // Update local state to reflect read status
          // In a real app we might move it to "read" section or styled differently
          // For now, just reload to keep it simple or update list
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            title: _notifications[index].title,
            message: _notifications[index].message,
            type: _notifications[index].type,
            priority: _notifications[index].priority,
            isRead: true, // Mark as read locally
            readAt: DateTime.now(),
            actionUrl: _notifications[index].actionUrl,
            metadata: _notifications[index].metadata,
            createdAt: _notifications[index].createdAt,
            expiresAt: _notifications[index].expiresAt,
          );
        }
      });
    } catch (e) {
      // Ignore error for UI smoothness
    }
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await _notificationService.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () async {
                await _notificationService.markAllAsRead();
                _loadData();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _invites.isEmpty && _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.white,
              backgroundColor: Colors.black,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_invites.isNotEmpty) ...[
                    const Text(
                      'Invites',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._invites.map((invite) => _buildInviteCard(invite)),
                    const SizedBox(height: 24),
                  ],

                  if (_notifications.isNotEmpty) ...[
                    if (_invites.isNotEmpty)
                      const Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(height: 12),
                    ..._notifications.map((n) => _buildNotificationCard(n)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _buildNotificationIcon(notification),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.bold,
              color: notification.isRead ? Colors.white60 : Colors.white,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: TextStyle(
                  color: notification.isRead ? Colors.white38 : Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                timeago.format(notification.createdAt),
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
          onTap: () {
            if (!notification.isRead) {
              _markAsRead(notification.id);
            }
            // Handle action URL if present
          },
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationModel n) {
    IconData icon;
    Color color;

    switch (n.type) {
      case 'task':
        icon = Icons.check_circle_outline;
        color = Colors.blue;
        break;
      case 'workspace':
        icon = Icons.work_outline;
        color = Colors.amber;
        break;
      case 'system':
        icon = Icons.info_outline;
        color = Colors.purple;
        break;
      case 'general':
      default:
        icon = Icons.notifications_outlined;
        color = Colors.grey;
    }

    if (n.priority == 'urgent' || n.priority == 'high') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildInviteCard(WorkspaceInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
        ), // Highlight invites
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  image: invite.workspaceAvatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(invite.workspaceAvatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: invite.workspaceAvatarUrl == null
                    ? const Icon(
                        Icons.work_outline,
                        color: Colors.amber,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitation to join',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invite.workspaceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToInvite(invite.id, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToInvite(invite.id, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
