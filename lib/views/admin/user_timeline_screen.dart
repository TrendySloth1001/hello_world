import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/shimmer/log_shimmer_loader.dart';

class UserTimelineScreen extends StatefulWidget {
  final int userId;
  final String email;

  const UserTimelineScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<UserTimelineScreen> createState() => _UserTimelineScreenState();
}

class _UserTimelineScreenState extends State<UserTimelineScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  List<dynamic> _logs = [];

  // Pagination
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreLogs();
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    // Only show full loading shimmer if we have no logs yet (initial load)
    if (_logs.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final logsData = await _adminService.getActivityLogs(
        userId: widget.userId,
        page: 1,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _logs = logsData['logs'];
          _currentPage = 1;
          _hasMore = logsData['pagination']['hasMore'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final logsData = await _adminService.getActivityLogs(
        userId: widget.userId,
        page: _currentPage + 1,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _logs.addAll(logsData['logs']);
          _currentPage++;
          _hasMore = logsData['pagination']['hasMore'] ?? false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 500) return Colors.red;
    if (statusCode >= 400) return Colors.orange;
    if (statusCode >= 300) return Colors.blue;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activity Timeline', style: TextStyle(fontSize: 16)),
            Text(
              widget.email,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading && _logs.isEmpty
          ? const LogShimmerLoader(itemCount: 10)
          : RefreshIndicator(
              onRefresh: () => _loadLogs(refresh: true),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _logs.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _logs.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final log = _logs[index];
                  final isLast = index == _logs.length - 1;
                  final createdAt = DateTime.parse(log['createdAt']).toLocal();
                  final statusCode = log['statusCode'];

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getStatusColor(statusCode),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                            if (!isLast || _hasMore)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: Colors.white12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormat('HH:mm').format(createdAt)} - ${log['method']}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log['path'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      statusCode,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Status: $statusCode • ${log['duration']}ms',
                                    style: TextStyle(
                                      color: _getStatusColor(statusCode),
                                      fontSize: 12,
                                    ),
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
            ),
    );
  }
}
