// lib/features/safepulse/services/ai_service.dart
import 'dart:async';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/services/api_service.dart';

class AIService {
  Interpreter? _interpreter;
  final List<List<double>> _sensorBuffer = [];
  
  Function(double probability)? onCrashDetected;
  Function(String message)? onLog;
  Function()? onInferenceAttempt;
  Function()? onInferenceCompleted;
  double currentSpeedKmh = 0.0;

  bool _isProcessing = false;
  bool _resetting = false;
  
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/crash_model.tflite');
      onLog?.call("🧠 TFLite AI Crash Model Loaded!");
      print("AIService: TFLite Model Loaded!");
    } catch (e) {
      onLog?.call("❌ ERROR: Failed to load AI model. Check assets folder.");
      print("AIService: TFLite Model FAILED TO LOAD! Error: $e");
    }
  }

  void addData(List<double> data) {
    if (_resetting) return;
    
    _sensorBuffer.add(data);

    if (_sensorBuffer.length > 250) {
      _sensorBuffer.removeAt(0); // Keep exactly 5 seconds
    }

    double ax = data[0], ay = data[1], az = data[2];
    double gForce = sqrt(pow(ax, 2) + pow(ay, 2) + pow(az, 2)) / 9.81;

    if (gForce > 3.0 && _sensorBuffer.length == 250) {
      if (!_isProcessing) {
        onLog?.call("⚠️ IMPACT: ${gForce.toStringAsFixed(1)} Gs. AI Analyzing...");
        print("AIService: IMPACT DETECTED! G-Force: ${gForce.toStringAsFixed(1)}");
        unawaited(_runAIAnalysis(List.from(_sensorBuffer), gForce));
        if (!_resetting) {
          _sensorBuffer.clear();
        }
      }
    }
  }

  void resetProcessingState() {
    _resetting = true;
    _isProcessing = false;
    _sensorBuffer.clear();
    _resetting = false;
  }

  int _recentSpikeCount = 0;

  Future<void> _runAIAnalysis(List<List<double>> windowToAnalyze, double maxGForce) async {
    _isProcessing = true;
    onInferenceAttempt?.call();

    final serverHandled = await _runServerAIAnalysis(windowToAnalyze);
    if (serverHandled) {
      _isProcessing = false;
      onInferenceCompleted?.call();
      return;
    }
    
    if (_interpreter == null) {
      if (maxGForce > 3.5) { // Lowered to 3.5 for manual testing
        _recentSpikeCount++;
        print("AIService: INTERPRETER NULL. Spike count: $_recentSpikeCount / 2");
        if (_recentSpikeCount >= 2) {
          print("AIService: FALLBACK CRASH TRIGGERED!");
          onLog?.call("⚠️ Basic Threshold Crash Detected! (AI offline)");
          onCrashDetected?.call(1.0);
        } else {
          onLog?.call("⚠️ Spike detected. Awaiting temporal confirmation...");
        }
        Future.delayed(const Duration(seconds: 2), () {
          _recentSpikeCount = 0;
        });
      } else {
        onLog?.call("⚠️ Impact filtered by Basic Threshold (AI offline)");
      }
      _isProcessing = false;
      onInferenceCompleted?.call();
      return;
    }

    try {
      var input = [windowToAnalyze];
      var output = List.filled(1, 0.0).reshape([1, 1]);

      _interpreter!.run(input, output);
      double crashProbability = output[0][0];

      if (crashProbability > 0.25) {
        print("AIService: AI CONFIRMED CRASH ($crashProbability)");
        onCrashDetected?.call(crashProbability);
      } else {
        print("AIService: AI FILTERED FALSE ALARM ($crashProbability)");
        onLog?.call("✅ AI Filtered: Just a drop/bump. (${(crashProbability * 100).toStringAsFixed(1)}%)");
      }
    } catch (e) {
      print("AIService: AI ERROR EXCEPTION: $e");
      onLog?.call("❌ AI Error: $e. Falling back to basic threshold.");
      if (maxGForce > 3.5) { // Lowered to 3.5 for manual testing
        print("AIService: FALLBACK THRESHOLD MET! Triggering SOS.");
        onCrashDetected?.call(1.0);
      } else {
        print("AIService: FALLBACK THRESHOLD NOT MET. ($maxGForce <= 3.5)");
      }
    } finally {
      _isProcessing = false;
      onInferenceCompleted?.call();
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  Future<bool> _runServerAIAnalysis(List<List<double>> windowToAnalyze) async {
    try {
      final samples = windowToAnalyze.map((data) {
        return {
          'ax': data[0],
          'ay': data[1],
          'az': data[2],
          'gx': data.length > 3 ? data[3] : 0.0,
          'gy': data.length > 4 ? data[4] : 0.0,
          'gz': data.length > 5 ? data[5] : 0.0,
          'speedKmh': currentSpeedKmh,
        };
      }).toList();

      final response = await ApiService.analyzeAccidentWindow(samples: samples);
      if (response['success'] != true || response['analysis'] is! Map) {
        onLog?.call("AI service unavailable. Falling back to local crash model.");
        return false;
      }

      final analysis = Map<String, dynamic>.from(response['analysis'] as Map);
      final probability = (analysis['crashProbability'] as num?)?.toDouble() ?? 0.0;
      final detected = analysis['crashDetected'] == true;
      final modelUsed = analysis['modelUsed'] ?? 'server-ai';

      if (detected) {
        onLog?.call("Server AI confirmed crash via $modelUsed (${(probability * 100).toStringAsFixed(1)}%).");
        onCrashDetected?.call(probability);
      } else {
        onLog?.call("Server AI filtered impact (${(probability * 100).toStringAsFixed(1)}%).");
      }
      return true;
    } catch (e) {
      onLog?.call("AI service error: $e. Falling back to local crash model.");
      return false;
    }
  }
}
