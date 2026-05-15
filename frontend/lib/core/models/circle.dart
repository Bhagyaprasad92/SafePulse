// UPDATED
import 'package:flutter/foundation.dart';
import 'circle_member.dart';

class Circle {
  final String id;
  final String name;
  final String inviteCode;
  final List<CircleMember> members;

  Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.members = const [],
  });

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Circle',
      inviteCode: json['inviteCode'] ?? '',
      members: (json['members'] as List?)
          ?.map((e) => CircleMember.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'inviteCode': inviteCode,
      'members': members.map((m) => m.toJson()).toList(),
    };
  }

  Circle copyWith({
    String? id,
    String? name,
    String? inviteCode,
    List<CircleMember>? members,
  }) {
    return Circle(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Circle &&
        other.id == id &&
        other.name == name &&
        other.inviteCode == inviteCode &&
        listEquals(other.members, members);
  }

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ inviteCode.hashCode ^ members.hashCode;
}
