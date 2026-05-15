// UPDATED
import 'package:flutter/foundation.dart';

class User {
  final String id;
  final String phone;
  final String email;
  final String name;
  final Map<String, double>? location;
  final String? batteryLevel;
  final bool? isDriving;
  final double? currentSpeed;
  final String? fcmToken;
  final List<Map<String, String>> emergencyContacts;

  User({
    required this.id,
    required this.phone,
    required this.email,
    required this.name,
    this.location,
    this.batteryLevel,
    this.isDriving,
    this.currentSpeed,
    this.fcmToken,
    this.emergencyContacts = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? 'User',
      location: json['location'] != null 
          ? Map<String, double>.from(json['location'].map((k, v) => MapEntry(k, (v as num).toDouble())))
          : null,
      batteryLevel: json['batteryLevel'],
      isDriving: json['isDriving'],
      currentSpeed: (json['currentSpeed'] as num?)?.toDouble(),
      fcmToken: json['fcmToken'],
      emergencyContacts: (json['emergencyContacts'] as List?)
          ?.map((e) => Map<String, String>.from(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'phone': phone,
      'email': email,
      'name': name,
      'location': location,
      'batteryLevel': batteryLevel,
      'isDriving': isDriving,
      'currentSpeed': currentSpeed,
      'fcmToken': fcmToken,
      'emergencyContacts': emergencyContacts,
    };
  }

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? name,
    Map<String, double>? location,
    String? batteryLevel,
    bool? isDriving,
    double? currentSpeed,
    String? fcmToken,
    List<Map<String, String>>? emergencyContacts,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      name: name ?? this.name,
      location: location ?? this.location,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isDriving: isDriving ?? this.isDriving,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      fcmToken: fcmToken ?? this.fcmToken,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.phone == phone &&
        other.email == email &&
        other.name == name &&
        mapEquals(other.location, location) &&
        other.batteryLevel == batteryLevel &&
        other.isDriving == isDriving &&
        other.currentSpeed == currentSpeed &&
        other.fcmToken == fcmToken &&
        listEquals(other.emergencyContacts, emergencyContacts);
  }

  @override
  int get hashCode =>
      id.hashCode ^
      phone.hashCode ^
      email.hashCode ^
      name.hashCode ^
      location.hashCode ^
      batteryLevel.hashCode ^
      isDriving.hashCode ^
      currentSpeed.hashCode ^
      fcmToken.hashCode ^
      emergencyContacts.hashCode;
}
