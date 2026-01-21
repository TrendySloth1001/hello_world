import 'user.dart';

class Task {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String assignmentStatus;
  final DateTime? dueDate;
  final DateTime createdAt;
  final User? createdBy;
  final User? assignedTo;
  final int? assignedToId;
  final List<Comment>? comments;
  final List<TaskActivity>? activities;
  final int commentCount;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.assignmentStatus = 'ACCEPTED',
    this.dueDate,
    required this.createdAt,
    this.createdBy,
    this.assignedTo,
    this.assignedToId,
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
      assignmentStatus: json['assignmentStatus'] ?? 'ACCEPTED',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'] != null
          ? User.fromJson(json['createdBy'])
          : null,
      assignedTo: json['assignedTo'] != null
          ? User.fromJson(json['assignedTo'])
          : null,
      assignedToId: json['assignedToId'],
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
  final User? user;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.taskId,
    this.user,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      content: json['content'],
      taskId: json['taskId'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
