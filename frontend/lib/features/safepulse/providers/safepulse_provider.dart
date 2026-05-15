import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../engine/safepulse_engine.dart';
import '../../../core/repositories/sos_repository.dart';
import '../../../core/services/location_service.dart';
import '../../../core/enums.dart';

// Note: SafePulseProvider in the UI isolate acts as a proxy for the background service.
// It should NOT run its own SafePulseEngine instance to avoid resource conflicts and crashes.

class SafePulseProvider extends ChangeNotifier {
  final SOSRepository _sosRepo;
  final LocationService _locationService;

  SafePulseProvider(this._sosRepo, this._locationService);

  // State synced from background service
  EngineState _state = EngineState.idle;
  double _currentSpeed = 0.0;
  int _distractionSeconds = 0;
  final List<LogMessage> _logs = [];
  LogMessage? _lastCriticalLog;

  // Getters
  EngineState get state => _state;
  double get currentSpeed => _currentSpeed;
  int get distractionSeconds => _distractionSeconds;
  List<LogMessage> get logs => List.unmodifiable(_logs);
  LogMessage? get lastCriticalLog => _lastCriticalLog;
  bool get isMonitoring => _state == EngineState.monitoring;
  bool get isProcessing => _state == EngineState.processingSos;

  void initialize() {
    // Sync with background service events
    _subscribeToBackgroundService();
  }

  void _subscribeToBackgroundService() {
    final service = FlutterBackgroundService();
    
    // Listen for state changes
    service.on('state').listen((event) {
      if (event != null) {
        final stateIndex = event['state'] as int;
        if (stateIndex >= 0 && stateIndex < EngineState.values.length) {
          _state = EngineState.values[stateIndex];
          notifyListeners();
        }
      }
    });

    // Listen for speed updates
    service.on('speed').listen((event) {
      if (event != null) {
        _currentSpeed = (event['speed'] as num).toDouble();
        notifyListeners();
      }
    });

    // Listen for distraction updates
    service.on('distraction').listen((event) {
      if (event != null) {
        _distractionSeconds = event['seconds'] as int;
        notifyListeners();
      }
    });

    // Listen for logs
    service.on('log').listen((event) {
      if (event != null) {
        final log = LogMessage(
          event['message'] as String,
          level: LogLevel.values[event['level'] as int],
        );
        _logs.insert(0, log);
        if (_logs.length > 100) _logs.removeLast(); // Prevent memory leak
        
        if (log.level == LogLevel.critical) {
          _lastCriticalLog = log;
        }
        notifyListeners();
      }
    });
  }

  Future<void> startMonitoring() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    // The background service will handle starting the engine via onStart()
  }

  Future<void> stopMonitoring() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  Future<void> triggerManualSOS() async {
    final pos = await _locationService.getCurrentPositionSafe();
    if (pos != null) {
      await _sosRepo.startSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        address: "Manual Emergency",
      );
    }
  }

  @override
  void dispose() {
    // No local engine to dispose anymore
    super.dispose();
  }
}
