import 'suggestion_model.dart';

class AppUsageBreakdown {
  final String appName;
  final int totalMinutes;
  final int sessionCount;

  AppUsageBreakdown({
    required this.appName,
    required this.totalMinutes,
    required this.sessionCount,
  });

  factory AppUsageBreakdown.fromJson(Map<String, dynamic> json) {
    return AppUsageBreakdown(
      appName: json['app_name'] as String,
      totalMinutes: json['total_minutes'] as int,
      sessionCount: json['session_count'] as int,
    );
  }
}

class DailySummaryModel {
  final String date;
  final int totalScreenTimeMinutes;
  final int totalDistractingTimeMinutes;
  final List<AppUsageBreakdown> appBreakdown;
  final int suggestionsCount;
  final int followedCount;
  final int ignoredCount;
  final int snoozedCount;
  final double compliancePercentage;
  final int focusStreakDays;
  final List<SuggestionModel> timeline;
  final String summaryMessage;

  DailySummaryModel({
    required this.date,
    required this.totalScreenTimeMinutes,
    required this.totalDistractingTimeMinutes,
    required this.appBreakdown,
    required this.suggestionsCount,
    required this.followedCount,
    required this.ignoredCount,
    required this.snoozedCount,
    required this.compliancePercentage,
    required this.focusStreakDays,
    required this.timeline,
    required this.summaryMessage,
  });

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    return DailySummaryModel(
      date: json['date'] as String,
      totalScreenTimeMinutes: json['total_screen_time_minutes'] as int? ?? 0,
      totalDistractingTimeMinutes: json['total_distracting_time_minutes'] as int? ?? 0,
      appBreakdown: (json['app_breakdown'] as List<dynamic>? ?? [])
          .map((e) => AppUsageBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggestionsCount: json['suggestions_count'] as int? ?? 0,
      followedCount: json['followed_count'] as int? ?? 0,
      ignoredCount: json['ignored_count'] as int? ?? 0,
      snoozedCount: json['snoozed_count'] as int? ?? 0,
      compliancePercentage: (json['compliance_percentage'] as num? ?? 0).toDouble(),
      focusStreakDays: json['focus_streak_days'] as int? ?? 1,
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map((e) => SuggestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summaryMessage: json['summary_message'] as String? ?? 'Keep focusing on your goals!',
    );
  }
}
