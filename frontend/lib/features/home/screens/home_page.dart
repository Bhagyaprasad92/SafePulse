import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../../core/services/location_service.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/theme/app_colors.dart';

import '../../profile/screens/settings_page.dart';
import '../../circles/screens/circle_page.dart';
import '../../sos/screens/sos_hub_page.dart';
import '../../sos/screens/sos_active_page.dart';
import '../../../core/providers/sos_provider.dart';
import 'driving_mode_page.dart';
import 'route_suggestion_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return const HomeContentView();
      case 1:
        return const SOSHubPage();
      case 2:
        return const CirclePage();
      case 3:
        return const SettingsPage();
      default:
        return const HomeContentView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: AppColors.cardBg,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.emergency_outlined), activeIcon: Icon(Icons.emergency), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), activeIcon: Icon(Icons.group), label: 'Circles'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeContentView extends StatefulWidget {
  const HomeContentView({super.key});

  @override
  State<HomeContentView> createState() => _HomeContentViewState();
}

class _HomeContentViewState extends State<HomeContentView> {
  final MapController _mapController = MapController();
  final Battery _battery = Battery();

  LatLng _center = const LatLng(17.38, 78.49);
  StreamSubscription<Position>? _positionStream;
  Timer? _syncTimer;
  String? _userId;

  bool _isOpeningSOS = false;
  late UserRepository _userRepo;

  @override
  void initState() {
    super.initState();
    _userRepo = context.read<UserRepository>();
    _loadUserId();
    _requestPermissions();
    _startLocationUpdates();
    _registerFCMToken();
  }

  Future<void> _requestPermissions() async {
    // 1. Request Core Permissions
    await [
      Permission.location,
      Permission.notification,
      Permission.sms,
      Permission.phone,
      Permission.contacts,
    ].request();

    // 2. Background Location
    if (await Permission.location.isGranted) {
      await Permission.locationAlways.request();
    }

    // 3. Ignore Battery Optimizations
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // 4. Ensure AI monitoring is synced with settings and started
    final prefs = await SharedPreferences.getInstance();
    bool shouldMonitor = prefs.getBool('crash_detection') ?? true;
    if (prefs.get('isMonitoring') == null) {
      await prefs.setBool('isMonitoring', shouldMonitor);
    } else {
      shouldMonitor = prefs.getBool('isMonitoring') ?? false;
    }
    
    if (shouldMonitor) {
      final service = FlutterBackgroundService();
      if (!(await service.isRunning())) {
        await service.startService();
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    _userId = await _userRepo.getUserId();
  }

  Future<void> _registerFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _userRepo.updateStatus(lat: 0, lng: 0, fcmToken: token);
      }
    } catch (_) {}
  }

  void _startLocationUpdates() {
    _positionStream = LocationService.getPositionStream().listen((pos) {
      if (mounted) {
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() => _center = newPos);
        _mapController.move(newPos, _mapController.camera.zoom);
      }
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_center.latitude != 17.38) {
        try {
          final level = await _battery.batteryLevel;
          await _userRepo.updateStatus(
            lat: _center.latitude,
            lng: _center.longitude,
            batteryLevel: "$level%",
          );
        } catch (e) {
          debugPrint("Battery fetch failed: $e");
        }
      }
    });
  }

  Future<void> _triggerSOS() async {
    if (_isOpeningSOS) return;
    setState(() => _isOpeningSOS = true);

    try {
      final pos = await LocationService.getCurrentLocation();
      final success = await context.read<SOSProvider>().startSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        address: 'Home Emergency',
      );

      if (!mounted) return;

      if (success) {
        final sosId = context.read<SOSProvider>().activeSosId;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SOSActivePage(
              sosId: sosId!,
              initialLocation: LatLng(pos.latitude, pos.longitude),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[SOS] Trigger error: $e');
    } finally {
      if (mounted) setState(() => _isOpeningSOS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _center, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.safepulse.app',
            ),
            MarkerLayer(markers: [
              Marker(
                point: _center,
                width: 60,
                height: 60,
                child: const Icon(Icons.my_location, color: AppColors.primary, size: 36),
              ),
            ]),
          ],
        ),

        Positioned(
          right: 16,
          bottom: 110,
          child: FloatingActionButton(
            backgroundColor: _isOpeningSOS ? Colors.grey : Colors.red,
            heroTag: 'home_sos',
            onPressed: _isOpeningSOS ? null : _triggerSOS,
            child: _isOpeningSOS
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          ),
        ),

        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    icon: Icons.explore,
                    label: 'Navigo',
                    bgColor: AppColors.background,
                    textColor: Colors.white,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RouteSuggestionPage()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionBtn(
                    icon: Icons.track_changes,
                    label: 'Track',
                    bgColor: Colors.grey.shade100,
                    textColor: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DrivingModePage(
                          initialLocation: _center,
                          selectedRoute: const {
                            'polyline': [],
                            'distance': 0,
                            'color': 'green',
                            'riskScore': 0,
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}