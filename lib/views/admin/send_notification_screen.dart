import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final AdminService _adminService = AdminService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _actionUrlController = TextEditingController();

  bool _isLoading = false;
  bool _sendToAll = true;
  String _selectedType = 'general';
  String _selectedPriority = 'normal';
  DateTime? _expiresAt;
  List<dynamic> _allUsers = [];
  Set<int> _selectedUserIds = {};

  final List<String> _types = ['general', 'task', 'workspace', 'system'];
  final List<String> _priorities = ['low', 'normal', 'high', 'urgent'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _actionUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _adminService.getAllUsersSimple();
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_sendToAll && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_sendToAll) {
        await _adminService.sendNotificationToAll(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          type: _selectedType,
          priority: _selectedPriority,
          actionUrl: _actionUrlController.text.trim().isEmpty
              ? null
              : _actionUrlController.text.trim(),
          expiresAt: _expiresAt,
        );
      } else {
        await _adminService.sendNotificationToUsers(
          userIds: _selectedUserIds.toList(),
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          type: _selectedType,
          priority: _selectedPriority,
          actionUrl: _actionUrlController.text.trim().isEmpty
              ? null
              : _actionUrlController.text.trim(),
          expiresAt: _expiresAt,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending notification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        setState(() {
          _expiresAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _showUserSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Users (${_selectedUserIds.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  setModalState(() {
                                    _selectedUserIds.clear();
                                  });
                                });
                              },
                              child: const Text('Clear All'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  setModalState(() {
                                    _selectedUserIds = _allUsers
                                        .map((u) => u['id'] as int)
                                        .toSet();
                                  });
                                });
                              },
                              child: const Text('Select All'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _allUsers.length,
                      itemBuilder: (context, index) {
                        final user = _allUsers[index];
                        final isSelected = _selectedUserIds.contains(
                          user['id'],
                        );

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              setModalState(() {
                                if (checked == true) {
                                  _selectedUserIds.add(user['id']);
                                } else {
                                  _selectedUserIds.remove(user['id']);
                                }
                              });
                            });
                          },
                          title: Text(user['email'] ?? 'Unknown'),
                          secondary: CircleAvatar(
                            backgroundImage: NetworkImage(
                              user['avatarUrl'] ?? '',
                            ),
                            onBackgroundImageError: (_, __) {},
                            child: user['avatarUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Send to all vs specific users toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recipients',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('All Users'),
                            value: true,
                            groupValue: _sendToAll,
                            onChanged: (value) {
                              setState(() => _sendToAll = value!);
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Select Users'),
                            value: false,
                            groupValue: _sendToAll,
                            onChanged: (value) {
                              setState(() => _sendToAll = value!);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!_sendToAll) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showUserSelector,
                        icon: const Icon(Icons.people),
                        label: Text(
                          _selectedUserIds.isEmpty
                              ? 'Select Users'
                              : '${_selectedUserIds.length} user(s) selected',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Message
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Message is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Type and Priority
            // Type and Priority
            Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type[0].toUpperCase() + type.substring(1)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.priority_high),
                  ),
                  items: _priorities.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getPriorityColor(priority),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            priority[0].toUpperCase() + priority.substring(1),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedPriority = value!);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action URL (optional)
            TextFormField(
              controller: _actionUrlController,
              decoration: const InputDecoration(
                labelText: 'Action URL (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: '/tasks/123',
              ),
            ),

            const SizedBox(height: 16),

            // Expiration date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Expiration Date (optional)'),
              subtitle: Text(
                _expiresAt == null
                    ? 'No expiration'
                    : 'Expires: ${_expiresAt!.toString().split('.')[0]}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_expiresAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _expiresAt = null);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _selectDate,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Send button
            ElevatedButton(
              onPressed: _isLoading ? null : _sendNotification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Notification',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
