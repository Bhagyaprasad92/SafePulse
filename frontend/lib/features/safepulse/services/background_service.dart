// lib/features/safepulse/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import '../engine/safepulse_engine.dart';

@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  if (notificationResponse.actionId == 'hide_battery_alert') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_battery_alert', true);
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  
  // Sync crash_detection default to isMonitoring if not set
  if (prefs.get('isMonitoring') == null) {
    await prefs.setBool('isMonitoring', prefs.getBool('crash_detection') ?? true);
  }

  if (!(prefs.getBool("isMonitoring") ?? false)) {
    service.stopSelf();
    return;
  }

  final engine = SafePulseEngine(serviceInstance: service);
  await engine.start();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  final Battery battery = Battery();

  Timer? statusTimer;
  Timer? watchdogTimer;
  String lastNotificationText = "";

  service.on('stopService').listen((event) async {
    statusTimer?.cancel();
    watchdogTimer?.cancel();
    await engine.stop();
    await flutterLocalNotificationsPlugin.cancelAll();
    service.stopSelf();
  });

  statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool("isMonitoring") ?? false)) {
      statusTimer?.cancel();
      watchdogTimer?.cancel();
      await engine.stop();
      await flutterLocalNotificationsPlugin.cancelAll();
      service.stopSelf();
      return;
    }
  });

  watchdogTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool("isMonitoring") ?? false)) {
      timer.cancel();
      return;
    }
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        String notificationTitle = '🛡️ SafePulse AI Active';
        String notificationBody =
            'Monitoring sensors and location autonomously.';
        Importance importance = Importance.low;
        Priority priority = Priority.low;

        switch (engine.healthState) {
          case EngineHealthState.recoveringSensors:
            notificationBody = 'Recovering sensors...';
            break;
          case EngineHealthState.recoveringAI:
            notificationBody = 'Recovering AI pipeline...';
            break;
          case EngineHealthState.degraded:
            notificationTitle = '⚠️ SafePulse Degraded Mode';
            notificationBody = 'Crash AI unavailable. Manual SOS still active.';
            importance = Importance.high;
            priority = Priority.high;
            break;
          case EngineHealthState.emergency:
            notificationTitle = '🚨 SOS TRIGGERED';
            notificationBody = 'Emergency protocol active.';
            importance = Importance.high;
            priority = Priority.high;
            break;
          default:
            break;
        }

        final currentText = "$notificationTitle:$notificationBody";
        if (currentText != lastNotificationText) {
          lastNotificationText = currentText;
          flutterLocalNotificationsPlugin.show(
            888,
            notificationTitle,
            notificationBody,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'safepulse_silent_v4',
                'SafePulse AI Service',
                ongoing: true,
                importance: importance,
                priority: priority,
              ),
            ),
          );
        }
      }
    }

    bool isLocationOn = false;
    try {
      isLocationOn = await Geolocator.isLocationServiceEnabled();
    } catch (e) {}

    await prefs.setBool('sys_isLocationOn', isLocationOn);

    if (!isLocationOn) {
      flutterLocalNotificationsPlugin.show(
        889,
        '⚠️ SafePulse: Location Disabled',
        'Turn on Location so SOS can broadcast your coordinates.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'safepulse_alerts_v1',
            'System Alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } else {
      flutterLocalNotificationsPlugin.cancel(889);
    }

    bool isBatterySaverOn = false;
    try {
      isBatterySaverOn = await battery.isInBatterySaveMode;
    } catch (e) {}
    await prefs.setBool('sys_isBatterySaverOn', isBatterySaverOn);

    bool isAlertHidden = prefs.getBool('hide_battery_alert') ?? false;

    if (isBatterySaverOn && !isAlertHidden) {
      flutterLocalNotificationsPlugin.show(
        890,
        '⚠️ SafePulse: Battery Saver Active',
        'Disable Battery Saver to prevent Android from killing the AI sensors.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'safepulse_alerts_v1',
            'System Alerts',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'hide_battery_alert',
                'Hide',
                cancelNotification: true,
              ),
            ],
          ),
        ),
      );
    } else if (!isBatterySaverOn) {
      await prefs.setBool('hide_battery_alert', false);
      flutterLocalNotificationsPlugin.cancel(890);
    }
  });
}

class BackgroundServiceHelper {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'safepulse_silent_v4',
      'SafePulse AI Service',
      description: 'Keeps SafePulse running silently in the background.',
      importance: Importance.low,
    );

    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      'safepulse_alerts_v1',
      'System Alerts',
      description: 'Warnings for GPS and Battery Saver.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alertChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'safepulse_silent_v4',
        initialNotificationTitle: '🛡️ SafePulse AI Active',
        initialNotificationContent: 'Monitoring sensors...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
      ),
    );
  }
}
