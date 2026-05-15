import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import 'driving_mode_page.dart';

class FullRouteMapScreen extends StatefulWidget {
  final LatLng currentLocation;
  final LatLng destination;
  final List<dynamic> routes;
  final int selectedRouteIndex;

  const FullRouteMapScreen({
    super.key,
    required this.currentLocation,
    required this.destination,
    required this.routes,
    required this.selectedRouteIndex,
  });

  @override
  State<FullRouteMapScreen> createState() => _FullRouteMapScreenState();
}

class _FullRouteMapScreenState extends State<FullRouteMapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    debugPrint('[FullMap] Screen initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitSelectedRoute();
    });
  }

  void _fitSelectedRoute() {
    if (widget.routes.isEmpty) return;

    final selectedRoute = widget.routes[widget.selectedRouteIndex];
    final polyData = selectedRoute['polyline'] as List?;
    if (polyData == null || polyData.isEmpty) return;

    final routePoints = polyData
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();

    final allPoints = [
      widget.currentLocation,
      widget.destination,
      ...routePoints,
    ];

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(allPoints),
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  Color _colorFromString(String? c) {
    switch (c) {
      case 'green':  return AppColors.safe;
      case 'yellow': return AppColors.idle;
      case 'red':    return AppColors.risk;
      default:       return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = widget.routes[widget.selectedRouteIndex];
    final routeColor = _colorFromString(selectedRoute['color']);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. MAP LAYER (Fills entire screen)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.currentLocation,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safepulse.app',
                ),
                PolylineLayer(
                  polylines: widget.routes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final route = entry.value;
                    final isSelected = index == widget.selectedRouteIndex;
                    final polyData = route['polyline'] as List?;
                    if (polyData == null) return Polyline(points: [], color: Colors.transparent);
                    
                    final pts = polyData
                        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
                        .toList();

                    return Polyline(
                      points: pts,
                      strokeWidth: isSelected ? 8 : 4,
                      color: isSelected ? _colorFromString(route['color']) : _colorFromString(route['color']).withOpacity(0.3),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.currentLocation,
                      width: 40, height: 40,
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                    ),
                    Marker(
                      point: widget.destination,
                      width: 40, height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. BACK NAVIGATION BUTTON (Top Left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Material(
              color: Colors.white,
              elevation: 8,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  debugPrint('[FullMap] Back button pressed');
                  Navigator.pop(context);
                },
              ),
            ),
          ),

          // 3. STATS FOOTER (Bottom)
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(selectedRoute['duration'] / 60).round()} min',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(selectedRoute['distance'] / 1000).toStringAsFixed(1)} km • Score: ${selectedRoute['riskScore']}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Using a more stable button structure to avoid layout errors
                  GestureDetector(
                    onTap: () {
                      debugPrint('[FullMap] Start Journey pressed');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DrivingModePage(
                            selectedRoute: Map<String, dynamic>.from(selectedRoute),
                            initialLocation: widget.currentLocation,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: routeColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
