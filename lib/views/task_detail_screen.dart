import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  final int currentUserId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.currentUserId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskService = TaskService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  Task? _task;
  bool _isLoading = true;
  bool _isSendingComment = false;
  int? _replyingToCommentId; // ID of the comment being replied to
  String? _replyingToUserEmail; // Email for display in input

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    try {
      final task = await _taskService.getTaskDetails(widget.taskId);
      if (mounted) {
        setState(() {
          _task = task;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load task: $e')));
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSendingComment = true);
    try {
      await _taskService.addComment(
        widget.taskId,
        _commentController.text.trim(),
        parentId: _replyingToCommentId,
      );
      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserEmail = null;
      });
      await _loadTask(); // Refresh to show new comment
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _toggleLike(int commentId) async {
    // Optimistic Update
    setState(() {
      _applyOptimisticLike(_task!.comments!, commentId, widget.currentUserId);
    });

    try {
      await _taskService.toggleCommentLike(commentId);
      // We could reload to sync exact server state, but optimistic is reliable enough for likes
      // _loadTask();
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _applyOptimisticLike(
            _task!.comments!,
            commentId,
            widget.currentUserId,
          );
        });
        // Optional: Show error only if it's NOT a unique constraint failure (which implies race/double click success)
        if (!e.toString().contains('Unique constraint')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
        }
      }
    }
  }

  bool _applyOptimisticLike(List<Comment> comments, int targetId, int userId) {
    for (var comment in comments) {
      if (comment.id == targetId) {
        final existingLikeIndex =
            comment.likes?.indexWhere((l) => l.userId == userId) ?? -1;
        if (existingLikeIndex != -1) {
          // Unlike
          comment.likes!.removeAt(existingLikeIndex);
        } else {
          // Like
          comment.likes ??= [];
          comment.likes!.add(
            CommentLike(id: 0, userId: userId, commentId: targetId),
          );
        }
        return true;
      }
      if (comment.replies != null) {
        if (_applyOptimisticLike(comment.replies!, targetId, userId))
          return true;
      }
    }
    return false;
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await _taskService.updateTask(widget.taskId, {'status': newStatus});
      _loadTask();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _respondToTask(String status) async {
    try {
      String? reason;
      if (status == 'REJECTED') {
        reason = await _showRejectDialog();
        if (reason == null) return; // Cancelled
      }
      await _taskService.respondToTask(
        widget.taskId,
        status,
        rejectionReason: reason,
      );

      if (status == 'REJECTED' && reason != null) {
        // Optionally add a comment automatically, though backend might not do it,
        // the previous code did it on frontend.
        // Let's keep the manual comment add if desired, or rely on backend activity logging.
        // Previous code: await _taskService.addComment(widget.taskId, "Rejected task: $reason");
        // Backend now stores reason in assignment.
        // Let's explicitly add a comment so it's visible in chat too.
        await _taskService.addComment(widget.taskId, "Rejected task: $reason");
      }

      _loadTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task $status'),
            backgroundColor: status == 'ACCEPTED' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to respond: $e')));
      }
    }
  }

  Future<void> _claimTask() async {
    try {
      await _taskService.claimTask(widget.taskId);
      _loadTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task Claimed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to claim task: $e')));
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reject Task', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Reason for rejection...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
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
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _startReply(int commentId, String userEmail) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserEmail = userEmail;
    });
    // Focus input
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserEmail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_task == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Task not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    // Find current user's assignment
    final myAssignment = _task!.assignments?.firstWhere(
      (a) => a.user?.id == widget.currentUserId,
      orElse: () => TaskAssignment(
        id: 0,
        taskId: 0,
        status: 'NONE',
        timestamp: DateTime.now(),
      ),
    );
    // Note: The orElse return is a dummy and won't have a user, so be careful checking `myAssignment.user`

    final isAssignedToMe =
        myAssignment != null &&
        myAssignment.status != 'NONE' &&
        myAssignment.user != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E1E1E),
            onSelected: _updateStatus,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'TODO',
                child: Text(
                  'Mark as TODO',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'IN_PROGRESS',
                child: Text(
                  'Mark as In Progress',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'DONE',
                child: Text(
                  'Mark as Done',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_task!.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(_task!.status)),
                    ),
                    child: Text(
                      _task!.status.replaceAll('_', ' '),
                      style: TextStyle(
                        color: _getStatusColor(_task!.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _task!.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_task!.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _task!.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Meta Data
                  Row(
                    children: [
                      _buildMetaItem(
                        Icons.flag_outlined,
                        'Priority',
                        _task!.priority,
                      ),
                      const SizedBox(width: 24),
                      if (_task!.dueDate != null)
                        _buildMetaItem(
                          Icons.calendar_today_outlined,
                          'Due Date',
                          DateFormat('MMM d, y').format(_task!.dueDate!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Assignments List
                  const Text(
                    'Assignees',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_task!.assignments != null &&
                      _task!.assignments!.isNotEmpty)
                    ..._task!.assignments!.map(
                      (assignment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage:
                                  assignment.user?.avatarUrl != null
                                  ? NetworkImage(assignment.user!.avatarUrl!)
                                  : null,
                              child: assignment.user?.avatarUrl == null
                                  ? Text(
                                      assignment.user?.email[0].toUpperCase() ??
                                          'U',
                                      style: const TextStyle(fontSize: 10),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              assignment.user?.email ?? 'Unknown',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            _buildAssignmentStatusBadge(assignment.status),
                          ],
                        ),
                      ),
                    )
                  else
                    const Text(
                      'No assignees',
                      style: TextStyle(color: Colors.white38),
                    ),

                  const SizedBox(height: 32),
                  // Assignment Approval (Only for me if Pending)
                  if (isAssignedToMe && myAssignment!.status == 'PENDING') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Task Assigned to You',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please accept or reject this task assignment.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respondToTask('REJECTED'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.red.withOpacity(0.5),
                                    ),
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _respondToTask('ACCEPTED'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Claim Task Section
                  if (_task!.isOpen) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Open Task',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This task is open for anyone to claim.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _claimTask,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Claim Task'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_task!.comments != null && _task!.comments!.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _task!.comments!.length,
                      itemBuilder: (context, index) {
                        return _buildCommentTree(_task!.comments![index]);
                      },
                    )
                  else
                    const Text(
                      'No comments yet.',
                      style: TextStyle(color: Colors.white38),
                    ),
                ],
              ),
            ),
          ),
          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                if (_replyingToUserEmail != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Text(
                          'Replying to $_replyingToUserEmail',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _cancelReply,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSendingComment ? null : _addComment,
                      icon: _isSendingComment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.amber),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'ACCEPTED':
        color = Colors.green;
        break;
      case 'REJECTED':
        color = Colors.red;
        break;
      default:
        color = Colors.amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCommentTree(Comment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(comment),
        if (comment.replies != null && comment.replies!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32.0), // Indent replies
            child: Column(
              children: comment.replies!
                  .map((reply) => _buildCommentTree(reply))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final hasLiked =
        comment.likes?.any((l) => l.userId == widget.currentUserId) ?? false;
    final likesCount = comment.likes?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment.user?.avatarUrl != null
                ? NetworkImage(comment.user!.avatarUrl!)
                : null,
            child: comment.user?.avatarUrl == null
                ? Text(
                    comment.user?.email[0].toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          comment.user?.email ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, h:mm a').format(comment.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  // Actions: Like & Reply
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _toggleLike(comment.id),
                        child: Row(
                          children: [
                            Icon(
                              hasLiked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: hasLiked ? Colors.red : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likesCount',
                              style: TextStyle(
                                color: hasLiked ? Colors.red : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _startReply(
                          comment.id,
                          comment.user?.email ?? 'Unknown',
                        ),
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
