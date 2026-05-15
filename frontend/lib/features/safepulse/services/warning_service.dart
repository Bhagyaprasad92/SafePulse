// lib/features/safepulse/services/warning_service.dart
import 'package:screen_state/screen_state.dart';
import 'dart:async';
import 'alert_service.dart';

class WarningService {
  final AlertService alertService;
  
  DateTime? _lastSpeedWarningTime;
  Timer? _distractionTimer;
  int _distractionSeconds = 0;
  
  final int distractionDemoThreshold = 15;
  final double overspeedLimitMs = 2.0; // ~7.2 km/h
  final double distractionLimitMs = 1.0; // ~3.6 km/h
  
  bool _isScreenOn = true;
  StreamSubscription<ScreenStateEvent>? _screenStateSub;
  
  Function(int seconds)? onDistractionUpdate;
  Function(String message)? onLog;

  WarningService(this.alertService) {
    _initScreenState();
  }

  void _initScreenState() {
    try {
      _screenStateSub = Screen().screenStateStream.listen((ScreenStateEvent event) {
        if (event == ScreenStateEvent.SCREEN_ON || event == ScreenStateEvent.SCREEN_UNLOCKED) {
          _isScreenOn = true;
          onLog?.call("📱 System: Screen Turned ON");
        } else if (event == ScreenStateEvent.SCREEN_OFF) {
          _isScreenOn = false;
          onLog?.call("📵 System: Screen Locked (Safe)");
          _stopDistractionTimer();
        }
      });
    } catch (e) {
      // Ignore
    }
  }

  void dispose() {
    _screenStateSub?.cancel();
    _stopDistractionTimer();
  }

  void handleSpeed(double speedMs) {
    // 1. Overspeed Logic
    if (speedMs > overspeedLimitMs) {
      _triggerOverspeedWarning(speedMs);
    }

    // 2. Distraction Logic
    if (speedMs > distractionLimitMs && _isScreenOn) {
      if (_distractionTimer == null || !_distractionTimer!.isActive) {
        _startDistractionTimer();
      }
    } else if (speedMs <= distractionLimitMs) {
      _stopDistractionTimer();
    }
  }

  void _triggerOverspeedWarning(double speedMs) async {
    // 15 seconds cooldown
    if (_lastSpeedWarningTime == null || 
        DateTime.now().difference(_lastSpeedWarningTime!) > const Duration(seconds: 15)) {
      _lastSpeedWarningTime = DateTime.now();
      
      onLog?.call("⚠️ SPEED LIMIT EXCEEDED");
      
      await alertService.maxVolume();
      alertService.vibrateAlert();
      alertService.flashTorch();
      
      await alertService.speakWarning("Warning! Reduce your speed. You are moving too fast.", times: 3);
    }
  }

  void _startDistractionTimer() {
    onLog?.call("👀 Distraction tracker started (Speeding + Screen ON)");
    _distractionSeconds = 0;
    onDistractionUpdate?.call(_distractionSeconds);

    _distractionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _distractionSeconds++;
      onDistractionUpdate?.call(_distractionSeconds);

      if (_distractionSeconds == distractionDemoThreshold) {
        alertService.speakWarning("Warning! Distracted driving detected. Please put your phone away.");
        onLog?.call("🚨 DISTRACTED DRIVING WARNING ISSUED");
      } else if (_distractionSeconds > distractionDemoThreshold && _distractionSeconds % 10 == 0) {
        alertService.speakWarning("Please lock your screen immediately.");
      }
    });
  }

  void _stopDistractionTimer() {
    if (_distractionTimer != null && _distractionTimer!.isActive) {
      _distractionTimer!.cancel();
      _distractionSeconds = 0;
      onDistractionUpdate?.call(_distractionSeconds);
      onLog?.call("✅ Distraction averted.");
    }
  }
}
