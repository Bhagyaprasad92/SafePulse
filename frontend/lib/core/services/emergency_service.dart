// lib/core/services/emergency_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class EmergencyService {
  void listenForEmergencyTrigger() {
    FlutterBackgroundService().on('executeEmergencySOS').listen((event) {
      if (event != null) {
        final contacts = List<String>.from(event['contacts'] ?? []);
        final payload = event['payload'] as String;
        _executeEmergencySOS(contacts, payload);
      }
    });
  }

  Future<void> _executeEmergencySOS(List<String> contacts, String payload) async {
    debugPrint("[EmergencyService] Received trigger for ${contacts.length} contacts.");
    
    final telephony = Telephony.instance;
    for (String number in contacts) {
      try {
        await telephony.sendSms(
          to: number, 
          message: payload,
          statusListener: (SendStatus status) {
            debugPrint("[EmergencyService] SMS status for $number: $status");
          }
        );
        debugPrint("[EmergencyService] SMS sent to $number");
      } catch (e) {
        debugPrint("[EmergencyService] SMS Failed to $number: $e");
      }
      // Keep the 500ms delay between SMS sends
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (contacts.isNotEmpty) {
      debugPrint("[EmergencyService] Triggering call to the first contact: ${contacts.first}");
      try {
        await FlutterPhoneDirectCaller.callNumber(contacts.first);
      } catch (e) {
        debugPrint("[EmergencyService] Call Failed: $e");
      }
    }
  }
}
