import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../models/circle.dart';

class CircleRepository {
  Future<List<Circle>> getMyCircles() async {
    final result = await ApiService.getUserCircles();
    if (result['success'] == true && result['circles'] != null) {
      return (result['circles'] as List)
          .map((e) => Circle.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createCircle(String name) {
    return ApiService.createCircle(name);
  }

  Future<Map<String, dynamic>> joinCircle(String inviteCode) {
    return ApiService.joinCircle(inviteCode);
  }

  Future<Map<String, dynamic>> requestDeleteCircle(String circleId) {
    return ApiService.requestDeleteCircle(circleId);
  }

  Future<void> updateMemberLocation({
    required double lat,
    required double lng,
    required int batteryLevel,
  }) async {
    final headers = await ApiService.authHeaders();
    await http.put(
      Uri.parse('${ApiService.baseUrl}/api/circle/update-location'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lng': lng, 'batteryLevel': batteryLevel}),
    );
  }

  Future<List<Map<String, dynamic>>> getCircleMemberLocations(String circleId) async {
    final headers = await ApiService.authHeaders();
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/api/circle/$circleId/members-location'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['members'] ?? []);
      }
    }
    return [];
  }
}
