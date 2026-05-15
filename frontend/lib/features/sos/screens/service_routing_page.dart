import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';

class ServiceRoutingPage extends StatefulWidget {
  final String serviceName;
  final double destinationLat;
  final double destinationLng;

  const ServiceRoutingPage({
    super.key,
    required this.serviceName,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<ServiceRoutingPage> createState() => _ServiceRoutingPageState();
}

class _ServiceRoutingPageState extends State<ServiceRoutingPage> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  @override
  void initState() {
    super.initState();
    _initRouting();
  }

  Future<void> _initRouting() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      
      setState(() {
        _markers = [
          Marker(
            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            width: 80,
            height: 80,
            child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
          ),
          Marker(
            point: LatLng(widget.destinationLat, widget.destinationLng),
            width: 80,
            height: 80,
            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
        ];

        _polylines = [
          Polyline(
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(widget.destinationLat, widget.destinationLng),
            ],
            color: AppColors.primary,
            strokeWidth: 5,
          ),
        ];
      });

      _mapController.move(
        LatLng(
          (_currentPosition!.latitude + widget.destinationLat) / 2,
          (_currentPosition!.longitude + widget.destinationLng) / 2,
        ),
        13.0,
      );
    } catch (e) {
      debugPrint("Routing Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Route to ${widget.serviceName}",
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.navigation, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Navigating to ${widget.serviceName}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Follow the blue line for the safest route.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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
