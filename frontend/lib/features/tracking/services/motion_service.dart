import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

class MotionService {
  /// Monitor for potential high-impact crashes.
  Stream<bool> monitorCrash() {
    return userAccelerometerEvents.map((event) {
      // Threshold for crash detection (~3.5G)
      const double crashThreshold = 35.0;
      return event.x.abs() > crashThreshold ||
          event.y.abs() > crashThreshold ||
          event.z.abs() > crashThreshold;
    });
  }

  /// Detect sudden braking / rapid deceleration.
  Stream<bool> monitorSuddenBraking() {
    return userAccelerometerEvents.map((event) {
      // Threshold for sudden braking (~0.5G - 0.7G)
      // Note: This is simplified; real apps would calibrate based on device orientation
      const double brakingThreshold = 7.0;
      return event.y < -brakingThreshold || event.z < -brakingThreshold;
    });
  }

  /// Detect if the phone is being handled while driving.
  Stream<bool> monitorPhoneHandling() {
    return gyroscopeEvents.map((event) {
      // Threshold for rotation indicating handling (~1.5 rad/s)
      const double rotationThreshold = 1.5;
      return event.x.abs() > rotationThreshold ||
          event.y.abs() > rotationThreshold ||
          event.z.abs() > rotationThreshold;
    });
  }

  /// Detect over-speeding.
  Stream<double> monitorSpeed() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((pos) => pos.speed * 3.6); // Convert to km/h
  }
}
