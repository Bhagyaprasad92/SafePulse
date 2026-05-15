import 'package:flutter/material.dart';

class SafetyBreakdown {
  final RiskComponent crimeRisk;
  final RiskComponent accidentRisk;
  final RiskComponent roadQuality;
  final RiskComponent lighting;
  final RiskComponent traffic;

  SafetyBreakdown({
    required this.crimeRisk,
    required this.accidentRisk,
    required this.roadQuality,
    required this.lighting,
    required this.traffic,
  });

  factory SafetyBreakdown.fromJson(Map<String, dynamic> json) {
    return SafetyBreakdown(
      crimeRisk: RiskComponent.fromJson(json['crimeRisk'] ?? {}),
      accidentRisk: RiskComponent.fromJson(json['accidentRisk'] ?? {}),
      roadQuality: RiskComponent.fromJson(json['roadQuality'] ?? {}),
      lighting: RiskComponent.fromJson(json['lighting'] ?? {}),
      traffic: RiskComponent.fromJson(json['traffic'] ?? {}),
    );
  }
}

class RiskComponent {
  final int score;
  final String level;
  final double weight;
  final Map<String, dynamic>? details;

  RiskComponent({
    required this.score,
    required this.level,
    required this.weight,
    this.details,
  });

  factory RiskComponent.fromJson(Map<String, dynamic> json) {
    return RiskComponent(
      score: json['score'] ?? 0,
      level: json['level'] ?? 'moderate',
      weight: (json['weight'] ?? 0.0).toDouble(),
      details: json['details'],
    );
  }

  Color get color {
    switch (level) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'high':
        return Colors.deepOrange;
      case 'very_high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get label {
    switch (level) {
      case 'low':
        return 'Low Risk';
      case 'moderate':
        return 'Moderate';
      case 'high':
        return 'High Risk';
      case 'very_high':
        return 'Very High';
      default:
        return 'Unknown';
    }
  }
}

class RouteWarning {
  final String type;
  final String severity;
  final String message;

  RouteWarning({
    required this.type,
    required this.severity,
    required this.message,
  });

  factory RouteWarning.fromJson(Map<String, dynamic> json) {
    return RouteWarning(
      type: json['type'] ?? '',
      severity: json['severity'] ?? 'medium',
      message: json['message'] ?? '',
    );
  }

  IconData get icon {
    switch (type) {
      case 'high_crime':
        return Icons.warning;
      case 'accident_prone':
        return Icons.car_crash;
      case 'poor_lighting':
        return Icons.lightbulb_outline;
      default:
        return Icons.info;
    }
  }

  Color get color {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
}

class RouteRecommendation {
  final String priority;
  final String message;
  final String reason;

  RouteRecommendation({
    required this.priority,
    required this.message,
    required this.reason,
  });

  factory RouteRecommendation.fromJson(Map<String, dynamic> json) {
    return RouteRecommendation(
      priority: json['priority'] ?? 'low',
      message: json['message'] ?? '',
      reason: json['reason'] ?? '',
    );
  }

  Color get color {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}