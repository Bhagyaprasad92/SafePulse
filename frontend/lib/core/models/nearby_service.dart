// NEW FILE
import 'package:flutter/foundation.dart';

class NearbyService {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lon;
  final int distanceMeters;
  final String? address;
  final String? phone;

  NearbyService({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
    this.address,
    this.phone,
  });

  factory NearbyService.fromJson(Map<String, dynamic> json) {
    return NearbyService(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Service',
      type: json['type'] ?? 'unknown',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      address: json['address'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'lat': lat,
      'lon': lon,
      'distanceMeters': distanceMeters,
      'address': address,
      'phone': phone,
    };
  }

  NearbyService copyWith({
    String? id,
    String? name,
    String? type,
    double? lat,
    double? lon,
    int? distanceMeters,
    String? address,
    String? phone,
  }) {
    return NearbyService(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NearbyService &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.lat == lat &&
        other.lon == lon &&
        other.distanceMeters == distanceMeters &&
        other.address == address &&
        other.phone == phone;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      lat.hashCode ^
      lon.hashCode ^
      distanceMeters.hashCode ^
      address.hashCode ^
      phone.hashCode;
}
