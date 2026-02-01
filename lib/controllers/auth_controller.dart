import '../services/auth_service.dart';
import '../models/auth_response.dart';

class AuthController {
  final AuthService _authService = AuthService();

  Future<AuthResponse> signInWithGoogle(
    String? idToken, {
    bool force = false,
    int? terminateSessionId,
  }) async {
    return await _authService.signInWithGoogle(
      idToken,
      force: force,
      terminateSessionId: terminateSessionId,
    );
  }

  Future<AuthResponse> signup(String email, String password) async {
    return await _authService.signup(email, password);
  }

  Future<AuthResponse> login(
    String email,
    String password, {
    bool force = false,
    int? terminateSessionId,
  }) async {
    return await _authService.login(
      email,
      password,
      force: force,
      terminateSessionId: terminateSessionId,
    );
  }

  Future<void> logout() async {
    await _authService.logout();
  }

  Future<int?> getUserId() async {
    return await _authService.getUserId();
  }
}
