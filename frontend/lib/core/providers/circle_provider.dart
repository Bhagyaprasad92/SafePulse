// MOVED FROM: lib/core/providers/circle_provider.dart
import 'package:flutter/foundation.dart';
import '../repositories/circle_repository.dart';
import '../models/circle.dart';

class CircleProvider extends ChangeNotifier {
  final CircleRepository _repo;

  CircleProvider(this._repo);

  List<Circle> _circles = [];
  bool _isLoading = false;
  String? _error;

  List<Circle> get circles => _circles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCircles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _circles = await _repo.getMyCircles();
    } catch (e) {
      _error = 'Unexpected error loading circles';
      debugPrint('[CircleProvider] error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCircle(String name) async {
    if (_isLoading) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repo.createCircle(name);
      if (result['success'] == true) {
        await loadCircles();
        return true;
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinCircle(String inviteCode) async {
    if (_isLoading) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repo.joinCircle(inviteCode);
      if (result['success'] == true) {
        await loadCircles();
        return true;
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> requestDeleteCircle(String circleId) async {
    final result = await _repo.requestDeleteCircle(circleId);
    if (result['success'] == true) {
      await loadCircles();
    }
    return result;
  }
}
