import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/database_helper.dart';
import '../models/daily_summary_model.dart';
import '../models/suggestion_model.dart';

class SummaryProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();

  DailySummaryModel? _summary;
  bool _isLoading = false;
  String? _error;

  DailySummaryModel? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDailySummary({DateTime? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    try {
      final res = await _api.get('/summary/daily?date=$dateStr');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _summary = DailySummaryModel.fromJson(data);
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Daily summary remote fetch error: $e');
    }

    // Offline SQLite fallback
    try {
      final localSuggestions = await _db.getDailySuggestions(dateStr);
      final totalDistracting = await _db.getCombinedDailyMinutes(dateStr);

      final timeline = localSuggestions.map((s) {
        return SuggestionModel(
          id: s['id'] as int,
          appName: s['app_name'] as String,
          timestamp: DateTime.parse(s['timestamp'] as String),
          suggestionText: s['suggestion_text'] as String,
          userReply: s['user_reply'] as String?,
          actionTakenAfter: s['action_taken'] as String? ?? 'pending',
        );
      }).toList();

      int followed = 0;
      for (final s in timeline) {
        if (s.actionTakenAfter == 'closed_app' || (s.userReply?.toLowerCase().contains('study') ?? false)) {
          followed++;
        }
      }

      final compliance = timeline.isNotEmpty ? (followed / timeline.length) * 100 : 100.0;

      _summary = DailySummaryModel(
        date: dateStr,
        totalScreenTimeMinutes: totalDistracting,
        totalDistractingTimeMinutes: totalDistracting,
        appBreakdown: [],
        suggestionsCount: timeline.length,
        followedCount: followed,
        ignoredCount: timeline.length - followed,
        snoozedCount: 0,
        compliancePercentage: compliance,
        focusStreakDays: 1,
        timeline: timeline,
        summaryMessage: 'Offline Summary: $followed out of ${timeline.length} interventions followed.',
      );
    } catch (e) {
      _error = 'Failed to load summary: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}

