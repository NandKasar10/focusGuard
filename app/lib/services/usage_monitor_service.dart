import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/database_helper.dart';
import '../models/tracked_app_model.dart';
import 'window_detector_service.dart';

typedef OnLimitReachedCallback = Future<void> Function(
  String appName,
  int sessionMinutes,
  int dailyTotalMinutes,
  String windowTitle,
);

class UsageMonitorService {
  static final UsageMonitorService _instance = UsageMonitorService._internal();
  factory UsageMonitorService() => _instance;
  UsageMonitorService._internal();

  final WindowDetectorService _detector = WindowDetectorService();
  final DatabaseHelper _db = DatabaseHelper();
  final ApiClient _api = ApiClient();

  Timer? _monitorTimer;
  Timer? _syncTimer;
  bool _isMonitoring = false;

  // Active session tracking
  String? _currentActiveApp;
  int _activeSessionSeconds = 0;

  // Tracked apps & limits
  List<TrackedAppModel> _trackedApps = [];
  int _combinedDailyLimitMinutes = 60;
  OnLimitReachedCallback? _onLimitReached;

  // Snooze tracking: appName -> snoozedUntil DateTime
  final Map<String, DateTime> _snoozedApps = {};

  bool get isMonitoring => _isMonitoring;

  void configure({
    required List<TrackedAppModel> trackedApps,
    required int combinedDailyLimitMinutes,
    required OnLimitReachedCallback onLimitReached,
  }) {
    _trackedApps = trackedApps;
    _combinedDailyLimitMinutes = combinedDailyLimitMinutes;
    _onLimitReached = onLimitReached;
  }

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Tick every 3 seconds to inspect foreground window
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _tick();
    });

    // Periodic sync to backend every 60 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      syncUsageToBackend();
    });
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _syncTimer?.cancel();
    _isMonitoring = false;
  }

  void snoozeApp(String appName, int minutes) {
    _snoozedApps[appName.toLowerCase()] = DateTime.now().add(Duration(minutes: minutes));
  }

  bool isAppSnoozed(String appName) {
    final until = _snoozedApps[appName.toLowerCase()];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _snoozedApps.remove(appName.toLowerCase());
    return false;
  }

  Future<void> _tick() async {
    final activeWindow = await _detector.getActiveWindow();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Prepare list for pattern matcher
    final patterns = _trackedApps.map((a) => {
      'name': a.appName,
      'pattern': a.matchPattern,
      'process': a.packageOrProcess,
    }).toList();

    final matchedApp = _detector.matchTrackedApp(
      activeWindow.title,
      activeWindow.processName,
      patterns,
    );

    if (matchedApp != null) {
      // Matching distracting app is currently in foreground!
      if (_currentActiveApp == matchedApp) {
        _activeSessionSeconds += 3;
      } else {
        _currentActiveApp = matchedApp;
        _activeSessionSeconds = 3;
      }

      // Check if 60 seconds of active usage has elapsed, write to local DB
      if (_activeSessionSeconds > 0 && _activeSessionSeconds % 60 == 0) {
        await _db.addUsageMinutes(
          appName: matchedApp,
          dateStr: todayStr,
          minutes: 1,
        );
      }

      // Check limits if app is not snoozed
      if (!isAppSnoozed(matchedApp)) {
        final dailyMinutes = await _db.getDailyMinutesForApp(matchedApp, todayStr);
        final combinedMinutes = await _db.getCombinedDailyMinutes(todayStr);

        final targetAppModel = _trackedApps.firstWhere(
          (a) => a.appName.toLowerCase() == matchedApp.toLowerCase(),
          orElse: () => TrackedAppModel(appName: matchedApp, packageOrProcess: '', matchPattern: ''),
        );

        final appLimit = targetAppModel.dailyLimitMinutes;
        final sessionMinutes = _activeSessionSeconds ~/ 60;

        // Check app daily limit, combined limit, or continuous session limit
        final limitReached = (appLimit > 0 && dailyMinutes >= appLimit) ||
            (_combinedDailyLimitMinutes > 0 && combinedMinutes >= _combinedDailyLimitMinutes) ||
            (targetAppModel.continuousSessionLimitMinutes != null &&
                sessionMinutes >= targetAppModel.continuousSessionLimitMinutes!);

        if (limitReached && _onLimitReached != null) {
          // Temporarily snooze for 2 minutes to prevent repeated alerts during the intervention
          snoozeApp(matchedApp, 2);
          await _onLimitReached!(
            matchedApp,
            sessionMinutes,
            dailyMinutes,
            activeWindow.title,
          );
        }
      }
    } else {
      // Not on a tracked app
      _currentActiveApp = null;
      _activeSessionSeconds = 0;
    }
  }

  /// Debug Simulation: Instantly inject usage minutes to test limit triggers
  Future<void> simulateUsage({
    required String appName,
    required int additionalMinutes,
    bool forceTrigger = false,
  }) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _db.addUsageMinutes(
      appName: appName,
      dateStr: todayStr,
      minutes: additionalMinutes,
    );

    final totalMinutes = await _db.getDailyMinutesForApp(appName, todayStr);

    if (forceTrigger && _onLimitReached != null) {
      await _onLimitReached!(
        appName,
        additionalMinutes,
        totalMinutes,
        'Simulated $appName Session',
      );
    }
  }

  Future<void> syncUsageToBackend() async {
    try {
      final unsynced = await _db.getUnsyncedUsage();
      if (unsynced.isEmpty) return;

      final records = unsynced.map((r) => {
        'app_name': r['app_name'],
        'date': r['date'],
        'total_minutes': r['total_minutes'],
        'session_count': r['session_count'],
      }).toList();

      final res = await _api.post('/usage/sync', body: {'records': records});
      if (res.statusCode == 200) {
        final ids = unsynced.map((r) => r['id'] as int).toList();
        await _db.markUsageSynced(ids);
      }
    } catch (e) {
      debugPrint('Usage sync error: $e');
    }
  }
}
