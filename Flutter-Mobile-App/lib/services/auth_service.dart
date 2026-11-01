import '../models/farmer_profile.dart';
import 'api_client.dart';
import 'secure_storage.dart';

class AuthResult {
  final bool success;
  final String message;
  final bool requiresEmailConfirmation;
  final FarmerProfile? profile;
  AuthResult({required this.success, required this.message, this.requiresEmailConfirmation = false, this.profile});
}

class AuthService {
  final ApiClient _api = ApiClient();

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final data = await _api.post('/api/auth/register', {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      }, auth: false);

      if (data['accessToken'] != null) {
        await SecureStorage.saveTokens(accessToken: data['accessToken'], refreshToken: data['refreshToken']);
      }

      return AuthResult(
        success: data['success'] ?? true,
        message: data['message'] ?? 'Account created.',
        requiresEmailConfirmation: data['requiresEmailConfirmation'] ?? false,
        profile: data['profile'] != null ? FarmerProfile.fromJson(data['profile']) : null,
      );
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  Future<AuthResult> login({required String email, required String password}) async {
    try {
      final data = await _api.post('/api/auth/login', {'email': email, 'password': password}, auth: false);
      await SecureStorage.saveTokens(accessToken: data['accessToken'], refreshToken: data['refreshToken']);
      return AuthResult(
        success: true,
        message: data['message'] ?? 'Logged in.',
        profile: data['profile'] != null ? FarmerProfile.fromJson(data['profile']) : null,
      );
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout', {});
    } catch (_) {
      // Even if the server call fails (offline, expired token, etc.) we
      // still want to drop local tokens so the app logs out client-side.
    } finally {
      await SecureStorage.clear();
    }
  }

  Future<FarmerProfile?> me() async {
    try {
      final data = await _api.get('/api/auth/me');
      return FarmerProfile.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  Future<AuthResult> updateProfile({String? fullName, String? phone, String? location}) async {
    try {
      final data = await _api.put('/api/auth/me', {
        'fullName': fullName,
        'phone': phone,
        'location': location,
      });
      return AuthResult(success: true, message: 'Profile updated.', profile: FarmerProfile.fromJson(data));
    } on ApiException catch (e) {
      return AuthResult(success: false, message: e.message);
    }
  }

  Future<bool> hasSession() async => (await SecureStorage.getAccessToken()) != null;
}
