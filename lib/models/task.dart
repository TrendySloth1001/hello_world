import 'user.dart';

class Task {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final bool isOpen;
  final DateTime? dueDate;
  final DateTime createdAt;
  final User? createdBy;
  final List<TaskAssignment>? assignments;
  final List<Comment>? comments;
  final List<TaskActivity>? activities;
  final int commentCount;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.isOpen = false,
    this.dueDate,
    required this.createdAt,
    this.createdBy,
    this.assignments,
    this.comments,
    this.activities,
    this.commentCount = 0,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      priority: json['priority'],
      isOpen: json['isOpen'] ?? false,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'] != null
          ? User.fromJson(json['createdBy'])
          : null,
      assignments: json['assignments'] != null
          ? (json['assignments'] as List)
                .map((e) => TaskAssignment.fromJson(e))
                .toList()
          : null,
      comments: json['comments'] != null
          ? (json['comments'] as List).map((e) => Comment.fromJson(e)).toList()
          : null,
      activities: json['activities'] != null
          ? (json['activities'] as List)
                .map((e) => TaskActivity.fromJson(e))
                .toList()
          : null,
      commentCount: json['_count'] != null ? json['_count']['comments'] : 0,
    );
  }
}

class TaskAssignment {
  final int id;
  final int taskId;
  final User? user;
  final String status; // PENDING, ACCEPTED, REJECTED
  final String? rejectionReason;
  final DateTime timestamp;

  TaskAssignment({
    required this.id,
    required this.taskId,
    this.user,
    required this.status,
    this.rejectionReason,
    required this.timestamp,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      id: json['id'],
      taskId: json['taskId'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      status: json['status'],
      rejectionReason: json['rejectionReason'],
      timestamp: DateTime.parse(
        json['updatedAt'],
      ), // Using updatedAt as latest status time
    );
  }
}

class TaskActivity {
  final int id;
  final int taskId;
  final User? user;
  final String action;
  final DateTime timestamp;

  TaskActivity({
    required this.id,
    required this.taskId,
    this.user,
    required this.action,
    required this.timestamp,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    return TaskActivity(
      id: json['id'],
      taskId: json['taskId'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      action: json['action'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class Comment {
  final int id;
  final String content;
  final int taskId;
  final int? parentId;
  final User? user;
  final DateTime createdAt;
  final List<Comment>? replies;
  List<CommentLike> likes;

  Comment({
    required this.id,
    required this.content,
    required this.taskId,
    this.parentId,
    this.user,
    required this.createdAt,
    this.replies,
    this.likes = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      taskId: json['taskId'],
      parentId: json['parentId'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      replies: json['replies'] != null
          ? (json['replies'] as List).map((e) => Comment.fromJson(e)).toList()
          : null,
      likes: json['likes'] != null
          ? (json['likes'] as List).map((e) => CommentLike.fromJson(e)).toList()
          : [],
    );
  }
}

class CommentLike {
  final int id;
  final int userId;
  final int commentId;

  CommentLike({
    required this.id,
    required this.userId,
    required this.commentId,
  });

  factory CommentLike.fromJson(Map<String, dynamic> json) {
    return CommentLike(
      id: json['id'],
      userId: json['userId'],
      commentId: json['commentId'],
    );
  }
}
