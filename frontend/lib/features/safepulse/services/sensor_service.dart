// lib/features/safepulse/services/sensor_service.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  Timer? _sensorTimer;
  Function(List<double> data)? onRawData;
  Function(String message)? onLog;

  double avgGapMs = 20.0;
  DateTime _lastTick = DateTime.now();

  int _accelRetryCount = 0;
  int _gyroRetryCount = 0;

  void start() {
    if (_sensorTimer != null || _accelSub != null || _gyroSub != null) return;
    
    _lastTick = DateTime.now();
    _startAccel();
    _startGyro();

    _sensorTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      final now = DateTime.now();
      final gap = now.difference(_lastTick).inMilliseconds.toDouble();
      avgGapMs = ((avgGapMs * 0.8) + (gap * 0.2)).clamp(20.0, 500.0);
      _lastTick = now;

      if (onRawData != null) {
        onRawData!([_ax, _ay, _az, _gx, _gy, _gz]);
      }
    });
    
    onLog?.call("Sensors active. Reading at 50Hz.");
  }

  Future<void> stop() async {
    _sensorTimer?.cancel();
    _sensorTimer = null;
    await _accelSub?.cancel();
    _accelSub = null;
    await _gyroSub?.cancel();
    _gyroSub = null;
    onLog?.call("Sensors stopped.");
  }

  Future<void> restart() async {
    stop();
    await Future.delayed(const Duration(seconds: 1));
    start();
  }

  void _startAccel() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEventStream().listen(
      (event) {
        _accelRetryCount = 0;
        _ax = event.x;
        _ay = event.y;
        _az = event.z;
      },
      onError: (_) => _restartAccel(),
      onDone: () => _restartAccel(),
    );
  }

  void _restartAccel() {
    final delay = Duration(milliseconds: min(500 * (_accelRetryCount + 1), 5000));
    onLog?.call("⚠️ Accelerometer error. Retrying in ${delay.inMilliseconds}ms...");
    Future.delayed(delay, () {
      _accelRetryCount++;
      _startAccel();
    });
  }

  void _startGyro() {
    _gyroSub?.cancel();
    _gyroSub = gyroscopeEventStream().listen(
      (event) {
        _gyroRetryCount = 0;
        _gx = event.x;
        _gy = event.y;
        _gz = event.z;
      },
      onError: (_) => _restartGyro(),
      onDone: () => _restartGyro(),
    );
  }

  void _restartGyro() {
    final delay = Duration(milliseconds: min(500 * (_gyroRetryCount + 1), 5000));
    onLog?.call("⚠️ Gyroscope error. Retrying in ${delay.inMilliseconds}ms...");
    Future.delayed(delay, () {
      _gyroRetryCount++;
      _startGyro();
    });
  }
}
