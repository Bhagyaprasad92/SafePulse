import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safepulse/core/services/api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'userId': 'test_user_id',
      'auth_token': 'test_token',
    });
  });

  group('ApiService Tests (Coverage for error paths)', () {
    test('sendSpeedAlert completes without throwing', () async {
      await ApiService.sendSpeedAlert(speed: 100, lat: 10, lon: 10, limit: 80);
      expect(true, isTrue);
    });

    test('sendRiskAlert completes without throwing', () async {
      await ApiService.sendRiskAlert(lat: 10, lon: 10, reason: 'Test Risk');
      expect(true, isTrue);
    });

    test('getToken returns mocked token', () async {
      final token = await ApiService.getToken();
      expect(token, 'test_token');
    });

    test('authHeaders includes token', () async {
      final headers = await ApiService.authHeaders();
      expect(headers['Authorization'], 'Bearer test_token');
    });

    test('sendOtp returns error map on connection failure', () async {
      final result = await ApiService.sendOtp('1234567890');
      expect(result['success'], false);
    });

    test('sendEmailOtp returns error map on connection failure', () async {
      final result = await ApiService.sendEmailOtp('test@test.com');
      expect(result['success'], false);
    });

    test('verifyOtp returns error map on connection failure', () async {
      final result = await ApiService.verifyOtp('1234567890', '123456');
      expect(result['success'], false);
    });

    test('getMyProfile returns error map on connection failure', () async {
      final result = await ApiService.getMyProfile();
      expect(result['success'], false);
    });

    test('updateStatus completes without throwing', () async {
      await ApiService.updateStatus(lat: 10, lng: 10);
      expect(true, isTrue);
    });

    test('suggestRoutes returns error map on connection failure', () async {
      final result = await ApiService.suggestRoutes(
        startLat: 10, startLng: 10, destLat: 20, destLng: 20,
      );
      expect(result.containsKey('error'), true);
    });

    test('startSOS returns null on connection failure', () async {
      final result = await ApiService.startSOS(lat: 10, lng: 10);
      expect(result, isNull);
    });

    test('cancelSOS returns false on connection failure', () async {
      final result = await ApiService.cancelSOS('sos_id');
      expect(result, false);
    });

    test('getSOSStatus returns null on connection failure', () async {
      final result = await ApiService.getSOSStatus('sos_id');
      expect(result, isNull);
    });

    test('getNearbyServices completes without throwing', () async {
      final result = await ApiService.getNearbyServices(lat: 10, lon: 10);
      expect(result, isNotNull);
    });

    test('getServicesInBBox completes without throwing', () async {
      final result = await ApiService.getServicesInBBox(
        south: 10, west: 10, north: 20, east: 20, type: 'all',
      );
      expect(result, isNotNull);
    });

    test('geocodeAddress completes without throwing', () async {
      final result = await ApiService.geocodeAddress('Test Address');
      expect(result, isNotNull);
    });

    test('syncEmergencyContacts completes without throwing', () async {
      await ApiService.syncEmergencyContacts([{'phone': '123'}]);
      expect(true, isTrue);
    });

    test('createCircle completes without throwing', () async {
      final result = await ApiService.createCircle('Family');
      expect(result, isNotNull);
    });

    test('joinCircle completes without throwing', () async {
      final result = await ApiService.joinCircle('CODE');
      expect(result, isNotNull);
    });

    test('getUserCircles completes without throwing', () async {
      final result = await ApiService.getUserCircles();
      expect(result, isNotNull);
    });
  });
}
