import '../config/api_config.dart';
import 'http_service.dart';

class ProfileService {
  static const String baseUrl = '${ApiConfig.baseUrl}/profile';
  final HttpService _httpService = HttpService();

  Future<Map<String, dynamic>> getProfile() async {
    return await _httpService.get(
      baseUrl,
      (data) => data as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> updateAvatar(String avatarUrl) async {
    return await _httpService.put('$baseUrl/avatar', {
      'avatarUrl': avatarUrl,
    }, (data) => data as Map<String, dynamic>);
  }

  Future<List<String>> getAvatarPresets() async {
    return await _httpService.get(
      '$baseUrl/avatars',
      (data) => List<String>.from(data['avatars']),
    );
  }

  Future<List<Map<String, dynamic>>> getLoginHistory() async {
    return await _httpService.get(
      '$baseUrl/login-history',
      (data) => List<Map<String, dynamic>>.from(data),
    );
  }
}
