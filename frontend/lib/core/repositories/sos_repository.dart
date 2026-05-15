// MOVED FROM: lib/core/repositories/sos_repository.dart
import '../services/api_service.dart';
import '../models/sos_event.dart';

class SOSRepository {
  Future<SOSEvent?> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) async {
    final result = await ApiService.startSOS(lat: lat, lng: lng, address: address);
    if (result != null && result['success'] == true && result['sosId'] != null) {
      return await getStatus(result['sosId']);
    }
    return null;
  }

  Future<bool> cancelSOS(String sosId) {
    return ApiService.cancelSOS(sosId);
  }

  Future<SOSEvent?> getStatus(String sosId) async {
    final result = await ApiService.getSOSStatus(sosId);
    if (result != null) {
      return SOSEvent.fromJson(result);
    }
    return null;
  }

  Future<Map<String, dynamic>> getNearbyServices({
    required double lat,
    required double lon,
  }) {
    return ApiService.getNearbyServices(lat: lat, lon: lon);
  }

  Future<bool> sendSafePulseSOS(
    double lat,
    double lng,
    String severity, {
    bool hasLocation = true,
    int? locationAgeSec,
  }) {
    return ApiService.sendSafePulseSOS(
      lat,
      lng,
      severity,
      hasLocation: hasLocation,
      locationAgeSec: locationAgeSec,
    );
  }

  Future<Map<String, dynamic>> getServicesInBBox({
    required double south,
    required double west,
    required double north,
    required double east,
    String type = 'all',
  }) {
    return ApiService.getServicesInBBox(
      south: south,
      west: west,
      north: north,
      east: east,
      type: type,
    );
  }

  Future<Map<String, dynamic>> suggestRoutes({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) {
    return ApiService.suggestRoutes(
      startLat: startLat,
      startLng: startLng,
      destLat: destLat,
      destLng: destLng,
    );
  }
}
