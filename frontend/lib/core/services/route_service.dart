// lib/core/services/route_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_models.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class RouteService {
  static const String osrmBaseUrl = 'http://router.project-osrm.org/route/v1';

  /// Get 3 alternative routes with risk analysis from your backend
  Future<List<RouteOption>> getAlternativeRoutes({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      print('🔍 Fetching routes from backend...');
      
      // Call your existing backend API
      final url = Uri.parse(AppConfig.routeSuggestUrl);
      final headers = await ApiService.authHeaders();
      
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'start': {
            'lat': startLat,
            'lng': startLng,
          },
          'destination': {
            'lat': endLat,
            'lng': endLng,
          },
          'alternatives': 3, // Request 3 alternative routes
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Backend error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      print('✅ Received ${data['routeCount'] ?? 0} routes from backend');

      // Parse routes from backend response
      List<RouteOption> routeOptions = [];
      
      if (data['routes'] != null && data['routes'] is List) {
        final routes = data['routes'] as List;
        
        for (int i = 0; i < routes.length; i++) {
          final route = routes[i];
          
          // Parse route points from polyline
          List<RoutePoint> points = [];
          if (route['polyline'] != null) {
            final polylineData = route['polyline'] as List;
            points = polylineData.map((coord) => RoutePoint(
              lat: coord[0].toDouble(),
              lng: coord[1].toDouble(),
            )).toList();
          } else if (route['points'] != null) {
            final pointsData = route['points'] as List;
            points = pointsData.map((p) => RoutePoint(
              lat: p['lat'].toDouble(),
              lng: p['lon'].toDouble(),
            )).toList();
          }

          // Parse crime hotspots from safety breakdown
          List<CrimeHotspot> hotspots = [];
          if (route['safetyBreakdown'] != null && 
              route['safetyBreakdown']['crimeRisk'] != null &&
              route['safetyBreakdown']['crimeRisk']['details'] != null) {
            
            final crimeDetails = route['safetyBreakdown']['crimeRisk']['details'];
            
            // Create hotspot representation from high risk segments
            if (crimeDetails['highRiskSegments'] != null && 
                crimeDetails['highRiskSegments'] > 0) {
              
              // Sample hotspots along the route
              final segmentCount = crimeDetails['highRiskSegments'] as int;
              final step = (points.length / (segmentCount + 1)).floor();
              
              for (int j = 0; j < segmentCount && j * step < points.length; j++) {
                final point = points[j * step];
                hotspots.add(CrimeHotspot(
                  location: point,
                  riskLevel: crimeDetails['maxRisk']?.toDouble() ?? 60.0,
                  crimeCount: 3 + j, // Estimated
                  crimeType: 'High Crime Area',
                  radiusMeters: 500,
                ));
              }
            }
          }

          // Parse risk segments from warnings
          List<RiskSegment> riskSegments = [];
          if (route['warnings'] != null) {
            final warnings = route['warnings'] as List;
            for (var warning in warnings) {
              if (warning['type'] == 'high_crime' && warning['segments'] != null) {
                // Create risk segments from warning data
                final segments = warning['segments'] as List;
                for (var seg in segments) {
                  List<RoutePoint> segmentPoints = [];
                  
                  if (seg['points'] != null) {
                    segmentPoints = (seg['points'] as List).map((p) => RoutePoint(
                      lat: p['lat'].toDouble(),
                      lng: p['lon'].toDouble(),
                    )).toList();
                  }
                  
                  riskSegments.add(RiskSegment(
                    points: segmentPoints,
                    riskLevel: seg['riskLevel']?.toDouble() ?? 70.0,
                    reason: warning['message'] ?? 'High crime area',
                  ));
                }
              }
            }
          }

          // Get risk score (use actualRiskScore if available)
          final riskScore = (route['actualRiskScore'] ?? route['riskScore'])?.toDouble() ?? 50.0;
          final safetyLevel = _getSafetyLevel(riskScore);

          // Create route option
          final routeOption = RouteOption(
            id: route['id'] ?? 'route_$i',
            points: points,
            distance: route['distance']?.toDouble() ?? 0,
            duration: route['duration']?.toDouble() ?? 0,
            riskScore: riskScore,
            safetyLevel: safetyLevel,
            crimeHotspots: hotspots,
            riskSegments: riskSegments,
            summary: route['type'] ?? 'Route ${i + 1}',
          );

          routeOptions.add(routeOption);
        }
      }

      // If backend didn't provide routes, fetch from OSRM directly
      if (routeOptions.isEmpty) {
        print('⚠️ No routes from backend, fetching from OSRM...');
        routeOptions = await _fetchRoutesFromOSRM(
          startLat: startLat,
          startLng: startLng,
          endLat: endLat,
          endLng: endLng,
        );
      }

      // Sort routes by risk score (safest first)
      routeOptions.sort((a, b) => a.riskScore.compareTo(b.riskScore));

      // Label routes based on risk
      _labelRoutes(routeOptions);

      print('✅ Returning ${routeOptions.length} analyzed routes');
      return routeOptions;

    } catch (e) {
      print('❌ Error getting routes: $e');
      
      // Fallback: Try OSRM directly if backend fails
      try {
        print('🔄 Trying OSRM fallback...');
        return await _fetchRoutesFromOSRM(
          startLat: startLat,
          startLng: startLng,
          endLat: endLat,
          endLng: endLng,
        );
      } catch (osrmError) {
        print('❌ OSRM fallback also failed: $osrmError');
        rethrow;
      }
    }
  }

  /// Fetch routes directly from OSRM (fallback method)
  Future<List<RouteOption>> _fetchRoutesFromOSRM({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final url = Uri.parse(
      '$osrmBaseUrl/driving/$startLng,$startLat;$endLng,$endLat'
      '?alternatives=3&geometries=geojson&overview=full&steps=true',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('OSRM error: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final routes = data['routes'] as List;

    List<RouteOption> routeOptions = [];

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final geometry = route['geometry'];
      final coordinates = geometry['coordinates'] as List;

      List<RoutePoint> points = coordinates
          .map((coord) => RoutePoint(
                lat: coord[1].toDouble(),
                lng: coord[0].toDouble(),
              ))
          .toList();

      // Create route with default risk (since backend is unavailable)
      final routeOption = RouteOption(
        id: 'route_$i',
        points: points,
        distance: route['distance'].toDouble(),
        duration: route['duration'].toDouble(),
        riskScore: 50.0, // Default moderate risk
        safetyLevel: SafetyLevel.moderate,
        crimeHotspots: [],
        riskSegments: [],
        summary: route['legs'][0]['summary'] ?? 'Route ${i + 1}',
      );

      routeOptions.add(routeOption);
    }

    _labelRoutes(routeOptions);
    return routeOptions;
  }

  /// Label routes based on their characteristics
  void _labelRoutes(List<RouteOption> routes) {
    if (routes.isEmpty) return;

    // Backend already labels routes, but we'll ensure proper display names
    for (int i = 0; i < routes.length; i++) {
      final riskScore = routes[i].riskScore;
      
      if (i == 0) {
        // First route is safest
        routes[i].label = 'Safest Route';
        routes[i].recommendationType = RouteRecommendationType.safest;
      } else if (riskScore < 40) {
        routes[i].label = 'Low Risk Route';
        routes[i].recommendationType = RouteRecommendationType.lowRisk;
      } else if (riskScore < 60) {
        routes[i].label = 'Moderate Risk Route';
        routes[i].recommendationType = RouteRecommendationType.moderate;
      } else {
        routes[i].label = 'High Risk Route';
        routes[i].recommendationType = RouteRecommendationType.risky;
      }
    }

    // Ensure fastest route is also marked
    if (routes.length > 1) {
      final fastestIndex = routes
          .asMap()
          .entries
          .reduce((a, b) => a.value.duration < b.value.duration ? a : b)
          .key;

      // If fastest is not the safest, give it dual label
      if (fastestIndex != 0 && routes[fastestIndex].label != 'Safest Route') {
        routes[fastestIndex].label = 'Fastest Route';
        routes[fastestIndex].recommendationType = RouteRecommendationType.fastest;
      }
    }
  }

  /// Get safety level from risk score
  SafetyLevel _getSafetyLevel(double riskScore) {
    if (riskScore < 20) return SafetyLevel.verySafe;
    if (riskScore < 40) return SafetyLevel.safe;
    if (riskScore < 60) return SafetyLevel.moderate;
    if (riskScore < 80) return SafetyLevel.caution;
    return SafetyLevel.unsafe;
  }
}
