import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
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
  final _subTaskController = TextEditingController(); // For adding subtasks
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
    _subTaskController.dispose();
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
      _loadComments(reset: true);
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
                  if (controller.text.trim().isNotEmpty)
                    Navigator.pop(context, controller.text.trim());
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to respond: $e')));
    }
  }

  Future<void> _claimTask() async {
    try {
      await _taskService.claimTask(widget.taskId);
      _loadTask();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task Claimed!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to claim task: $e')));
    }
  }

  Future<void> _requestContribution() async {
    try {
      await _taskService.requestContribution(widget.taskId);
      _loadTask();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution Requested!'),
            backgroundColor: Colors.blue,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _manageContribution(int contributorId, String action) async {
    try {
      await _taskService.manageContribution(
        widget.taskId,
        contributorId,
        action,
      );
      _loadTask();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request ${action == 'ACCEPT' ? 'Accepted' : 'Rejected'}',
            ),
            backgroundColor: action == 'ACCEPT' ? Colors.green : Colors.red,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // --- SubTasks Methods ---
  Future<void> _addSubTask() async {
    if (_subTaskController.text.trim().isEmpty) return;
    try {
      await _taskService.addSubTask(
        widget.taskId,
        _subTaskController.text.trim(),
      );
      _subTaskController.clear();
      _loadTask();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add subtask: $e')));
    }
  }

  Future<void> _toggleSubTask(int subTaskId) async {
    try {
      await _taskService.toggleSubTask(widget.taskId, subTaskId);
      _loadTask();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update subtask: $e')));
    }
  }

  Future<void> _deleteSubTask(int subTaskId) async {
    try {
      await _taskService.deleteSubTask(widget.taskId, subTaskId);
      _loadTask();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete subtask: $e')));
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
                  child: _buildSubTasksSection(),
                ), // SubTasks Section
                SliverToBoxAdapter(child: _buildActivityLog()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Comments',
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
                            ? const Center(child: CircularProgressIndicator())
                            : const SizedBox.shrink();
                      }
                      return _buildCommentItem(_comments[index]);
                    },
                    childCount: _comments.length + (_isLoadingComments ? 1 : 0),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
          _buildUserRow(_task!.createdBy, 'Created by'),
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
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetaItem(
                Icons.flag_outlined,
                'Priority',
                _task!.priority,
                _getPriorityColor(_task!.priority),
              ),
              const SizedBox(width: 24),
              if (_task!.dueDate != null)
                _buildMetaItem(
                  Icons.calendar_today,
                  'Due Date',
                  DateFormat('MMM d').format(_task!.dueDate!),
                  Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(User? user, String subtitle) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[800],
          backgroundImage: user?.avatarUrl != null
              ? NetworkImage(user!.avatarUrl!)
              : null,
          child: user?.avatarUrl == null
              ? Text(user?.email[0].toUpperCase() ?? 'U')
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.email ?? 'Unknown User',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentSection() {
    // Check if I am assigned (Primary or Collaborator)
    final myAssignment = _task!.assignments?.firstWhere(
      (a) => a.user?.id == widget.currentUserId,
      orElse: () => TaskAssignment(
        id: 0,
        taskId: 0,
        status: 'NONE',
        role: 'ASSIGNEE',
        timestamp: DateTime.now(),
      ),
    );
    final isAssignedToMe = myAssignment != null && (myAssignment.id != 0);
    final amIAssignee =
        isAssignedToMe &&
        myAssignment!.role == 'ASSIGNEE' &&
        myAssignment.status == 'ACCEPTED';
    final amICreator = _task!.createdById == widget.currentUserId;
    final canManage = amIAssignee || amICreator;

    // Filter Lists
    final assignees =
        _task!.assignments
            ?.where((a) => a.role == 'ASSIGNEE' && a.status != 'REJECTED')
            .toList() ??
        [];
    final collaborators =
        _task!.assignments
            ?.where((a) => a.role == 'COLLABORATOR' && a.status == 'ACCEPTED')
            .toList() ??
        [];
    final pendingRequests =
        _task!.assignments
            ?.where((a) => a.role == 'COLLABORATOR' && a.status == 'PENDING')
            .toList() ??
        [];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Assignees
          if (assignees.isNotEmpty) ...[
            const Text(
              'Assignees',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...assignees.map((a) => _buildPersonItem(a)).toList(),
            const SizedBox(height: 16),
          ],

          // Collaborators
          if (collaborators.isNotEmpty) ...[
            const Text(
              'Collaborators',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...collaborators.map((a) => _buildPersonItem(a)).toList(),
            const SizedBox(height: 16),
          ],

          // Pending Requests (Only visible to Manager)
          if (canManage && pendingRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...pendingRequests.map((a) => _buildRequestItem(a)).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions for Me
          if (isAssignedToMe &&
              myAssignment!.status == 'PENDING' &&
              myAssignment.role == 'ASSIGNEE') ...[
            // Pending Assignment Acceptance
            _buildPendingAssignmentMsg(),
          ] else if (!isAssignedToMe) ...[
            // Contribute Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestContribution,
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Request to Contribute'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
              ),
            ),
          ] else if (isAssignedToMe &&
              myAssignment!.status == 'PENDING' &&
              myAssignment.role == 'COLLABORATOR') ...[
            const Text(
              'Contribution request pending...',
              style: TextStyle(color: Colors.orange),
            ),
          ],

          // Claim Open Task
          if (_task!.isOpen && !isAssignedToMe) ...[
            const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildPersonItem(TaskAssignment assignment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[800],
            backgroundImage: assignment.user?.avatarUrl != null
                ? NetworkImage(assignment.user!.avatarUrl!)
                : null,
            child: assignment.user?.avatarUrl == null
                ? Text(
                    assignment.user?.email[0].toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            assignment.user?.email ?? 'Unknown',
            style: const TextStyle(color: Colors.white),
          ),
          const Spacer(),
          if (assignment.status == 'PENDING')
            const Text(
              'Pending',
              style: TextStyle(color: Colors.orange, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(TaskAssignment assignment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            assignment.user?.email ?? 'Unknown',
            style: const TextStyle(color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () =>
                _manageContribution(assignment.user?.id ?? 0, 'ACCEPT'),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () =>
                _manageContribution(assignment.user?.id ?? 0, 'REJECT'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAssignmentMsg() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'You were assigned this task',
            style: TextStyle(color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToTask('REJECTED'),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToTask('ACCEPTED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTasksSection() {
    final subTasks = _task!.subTasks ?? [];

    // Permission Logic
    final myAssignment = _task!.assignments?.firstWhere(
      (a) => a.user?.id == widget.currentUserId,
      orElse: () => TaskAssignment(
        id: 0,
        taskId: 0,
        status: 'NONE',
        role: 'NONE',
        timestamp: DateTime.now(),
      ),
    );
    final amIAssignee =
        (myAssignment?.role == 'ASSIGNEE' &&
        myAssignment?.status == 'ACCEPTED');
    final amICreator = _task!.createdById == widget.currentUserId;
    final amICollaborator =
        (myAssignment?.role == 'COLLABORATOR' &&
        myAssignment?.status == 'ACCEPTED');

    final canEditStructure = amIAssignee || amICreator;
    final canToggle = canEditStructure || amICollaborator;

    if (subTasks.isEmpty && !canEditStructure) return const SizedBox.shrink();

    final completedCount = subTasks.where((s) => s.isCompleted).length;
    final progress = subTasks.isEmpty ? 0.0 : completedCount / subTasks.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sub-tasks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount/${subTasks.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation(Colors.green),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          ...subTasks
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Transform.scale(
                            scale: 0.9,
                            child: Checkbox(
                              value: s.isCompleted,
                              onChanged: canToggle
                                  ? (v) => _toggleSubTask(s.id)
                                  : null,
                              fillColor: MaterialStateProperty.resolveWith(
                                (states) => s.isCompleted
                                    ? Colors.green
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s.title,
                              style: TextStyle(
                                color: Colors.white,
                                decoration: s.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.grey,
                              ),
                            ),
                          ),
                          if (canEditStructure)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 16,
                              ),
                              onPressed: () => _deleteSubTask(s.id),
                            ),
                        ],
                      ),
                      if (s.isCompleted && s.completedBy != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Text(
                            'Completed by ${s.completedBy!.email} at ${DateFormat('MMM d, h:mm a').format(s.completedAt!.toLocal())}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .toList(),

          if (canEditStructure && subTasks.length < 20)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subTaskController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a sub-task...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[800]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[800]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _addSubTask,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    final activities = _task!.activities ?? [];
    if (activities.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: activity.user?.email ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            TextSpan(text: ' ${activity.action} '),
                            TextSpan(
                              text: DateFormat(
                                'MMM d, h:mm a',
                              ).format(activity.timestamp.toLocal()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final isLiked = comment.likes.any((l) => l.userId == widget.currentUserId);
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
                    if (comment.likes.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likes.length}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
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
                if (comment.replies != null)
                  Column(
                    children: comment.replies!
                        .map((r) => _buildReplyItem(r))
                        .toList(),
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
      padding: const EdgeInsets.only(top: 8),
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
                      reply.user?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(reply.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  reply.content,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                    const SizedBox(width: 24),
                    InkWell(
                      onTap: () => _startReply(
                        reply.parentId ?? reply.id,
                        reply.user?.email ?? '',
                      ),
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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
              Row(
                children: [
                  Text(
                    'Replying to ${_replyingToUserEmail}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSendingComment ? null : _addComment,
                  icon: const Icon(Icons.send, color: Colors.blue),
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
    return '${diff.inMinutes}m';
  }
}
