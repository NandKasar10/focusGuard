import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _secureStorage.write(key: AppConstants.keyAccessToken, value: accessToken);
    await _secureStorage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: AppConstants.keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.keyRefreshToken);
  }

  Future<void> clearAuth() async {
    await _secureStorage.delete(key: AppConstants.keyAccessToken);
    await _secureStorage.delete(key: AppConstants.keyRefreshToken);
    await _prefs?.remove(AppConstants.keyUserEmail);
    await _prefs?.remove(AppConstants.keyUserName);
  }

  // User Profile
  Future<void> saveUserProfile({required String name, required String email}) async {
    await _prefs?.setString(AppConstants.keyUserName, name);
    await _prefs?.setString(AppConstants.keyUserEmail, email);
  }

  String? getUserName() => _prefs?.getString(AppConstants.keyUserName);
  String? getUserEmail() => _prefs?.getString(AppConstants.keyUserEmail);

  // Local Motivational Video (stored strictly on local device)
  Future<void> saveLocalVideoPath(String path) async {
    await _prefs?.setString(AppConstants.keyVideoPath, path);
    await _prefs?.setBool(AppConstants.keyHasVideo, true);
  }

  String? getLocalVideoPath() => _prefs?.getString(AppConstants.keyVideoPath);
  bool hasLocalVideo() {
    final path = getLocalVideoPath();
    if (path == null) return false;
    return File(path).existsSync();
  }

  // Consent & Preferences
  Future<void> setScreenshotConsent(bool consent) async {
    await _prefs?.setBool(AppConstants.keyScreenshotConsent, consent);
  }

  bool getScreenshotConsent() => _prefs?.getBool(AppConstants.keyScreenshotConsent) ?? false;

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs?.setBool(AppConstants.keyOnboardingCompleted, completed);
  }

  bool isOnboardingCompleted() => _prefs?.getBool(AppConstants.keyOnboardingCompleted) ?? false;

  Future<void> setStudyGoals(String goals) async {
    await _prefs?.setString(AppConstants.keyStudyGoals, goals);
  }

  String getStudyGoals() => _prefs?.getString(AppConstants.keyStudyGoals) ?? 'Exam preparation and focused coding';
}

