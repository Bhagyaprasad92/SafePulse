// NEW FILE
import 'package:flutter/foundation.dart';
import 'nearby_service.dart';

class NearbyServicesResponse {
  final bool success;
  final Map<String, int> counts;
  final List<NearbyService> hospitals;
  final List<NearbyService> police;

  NearbyServicesResponse({
    required this.success,
    required this.counts,
    required this.hospitals,
    required this.police,
  });

  factory NearbyServicesResponse.fromJson(Map<String, dynamic> json) {
    final services = json['services'] ?? {};
    return NearbyServicesResponse(
      success: json['success'] ?? false,
      counts: Map<String, int>.from(json['counts'] ?? {}),
      hospitals: (services['hospitals'] as List? ?? [])
          .map((e) => NearbyService.fromJson(e))
          .toList(),
      police: (services['police'] as List? ?? [])
          .map((e) => NearbyService.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'counts': counts,
      'services': {
        'hospitals': hospitals.map((e) => e.toJson()).toList(),
        'police': police.map((e) => e.toJson()).toList(),
      },
    };
  }

  NearbyServicesResponse copyWith({
    bool? success,
    Map<String, int>? counts,
    List<NearbyService>? hospitals,
    List<NearbyService>? police,
  }) {
    return NearbyServicesResponse(
      success: success ?? this.success,
      counts: counts ?? this.counts,
      hospitals: hospitals ?? this.hospitals,
      police: police ?? this.police,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NearbyServicesResponse &&
        other.success == success &&
        mapEquals(other.counts, counts) &&
        listEquals(other.hospitals, hospitals) &&
        listEquals(other.police, police);
  }

  @override
  int get hashCode =>
      success.hashCode ^ counts.hashCode ^ hospitals.hashCode ^ police.hashCode;
}
