import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'api_service.dart';

class RealtimeTrackingService {
  WebSocket? _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<void> connect() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Cannot open realtime tracking without an auth token');
    }

    final uri = Uri.parse(AppConfig.realtimeUrl)
        .replace(queryParameters: {'token': token});
    _socket = await WebSocket.connect(uri.toString());
    _socket!.listen(
      (raw) {
        if (!_disposed) _events.add(jsonDecode(raw as String) as Map<String, dynamic>);
      },
      onError: (error) {
        if (!_disposed) _events.add({'type': 'connection:error', 'error': '$error'});
      },
      onDone: () {
        if (!_disposed) _events.add({'type': 'connection:closed'});
      },
      cancelOnError: true,
    );
  }

  void sendTrackingUpdate({
    required double speed,
    required bool isPhoneOn,
    double? lat,
    double? lng,
    List<String> circleMemberIds = const [],
  }) {
    _send({
      'type': 'tracking:update',
      'speed': speed,
      'isPhoneOn': isPhoneOn,
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
      'circleMemberIds': circleMemberIds,
    });
  }

  void sendSosStarted({
    required String sosId,
    required double lat,
    required double lng,
    List<String> circleMemberIds = const [],
  }) {
    _send({
      'type': 'sos:started',
      'sosId': sosId,
      'location': {'lat': lat, 'lng': lng},
      'circleMemberIds': circleMemberIds,
    });
  }

  void _send(Map<String, dynamic> message) {
    if (!isConnected) return;
    _socket!.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    _disposed = true;
    await _socket?.close();
    await _events.close();
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
