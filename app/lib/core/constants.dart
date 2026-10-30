import 'dart:io';

class AppConstants {
  static const String appName = 'FocusGuard';
  
  // Base API URL (Localhost: 10.0.2.2 for Android Emulator, 127.0.0.1 for Windows)
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  // Storage Keys
  static const String keyAccessToken = 'fg_access_token';
  static const String keyRefreshToken = 'fg_refresh_token';
  static const String keyUserEmail = 'fg_user_email';
  static const String keyUserName = 'fg_user_name';
  static const String keyHasVideo = 'fg_has_video';
  static const String keyVideoPath = 'fg_video_local_path';
  static const String keyScreenshotConsent = 'fg_screenshot_consent';
  static const String keyOnboardingCompleted = 'fg_onboarding_completed';
  static const String keyStudyGoals = 'fg_study_goals';

  // Default Tracked Apps
  static const List<Map<String, String>> defaultTrackedApps = [
    {
      'name': 'YouTube',
      'process': 'chrome.exe,msedge.exe,com.google.android.youtube',
      'pattern': '*YouTube*',
    },
    {
      'name': 'Instagram',
      'process': 'chrome.exe,msedge.exe,com.instagram.android',
      'pattern': '*Instagram*',
    },
    {
      'name': 'Facebook',
      'process': 'chrome.exe,msedge.exe,com.facebook.katana',
      'pattern': '*Facebook*',
    },
  ];
}

