import 'package:flutter/material.dart';

import '../models/workspace.dart';
import '../services/task_service.dart';
import '../services/workspace_service.dart';

class CreateTaskScreen extends StatefulWidget {
  final int workspaceId;
  final int
  currentUserId; // To check limits if we wanted to on UI, but backend handles it

  const CreateTaskScreen({
    super.key,
    required this.workspaceId,
    required this.currentUserId,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taskService = TaskService();
  final _workspaceService = WorkspaceService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'MEDIUM';
  DateTime? _dueDate;
  final List<WorkspaceMember> _selectedMembers = [];
  List<WorkspaceMember> _members = [];
  bool _isLoadingMembers = true;
  bool _isCreating = false;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _workspaceService.getMembers(widget.workspaceId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load members: $e')));
      }
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      await _taskService.createTask(
        workspaceId: widget.workspaceId,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        priority: _priority,
        dueDate: _dueDate,
        assigneeIds: _selectedMembers.map((m) => m.user.id).toList(),
        isPrivate: _isPrivate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh list
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
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showMultiSelectDialog() async {
    final selected = await showDialog<List<WorkspaceMember>>(
      context: context,
      builder: (ctx) {
        return _MultiSelectDialog(
          members: _members,
          initialSelected: _selectedMembers,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedMembers.clear();
        _selectedMembers.addAll(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    _isPrivate ? 'New Private Task' : 'New Task',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      // Priority & Due Date Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _priority,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                labelStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(),
                              ),
                              items: ['LOW', 'MEDIUM', 'HIGH']
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _priority = val!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _dueDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date',
                                  labelStyle: TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    color: Colors.white54,
                                  ),
                                ),
                                child: Text(
                                  _dueDate == null
                                      ? 'Set Date'
                                      : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Private Task Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Private Task',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Only you and assignees can see this task',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        value: _isPrivate,
                        activeThumbColor: Colors.amber,
                        onChanged: (val) => setState(() => _isPrivate = val),
                      ),
                      const SizedBox(height: 24),
                      // Assignees
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Assign To',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isLoadingMembers
                                ? null
                                : _showMultiSelectDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Assignees'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedMembers.isEmpty)
                        const Text(
                          'No members assigned (Self-assigned by default logic)',
                          style: TextStyle(
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedMembers
                              .map(
                                (m) => Chip(
                                  avatar: CircleAvatar(
                                    backgroundImage: m.user.avatarUrl != null
                                        ? NetworkImage(m.user.avatarUrl!)
                                        : null,
                                    child: m.user.avatarUrl == null
                                        ? Text(m.user.email[0].toUpperCase())
                                        : null,
                                  ),
                                  label: Text(m.user.email),
                                  backgroundColor: Colors.white10,
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedMembers.remove(m);
                                    });
                                  },
                                  deleteIconColor: Colors.white54,
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _createTask,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCreating
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : const Text(
                                  'Create Task',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final List<WorkspaceMember> members;
  final List<WorkspaceMember> initialSelected;

  const _MultiSelectDialog({
    required this.members,
    required this.initialSelected,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<WorkspaceMember> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: const Text(
        'Select Assignees',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.members.length,
          itemBuilder: (context, index) {
            final member = widget.members[index];
            final isSelected = _selected.contains(member);
            return CheckboxListTile(
              value: isSelected,
              title: Text(
                member.user.email,
                style: const TextStyle(color: Colors.white),
              ),
              secondary: CircleAvatar(
                backgroundImage: member.user.avatarUrl != null
                    ? NetworkImage(member.user.avatarUrl!)
                    : null,
                child: member.user.avatarUrl == null
                    ? Text(member.user.email[0].toUpperCase())
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(member);
                  } else {
                    _selected.remove(member);
                  }
                });
              },
              activeColor: Colors.amber,
              checkColor: Colors.black,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
