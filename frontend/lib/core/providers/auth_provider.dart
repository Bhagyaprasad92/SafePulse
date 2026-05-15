// MOVED FROM: lib/core/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final UserRepository _repo;

  AuthProvider(this._repo);

  AuthStatus _status = AuthStatus.unknown;
  String? _userId;
  User? _user;

  AuthStatus get status => _status;
  String? get userId => _userId;
  User? get user => _user;
  bool get isLoggedIn => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    final loggedIn = await _repo.isLoggedIn();
    _userId = await _repo.getUserId();
    _status = loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
    
    if (loggedIn) {
      loadProfile(); // Do not await, let it happen in background
    }
  }

  Future<void> saveSession({
    required String userId,
    required String token,
  }) async {
    await _repo.saveSession(userId: userId, token: token);
    _userId = userId;
    _status = AuthStatus.authenticated;
    await loadProfile();
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.clearSession();
    _userId = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final profile = await _repo.getProfile();
    if (profile != null) {
      _user = profile;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) {
    return _repo.sendOtp(phone);
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email, {String? name, String? phone}) {
    return _repo.sendEmailOtp(email, name: name, phone: phone);
  }

  Future<Map<String, dynamic>> verifyOtp(String? phone, String otp, {String? email}) {
    return _repo.verifyOtp(phone, otp, email: email);
  }

  Future<void> updateStatus({
    required double lat,
    required double lng,
    String? batteryLevel,
    bool? isDriving,
    double? currentSpeed,
    String? fcmToken,
  }) {
    return _repo.updateStatus(
      lat: lat,
      lng: lng,
      batteryLevel: batteryLevel,
      isDriving: isDriving,
      currentSpeed: currentSpeed,
      fcmToken: fcmToken,
    );
  }
}
