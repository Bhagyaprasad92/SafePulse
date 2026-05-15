// lib/core/models/route_models.dart
import 'package:flutter/foundation.dart';

class RoutePoint {
  final double lat;
  final double lng;

  RoutePoint({
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        lat: json['lat'].toDouble(),
        lng: json['lng'].toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode;
}

class CrimeHotspot {
  final RoutePoint location;
  final double riskLevel;
  final int crimeCount;
  final String crimeType;
  final double radiusMeters;

  CrimeHotspot({
    required this.location,
    required this.riskLevel,
    required this.crimeCount,
    required this.crimeType,
    this.radiusMeters = 500,
  });

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'riskLevel': riskLevel,
        'crimeCount': crimeCount,
        'crimeType': crimeType,
        'radiusMeters': radiusMeters,
      };

  factory CrimeHotspot.fromJson(Map<String, dynamic> json) => CrimeHotspot(
        location: RoutePoint.fromJson(json['location']),
        riskLevel: json['riskLevel'].toDouble(),
        crimeCount: json['crimeCount'],
        crimeType: json['crimeType'],
        radiusMeters: json['radiusMeters']?.toDouble() ?? 500,
      );
}

class RiskSegment {
  final List<RoutePoint> points;
  final double riskLevel;
  final String reason;

  RiskSegment({
    required this.points,
    required this.riskLevel,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'riskLevel': riskLevel,
        'reason': reason,
      };

  factory RiskSegment.fromJson(Map<String, dynamic> json) => RiskSegment(
        points: (json['points'] as List)
            .map((p) => RoutePoint.fromJson(p))
            .toList(),
        riskLevel: json['riskLevel'].toDouble(),
        reason: json['reason'],
      );
}

class RouteOption {
  final String id;
  final List<RoutePoint> points;
  final double distance; // in meters
  final double duration; // in seconds
  final double riskScore; // 0-100, lower is safer
  final SafetyLevel safetyLevel;
  final List<CrimeHotspot> crimeHotspots;
  final List<RiskSegment> riskSegments;
  final String summary;
  
  String? label; // e.g., "Safest Route", "Fastest Route"
  RouteRecommendationType? recommendationType;

  RouteOption({
    required this.id,
    required this.points,
    required this.distance,
    required this.duration,
    required this.riskScore,
    required this.safetyLevel,
    required this.crimeHotspots,
    required this.riskSegments,
    required this.summary,
    this.label,
    this.recommendationType,
  });

  String get distanceText {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  String get durationText {
    final minutes = (duration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  String get riskLevelText {
    if (riskScore < 20) return 'Very Low Risk';
    if (riskScore < 40) return 'Low Risk';
    if (riskScore < 60) return 'Moderate Risk';
    if (riskScore < 80) return 'High Risk';
    return 'Very High Risk';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'distance': distance,
        'duration': duration,
        'riskScore': riskScore,
        'safetyLevel': safetyLevel.toString(),
        'crimeHotspots': crimeHotspots.map((h) => h.toJson()).toList(),
        'riskSegments': riskSegments.map((s) => s.toJson()).toList(),
        'summary': summary,
        'label': label,
        'recommendationType': recommendationType?.toString(),
      };
}

class RiskAnalysis {
  final double overallRisk;
  final List<CrimeHotspot> hotspots;
  final List<RiskSegment> highRiskSegments;
  final Map<String, int> crimeBreakdown;

  RiskAnalysis({
    required this.overallRisk,
    required this.hotspots,
    required this.highRiskSegments,
    required this.crimeBreakdown,
  });
}

enum SafetyLevel {
  verySafe,
  safe,
  moderate,
  caution,
  unsafe,
}

enum RouteRecommendationType {
  safest,
  fastest,
  lowRisk,
  moderate,
  risky,
}

extension SafetyLevelExtension on SafetyLevel {
  String get displayName {
    switch (this) {
      case SafetyLevel.verySafe:
        return 'Very Safe';
      case SafetyLevel.safe:
        return 'Safe';
      case SafetyLevel.moderate:
        return 'Moderate';
      case SafetyLevel.caution:
        return 'Caution';
      case SafetyLevel.unsafe:
        return 'Unsafe';
    }
  }

  String get emoji {
    switch (this) {
      case SafetyLevel.verySafe:
        return '🟢';
      case SafetyLevel.safe:
        return '🟢';
      case SafetyLevel.moderate:
        return '🟡';
      case SafetyLevel.caution:
        return '🟠';
      case SafetyLevel.unsafe:
        return '🔴';
    }
  }
}