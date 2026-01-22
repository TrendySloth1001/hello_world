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
  List<Comment> _comments = [];
  bool _isLoadingTask = true;
  bool _isLoadingComments = false;
  bool _isSendingComment = false;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  static const int _limit = 20;

  int? _replyingToCommentId;
  String? _replyingToUserEmail;

  @override
  void initState() {
    super.initState();
    _loadTask();
    _loadComments(reset: true);

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingComments && _currentPage < _totalPages) {
        _loadComments();
      }
    }
  }

  Future<void> _loadTask() async {
    try {
      final task = await _taskService.getTaskDetails(widget.taskId);
      if (mounted) {
        setState(() {
          _task = task;
          _isLoadingTask = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTask = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load task: $e')));
      }
    }
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (_isLoadingComments) return;

    if (reset) {
      setState(() {
        _comments = [];
        _currentPage = 1;
        _isLoadingComments = true;
      });
    } else {
      setState(() => _isLoadingComments = true);
    }

    try {
      final result = await _taskService.getComments(
        widget.taskId,
        page: _currentPage,
        limit: _limit,
      );

      final newComments = (result['comments'] as List)
          .map((e) => Comment.fromJson(e))
          .toList();

      final meta = result['meta'];

      if (mounted) {
        setState(() {
          if (reset) {
            _comments = newComments;
          } else {
            _comments.addAll(newComments);
          }
          _totalPages = meta['totalPages'];
          if (_currentPage < _totalPages) _currentPage++;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
        // Silent fail or toast
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

      // Refresh comments from scratch to show the new one at the top
      await _loadComments(reset: true);
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
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index != -1) {
      setState(() {
        final isLiked = _comments[index].likes.any(
          (l) => l.userId == widget.currentUserId,
        );
        if (isLiked) {
          _comments[index].likes.removeWhere(
            (l) => l.userId == widget.currentUserId,
          );
        } else {
          _comments[index].likes.add(
            CommentLike(
              id: 0,
              userId: widget.currentUserId,
              commentId: commentId,
            ),
          );
        }
      });
    }

    try {
      await _taskService.toggleCommentLike(commentId);
    } catch (e) {
      _loadComments(reset: true); // Revert on failure
    }
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
        // Show dialog
        final controller = TextEditingController();
        reason = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Reject Task',
              style: TextStyle(color: Colors.white),
            ),
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
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (reason == null) return;
      }

      await _taskService.respondToTask(
        widget.taskId,
        status,
        rejectionReason: reason,
      );

      // Add comment if rejected
      if (status == 'REJECTED' && reason != null) {
        await _taskService.addComment(widget.taskId, "Rejected task: $reason");
        _loadComments(reset: true);
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

  void _startReply(int commentId, String userEmail) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserEmail = userEmail;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserEmail = null;
    });
  }

  Color _getPriorityColor(String priority) {
    if (priority == 'HIGH') return Colors.red;
    if (priority == 'MEDIUM') return Colors.orange;
    return Colors.blue;
  }

  Color _getStatusColor(String status) {
    if (status == 'DONE') return Colors.green;
    if (status == 'IN_PROGRESS') return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTask) {
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildTaskHeader()),
                SliverToBoxAdapter(child: _buildAssignmentSection()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Comments', // Removed count as it might be misleading with pagination
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _comments.length) {
                        return _isLoadingComments
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink();
                      }
                      return _buildCommentItem(_comments[index]);
                    },
                    childCount: _comments.length + (_isLoadingComments ? 1 : 0),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ), // Space for input
              ],
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(_task!.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor(_task!.status)),
            ),
            child: Text(
              _task!.status.replaceAll('_', ' '),
              style: TextStyle(
                color: _getStatusColor(_task!.status),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[800],
                backgroundImage: _task!.createdBy?.avatarUrl != null
                    ? NetworkImage(_task!.createdBy!.avatarUrl!)
                    : null,
                child: _task!.createdBy?.avatarUrl == null
                    ? Text(_task!.createdBy?.email[0].toUpperCase() ?? 'U')
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _task!.createdBy?.email ?? 'Unknown User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'MMM d, yyyy • h:mm a',
                    ).format(_task!.createdAt.toLocal()),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(_task!.priority).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getPriorityColor(_task!.priority)),
                ),
                child: Text(
                  _task!.priority,
                  style: TextStyle(
                    color: _getPriorityColor(_task!.priority),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _task!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_task!.description != null && _task!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _task!.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentSection() {
    // Logic for showing assignment status / buttons
    final myAssignment = _task!.assignments?.firstWhere(
      (a) => a.user?.id == widget.currentUserId,
      orElse: () => TaskAssignment(
        id: 0,
        taskId: 0,
        status: 'NONE',
        timestamp: DateTime.now(),
      ),
    );
    // Be careful with the dummy object having no user
    final isAssignedToMe =
        myAssignment != null &&
        myAssignment.status != 'NONE' &&
        (myAssignment.id != 0);

    // 1. Pending Assignment Actions
    if (isAssignedToMe && myAssignment?.status == 'PENDING') {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Assigned to You',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please accept or reject this assignment.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToTask('REJECTED'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
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
      );
    }

    // 2. Open Task Actions
    if (_task!.isOpen) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Text(
              'Open Task',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCommentItem(Comment comment) {
    final isLiked = comment.likes.any((l) => l.userId == widget.currentUserId);
    final likeCount = comment.likes.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: comment.user?.avatarUrl != null
                ? NetworkImage(comment.user!.avatarUrl!)
                : null,
            child: comment.user?.avatarUrl == null
                ? Text(comment.user?.email[0].toUpperCase() ?? 'U')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.user?.email ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(comment.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(comment.id),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isLiked ? Colors.red : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (likeCount > 0)
                      Text(
                        '$likeCount',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),

                    const SizedBox(width: 24),

                    InkWell(
                      onTap: () =>
                          _startReply(comment.id, comment.user?.email ?? ''),
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (comment.replies != null && comment.replies!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: comment.replies!
                          .map((reply) => _buildReplyItem(reply))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Comment reply) {
    final isLiked = reply.likes.any((l) => l.userId == widget.currentUserId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[800],
            backgroundImage: reply.user?.avatarUrl != null
                ? NetworkImage(reply.user!.avatarUrl!)
                : null,
            child: reply.user?.avatarUrl == null
                ? Text(
                    reply.user?.email[0].toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.user?.email ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(reply.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.content,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(reply.id),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: isLiked ? Colors.red : Colors.grey[500],
                      ),
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

  Widget _buildInputArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_replyingToCommentId != null)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      'Replying to ${_replyingToUserEmail ?? 'comment'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: _cancelReply,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue,
                  child: const Text(
                    'Me',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyingToCommentId != null
                          ? 'Add a reply...'
                          : 'Add a comment...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    minLines: 1,
                    maxLines: 4,
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
                      : const Icon(Icons.send_rounded, color: Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('MMM d').format(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}
