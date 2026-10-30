import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart' as win32;

class ActiveWindowInfo {
  final String title;
  final String processName;
  final String? matchedAppName;

  ActiveWindowInfo({
    required this.title,
    required this.processName,
    this.matchedAppName,
  });
}

class WindowDetectorService {
  static final WindowDetectorService _instance = WindowDetectorService._internal();
  factory WindowDetectorService() => _instance;
  WindowDetectorService._internal();

  static const MethodChannel _androidChannel = MethodChannel('com.focusguard/usage');

  // Simulated active window for manual testing or simulation mode
  String? _simulatedApp;
  void setSimulatedApp(String? app) => _simulatedApp = app;

  Future<ActiveWindowInfo> getActiveWindow() async {
    if (_simulatedApp != null) {
      return ActiveWindowInfo(
        title: '$_simulatedApp - Active Window',
        processName: '${_simulatedApp!.toLowerCase()}.exe',
        matchedAppName: _simulatedApp,
      );
    }

    if (Platform.isWindows) {
      return _getWindowsActiveWindow();
    } else if (Platform.isAndroid) {
      return await _getAndroidForegroundApp();
    }

    return ActiveWindowInfo(title: 'Desktop Workspace', processName: 'system');
  }

  ActiveWindowInfo _getWindowsActiveWindow() {
    try {
      final hwnd = win32.GetForegroundWindow();
      if (hwnd == 0) {
        return ActiveWindowInfo(title: 'None', processName: 'none');
      }

      final length = win32.GetWindowTextLength(hwnd);
      if (length == 0) {
        return ActiveWindowInfo(title: 'Desktop', processName: 'explorer.exe');
      }

      final buffer = win32.wsalloc(length + 1);
      try {
        win32.GetWindowText(hwnd, buffer, length + 1);
        final title = buffer.toDartString();
        return ActiveWindowInfo(title: title, processName: 'active_window');
      } finally {
        win32.free(buffer);
      }
    } catch (e) {
      debugPrint('Win32 active window check error: $e');
      return ActiveWindowInfo(title: 'Unknown', processName: 'unknown');
    }
  }

  Future<ActiveWindowInfo> _getAndroidForegroundApp() async {
    try {
      final String? packageName = await _androidChannel.invokeMethod('getForegroundApp');
      final pkg = packageName ?? 'unknown';
      String title = pkg;
      if (pkg.contains('youtube')) title = 'YouTube';
      if (pkg.contains('instagram')) title = 'Instagram';
      if (pkg.contains('facebook')) title = 'Facebook';

      return ActiveWindowInfo(title: title, processName: pkg);
    } catch (e) {
      return ActiveWindowInfo(title: 'Android Activity', processName: 'android');
    }
  }

  /// Checks if the window title or process matches a tracked app pattern
  String? matchTrackedApp(String title, String process, List<Map<String, String>> trackedApps) {
    final lowerTitle = title.toLowerCase();
    final lowerProcess = process.toLowerCase();

    for (final app in trackedApps) {
      final name = app['name'] ?? '';
      final pattern = (app['pattern'] ?? name).replaceAll('*', '').toLowerCase();
      final procList = (app['process'] ?? '').toLowerCase().split(',');

      if (lowerTitle.contains(pattern) || lowerTitle.contains(name.toLowerCase())) {
        return name;
      }

      for (final p in procList) {
        final cleanP = p.trim();
        if (cleanP.isNotEmpty && lowerProcess.contains(cleanP)) {
          return name;
        }
      }
    }
    return null;
  }

  // --- Android Permission & Native Helpers ---

  Future<bool> hasUsagePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? res = await _androidChannel.invokeMethod('hasUsagePermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openUsageSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidChannel.invokeMethod('openUsageSettings');
    } catch (_) {}
  }

  Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? res = await _androidChannel.invokeMethod('hasOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidChannel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  Future<Map<String, int>> getDailyUsageMinutes() async {
    if (!Platform.isAndroid) return {};
    try {
      final dynamic raw = await _androidChannel.invokeMethod('getDailyUsageStats');
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (e) {
      debugPrint('getDailyUsageMinutes error: $e');
    }
    return {};
  }

  Future<void> bringToFront() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidChannel.invokeMethod('bringToFront');
    } catch (_) {}
  }

  Future<void> startForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidChannel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidChannel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }
}
