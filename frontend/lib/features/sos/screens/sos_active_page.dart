import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/sos_provider.dart';
import '../../../core/theme/app_colors.dart';

class SOSActivePage extends StatefulWidget {
  final String sosId;
  final LatLng initialLocation;

  const SOSActivePage({
    super.key, 
    required this.sosId, 
    required this.initialLocation,
  });

  @override
  State<SOSActivePage> createState() => _SOSActivePageState();
}

class _SOSActivePageState extends State<SOSActivePage> {
  Timer? _refreshTimer;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<SOSProvider>();
    await provider.refreshSOSStatus();
    await provider.loadNearbyServices(
      lat: widget.initialLocation.latitude,
      lon: widget.initialLocation.longitude,
    );
  }

  Future<void> _refreshData() async {
    await context.read<SOSProvider>().refreshSOSStatus();
  }

  Future<void> _cancelSOS() async {
    setState(() => _isCancelling = true);
    final provider = context.read<SOSProvider>();
    await provider.cancelSOS();
    if (mounted) {
      if (provider.status == SOSStatus.cancelled) {
        Navigator.pop(context);
      } else {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel SOS. Try again.')),
        );
      }
    }
  }

  List<Marker> _buildMapMarkers(SOSProvider provider) {
    final markers = <Marker>[
      Marker(
        point: widget.initialLocation,
        width: 60,
        height: 60,
        child: Pulse(
          infinite: true,
          child: const Icon(Icons.location_on, color: Colors.red, size: 46),
        ),
      ),
    ];

    final services = _getServices(provider);
    for (final s in services) {
      markers.add(Marker(
        point: LatLng(s['lat'], s['lon']),
        width: 40,
        height: 40,
        child: Tooltip(
          message: '${s['name']} (${s['distanceMeters']}m)',
          child: Icon(
            s['type'] == 'hospital' ? Icons.local_hospital : Icons.local_police,
            color: s['type'] == 'hospital' ? Colors.blue : Colors.indigo,
            size: 28,
          ),
        ),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SOSProvider>();
    final sos = provider.activeSos;
    
    final contactsCount = sos?.contactsNotified.length ?? 0;
    final nearbyCount = sos?.nearbyUsersNotified.length ?? 0;
    final respondersCount = sos?.responders.length ?? 0;
    
    final services = _getServices(provider);

    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safepulse.app',
              ),
              MarkerLayer(markers: _buildMapMarkers(provider)),
            ],
          ),

          SafeArea(
            child: Column(
              children: [
                FadeInDown(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SOS ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                              Text('Contacts & nearby users notified', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (provider.isLoading)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      ],
                    ),
                  ),
                ),

                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _statCard('Contacts\nNotified', contactsCount, Colors.orange),
                        const SizedBox(width: 10),
                        _statCard('Nearby\nAlerted', nearbyCount, Colors.yellow),
                        const SizedBox(width: 10),
                        _statCard('Active\nResponders', respondersCount, Colors.green),
                      ],
                    ),
                  ),
                ),

                if (services.isNotEmpty)
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: services.take(5).map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _serviceChip(
                                s['type'] == 'hospital' ? Icons.local_hospital : Icons.local_police,
                                '${s['name']} - ${_fmtDist(s['distanceMeters'].toDouble())}',
                                s['type'] == 'hospital' ? Colors.blue : Colors.indigo,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                const Spacer(),

                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton.icon(
                      onPressed: _isCancelling ? null : _cancelSOS,
                      icon: _isCancelling
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cancel),
                      label: const Text('Cancel SOS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade700,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _serviceChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<dynamic> _getServices(SOSProvider provider) {
    final nearbyData = provider.nearbyData;
    if (nearbyData == null) return [];

    final servicesData = nearbyData['services'];
    if (servicesData is List) return servicesData;

    if (servicesData is Map) {
      final List<dynamic> flattened = [];
      flattened.addAll(servicesData['hospitals'] as List? ?? []);
      flattened.addAll(servicesData['police'] as List? ?? []);
      return flattened;
    }

    return [];
  }

  String _fmtDist(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}
