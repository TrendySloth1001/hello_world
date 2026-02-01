import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ProfileService _profileService = ProfileService();
  int _currentIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final profile = await _profileService.getProfile();
      if (profile['email'] == 'nkumawat1010@gmail.com') {
        // Hardcoded for frontend UI toggle
        if (mounted) {
          setState(() {
            _isAdmin = true;
          });
        }
      }
    } catch (e) {
      // Ignore errors, just don't show admin button
    }
  }

  List<Widget> get _screens {
    final screens = <Widget>[
      const HomeScreen(),
      const ChatScreen(),
      const ProfileScreen(),
    ];
    if (_isAdmin) {
      screens.add(const AdminDashboardScreen());
    }
    return screens;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              0,
              Icons.workspaces_outline,
              Icons.workspaces,
              'Workspaces',
            ),
            _buildNavItem(
              1,
              Icons.chat_bubble_outline,
              Icons.chat_bubble,
              'Chat',
            ),
            _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
            if (_isAdmin)
              _buildNavItem(
                3,
                Icons.admin_panel_settings_outlined,
                Icons.admin_panel_settings,
                'Admin',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.white38,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
