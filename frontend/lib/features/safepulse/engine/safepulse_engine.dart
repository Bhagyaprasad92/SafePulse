// lib/features/safepulse/engine/safepulse_engine.dart
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/ai_service.dart';
import '../services/alert_service.dart';
import '../../../core/repositories/sos_repository.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/realtime_tracking_service.dart';
import '../services/sensor_service.dart';
import '../services/sos_service.dart';
import '../services/warning_service.dart';
import '../../../core/enums.dart';

enum EngineState { idle, monitoring, processingSos }

enum EngineHealthState {
  active,
  recoveringSensors,
  recoveringAI,
  degraded,
  emergency,
}

enum EngineSeverity { normal, warning, critical }

class SafePulseEngine {
  final ServiceInstance? serviceInstance;
  SafePulseEngine({this.serviceInstance}) {
    _initializeServices();
  }

  // Services
  final AIService aiService = AIService();
  final SensorService sensorService = SensorService();
  final LocationService locationService = LocationService();
  final RealtimeTrackingService realtimeTrackingService = RealtimeTrackingService();
  final AlertService alertService = AlertService();
  late final WarningService warningService;
  late final SosService sosService;
  final SOSRepository sosRepository = SOSRepository();

  // Streams
  final logStream = StreamController<LogMessage>.broadcast();
  final speedStream = StreamController<double>.broadcast();
  final distractionStream = StreamController<int>.broadcast();
  final stateStream = StreamController<EngineState>.broadcast();

  // Custom event for police fallback UI
  final callReturnedStream = StreamController<void>.broadcast();

  bool _isRunning = false;
  DateTime? _lastEmergencyTrigger;

  bool sysLocationOn = true;
  bool sysBatterySaverOn = false;

  // --- Watchdog & Recovery State ---
  DateTime _lastSensorEvent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInferenceAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInferenceCompleted = DateTime.fromMillisecondsSinceEpoch(0);

  bool _sensorHealthy = true;
  bool _aiHealthy = true;

  bool _recoveringSensors = false;
  bool _recoveringAI = false;
  final bool _recoveringEngine = false;

  int _degradedRecoveryAttempts = 0;
  DateTime? _lastRecoveryTime;

  EngineHealthState healthState = EngineHealthState.active;
  Timer? _watchdogTimer;
  bool _stopping = false;

  bool _canTriggerSOS() {
    if (_lastEmergencyTrigger == null) {
      _lastEmergencyTrigger = DateTime.now();
      return true;
    }

    final diff = DateTime.now().difference(_lastEmergencyTrigger!);

    if (diff.inSeconds < 30) {
      return false;
    }

    _lastEmergencyTrigger = DateTime.now();
    return true;
  }

  EngineSeverity get severity {
    switch (healthState) {
      case EngineHealthState.active:
        return EngineSeverity.normal;
      case EngineHealthState.recoveringSensors:
      case EngineHealthState.recoveringAI:
      case EngineHealthState.degraded:
        return EngineSeverity.warning;
      case EngineHealthState.emergency:
        return EngineSeverity.critical;
    }
  }

  void pingSensor() {
    _lastSensorEvent = DateTime.now();
  }

  void pingAIAttempt() {
    _lastInferenceAttempt = DateTime.now();
  }

  void pingAICompleted() {
    _lastInferenceCompleted = DateTime.now();
  }

  void _initializeServices() {
    warningService = WarningService(alertService);
    sosService = SosService(sosRepository);

    // Bind loggers
    aiService.onLog = (msg) => log(msg, level: LogLevel.info);
    sensorService.onLog = (msg) => log(msg, level: LogLevel.info);
    locationService.onLog =
        (msg) => log(
          msg,
          level:
              msg.contains("⚠️") || msg.contains("❌")
                  ? LogLevel.warning
                  : LogLevel.info,
        );
    warningService.onLog = (msg) => log(msg, level: LogLevel.warning);
    sosService.onLog =
        (msg) => log(
          msg,
          level:
              msg.contains("FAILED") || msg.contains("⚠️")
                  ? LogLevel.warning
                  : LogLevel.info,
        );

    // Bind event streams
    locationService.onSpeedUpdate = (speedMs) {
      aiService.currentSpeedKmh = speedMs * 3.6;
      speedStream.add(speedMs);
      serviceInstance?.invoke('speed', {'speed': speedMs});
      warningService.handleSpeed(speedMs);
      final position = locationService.lastValidPosition;
      realtimeTrackingService.sendTrackingUpdate(
        speed: speedMs,
        isPhoneOn: true,
        lat: position?.latitude,
        lng: position?.longitude,
      );
    };

    warningService.onDistractionUpdate = (seconds) {
      distractionStream.add(seconds);
      serviceInstance?.invoke('distraction', {'seconds': seconds});
    };

    sensorService.onRawData = (data) {
      pingSensor();
      if (healthState != EngineHealthState.degraded) {
        aiService.addData(data);
      }
    };

    aiService.onCrashDetected = (probability) {
      _handleCrash();
    };

    sosService.onCallReturned = () {
      log("Call returned. Escalate to Police if needed.");
      callReturnedStream.add(null);
      serviceInstance?.invoke('callReturned');
    };

    sosService.onEmergencySOS = (contacts, payload) {
      serviceInstance?.invoke('executeEmergencySOS', {
        'contacts': contacts,
        'payload': payload,
      });
    };

    // Init AI
    aiService.initialize();
    alertService.initialize();
  }

  void log(String message, {LogLevel level = LogLevel.info}) {
    logStream.add(LogMessage(message, level: level));
    try {
      serviceInstance?.invoke('log', {
        'message': message,
        'level': level.index,
      });
    } catch (e) {}
  }

  void _updateState(EngineState state) {
    stateStream.add(state);
    try {
      serviceInstance?.invoke('state', {'state': state.index});
    } catch (e) {}
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _stopping = false;

    _updateState(EngineState.monitoring);
    healthState = EngineHealthState.active;
    log("🛡️ AI Dashcam STARTED in Background Isolate.");

    _lastSensorEvent = DateTime.fromMillisecondsSinceEpoch(0);
    _lastInferenceAttempt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastInferenceCompleted = DateTime.fromMillisecondsSinceEpoch(0);

    sensorService.start();
    locationService.startSpeedMonitoring();
    unawaited(_connectRealtimeTracking());

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _healthCheck(),
    );
  }

  Future<void> _healthCheck() async {
    if (_recoveringSensors || _recoveringAI || _recoveringEngine || _stopping) {
      return; // Cascade prevention
    }

    final now = DateTime.now();

    final avgGapMs = sensorService.avgGapMs;
    final dynamicTimeoutSeconds = (avgGapMs * 10 / 1000).toInt();
    final timeout = dynamicTimeoutSeconds.clamp(5, 25);

    final sensorDead = now.difference(_lastSensorEvent).inSeconds > timeout;
    final aiStall =
        now.difference(_lastInferenceAttempt).inSeconds > 20 &&
        _lastInferenceAttempt.isAfter(_lastInferenceCompleted);

    _sensorHealthy = !sensorDead;
    _aiHealthy = !aiStall;

    if (_sensorHealthy && _aiHealthy) {
      if (healthState != EngineHealthState.active) {
        healthState = EngineHealthState.active;
        log("System fully recovered. Monitoring active.");
      }
      _degradedRecoveryAttempts = 0; // Reset budget
      return;
    }

    if (avgGapMs > 200) {
      log(
        "Sensor cadence degraded: ${avgGapMs.toStringAsFixed(1)}ms gap",
        level: LogLevel.warning,
      );
    }

    if (healthState == EngineHealthState.degraded) {
      if (_degradedRecoveryAttempts < 5) {
        _degradedRecoveryAttempts++;
        log(
          "Degraded Mode: Attempting lightweight recovery ($_degradedRecoveryAttempts/5)",
        );
        _recoverSensors();
      }
      return;
    }

    if (_lastRecoveryTime != null &&
        now.difference(_lastRecoveryTime!).inSeconds < 20) {
      return;
    }

    _lastRecoveryTime = now;

    if (sensorDead) {
      _recoverSensors();
    } else if (aiStall) {
      _recoverAI();
    }
  }

  Future<void> _recoverSensors() async {
    _recoveringSensors = true;
    healthState =
        healthState == EngineHealthState.degraded
            ? EngineHealthState.degraded
            : EngineHealthState.recoveringSensors;
    log("Watchdog: Restarting sensors...", level: LogLevel.warning);
    try {
      await sensorService.restart();
    } finally {
      _recoveringSensors = false;
      _checkDegradeEscalation();
    }
  }

  Future<void> _recoverAI() async {
    _recoveringAI = true;
    healthState = EngineHealthState.recoveringAI;
    log("Watchdog: Resetting AI pipeline...", level: LogLevel.warning);
    try {
      aiService.resetProcessingState();
    } finally {
      _recoveringAI = false;
      _checkDegradeEscalation();
    }
  }

  void _checkDegradeEscalation() {
    if (healthState != EngineHealthState.degraded) {
      _degradedRecoveryAttempts++;
      if (_degradedRecoveryAttempts >= 3) {
        healthState = EngineHealthState.degraded;
        log(
          "Watchdog: Recovery limit exceeded. Entering Degraded Mode.",
          level: LogLevel.critical,
        );
      }
    }
  }

  Future<void> stop() async {
    if (_stopping || !_isRunning) return;
    _stopping = true;
    _isRunning = false;

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _updateState(EngineState.idle);
    await sensorService.stop();
    locationService.stop();
    await realtimeTrackingService.disconnect();
    log("🛑 AI Dashcam STOPPED.");
  }

  Future<void> _handleCrash() async {
    if (!_canTriggerSOS()) {
      return;
    }

    try {
      log("🚀 SOS TRIGGERED AUTONOMOUSLY BY AI!", level: LogLevel.critical);
      _updateState(EngineState.processingSos);

      final position = await locationService.getCurrentPositionSafe();
      bool hasLocation = position != null;
      int? locationAgeSec =
          hasLocation && locationService.lastValidTime != null
              ? DateTime.now()
                  .difference(locationService.lastValidTime!)
                  .inSeconds
              : null;

      double lat = position?.latitude ?? 0.0;
      double lng = position?.longitude ?? 0.0;

      log("Initiating Hybrid SOS Protocol...", level: LogLevel.critical);
      double currentSpeed = locationService.currentSpeedMs ?? 0.0;
      await sosService.triggerHybridSOS(
        lat: lat,
        lng: lng,
        hasLocation: hasLocation,
        locationAgeSec: locationAgeSec,
        speedMs: currentSpeed,
      );
    } finally {
      _updateState(EngineState.idle);
    }
  }

  void dispose() {
    logStream.close();
    speedStream.close();
    distractionStream.close();
    stateStream.close();
    callReturnedStream.close();

    aiService.dispose();
    warningService.dispose();
    unawaited(realtimeTrackingService.dispose());
  }

  Future<void> _connectRealtimeTracking() async {
    try {
      await realtimeTrackingService.connect();
      log("Realtime WebSocket tracking connected.");
    } catch (e) {
      log("Realtime WebSocket unavailable: $e", level: LogLevel.warning);
    }
  }
}
