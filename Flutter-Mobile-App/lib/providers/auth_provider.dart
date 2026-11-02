import 'package:flutter/foundation.dart';
import '../models/farmer_profile.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  FarmerProfile? profile;
  String? lastError;

  bool get isFarmer => profile?.isFarmer ?? false;

  Future<void> bootstrap() async {
    final hasSession = await _authService.hasSession();
    if (!hasSession) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    final me = await _authService.me();
    if (me != null) {
      profile = me;
      status = AuthStatus.authenticated;
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    final result = await _authService.login(email: email, password: password);
    if (!result.success) {
      lastError = result.message;
      notifyListeners();
      return false;
    }
    profile = result.profile;
    status = AuthStatus.authenticated;
    lastError = null;
    notifyListeners();
    return true;
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final result = await _authService.register(fullName: fullName, email: email, phone: phone, password: password);
    if (result.success && !result.requiresEmailConfirmation) {
      profile = result.profile;
      status = AuthStatus.authenticated;
    }
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    profile = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<AuthResult> updateProfile({String? fullName, String? phone, String? location}) async {
    final result = await _authService.updateProfile(fullName: fullName, phone: phone, location: location);
    if (result.success && result.profile != null) {
      profile = result.profile;
      notifyListeners();
    }
    return result;
  }
}
