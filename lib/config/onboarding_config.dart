/// Configuration file for app assets and onboarding content.
/// Edit this file to change onboarding text and asset paths.
library;

class AppAssets {
  // Onboarding Images (SVG)
  static const String onboarding1 =
      'assets/new_images/undraw_onboarding_dcq2.svg';
  static const String onboarding2 =
      'assets/new_images/undraw_programming_j1zw.svg';
  static const String onboarding3 =
      'assets/new_images/undraw_hr-presentation_uunk.svg';

  // Auth Images (SVG)
  static const String login =
      'assets/new_images/undraw_two-factor-authentication_ofho.svg';
  static const String signup = 'assets/new_images/undraw_setup-wizard_wzp9.svg';

  // Post-login (SVG)
  static const String welcome =
      'assets/new_images/undraw_welcome-cats_tw36.svg';

  // Additional Images (SVG)
  static const String homeSettings =
      'assets/new_images/undraw_home-settings_lw7v.svg';
  static const String preferences =
      'assets/new_images/undraw_preferences-popup_cru5.svg';
  static const String notifications =
      'assets/new_images/undraw_push-notifications_5z1s.svg';

  // Branding (PNG)
  static const String logo = 'assets/images/logo.png';
  static const String appIcon = 'assets/images/app_icon.png';
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
