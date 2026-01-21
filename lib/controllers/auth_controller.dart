import '../services/auth_service.dart';
import '../models/auth_response.dart';

class AuthController {
  final AuthService _authService = AuthService();

  Future<AuthResponse> login(String email, String password) async {
    return await _authService.login(email, password);
  }

  Future<AuthResponse> signup(String email, String password) async {
    return await _authService.signup(email, password);
  }

  Future<void> logout() async {
    await _authService.logout();
  }
}
