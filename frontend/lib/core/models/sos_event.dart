import 'package:flutter/foundation.dart';

class SOSEvent {
  final String id;
  final String userId;
  final double lat;
  final double lng;
  final String address;
  final String status;
  final DateTime createdAt;
  final List<dynamic> contactsNotified;
  final List<dynamic> nearbyUsersNotified;
  final List<dynamic> responders;

  SOSEvent({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.address,
    required this.status,
    required this.createdAt,
    this.contactsNotified = const [],
    this.nearbyUsersNotified = const [],
    this.responders = const [],
  });

  factory SOSEvent.fromJson(Map<String, dynamic> json) {
    return SOSEvent(
      id: json['_id'] ?? json['id'] ?? json['sosId'] ?? '',
      userId: json['userId'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] ?? 'Emergency Location',
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      contactsNotified: json['contactsNotified'] ?? [],
      nearbyUsersNotified: json['nearbyUsersNotified'] ?? [],
      responders: json['responders'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sosId': id,
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'address': address,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'contactsNotified': contactsNotified,
      'nearbyUsersNotified': nearbyUsersNotified,
      'responders': responders,
    };
  }

  SOSEvent copyWith({
    String? id,
    String? userId,
    double? lat,
    double? lng,
    String? address,
    String? status,
    DateTime? createdAt,
    List<dynamic>? contactsNotified,
    List<dynamic>? nearbyUsersNotified,
    List<dynamic>? responders,
  }) {
    return SOSEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      nearbyUsersNotified: nearbyUsersNotified ?? this.nearbyUsersNotified,
      responders: responders ?? this.responders,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SOSEvent &&
        other.id == id &&
        other.userId == userId &&
        other.lat == lat &&
        other.lng == lng &&
        other.address == address &&
        other.status == status &&
        other.createdAt == createdAt &&
        listEquals(other.contactsNotified, contactsNotified) &&
        listEquals(other.nearbyUsersNotified, nearbyUsersNotified) &&
        listEquals(other.responders, responders);
  }

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      lat.hashCode ^
      lng.hashCode ^
      address.hashCode ^
      status.hashCode ^
      createdAt.hashCode ^
      contactsNotified.hashCode ^
      nearbyUsersNotified.hashCode ^
      responders.hashCode;
}
