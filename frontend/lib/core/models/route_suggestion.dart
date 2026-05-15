import 'package:flutter/foundation.dart';

class RouteSuggestion {
  // Existing fields
  final String type;
  final String color;
  final String riskScore;
  final double duration;
  final double distance;
  final List<List<double>> polyline;
  
  // ✨ NEW FIELDS - Add these
  final int safetyScore;      // 0-100 (higher is safer)
  final String safetyLevel;   // 'very_safe', 'safe', 'moderate', 'caution', 'unsafe'
  final int actualRiskScore;  // 0-100 numeric version
  final List<RouteWarning> warnings;
  final List<RouteRecommendation> recommendations;
  
  RouteSuggestion({
    required this.type,
    required this.color,
    required this.riskScore,
    required this.duration,
    required this.distance,
    required this.polyline,
    this.safetyScore = 50,              // Default values
    this.safetyLevel = 'moderate',
    this.actualRiskScore = 50,
    this.warnings = const [],
    this.recommendations = const [],
  });
  
  factory RouteSuggestion.fromJson(Map<String, dynamic> json) {
    return RouteSuggestion(
      type: json['type'] ?? 'Unknown',
      color: json['color'] ?? 'blue',
      riskScore: json['riskScore']?.toString() ?? 'N/A',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      polyline: (json['polyline'] as List?)
          ?.map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
          .toList() ?? [],
      
      // ✨ PARSE NEW FIELDS
      safetyScore: json['safetyScore'] ?? 50,
      safetyLevel: json['safetyLevel'] ?? 'moderate',
      actualRiskScore: json['riskScore'] is int ? json['riskScore'] : 50,
      
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((w) => RouteWarning.fromJson(w))
              .toList() ?? [],
      
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => RouteRecommendation.fromJson(r))
              .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'color': color,
      'riskScore': riskScore,
      'duration': duration,
      'distance': distance,
      'polyline': polyline,
      'safetyScore': safetyScore,
      'safetyLevel': safetyLevel,
      'warnings': warnings.map((w) => w.toJson()).toList(),
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
    };
  }
  
  RouteSuggestion copyWith({
    String? type,
    String? color,
    String? riskScore,
    double? duration,
    double? distance,
    List<List<double>>? polyline,
    int? safetyScore,
    String? safetyLevel,
    int? actualRiskScore,
    List<RouteWarning>? warnings,
    List<RouteRecommendation>? recommendations,
  }) {
    return RouteSuggestion(
      type: type ?? this.type,
      color: color ?? this.color,
      riskScore: riskScore ?? this.riskScore,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      polyline: polyline ?? this.polyline,
      safetyScore: safetyScore ?? this.safetyScore,
      safetyLevel: safetyLevel ?? this.safetyLevel,
      actualRiskScore: actualRiskScore ?? this.actualRiskScore,
      warnings: warnings ?? this.warnings,
      recommendations: recommendations ?? this.recommendations,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteSuggestion &&
        other.type == type &&
        other.color == color &&
        other.riskScore == riskScore &&
        other.duration == duration &&
        other.distance == distance &&
        other.safetyScore == safetyScore &&
        other.safetyLevel == safetyLevel &&
        listEquals(other.polyline, polyline);
  }
  
  @override
  int get hashCode =>
      type.hashCode ^
      color.hashCode ^
      riskScore.hashCode ^
      duration.hashCode ^
      distance.hashCode ^
      safetyScore.hashCode ^
      safetyLevel.hashCode ^
      polyline.hashCode;
}

// ✨ NEW CLASS - Add this at the bottom of the file
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

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity,
      'message': message,
    };
  }
}

// ✨ NEW CLASS - Add this too
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

  Map<String, dynamic> toJson() {
    return {
      'priority': priority,
      'message': message,
      'reason': reason,
    };
  }
}