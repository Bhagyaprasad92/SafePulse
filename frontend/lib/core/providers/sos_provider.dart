// MOVED FROM: lib/core/providers/sos_provider.dart
import 'package:flutter/foundation.dart';
import '../repositories/sos_repository.dart';
import '../models/sos_event.dart';

enum SOSStatus { idle, active, cancelled }

class SOSProvider extends ChangeNotifier {
  final SOSRepository _repo;

  SOSProvider(this._repo);

  SOSStatus _status = SOSStatus.idle;
  SOSEvent? _activeSos;
  bool _isLoading = false;
  Map<String, dynamic>? _nearbyData;

  SOSStatus get status => _status;
  SOSEvent? get activeSos => _activeSos;
  bool get isLoading => _isLoading;
  bool get isActive => _status == SOSStatus.active;
  Map<String, dynamic>? get nearbyData => _nearbyData;
  String? get activeSosId => _activeSos?.id;

  Future<bool> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repo.startSOS(lat: lat, lng: lng, address: address);
      if (result != null) {
        _activeSos = result;
        _status = SOSStatus.active;
        return true;
      }
    } catch (e) {
      debugPrint('[SOSProvider] startSOS error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> cancelSOS() async {
    if (_activeSos == null) return;
    final success = await _repo.cancelSOS(_activeSos!.id);
    if (success) {
      _status = SOSStatus.cancelled;
      _activeSos = null;
      notifyListeners();
    }
  }

  Future<void> loadNearbyServices({
    required double lat,
    required double lon,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _repo.getNearbyServices(lat: lat, lon: lon);
      _nearbyData = response; // response is already a Map
    } catch (e) {
      debugPrint('[SOSProvider] loadNearbyServices error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSOSStatus() async {
    if (_activeSos == null) return;
    try {
      final updated = await _repo.getStatus(_activeSos!.id);
      if (updated != null) {
        _activeSos = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SOSProvider] refreshSOSStatus error: $e');
    }
  }

  void reset() {
    _status = SOSStatus.idle;
    _activeSos = null;
    notifyListeners();
  }
}
