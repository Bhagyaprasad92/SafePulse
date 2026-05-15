import 'package:flutter/material.dart';

enum SafetyStatus { normal, warning, danger }

class SafetyAiMonitorService {
  static Map<String, dynamic> analyzeRisk({
    required double speed,
    required int riskZoneScore,
    required bool isOffRoute,
    required DateTime time,
  }) {
    int riskLevel = 0;
    String message = "Drive safe!";
    SafetyStatus status = SafetyStatus.normal;

    // 1. Overspeed check
    if (speed > 80) {
      riskLevel += 3;
    } else if (speed > 65) riskLevel += 1;

    // 2. Risk zone check
    if (riskZoneScore > 60) {
      riskLevel += 2;
    } else if (riskZoneScore > 30) riskLevel += 1;

    // 3. Night time check (8 PM to 5 AM)
    int hour = time.hour;
    if (hour >= 20 || hour <= 5) riskLevel += 1;

    // 4. Off-route check
    if (isOffRoute) riskLevel += 2;

    // Final Decision
    if (riskLevel >= 5) {
      status = SafetyStatus.danger;
      message = "HIGH RISK! Moving fast in dangerous conditions.";
    } else if (riskLevel >= 3) {
      status = SafetyStatus.warning;
      message = "Be cautious. Safety score is decreasing.";
    }

    return {
      'status': status,
      'message': message,
      'score': riskLevel,
    };
  }
}
