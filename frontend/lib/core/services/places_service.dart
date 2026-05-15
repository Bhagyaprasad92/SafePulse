// lib/core/services/places_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PlacesService {
  /// Search for places using your Node.js backend (which securely uses OpenStreetMap Nominatim)
  /// This completely removes the Google Places API dependency.
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/places/search?q=$query');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Failed to search places');
      }

      final data = json.decode(response.body) as List;

      return data.map((item) => PlaceSuggestion(
        placeId: '${item['lat']},${item['lng']}', // Nominatim doesn't have Google place_ids, we can use coordinates as a unique ID
        description: item['displayName'] ?? '',
        mainText: item['displayName']?.split(',').first ?? '',
        secondaryText: item['address'] ?? '',
        latitude: item['lat'] != null ? (item['lat'] is String ? double.parse(item['lat']) : item['lat'].toDouble()) : 0.0,
        longitude: item['lng'] != null ? (item['lng'] is String ? double.parse(item['lng']) : item['lng'].toDouble()) : 0.0,
      )).toList();
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  /// Since Nominatim returns coordinates during the initial search phase, 
  /// we can simply return the coordinates already stored in PlaceSuggestion!
  /// No need for a secondary Google Details or Geocoding API call.
  Future<PlaceDetails?> getPlaceDetails(PlaceSuggestion suggestion) async {
    try {
      return PlaceDetails(
        name: suggestion.mainText,
        address: suggestion.description,
        latitude: suggestion.latitude,
        longitude: suggestion.longitude,
      );
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double latitude;
  final double longitude;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.latitude,
    required this.longitude,
  });
}

class PlaceDetails {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
