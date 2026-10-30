import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) async {
    final url = Uri.parse('${AppConstants.baseUrl}$path');
    var response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await http.get(url, headers: await _getHeaders());
      }
    }
    return response;
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${AppConstants.baseUrl}$path');
    var response = await http.post(
      url,
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await http.post(
          url,
          headers: await _getHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${AppConstants.baseUrl}$path');
    var response = await http.put(
      url,
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await http.put(
          url,
          headers: await _getHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> delete(String path) async {
    final url = Uri.parse('${AppConstants.baseUrl}$path');
    var response = await http.delete(url, headers: await _getHeaders());

    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await http.delete(url, headers: await _getHeaders());
      }
    }
    return response;
  }

  /// Sends multipart request for screenshot analysis to backend /guidance
  Future<http.Response> postGuidance({
    required String appName,
    required int sessionMinutes,
    required int dailyTotalMinutes,
    String? activeWindowTitle,
    int? videoLengthSeconds,
    int? videoWatchedSeconds,
    List<int>? screenshotBytes,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/guidance');
    final request = http.MultipartRequest('POST', url);

    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['app_name'] = appName;
    request.fields['session_minutes'] = sessionMinutes.toString();
    request.fields['daily_total_minutes'] = dailyTotalMinutes.toString();
    if (activeWindowTitle != null) {
      request.fields['active_window_title'] = activeWindowTitle;
    }
    if (videoLengthSeconds != null) {
      request.fields['video_length_seconds'] = videoLengthSeconds.toString();
    }
    if (videoWatchedSeconds != null) {
      request.fields['video_watched_seconds'] = videoWatchedSeconds.toString();
    }

    if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'screenshot',
          screenshotBytes,
          filename: 'screenshot.jpg',
        ),
      );
    }

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final url = Uri.parse('${AppConstants.baseUrl}/auth/refresh');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}
