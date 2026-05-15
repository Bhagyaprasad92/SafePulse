import 'package:do_not_disturb/do_not_disturb.dart';
import 'package:flutter/foundation.dart';

class DndService {
  static final _plugin = DoNotDisturbPlugin();

  static Future<bool> isPermissionGranted() async {
    try {
      return await _plugin.isNotificationPolicyAccessGranted();
    } catch (e) {
      debugPrint('[DND] Error checking permission: $e');
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _plugin.openNotificationPolicyAccessSettings();
    } catch (e) {
      debugPrint('[DND] Error opening settings: $e');
    }
  }

  static Future<void> setDndOn() async {
    try {
      if (await isPermissionGranted()) {
        await _plugin.setInterruptionFilter(InterruptionFilter.priority);
        debugPrint('[DND] Mode ON (Priority)');
      } else {
        debugPrint('[DND] Permission not granted');
      }
    } catch (e) {
      debugPrint('[DND] Error setting ON: $e');
    }
  }

  static Future<void> setDndOff() async {
    try {
      if (await isPermissionGranted()) {
        await _plugin.setInterruptionFilter(InterruptionFilter.all);
        debugPrint('[DND] Mode OFF (All allowed)');
      }
    } catch (e) {
      debugPrint('[DND] Error setting OFF: $e');
    }
  }
}
