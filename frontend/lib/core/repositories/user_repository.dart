// MOVED FROM: lib/core/repositories/user_repository.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/geocode_result.dart';
import '../models/route_suggestion.dart';

class UserRepository {
  // Single source of truth for session data
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('userId') && prefs.containsKey('auth_token');
  }

  Future<void> saveSession({
    required String userId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('auth_token', token);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('auth_token');
  }

  Future<Map<String, dynamic>> sendOtp(String phone) {
    return ApiService.sendOtp(phone);
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email, {String? name, String? phone}) {
    return ApiService.sendEmailOtp(email, name: name, phone: phone);
  }

  Future<Map<String, dynamic>> verifyOtp(String? phone, String otp, {String? email}) {
    return ApiService.verifyOtp(phone, otp, email: email);
  }

  Future<User?> getProfile() async {
    final result = await ApiService.getMyProfile();
    if (result['success'] == true && result['user'] != null) {
      return User.fromJson(result['user']);
    }
    return null;
  }

  Future<void> updateStatus({
    required double lat,
    required double lng,
    String? batteryLevel,
    bool? isDriving,
    double? currentSpeed,
    String? fcmToken,
  }) {
    return ApiService.updateStatus(
      lat: lat,
      lng: lng,
      batteryLevel: batteryLevel,
      isDriving: isDriving,
      currentSpeed: currentSpeed,
      fcmToken: fcmToken,
    );
  }

  Future<void> syncEmergencyContacts(List<Map<String, String>> contacts) {
    return ApiService.syncEmergencyContacts(contacts);
  }

  Future<Map<String, dynamic>?> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) {
    return ApiService.startSOS(lat: lat, lng: lng, address: address);
  }

  Future<void> sendSpeedAlert({
    required double speed,
    required double lat,
    required double lon,
    required double limit,
  }) {
    return ApiService.sendSpeedAlert(speed: speed, lat: lat, lon: lon, limit: limit);
  }

  Future<List<GeocodeResult>> geocodeAddress(String query) async {
    final results = await ApiService.geocodeAddress(query);
    return results.map((r) => GeocodeResult.fromJson(r)).toList();
  }

  Future<List<RouteSuggestion>> getRouteSuggestions({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    final results = await ApiService.suggestRoutes(
      startLat: startLat,
      startLng: startLng,
      destLat: destLat,
      destLng: destLng,
    );
    if (results['success'] == true && results['routes'] != null) {
      return (results['routes'] as List)
          .map((r) => RouteSuggestion.fromJson(r))
          .toList();
    }
    return [];
  }

  Future<Map<String, String>> authHeaders() {
    return ApiService.authHeaders();
  }
}
