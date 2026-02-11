import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/admin_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'user_activity_screen.dart';
import 'send_notification_screen.dart';
import '../../widgets/shimmer/log_shimmer_loader.dart';
import '../widgets/daily_requests_chart.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _logs = [];
  int _currentPage = 1;
  bool _hasMoreLogs = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
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
        !_isLoading &&
        !_isLoadingMore &&
        _hasMoreLogs) {
      _loadMoreLogs();
    }
  }

  Future<void> _loadData() async {
    // Only show full loading shimmer if we have no logs yet
    if (_logs.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final stats = await _adminService.getDashboardStats();
      final logsData = await _adminService.getActivityLogs(page: 1);

      if (mounted) {
        setState(() {
          _stats = stats;
          _logs = logsData['logs'];
          _currentPage = 1;
          _hasMoreLogs = logsData['pagination']['hasMore'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading admin data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final logsData = await _adminService.getActivityLogs(
        page: _currentPage + 1,
      );
      if (mounted) {
        setState(() {
          _logs.addAll(logsData['logs']);
          _currentPage++;
          _hasMoreLogs = logsData['pagination']['hasMore'] ?? false;
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
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Send Notification',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SendNotificationScreen(),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading && _logs.isEmpty
          ? const LogShimmerLoader(itemCount: 8)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsGrid(),
                          const SizedBox(height: 24),
                          if (_stats != null &&
                              _stats!.containsKey('dailyRequests'))
                            DailyRequestsChart(
                              dailyRequests: _stats!['dailyRequests'] ?? [],
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= _logs.length) {
                        return _hasMoreLogs
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink();
                      }
                      return _buildLogCard(_logs[index]);
                    }, childCount: _logs.length + (_isLoadingMore ? 1 : 0)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Total Requests',
          '${_stats!['totalRequests']}',
          Icons.bar_chart,
          Colors.blue,
        ),
        _buildStatCard(
          'Error Rate',
          '${_stats!['errorRate']}%',
          Icons.warning_amber,
          Colors.red,
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserActivityScreen(),
              ),
            );
          },
          child: _buildStatCard(
            'Active Users (24h)',
            '${_stats!['activeUsers24h']}',
            Icons.people,
            Colors.green,
          ),
        ),
        _buildStatCard(
          'Server Status',
          'Online',
          Icons.check_circle,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(dynamic log) {
    final statusCode = log['statusCode'] as int;
    final method = log['method'] as String;
    final path = log['path'] as String;
    final duration = log['duration'] as int;
    final createdAt = DateTime.parse(log['createdAt']).toLocal();
    // final user = log['user']; // Optionally show user info

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(statusCode).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getStatusColor(statusCode),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$statusCode',
                  style: TextStyle(
                    color: _getStatusColor(statusCode),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          method,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            path,
                            style: const TextStyle(fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('HH:mm:ss').format(createdAt)} • ${duration}ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(dynamic log) async {
    // Show loading dialog while fetching detailed data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch the complete log details from backend
      final detailedLog = await _adminService.getActivityLogDetails(log['id']);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final details = detailedLog['details'] ?? {};
      final requestBody = details['body'];
      final responseBody = details['response'];
      final query = details['query'];
      final headers = details['headers'];
      final user = detailedLog['user'];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaction Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Request Info'),
                      _buildDetailRow('Method', detailedLog['method'] ?? 'N/A'),
                      _buildDetailRow('Path', detailedLog['path'] ?? 'N/A'),
                      _buildDetailRow('Status Code', '${detailedLog['statusCode'] ?? 'N/A'}'),
                      _buildDetailRow('Duration', '${detailedLog['duration'] ?? 0}ms'),
                      const SizedBox(height: 24),
                      
                      _buildSectionHeader('Meta Info'),
                      _buildDetailRow(
                        'User',
                        user != null 
                          ? '${user['email'] ?? 'Unknown'} (ID: ${detailedLog['userId']})' 
                          : 'Anonymous',
                      ),
                      _buildDetailRow('IP Address', detailedLog['ipAddress'] ?? 'N/A'),
                      _buildDetailRow('User Agent', detailedLog['userAgent'] ?? 'N/A'),
                      _buildDetailRow(
                        'Timestamp', 
                        detailedLog['createdAt'] != null 
                          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(detailedLog['createdAt']).toLocal())
                          : 'N/A'
                      ),
                      const SizedBox(height: 24),

                      if (responseBody != null) ...[
                        _buildSectionHeader('Response Body'),
                        _buildJsonBlock(responseBody),
                        const SizedBox(height: 24),
                      ],

                      if (requestBody != null &&
                          requestBody is Map &&
                          requestBody.isNotEmpty) ...[
                        _buildSectionHeader('Request Body'),
                        _buildJsonBlock(requestBody),
                        const SizedBox(height: 24),
                      ],

                      if (query != null && query is Map && query.isNotEmpty) ...[
                        _buildSectionHeader('Query Params'),
                        _buildKeyValueTable(Map<String, dynamic>.from(query)),
                        const SizedBox(height: 24),
                      ],

                      if (headers != null && headers is Map && headers.isNotEmpty) ...[
                        _buildSectionHeader('Headers'),
                        _buildKeyValueTable(Map<String, dynamic>.from(headers)),
                      ],

                      // Show message if no details available
                      if ((responseBody == null || (responseBody is Map && responseBody.isEmpty)) &&
                          (requestBody == null || (requestBody is Map && requestBody.isEmpty)) &&
                          (query == null || (query is Map && query.isEmpty)) &&
                          (headers == null || (headers is Map && headers.isEmpty))) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.info_outline, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No additional transaction details available',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading transaction details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildKeyValueTable(Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: data.entries.map((entry) {
          final isLast = entry.key == data.keys.last;
          return Container(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: SelectableText(
                      '${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJsonBlock(dynamic data) {
    String prettyJson = '{}';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      prettyJson = encoder.convert(data);
    } catch (e) {
      prettyJson = data.toString();
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: SelectableText(
            prettyJson,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFA9B7C6),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Colors.white38),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Copy',
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
