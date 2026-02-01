import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final ProfileService _profileService = ProfileService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _profileService.getLoginHistory();
      print('LOGIN HISTORY DATA: $history'); // Debug log
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      print('LOGIN HISTORY ERROR: $e'); // Debug log
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final time = '$hour:$minute';

      if (difference.inSeconds < 30) {
        return 'Just now';
      } else if (difference.inMinutes < 1) {
        return '${difference.inSeconds} seconds ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago at $time';
      } else if (difference.inDays == 1) {
        return 'Yesterday at $time';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago at $time';
      } else {
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final year = dateTime.year;
        return '$day/$month/$year at $time';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String? _getDeviceInfo(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return null;

    // specific app format: ManagementApp/1.0 (os; version)
    if (userAgent.startsWith('ManagementApp')) {
      final parts = userAgent.split('(');
      if (parts.length > 1) {
        final infoObj = parts[1].replaceAll(')', '');
        final infoParts = infoObj.split(';');
        if (infoParts.isNotEmpty) {
          String os = infoParts[0].trim();
          // Capitalize OS name
          if (os.isNotEmpty) {
            os = os[0].toUpperCase() + os.substring(1);
          }
          String version = infoParts.length > 1 ? infoParts[1].trim() : '';

          if (version.isNotEmpty) {
            return '$os $version';
          }
          return os;
        }
      }
    }

    final lowerAgent = userAgent.toLowerCase();

    // Fallback detection
    if (lowerAgent.contains('android')) {
      return 'Android Device';
    } else if (lowerAgent.contains('iphone')) {
      return 'iPhone';
    } else if (lowerAgent.contains('ipad')) {
      return 'iPad';
    } else if (lowerAgent.contains('windows')) {
      return 'Windows PC';
    } else if (lowerAgent.contains('macintosh') ||
        lowerAgent.contains('mac os')) {
      return 'Mac';
    } else if (lowerAgent.contains('linux')) {
      return 'Linux PC';
    }
    return 'Unknown Device';
  }

  Duration? _getSessionDuration(String loginAt, String? logoutAt) {
    try {
      final login = DateTime.parse(loginAt);
      if (logoutAt != null) {
        final logout = DateTime.parse(logoutAt);
        return logout.difference(login);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} seconds';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '$hours hour${hours == 1 ? '' : 's'} $minutes min';
      }
      return '$hours hour${hours == 1 ? '' : 's'}';
    } else {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      if (hours > 0) {
        return '$days day${days == 1 ? '' : 's'} $hours hour${hours == 1 ? '' : 's'}';
      }
      return '$days day${days == 1 ? '' : 's'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Login History',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadHistory,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _history.isEmpty
          ? const Center(
              child: Text(
                'No login history',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                final loginAt = entry['loginAt'] as String;
                final logoutAt = entry['logoutAt'] as String?;
                final ipAddress = entry['ipAddress'] as String?;
                final userAgent = entry['userAgent'] as String?;
                final isActive = logoutAt == null;
                final deviceInfo = _getDeviceInfo(userAgent);
                final duration = _getSessionDuration(loginAt, logoutAt);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Login Time
                          Row(
                            children: [
                              const Text(
                                'Login:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDateTime(loginAt),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.green),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Logout Time
                          if (logoutAt != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Logout:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDateTime(logoutAt),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Session Duration
                          if (duration != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Duration:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Device Info
                          if (deviceInfo != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Device:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    deviceInfo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // IP Address
                          if (ipAddress != null && ipAddress.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'IP:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ipAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                  ],
                );
              },
            ),
    );
  }
}
