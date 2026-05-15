// NEW FILE
import 'package:flutter/foundation.dart';

class GeocodeResult {
  final String displayName;
  final double lat;
  final double lng;

  GeocodeResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    return GeocodeResult(
      displayName: json['displayName'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'lat': lat,
      'lng': lng,
    };
  }

  GeocodeResult copyWith({
    String? displayName,
    double? lat,
    double? lng,
  }) {
    return GeocodeResult(
      displayName: displayName ?? this.displayName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeocodeResult &&
        other.displayName == displayName &&
        other.lat == lat &&
        other.lng == lng;
  }

  @override
  int get hashCode => displayName.hashCode ^ lat.hashCode ^ lng.hashCode;
}
