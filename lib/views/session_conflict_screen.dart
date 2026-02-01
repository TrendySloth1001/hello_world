import 'package:flutter/material.dart';

class SessionConflictScreen extends StatelessWidget {
  final List<dynamic> sessions;

  const SessionConflictScreen({super.key, required this.sessions});

  String _getDeviceInfo(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return 'Unknown Device';
    if (userAgent.startsWith('ManagementApp')) {
      final parts = userAgent.split('(');
      if (parts.length > 1) {
        final infoObj = parts[1].replaceAll(')', '');
        final infoParts = infoObj.split(';');
        if (infoParts.isNotEmpty) {
          String os = infoParts[0].trim();
          if (os.isNotEmpty) os = os[0].toUpperCase() + os.substring(1);
          String version = infoParts.length > 1 ? infoParts[1].trim() : '';
          return version.isNotEmpty ? '$os $version' : os;
        }
      }
    }
    final lowerAgent = userAgent.toLowerCase();
    if (lowerAgent.contains('android')) return 'Android Device';
    if (lowerAgent.contains('iphone')) return 'iPhone';
    if (lowerAgent.contains('ipad')) return 'iPad';
    if (lowerAgent.contains('windows')) return 'Windows PC';
    if (lowerAgent.contains('macintosh') || lowerAgent.contains('mac os'))
      return 'Mac';
    if (lowerAgent.contains('linux')) return 'Linux PC';
    return 'Unknown Device';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'Unknown time';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Session Limit Reached',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You have reached the maximum number of active sessions (2).\nSelect a session to log out, or continue to replace the oldest one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final userAgent = session['userAgent'] as String?;
                      final ipAddress = session['ipAddress'] as String?;
                      final loginAt = session['loginAt'] as String?;
                      final deviceInfo = _getDeviceInfo(userAgent);
                      // final isOldest = index == sessions.length - 1; // Assuming server sends sorted list? Actually backend sends desc, so oldest is last.

                      return GestureDetector(
                        onTap: () => Navigator.pop(context, session['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.devices,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deviceInfo,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Active since: ${_formatTime(loginAt)}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (ipAddress != null)
                                      Text(
                                        'IP: $ipAddress',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.logout, color: Colors.redAccent),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, true), // Replace oldest
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Replace Oldest Session',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
