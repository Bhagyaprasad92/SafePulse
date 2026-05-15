import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/dnd_service.dart';
import '../../../core/services/safety_ai_service.dart';
import '../../../core/providers/sos_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../sos/screens/sos_active_page.dart';
import '../../tracking/services/motion_service.dart';
import 'route_suggestion_page.dart';

class DrivingModePage extends StatefulWidget {
  final Map<String, dynamic> selectedRoute;
  final LatLng? initialLocation;

  const DrivingModePage({
    super.key,
    required this.selectedRoute,
    this.initialLocation,
  });

  @override
  State<DrivingModePage> createState() => _DrivingModePageState();
}

class _DrivingModePageState extends State<DrivingModePage> {
  final MotionService _motionService = MotionService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _brakingSub;
  StreamSubscription? _crashSub;

  LatLng _currentPos = const LatLng(0, 0);
  double _currentSpeed = 0;
  double _heading = 0;
  bool _isLocationLoaded = false;
  String? _locationError;
  bool _isRetrying = false;

  DateTime? _lastPosTime;
  LatLng? _lastPos;
  final List<double> _speedBuffer = [];
  int _overspeedSeconds = 0;
  bool _dndActive = false;

  double _distanceRemaining = 0;
  String _eta = '--:--';
  int _closestPointIndex = 0;

  bool _isOverSpeeding = false;
  bool _isOffRoute = false;
  final List<Map<String, dynamic>> _alerts = [];
  String _aiSafetyMessage = "Analyzing safety...";
  SafetyStatus _safetyStatus = SafetyStatus.normal;

  late List<LatLng> _polylinePoints;
  late Color _routeColor;
  Timer? _statusTimer;
  bool _isOpeningSOS = false;

  @override
  void initState() {
    super.initState();
    _polylinePoints = (widget.selectedRoute['polyline'] as List)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    _distanceRemaining = (widget.selectedRoute['distance'] as num).toDouble();
    _routeColor = _colorFromString(widget.selectedRoute['color']);

    if (widget.initialLocation != null && widget.initialLocation!.latitude != 0) {
      _currentPos = widget.initialLocation!;
      _isLocationLoaded = true;
    }

    _loadCurrentLocation();
    _startStatusUpdates();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _locationError = null;
      _isRetrying = true;
    });

    try {
      if (!_isLocationLoaded) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentPos = LatLng(lastKnown.latitude, lastKnown.longitude);
            _isLocationLoaded = true;
          });
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _currentPos = LatLng(pos.latitude, pos.longitude);
          _isLocationLoaded = true;
          _isRetrying = false;
        });
        _startTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          if (!_isLocationLoaded) {
            _locationError = "Unable to get GPS location.";
          } else {
            _startTracking();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _brakingSub?.cancel();
    _crashSub?.cancel();
    _statusTimer?.cancel();
    DndService.setDndOff();
    super.dispose();
  }

  void _startTracking() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen((pos) {
      if (mounted) _onPosition(pos);
    });

    _brakingSub = _motionService.monitorSuddenBraking().listen((braking) {
      if (braking) _addAlert(Icons.warning, 'Sudden braking', 'Rapid deceleration detected', Colors.orange);
    });

    _crashSub = _motionService.monitorCrash().listen((crash) {
      if (crash) _addAlert(Icons.car_crash, 'CRASH DETECTED', 'High-impact event. Triggering SOS.', Colors.red);
    });
  }

  void _startStatusUpdates() {
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentPos.latitude != 0) {
        context.read<AuthProvider>().updateStatus(
          lat: _currentPos.latitude,
          lng: _currentPos.longitude,
          isDriving: true,
          currentSpeed: _currentSpeed,
        );
      }
    });
  }

  void _onPosition(Position pos) {
    if (pos.accuracy > 30) return;
    final newPos = LatLng(pos.latitude, pos.longitude);
    final now = DateTime.now();

    double speedKmh = pos.speed * 3.6;
    _speedBuffer.add(speedKmh);
    if (_speedBuffer.length > 3) _speedBuffer.removeAt(0);
    final smoothedSpeed = _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;

    if (smoothedSpeed > 80) {
      _overspeedSeconds++;
      if (_overspeedSeconds >= 10 && !_dndActive) {
        _triggerOverspeedResponse(smoothedSpeed, newPos);
      }
    } else {
      if (_overspeedSeconds > 0) _overspeedSeconds--;
      if (_overspeedSeconds == 0 && _dndActive) _stopOverspeedResponse();
    }

    final aiResult = SafetyAiMonitorService.analyzeRisk(
      speed: smoothedSpeed,
      riskZoneScore: widget.selectedRoute['riskScore'] ?? 0,
      isOffRoute: _isOffRoute,
      time: now,
    );

    setState(() {
      _currentPos = newPos;
      _currentSpeed = smoothedSpeed;
      _heading = pos.heading;
      _isLocationLoaded = true;
      _lastPos = newPos;
      _lastPosTime = now;
      _aiSafetyMessage = aiResult['message'];
      _safetyStatus = aiResult['status'];
      _isOverSpeeding = smoothedSpeed > 65;
    });

    _mapController.move(_currentPos, 17);
    _mapController.rotate(-_heading);

    if (_polylinePoints.isNotEmpty) {
      _processRouteLogic(newPos, smoothedSpeed);
    }
  }

  void _processRouteLogic(LatLng newPos, double speed) {
    double minDist = double.infinity;
    int closest = _closestPointIndex;
    final start = (_closestPointIndex - 5).clamp(0, _polylinePoints.length - 1);
    for (int i = start; i < _polylinePoints.length; i++) {
      final d = Geolocator.distanceBetween(newPos.latitude, newPos.longitude, _polylinePoints[i].latitude, _polylinePoints[i].longitude);
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    _closestPointIndex = closest;

    double remaining = 0;
    for (int i = closest; i < _polylinePoints.length - 1; i++) {
      remaining += Geolocator.distanceBetween(_polylinePoints[i].latitude, _polylinePoints[i].longitude, _polylinePoints[i + 1].latitude, _polylinePoints[i + 1].longitude);
    }

    String eta = '--:--';
    if (speed > 5) {
      final hoursLeft = (remaining / 1000) / speed;
      final etaTime = DateTime.now().add(Duration(seconds: (hoursLeft * 3600).round()));
      eta = DateFormat('hh:mm a').format(etaTime);
    }

    final offRoute = minDist > 65;
    if (offRoute && !_isOffRoute) {
      _addAlert(Icons.alt_route, 'Off route', 'Rerouting to safe path...', Colors.redAccent);
      _reroute(newPos);
    }

    setState(() {
      _distanceRemaining = remaining;
      _eta = eta;
      _isOffRoute = offRoute;
    });
  }

  void _triggerOverspeedResponse(double speed, LatLng pos) {
    _dndActive = true;
    DndService.setDndOn();
    _addAlert(Icons.do_not_disturb_on, 'DND Active', 'High speed detected. Focus on road.', Colors.red);
    context.read<UserRepository>().sendSpeedAlert(speed: speed, lat: pos.latitude, lon: pos.longitude, limit: 80);
  }

  void _stopOverspeedResponse() {
    _dndActive = false;
    DndService.setDndOff();
    _addAlert(Icons.check_circle, 'Safe speed', 'DND Mode disabled', Colors.green);
  }

  Future<void> _reroute(LatLng from) async {
    final navProvider = context.read<NavigationProvider>();
    if (navProvider.isLoading || _polylinePoints.isEmpty) return;
    
    final dest = _polylinePoints.last;
    await navProvider.fetchRoutes(
      startLat: from.latitude,
      startLng: from.longitude,
      destLat: dest.latitude,
      destLng: dest.longitude,
    );

    if (!mounted) return;
    if (navProvider.routes.isNotEmpty) {
      final bestRoute = navProvider.routes.first;
      setState(() {
        _polylinePoints = bestRoute.polyline.map((p) => LatLng(p[0], p[1])).toList();
        _closestPointIndex = 0;
        _isOffRoute = false;
      });
    }
  }

  void _addAlert(IconData icon, String title, String sub, Color color) {
    if (_alerts.isNotEmpty && _alerts.first['title'] == title && DateTime.now().difference(_alerts.first['time'] as DateTime).inSeconds < 15) return;
    setState(() {
      _alerts.insert(0, {'icon': icon, 'title': title, 'sub': sub, 'color': color, 'time': DateTime.now()});
      if (_alerts.length > 3) _alerts.removeLast();
    });
  }

  Color _colorFromString(String? c) {
    switch (c) {
      case 'green': return AppColors.safe;
      case 'yellow': return AppColors.idle;
      case 'red': return AppColors.risk;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: !_isLocationLoaded
          ? _buildLoadingState()
          : Stack(
              children: [
                _buildMap(),
                _buildHud(),
                _buildControls(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          const Text('Getting GPS lock...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _currentPos, initialZoom: 17),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.safepulse.app'),
        if (_polylinePoints.isNotEmpty)
          PolylineLayer(polylines: [Polyline(points: _polylinePoints, color: _routeColor, strokeWidth: 8)]),
        MarkerLayer(markers: [
          Marker(
            point: _currentPos,
            width: 50, height: 50,
            child: Transform.rotate(angle: _heading * (3.14159 / 180), child: const Icon(Icons.navigation, color: AppColors.primary, size: 38)),
          ),
        ]),
      ],
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Column(
        children: [
          _buildSafetyAiCard(),
          _buildStatsBar(),
          ..._alerts.take(2).map((a) => _buildAlertWidget(a)),
        ],
      ),
    );
  }

  Widget _buildSafetyAiCard() {
    final bool isDanger = _safetyStatus == SafetyStatus.danger;
    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDanger ? Colors.red.withOpacity(0.9) : AppColors.cardBg.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDanger ? Colors.white : AppColors.surface),
        ),
        child: Row(
          children: [
            Icon(isDanger ? Icons.gpp_bad : Icons.gpp_good, color: isDanger ? Colors.white : AppColors.safe),
            const SizedBox(width: 12),
            Expanded(child: Text(_aiSafetyMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem('Speed', '${_currentSpeed.toStringAsFixed(0)} km/h', _currentSpeed > 80 ? Colors.red : Colors.white),
          _statItem('ETA', _eta, Colors.white),
          _statItem('Left', _distanceRemaining < 1000 ? '${_distanceRemaining.round()} m' : '${(_distanceRemaining / 1000).toStringAsFixed(1)} km', Colors.white),
          _statItem('Risk', widget.selectedRoute['riskScore'].toString(), _routeColor),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      right: 16,
      bottom: 30,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'sos',
            backgroundColor: _isOpeningSOS ? Colors.grey : Colors.red,
            onPressed: _isOpeningSOS ? null : _triggerSOS,
            child: _isOpeningSOS ? const CircularProgressIndicator(color: Colors.white) : const Text('SOS'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'stop',
            backgroundColor: AppColors.cardBg,
            mini: true,
            onPressed: () => Navigator.pop(context),
            child: const Icon(Icons.stop, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Widget _buildAlertWidget(Map<String, dynamic> a) {
    return FadeInLeft(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.9), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(a['icon'] as IconData, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(a['sub'], style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }

  Future<void> _triggerSOS() async {
    if (_isOpeningSOS) return;
    setState(() => _isOpeningSOS = true);
    final sosProvider = context.read<SOSProvider>();
    final success = await sosProvider.startSOS(lat: _currentPos.latitude, lng: _currentPos.longitude, address: 'Emergency during tracking');
    if (success && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => SOSActivePage(sosId: sosProvider.activeSos!.id, initialLocation: _currentPos)));
    }
    if (mounted) setState(() => _isOpeningSOS = false);
  }
}
