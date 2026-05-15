import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/sos_repository.dart';
import '../models/nearby_service.dart';
import '../../home/screens/full_route_map_screen.dart';

class NearbyServiceMapScreen extends StatefulWidget {
  final String title;
  final LatLng userLocation;
  final List<NearbyService> services;

  const NearbyServiceMapScreen({
    super.key,
    required this.title,
    required this.userLocation,
    required this.services,
  });

  @override
  State<NearbyServiceMapScreen> createState() => _NearbyServiceMapScreenState();
}

class _NearbyServiceMapScreenState extends State<NearbyServiceMapScreen> {
  final MapController _mapController = MapController();
  final List<NearbyService> _cachedServices = [];
  Timer? _debounce;
  bool _isLoading = false;
  String _statusText = '';
  late SOSRepository _sosRepo;

  @override
  void initState() {
    super.initState();
    _sosRepo = context.read<SOSRepository>();
    _cachedServices.addAll(widget.services.take(4));
    _statusText = 'Showing closest ${_cachedServices.length} services';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMarkers();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchForVisibleBounds();
    });
  }

  Future<void> _fetchForVisibleBounds() async {
    if (_isLoading || !mounted) return;

    final camera = _mapController.camera;
    if (camera.zoom < 11) {
      setState(() => _statusText = 'Zoom in to see more services');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusText = 'Fetching more services...';
    });

    final bounds = camera.visibleBounds;
    final type = widget.title.contains('Hospital') ? 'hospital' : 'police';

    try {
      final result = await _sosRepo.getServicesInBBox(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
        type: type,
      );

      if (result['success'] == true && mounted) {
        final List<dynamic> list = result['services'] ?? [];
        final newServices = list.map((s) => NearbyService.fromJson(s)).toList();

        setState(() {
          for (var ns in newServices) {
            if (!_cachedServices.any((existing) => existing.id == ns.id)) {
              _cachedServices.add(ns);
            }
          }
          _isLoading = false;
          _statusText = '${_cachedServices.length} total services visible';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fitMarkers() {
    if (_cachedServices.isEmpty) return;

    final allPoints = [
      widget.userLocation,
      ..._cachedServices.map((s) => LatLng(s.lat, s.lon)),
    ];

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(allPoints),
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  void _showServiceDetails(NearbyService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  service.type == 'hospital'
                      ? Icons.local_hospital
                      : Icons.local_police,
                  color: service.type == 'hospital'
                      ? Colors.redAccent
                      : Colors.blueAccent,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Location: ${service.lat.toStringAsFixed(4)}, ${service.lon.toStringAsFixed(4)}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateTo(service.lat, service.lon),
              icon: const Icon(Icons.navigation),
              label: const Text('NAVIGATE NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Center(
                  child: Text('Close', style: TextStyle(color: Colors.grey))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateTo(double lat, double lon) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final routesData = await _sosRepo.suggestRoutes(
        startLat: widget.userLocation.latitude,
        startLng: widget.userLocation.longitude,
        destLat: lat,
        destLng: lon,
      );

      if (mounted) Navigator.pop(context);

      if (routesData['routes'] != null && (routesData['routes'] as List).isNotEmpty) {
        final routes = routesData['routes'] as List<dynamic>;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullRouteMapScreen(
                currentLocation: widget.userLocation,
                destination: LatLng(lat, lon),
                routes: routes,
                selectedRouteIndex: 0,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(routesData['error'] ??
                    'Could not find a safe route to this location.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating route: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18)),
            Text(_statusText,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.userLocation,
              initialZoom: 14,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safepulse.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation,
                    width: 45,
                    height: 45,
                    child: const Icon(Icons.my_location,
                        color: Colors.blue, size: 30),
                  ),
                  ..._cachedServices.map((s) => Marker(
                        point: LatLng(s.lat, s.lon),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showServiceDetails(s),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: Icon(
                              s.type == 'hospital'
                                  ? Icons.local_hospital
                                  : Icons.local_police,
                              color: s.type == 'hospital'
                                  ? Colors.red
                                  : Colors.blue,
                              size: 24,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _fitMarkers,
              child: const Icon(Icons.center_focus_strong, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
