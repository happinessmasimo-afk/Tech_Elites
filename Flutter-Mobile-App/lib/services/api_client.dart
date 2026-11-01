import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Talks to the ASP.NET backend only — the Flutter app never calls Supabase
/// directly. Automatically attaches the stored access token, and retries a
/// request exactly once after a silent token refresh on a 401.
class ApiClient {
  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await SecureStorage.getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<dynamic> get(String path, {bool auth = true}) =>
      _send(() async => http.get(_uri(path), headers: await _headers(auth: auth)), path, auth: auth);

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) => _send(
        () async => http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body)),
        path,
        auth: auth,
      );

  Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) => _send(
        () async => http.put(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body)),
        path,
        auth: auth,
      );

  Future<dynamic> patch(String path, Map<String, dynamic> body, {bool auth = true}) => _send(
        () async => http.patch(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body)),
        path,
        auth: auth,
      );

  Future<dynamic> delete(String path, {bool auth = true}) =>
      _send(() async => http.delete(_uri(path), headers: await _headers(auth: auth)), path, auth: auth);

  Future<dynamic> _send(Future<http.Response> Function() call, String path, {required bool auth}) async {
    var response = await call();

    if (response.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) response = await call();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Request failed (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) message = decoded['message'];
      if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
    } catch (_) {
      // response wasn't JSON; keep the generic message
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken == null) return false;

    final response = await http.post(
      _uri('/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode != 200) {
      await SecureStorage.clear();
      return false;
    }

    final decoded = jsonDecode(response.body);
    final accessToken = decoded['accessToken'] as String?;
    final newRefreshToken = decoded['refreshToken'] as String?;
    if (accessToken == null || newRefreshToken == null) return false;

    await SecureStorage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);
    return true;
  }
}
