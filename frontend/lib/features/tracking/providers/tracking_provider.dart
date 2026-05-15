// NEW FILE
import 'package:flutter/foundation.dart';
import '../../../core/services/sensor_service.dart';

class TrackingProvider extends ChangeNotifier {
  final SensorService _sensorService;

  TrackingProvider(this._sensorService);

  double _currentSpeed = 0.0;
  bool _isMonitoring = false;

  double get currentSpeed => _currentSpeed;
  bool get isMonitoring => _isMonitoring;

  void startTracking() {
    _isMonitoring = true;
    _sensorService.startTracking(
      onSpeedChanged: (speed) {
        _currentSpeed = speed;
        notifyListeners();
      },
      onSuddenBraking: () {
        // Handle sudden braking
        debugPrint("[TrackingProvider] Sudden braking detected!");
      },
    );
    notifyListeners();
  }

  void stopTracking() {
    _isMonitoring = false;
    _sensorService.stop();
    notifyListeners();
  }
}
