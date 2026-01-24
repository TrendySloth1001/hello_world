/// Configuration file for app assets and onboarding content.
/// Edit this file to change onboarding text and asset paths.
library;

class AppAssets {
  // Onboarding GIFs
  static const String onboarding1 = 'assets/Hello.gif';
  static const String onboarding2 = 'assets/Office work.gif';
  static const String onboarding3 = 'assets/Walking business woman.gif';

  // Auth GIFs
  static const String login = 'assets/login.gif';
  static const String signup = 'assets/reset_forgot.gif';

  // Post-login
  static const String welcome = 'assets/Welcome.gif';
}

class OnboardingConfig {
  static const List<Map<String, String>> slides = [
    {
      'image': AppAssets.onboarding1,
      'title': 'Welcome to TaskFlow',
      'description': 'Your personal task and work management companion.',
    },
    {
      'image': AppAssets.onboarding2,
      'title': 'Stay Organized',
      'description': 'Manage your projects and tasks with ease.',
    },
    {
      'image': AppAssets.onboarding3,
      'title': 'Achieve More',
      'description': 'Track your progress and accomplish your goals.',
    },
  ];
}
