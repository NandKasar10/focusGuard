class SuggestionModel {
  final int id;
  final String appName;
  final DateTime timestamp;
  final String? contextSummary;
  final String suggestionText;
  String? userReply;
  String actionTakenAfter;
  final DateTime? followUpTime;

  SuggestionModel({
    required this.id,
    required this.appName,
    required this.timestamp,
    this.contextSummary,
    required this.suggestionText,
    this.userReply,
    this.actionTakenAfter = 'pending',
    this.followUpTime,
  });

  factory SuggestionModel.fromJson(Map<String, dynamic> json) {
    return SuggestionModel(
      id: json['id'] as int,
      appName: json['app_name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      contextSummary: json['context_summary'] as String?,
      suggestionText: json['suggestion_text'] as String,
      userReply: json['user_reply'] as String?,
      actionTakenAfter: json['action_taken_after'] as String? ?? 'pending',
      followUpTime: json['follow_up_time'] != null
          ? DateTime.tryParse(json['follow_up_time'] as String)
          : null,
    );
  }
}
