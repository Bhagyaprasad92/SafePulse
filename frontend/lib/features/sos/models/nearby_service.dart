class NearbyService {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lon;
  final int distanceMeters;

  NearbyService({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
  });

  factory NearbyService.fromJson(Map<String, dynamic> json) {
    return NearbyService(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Service',
      type: json['type'] ?? 'unknown',
      lat: _toDouble(json['lat']),
      lon: _toDouble(json['lon']),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
