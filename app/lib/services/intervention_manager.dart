import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/database_helper.dart';
import '../core/notification_service.dart';
import '../core/storage_service.dart';
import '../models/suggestion_model.dart';
import '../screens/overlay/motivational_overlay.dart';
import 'screen_capture_service.dart';
import 'usage_monitor_service.dart';
import 'window_detector_service.dart';

class InterventionManager {
  static final InterventionManager _instance = InterventionManager._internal();
  factory InterventionManager() => _instance;
  InterventionManager._internal();

  final StorageService _storage = StorageService();
  final ScreenCaptureService _captureService = ScreenCaptureService();
  final ApiClient _api = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();
  final NotificationService _notifications = NotificationService();
  final WindowDetectorService _detector = WindowDetectorService();
  final UsageMonitorService _monitor = UsageMonitorService();

  GlobalKey<NavigatorState>? navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  /// Triggers the full intervention workflow
  Future<void> triggerIntervention({
    required String appName,
    required int sessionMinutes,
    required int dailyTotalMinutes,
    required String windowTitle,
  }) async {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    // 1. Capture screen only if user gave explicit consent
    List<int>? screenshotBytes;
    if (_storage.getScreenshotConsent()) {
      screenshotBytes = await _captureService.captureScreen(
        windowTitle: windowTitle,
        appName: appName,
      );
    }

    // 2. Call backend /guidance for AI Hinglish reality-check
    SuggestionModel? suggestion;
    try {
      final res = await _api.postGuidance(
        appName: appName,
        sessionMinutes: sessionMinutes,
        dailyTotalMinutes: dailyTotalMinutes,
        activeWindowTitle: windowTitle,
        screenshotBytes: screenshotBytes,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        suggestion = SuggestionModel(
          id: data['suggestion_id'] as int,
          appName: appName,
          timestamp: DateTime.now(),
          contextSummary: data['activity_description'] as String?,
          suggestionText: data['suggestion_text'] as String,
          userReply: null,
          actionTakenAfter: 'pending',
          followUpTime: DateTime.now().add(Duration(minutes: (data['follow_up_minutes'] as int?) ?? 40)),
        );

        // Cache suggestion locally
        await _db.saveLocalSuggestion(
          id: suggestion.id,
          appName: appName,
          timestamp: suggestion.timestamp.toIso8601String(),
          suggestionText: suggestion.suggestionText,
        );
      }
    } catch (e) {
      debugPrint('AI Guidance API error: $e');
    }

    // Fallback suggestion if offline
    suggestion ??= SuggestionModel(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      appName: appName,
      timestamp: DateTime.now(),
      contextSummary: 'Limit reached on $appName',
      suggestionText: 'Bhai, $dailyTotalMinutes min ho chuke hain! Abhi kaam pehle nipta le, 40 min baad reward ke taur pe dekhna.',
      followUpTime: DateTime.now().add(const Duration(minutes: 40)),
    );

    // 3. Display the Full-Screen Motivational Video Overlay
    final videoPath = _storage.getLocalVideoPath();

    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => MotivationalOverlay(
            appName: appName,
            videoPath: videoPath,
            suggestion: suggestion!,
            dailyMinutes: dailyTotalMinutes,
            onReplySelected: (reply) async {
              await handleUserReply(
                suggestion: suggestion!,
                reply: reply,
                appName: appName,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> handleUserReply({
    required SuggestionModel suggestion,
    required String reply,
    required String appName,
  }) async {
    String actionTaken = 'pending';
    int followUpMinutes = 40;

    if (reply == "Okay, I'll study") {
      actionTaken = 'closed_app';
      followUpMinutes = 40;
      // Schedule study check-in notification
      await _notifications.scheduleStudyReminder(
        id: suggestion.id,
        delayMinutes: followUpMinutes,
        message: '40 min ho gaye! Ab batao target complete hua kya?',
      );
    } else if (reply == 'Snooze 10 min') {
      actionTaken = 'snoozed';
      followUpMinutes = 10;
      _monitor.snoozeApp(appName, 10);
      await _notifications.scheduleStudyReminder(
        id: suggestion.id,
        delayMinutes: 10,
        message: '10 min snooze khatam! Ab break le lo aur focus wapas lao.',
      );
    } else {
      actionTaken = 'continued_watching';
    }

    // 1. Update backend
    try {
      await _api.post(
        '/suggestions/${suggestion.id}/reply',
        body: {
          'user_reply': reply,
          'action_taken_after': actionTaken,
          'follow_up_minutes': followUpMinutes,
        },
      );
    } catch (_) {}

    // 2. Update local DB
    await _db.updateSuggestionReply(
      id: suggestion.id,
      userReply: reply,
      actionTaken: actionTaken,
    );

    // 3. Post-intervention detection: Check if user actually closed distracting window within 2 minutes
    _startPostInterventionCheck(suggestion.id, appName);
  }

  void _startPostInterventionCheck(int suggestionId, String appName) {
    int elapsedChecks = 0;
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      elapsedChecks++;
      final active = await _detector.getActiveWindow();
      final isStillOnApp = active.title.toLowerCase().contains(appName.toLowerCase());

      if (!isStillOnApp) {
        // User closed or switched away from the distracting app!
        timer.cancel();
        await _db.updateSuggestionReply(
          id: suggestionId,
          userReply: "Okay, I'll study",
          actionTaken: 'closed_app',
        );
        try {
          await _api.post(
            '/suggestions/$suggestionId/reply',
            body: {
              'user_reply': "Okay, I'll study",
              'action_taken_after': 'closed_app',
            },
          );
        } catch (_) {}
      } else if (elapsedChecks >= 8) {
        // 2 minutes passed and user is still on the distracting app
        timer.cancel();
        await _db.updateSuggestionReply(
          id: suggestionId,
          userReply: 'Ignored',
          actionTaken: 'continued_watching',
        );
      }
    });
  }
}

