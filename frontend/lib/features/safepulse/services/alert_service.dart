// lib/features/safepulse/services/alert_service.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';
import 'package:volume_controller/volume_controller.dart';

class AlertService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> initialize() async {
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(false);
  }

  Future<void> maxVolume() async {
    try {
      VolumeController.instance.showSystemUI = false;
      VolumeController.instance.setVolume(1.0);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> flashTorch({int times = 3}) async {
    try {
      bool hasTorch = await TorchLight.isTorchAvailable();
      if (hasTorch) {
        for (int i = 0; i < times; i++) {
          await TorchLight.enableTorch();
          await Future.delayed(const Duration(milliseconds: 300));
          await TorchLight.disableTorch();
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> vibrateAlert() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 500, 500, 500, 500, 500]);
      }
    } catch (e) {
      // Ignore
    }
  }

  bool _isSpeaking = false;

  Future<void> speakWarning(String text, {int times = 1}) async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    try {
      try {
        await _flutterTts.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
      for (int i = 0; i < times; i++) {
        await _flutterTts.speak(text);
        if (i < times - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      Future.delayed(const Duration(seconds: 5), () {
        _isSpeaking = false;
      });
    } catch (_) {
      _isSpeaking = false;
    }
  }
}
