class TrackedAppModel {
  final int? id;
  final String appName;
  final String packageOrProcess;
  final String matchPattern;
  bool isActive;
  int dailyLimitMinutes;
  int? continuousSessionLimitMinutes;
  int currentUsageTodayMinutes;

  TrackedAppModel({
    this.id,
    required this.appName,
    required this.packageOrProcess,
    required this.matchPattern,
    this.isActive = true,
    this.dailyLimitMinutes = 60,
    this.continuousSessionLimitMinutes = 30,
    this.currentUsageTodayMinutes = 0,
  });

  factory TrackedAppModel.fromJson(Map<String, dynamic> json) {
    return TrackedAppModel(
      id: json['id'] as int?,
      appName: json['app_name'] as String,
      packageOrProcess: json['package_or_process'] as String,
      matchPattern: json['match_pattern'] as String,
      isActive: json['is_active'] as bool? ?? true,
      dailyLimitMinutes: json['daily_limit_minutes'] as int? ?? 60,
      continuousSessionLimitMinutes: json['continuous_session_limit_minutes'] as int?,
      currentUsageTodayMinutes: json['current_usage_today_minutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'app_name': appName,
      'package_or_process': packageOrProcess,
      'match_pattern': matchPattern,
      'is_active': isActive,
      'daily_limit_minutes': dailyLimitMinutes,
      'continuous_session_limit_minutes': continuousSessionLimitMinutes,
    };
  }
}

