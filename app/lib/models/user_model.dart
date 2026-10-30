class UserModel {
  final int id;
  final String name;
  final String email;
  final bool hasVideo;
  final String? studyGoals;
  final bool screenshotConsent;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.hasVideo,
    this.studyGoals,
    required this.screenshotConsent,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      hasVideo: json['has_video'] as bool? ?? false,
      studyGoals: json['study_goals'] as String?,
      screenshotConsent: json['screenshot_consent'] as bool? ?? false,
    );
  }
}

