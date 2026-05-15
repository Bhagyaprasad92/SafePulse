// UPDATED
import 'package:flutter/foundation.dart';

class CircleMember {
  final String id;
  final String name;
  final String phone;
  final double? lat;
  final double? lng;
  final String? batteryLevel;
  final bool? isDriving;
  final DateTime? lastUpdated;

  CircleMember({
    required this.id,
    required this.name,
    required this.phone,
    this.lat,
    this.lng,
    this.batteryLevel,
    this.isDriving,
    this.lastUpdated,
  });

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember(
      id: json['userId'] ?? json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Member',
      phone: json['phone'] ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      batteryLevel: json['batteryLevel'],
      isDriving: json['isDriving'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.tryParse(json['lastUpdated']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'name': name,
      'phone': phone,
      'lat': lat,
      'lng': lng,
      'batteryLevel': batteryLevel,
      'isDriving': isDriving,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  CircleMember copyWith({
    String? id,
    String? name,
    String? phone,
    double? lat,
    double? lng,
    String? batteryLevel,
    bool? isDriving,
    DateTime? lastUpdated,
  }) {
    return CircleMember(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isDriving: isDriving ?? this.isDriving,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CircleMember &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.lat == lat &&
        other.lng == lng &&
        other.batteryLevel == batteryLevel &&
        other.isDriving == isDriving &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      phone.hashCode ^
      lat.hashCode ^
      lng.hashCode ^
      batteryLevel.hashCode ^
      isDriving.hashCode ^
      lastUpdated.hashCode;
}
