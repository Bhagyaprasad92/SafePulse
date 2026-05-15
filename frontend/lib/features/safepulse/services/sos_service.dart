// lib/features/safepulse/services/sos_service.dart
import 'dart:async';
import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/repositories/sos_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class SosService {
  final SOSRepository _sosRepo;
  final Telephony telephony = Telephony.instance;

  SosService(this._sosRepo);

  List<String> emergencyContacts = [];

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    emergencyContacts = contactsJson.map((c) {
      final parts = c.split('|');
      return parts.length > 1 ? parts[1] : parts[0];
    }).where((phone) => phone.isNotEmpty).toList();
    
    if (emergencyContacts.isEmpty) {
      emergencyContacts = [
        "+YOUR_COUNTRY_CODE_YOUR_NUMBER_1", // Placeholder: Users must replace this
        "+YOUR_COUNTRY_CODE_YOUR_NUMBER_2", // Placeholder: Users must replace this
      ];
    }
  }

  Function(String message)? onLog;
  Function()? onCallReturned;
  Function(List<String> contacts, String payload)? onEmergencySOS;
  bool _isAwaitingCallReturn = false;

  Future<void> triggerHybridSOS({
    required double lat,
    required double lng,
    required bool hasLocation,
    required int? locationAgeSec,
    double speedMs = 0.0,
  }) async {
    // Fire online in background
    print("SosService: Firing ONLINE SOS...");
    unawaited(
      _sosRepo.sendSafePulseSOS(
        lat,
        lng,
        "HIGH",
        hasLocation: hasLocation,
        locationAgeSec: locationAgeSec,
      ),
    );

    // ALWAYS execute offline emergency actions
    print("SosService: Proceeding to OFFLINE SOS...");
    await triggerOfflineSOS(
      lat,
      lng,
      hasLocation: hasLocation,
      locationAgeSec: locationAgeSec,
      speedMs: speedMs,
    );
  }

  Future<void> triggerOfflineSOS(
    double lat,
    double lng, {
    bool hasLocation = true,
    int? locationAgeSec,
    double speedMs = 0.0,
  }) async {
    await _loadContacts();
    final now = DateTime.now();
    String timestamp =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    String locText;

    if (hasLocation) {
      int staleThreshold = speedMs > 10.0 ? 10 : 30;
      if (locationAgeSec != null && locationAgeSec > staleThreshold) {
        locText = "Loc(stale): https://maps.google.com/?q=$lat,$lng";
      } else {
        locText = "Loc: https://maps.google.com/?q=$lat,$lng";
      }
    } else {
      locText = "Loc: UNAVAILABLE. Call immediately.";
    }

    String payload = "SOS! Crash detected.\nTime: $timestamp\n$locText";
    if (payload.length > 150) {
      payload = payload.substring(0, 150);
    }

    print("SosService: Delegating SMS and Call to UI Isolate to bypass restrictions.");
    onEmergencySOS?.call(emergencyContacts, payload);

    print("SosService: Executing fallback SOS directly from background isolate.");
    _executeEmergencySOSLocal(emergencyContacts, payload);
  }

  Future<void> _executeEmergencySOSLocal(List<String> contacts, String payload) async {
    for (String number in contacts) {
      try {
        await telephony.sendSms(to: number, message: payload);
        print("[SosService Background] SMS sent to $number");
      } catch (e) {
        print("[SosService Background] SMS Failed to $number: $e");
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (contacts.isNotEmpty) {
      print("[SosService Background] Triggering call to: ${contacts.first}");
      try {
        await FlutterPhoneDirectCaller.callNumber(contacts.first);
      } catch (e) {
        print("[SosService Background] Call Failed with direct caller: $e, falling back to url_launcher...");
        try {
          final Uri url = Uri.parse("tel:${contacts.first}");
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        } catch (e2) {
          print("[SosService Background] url_launcher also failed: $e2");
        }
      }
    }
  }

  void checkCallReturn() {
    if (_isAwaitingCallReturn) {
      _isAwaitingCallReturn = false;
      onCallReturned?.call();
    }
  }
}
