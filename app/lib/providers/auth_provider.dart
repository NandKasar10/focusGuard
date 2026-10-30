import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/storage_service.dart';
import '../models/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final res = await _api.get('/auth/me');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _user = UserModel.fromJson(data);
        await _storage.saveUserProfile(name: _user!.name, email: _user!.email);
        _status = AuthStatus.authenticated;
      } else {
        await _storage.clearAuth();
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      // In offline scenario, use cached profile
      final name = _storage.getUserName();
      final email = _storage.getUserEmail();
      if (email != null) {
        _user = UserModel(
          id: 1,
          name: name ?? 'Focus User',
          email: email,
          hasVideo: _storage.hasLocalVideo(),
          screenshotConsent: _storage.getScreenshotConsent(),
        );
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? studyGoals,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/register',
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'study_goals': studyGoals ?? 'Master focus and achieve academic/career goals',
        },
      );

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        await _storage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        await _storage.saveUserProfile(name: name, email: email);
        if (studyGoals != null) {
          await _storage.setStudyGoals(studyGoals);
        }
        _user = UserModel(
          id: 1,
          name: name,
          email: email,
          hasVideo: false,
          studyGoals: studyGoals,
          screenshotConsent: false,
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        final err = jsonDecode(res.body);
        _errorMessage = err['detail'] ?? 'Registration failed.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error during registration: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _storage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );

        // Fetch me
        final meRes = await _api.get('/auth/me');
        if (meRes.statusCode == 200) {
          final meData = jsonDecode(meRes.body);
          _user = UserModel.fromJson(meData);
          await _storage.saveUserProfile(name: _user!.name, email: _user!.email);
        } else {
          _user = UserModel(
            id: 1,
            name: 'Focus User',
            email: email,
            hasVideo: _storage.hasLocalVideo(),
            screenshotConsent: _storage.getScreenshotConsent(),
          );
        }
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        final err = jsonDecode(res.body);
        _errorMessage = err['detail'] ?? 'Invalid email or password.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAuth();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
