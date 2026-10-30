import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/database_helper.dart';
import '../core/storage_service.dart';
import '../models/tracked_app_model.dart';
import '../services/intervention_manager.dart';
import '../services/usage_monitor_service.dart';

class UsageProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();
  final DatabaseHelper _db = DatabaseHelper();
  final UsageMonitorService _monitor = UsageMonitorService();
  final InterventionManager _intervention = InterventionManager();

  List<TrackedAppModel> _trackedApps = [];
  int _combinedDailyLimitMinutes = 60;
  bool _isLoading = false;

  List<TrackedAppModel> get trackedApps => _trackedApps;
  int get combinedDailyLimitMinutes => _combinedDailyLimitMinutes;
  bool get isLoading => _isLoading;
  bool get isMonitoring => _monitor.isMonitoring;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // 1. Initialize default apps if empty
    _loadDefaultApps();

    // 2. Fetch remote settings from backend
    try {
      final res = await _api.get('/settings');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final appsJson = data['tracked_apps'] as List<dynamic>? ?? [];
        if (appsJson.isNotEmpty) {
          _trackedApps = appsJson.map((e) => TrackedAppModel.fromJson(e as Map<String, dynamic>)).toList();
        }

        final limitsJson = data['limits'] as List<dynamic>? ?? [];
        if (limitsJson.isNotEmpty) {
          final firstLimit = limitsJson.first as Map<String, dynamic>;
          _combinedDailyLimitMinutes = firstLimit['daily_limit_minutes'] as int? ?? 60;
        }

        if (data['screenshot_consent'] != null) {
          await _storage.setScreenshotConsent(data['screenshot_consent'] as bool);
        }
      }
    } catch (e) {
      debugPrint('Settings fetch error: $e');
    }

    // 3. Load daily usage from local SQLite
    await refreshUsageStats();

    // 4. Start usage monitor
    _monitor.configure(
      trackedApps: _trackedApps,
      combinedDailyLimitMinutes: _combinedDailyLimitMinutes,
      onLimitReached: (appName, sessionM, dailyM, winTitle) async {
        await _intervention.triggerIntervention(
          appName: appName,
          sessionMinutes: sessionM,
          dailyTotalMinutes: dailyM,
          windowTitle: winTitle,
        );
        await refreshUsageStats();
      },
    );
    _monitor.startMonitoring();

    _isLoading = false;
    notifyListeners();
  }

  void _loadDefaultApps() {
    _trackedApps = AppConstants.defaultTrackedApps.map((map) {
      return TrackedAppModel(
        appName: map['name']!,
        packageOrProcess: map['process']!,
        matchPattern: map['pattern']!,
        dailyLimitMinutes: 60,
      );
    }).toList();
  }

  Future<void> refreshUsageStats() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final app in _trackedApps) {
      app.currentUsageTodayMinutes = await _db.getDailyMinutesForApp(app.appName, todayStr);
    }
    notifyListeners();
  }

  Future<void> updateAppLimit(String appName, int limitMinutes) async {
    final app = _trackedApps.firstWhere((a) => a.appName == appName);
    app.dailyLimitMinutes = limitMinutes;
    notifyListeners();
    await _saveSettingsToBackend();
  }

  Future<void> updateCombinedLimit(int limitMinutes) async {
    _combinedDailyLimitMinutes = limitMinutes;
    _monitor.configure(
      trackedApps: _trackedApps,
      combinedDailyLimitMinutes: _combinedDailyLimitMinutes,
      onLimitReached: _monitorLimitReachedCallback,
    );
    notifyListeners();
    await _saveSettingsToBackend();
  }

  Future<void> toggleAppActive(String appName) async {
    final app = _trackedApps.firstWhere((a) => a.appName == appName);
    app.isActive = !app.isActive;
    notifyListeners();
    await _saveSettingsToBackend();
  }

  Future<void> addTrackedApp({
    required String appName,
    required String pattern,
    required String process,
    int dailyLimitMinutes = 60,
  }) async {
    _trackedApps.add(
      TrackedAppModel(
        appName: appName,
        packageOrProcess: process,
        matchPattern: pattern,
        dailyLimitMinutes: dailyLimitMinutes,
      ),
    );
    notifyListeners();
    await _saveSettingsToBackend();
  }

  Future<void> _saveSettingsToBackend() async {
    try {
      await _api.put(
        '/settings',
        body: {
          'tracked_apps': _trackedApps.map((a) => a.toJson()).toList(),
          'limits': [
            {
              'app_id': null,
              'daily_limit_minutes': _combinedDailyLimitMinutes,
              'continuous_session_limit_minutes': 30,
            }
          ],
        },
      );
    } catch (_) {}
  }

  Future<void> _monitorLimitReachedCallback(String app, int sesM, int dayM, String title) async {
    await _intervention.triggerIntervention(
      appName: app,
      sessionMinutes: sesM,
      dailyTotalMinutes: dayM,
      windowTitle: title,
    );
    await refreshUsageStats();
  }

  // Debug Simulation Helpers
  Future<void> simulateAddUsage({required String appName, required int minutes, bool triggerNow = false}) async {
    await _monitor.simulateUsage(
      appName: appName,
      additionalMinutes: minutes,
      forceTrigger: triggerNow,
    );
    await refreshUsageStats();
  }
}

