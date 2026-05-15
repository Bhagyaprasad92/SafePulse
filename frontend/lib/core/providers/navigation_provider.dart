// lib/core/providers/navigation_provider.dart
import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';
import '../models/route_suggestion.dart';
import '../models/geocode_result.dart';

class NavigationProvider extends ChangeNotifier {
  final UserRepository _userRepo;

  NavigationProvider(this._userRepo);

  List<GeocodeResult> _suggestions = [];
  List<RouteSuggestion> _routes = [];
  bool _isLoading = false;
  String? _error;

  List<GeocodeResult> get suggestions => _suggestions;
  List<RouteSuggestion> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> searchDestination(String query) async {
    if (query.trim().length < 3) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _suggestions = await _userRepo.geocodeAddress(query);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRoutes({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    _isLoading = true;
    _error = null;
    _routes = [];
    notifyListeners();

    try {
      _routes = await _userRepo.getRouteSuggestions(
        startLat: startLat,
        startLng: startLng,
        destLat: destLat,
        destLng: destLng,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  void reset() {
    _suggestions = [];
    _routes = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
