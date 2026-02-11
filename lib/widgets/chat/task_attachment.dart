import 'package:flutter/material.dart';
import '../../views/task_detail_screen.dart';

class TaskAttachment extends StatelessWidget {
  final int taskId;
  final String title;
  final String status;
  final String priority;
  final int currentUserId; // Required for navigation

  const TaskAttachment({
    Key? key,
    required this.taskId,
    required this.title,
    required this.status,
    required this.priority,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TaskDetailScreen(taskId: taskId, currentUserId: currentUserId),
          ),
        );
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF233138), // Darker, cleaner background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority Color Strip
                Container(width: 6, color: _getPriorityColor(priority)),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: ID and Priority
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.task_alt,
                                  size: 14,
                                  color: _getStatusColor(status),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'TASK-$taskId',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            _buildPriorityBadge(priority),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Footer: Status and Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusBadge(status),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    IconData icon;
    Color color = _getPriorityColor(priority);

    switch (priority.toUpperCase()) {
      case 'HIGH':
        icon = Icons.keyboard_double_arrow_up;
        break;
      case 'MEDIUM':
        icon = Icons.keyboard_arrow_up;
        break;
      case 'LOW':
        icon = Icons.keyboard_arrow_down;
        break;
      default:
        icon = Icons.remove;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          priority.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
        return Colors.blueGrey;
      case 'IN_PROGRESS':
        return const Color(0xFFE69A00); // Amber/Orange
      case 'DONE':
        return const Color(0xFF00C853); // Green Accent
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFFF5252); // Red Accent
      case 'MEDIUM':
        return const Color(0xFFFFAB40); // Orange Accent
      case 'LOW':
        return const Color(0xFF448AFF); // Blue Accent
      default:
        return Colors.grey;
    }
  }
}
