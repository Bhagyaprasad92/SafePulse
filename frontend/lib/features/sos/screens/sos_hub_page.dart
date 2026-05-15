import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/sos_provider.dart';
import '../widgets/emergency_countdown.dart';
import '../../../core/repositories/user_repository.dart';
import './service_routing_page.dart';
import './sos_active_page.dart';
import '../models/nearby_service.dart';
import './nearby_service_map_screen.dart';

class SOSHubPage extends StatefulWidget {
  const SOSHubPage({super.key});

  @override
  State<SOSHubPage> createState() => _SOSHubPageState();
}

class _SOSHubPageState extends State<SOSHubPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  double _pressProgress = 0.0;
  bool _isPressed = false;
  Timer? _pressTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadContacts().then((_) => _saveContacts());
    _updateNearbyServices();
  }

  String _currentLocation = "Fetching location...";
  Map<String, dynamic>? _nearbyData;
  bool _isLoadingServices = false;
  bool _isNavigating = false; // Prevents multiple screen pushes
  final MapController _mapController = MapController();

  Future<void> _updateNearbyServices() async {
    if (!mounted || _isLoadingServices) return;
    setState(() => _isLoadingServices = true);

    try {
      final position = await LocationService.getCurrentLocation();
      await context.read<SOSProvider>().loadNearbyServices(
        lat: position.latitude,
        lon: position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentLocation = "Near your current location";
          _nearbyData = context.read<SOSProvider>().nearbyData;
          _isLoadingServices = false;
        });
        _mapController.move(LatLng(position.latitude, position.longitude), 14);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = "Location Unavailable";
          _isLoadingServices = false;
        });
      }
    }
  }

  void _navigateToNearbyMap(String type) async {
    if (_isNavigating) return;
    if (_nearbyData == null || _nearbyData!['services'] == null) return;

    setState(() => _isNavigating = true);

    try {
      final serviceList = type == 'hospital'
          ? _nearbyData!['services']['hospitals']
          : _nearbyData!['services']['police'];

      final List<NearbyService> services =
          (serviceList as List).map((s) => NearbyService.fromJson(s)).toList();

      final pos = await LocationService.getCurrentLocation();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NearbyServiceMapScreen(
            title: type == 'hospital'
                ? "Nearby Hospitals"
                : "Nearby Police Stations",
            userLocation: LatLng(pos.latitude, pos.longitude),
            services: services,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _routeToService(String name, double lat, double lng) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRoutingPage(
          serviceName: name,
          destinationLat: lat,
          destinationLng: lng,
        ),
      ),
    );
  }

  List<Map<String, String>> _emergencyContacts = [];

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    setState(() {
      _emergencyContacts = contactsJson.map((c) {
        final parts = c.split('|');
        return {'name': parts[0], 'phone': parts[1]};
      }).toList();

      if (_emergencyContacts.isEmpty) {
        // Start empty as per user request
        _emergencyContacts = [];
      }
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson =
        _emergencyContacts.map((c) => "${c['name']}|${c['phone']}").toList();
    await prefs.setStringList('emergency_contacts', contactsJson);
    
    // Sync to backend so SOS start knows about them
    if (mounted) {
      await context.read<UserRepository>().syncEmergencyContacts(_emergencyContacts);
    }
  }

  Future<void> _pickContact() async {
    try {
      debugPrint(
          "CONTACT_DEBUG: Requesting permission with permission_handler...");
      var status = await Permission.contacts.request();

      if (status.isGranted) {
        debugPrint("CONTACT_DEBUG: Permission granted. Opening picker...");
        // Re-check with flutter_contacts as well
        if (await FlutterContacts.requestPermission()) {
          final contact = await FlutterContacts.openExternalPick();
          debugPrint("CONTACT_DEBUG: Picker result: $contact");

          if (contact != null) {
            final fullContact = await FlutterContacts.getContact(contact.id);
            if (fullContact != null && fullContact.phones.isNotEmpty) {
              setState(() {
                if (_emergencyContacts.length >= 3) {
                  _emergencyContacts.removeAt(0);
                }
                _emergencyContacts.add({
                  'name': fullContact.displayName,
                  'phone': fullContact.phones.first.number,
                });
              });
              _saveContacts();
            } else {
              debugPrint("CONTACT_DEBUG: Contact has no phone numbers");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Selected contact has no phone numbers")),
              );
            }
          }
        }
      } else if (status.isPermanentlyDenied) {
        debugPrint("CONTACT_DEBUG: Permanently denied");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Permission permanently denied. Please enable in Settings."),
            action:
                SnackBarAction(label: "Settings", onPressed: openAppSettings),
          ),
        );
      } else {
        debugPrint("CONTACT_DEBUG: Permission denied (status: $status)");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                "Contact permission is required to add emergency contacts."),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "Enable",
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("CONTACT_DEBUG: Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking contact: $e")),
      );
    }
  }

  void _handlePressStart() {
    setState(() => _isPressed = true);
    _pressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _pressProgress += 0.033; // ~3 seconds to reach 1.0
        if (_pressProgress >= 1.0) {
          _triggerSOS();
          _cancelTimer();
        }
      });
    });
  }

  void _handlePressEnd() {
    _cancelTimer();
    setState(() {
      _isPressed = false;
      _pressProgress = 0.0;
    });
  }

  void _cancelTimer() {
    _pressTimer?.cancel();
    _pressTimer = null;
  }

  bool _isTriggeringSOS = false;

  Future<void> _triggerSOS() async {
    if (_isTriggeringSOS) return;
    setState(() => _isTriggeringSOS = true);

    try {
      final pos = await LocationService.getCurrentLocation();
      final success = await context.read<SOSProvider>().startSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        address: _currentLocation.replaceFirst("Your Location: ", ""),
      );

      if (success && mounted) {
        final sosId = context.read<SOSProvider>().activeSosId;
        if (sosId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SOSActivePage(
                sosId: sosId,
                initialLocation: LatLng(pos.latitude, pos.longitude),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isTriggeringSOS = false);
      }
    }
  }

  Future<void> _makeCall(String name, String phone) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);

      // Auto-send SMS alert as a fallback/secondary notification
      _sendSMSAlert(name, phone);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not launch call to $phone"),
          backgroundColor: AppColors.risk,
        ),
      );
    }
  }

  Future<void> _sendSMSAlert(String name, String phone) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': 'Emergency! I need help. This is an SOS alert from SafePulse.',
      },
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // SOS screen is white in reference
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // This handles cases where SOS is viewed from BottomNavBar
              // It should basically "switch" back to home tab, but for now
              // we ensure it doesn't show a black screen.
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
        ),
        title: const Text(
          "SOS Emergency Hub",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadContacts();
          await _updateNearbyServices();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                "Hold for 3 Seconds to\nSOS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.background,
                ),
              ),
              const SizedBox(height: 40),

              // Pulsing SOS Button
              Center(
                child: GestureDetector(
                  onLongPressStart: (_) => _handlePressStart(),
                  onLongPressEnd: (_) => _handlePressEnd(),
                  onLongPressCancel: () => _handlePressEnd(),
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulse
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 250 * (1 + _pulseController.value * 0.1),
                              height: 250 * (1 + _pulseController.value * 0.1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                        // Middle Ring
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        // Progress Ring
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: _pressProgress,
                            strokeWidth: 8,
                            color: Colors.red,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        // Main Button
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isPressed
                                  ? [Colors.red, Colors.redAccent]
                                  : [AppColors.primary, AppColors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isPressed
                                    ? Colors.red.withOpacity(0.5)
                                    : AppColors.primary.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_rounded,
                                  color: Colors.white, size: 50),
                              SizedBox(height: 8),
                              Text(
                                "SOS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Emergency services and contacts will be notified",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),

              const SizedBox(height: 40),

              // Emergency Contacts Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Emergency Contacts",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: _pickContact,
                          child: const Text("Add",
                              style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._emergencyContacts.map((contact) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildContactCard(
                              contact['name']!, contact['phone']!),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Nearby Services Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Nearby Services",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_isLoadingServices)
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Hospital Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _navigateToNearbyMap('hospital'),
                            child: _buildServiceCard(
                              "Hospitals",
                              _nearbyData != null
                                  ? "${_nearbyData!['counts']['hospitals']} nearby"
                                  : "Loading...",
                              Icons.local_hospital,
                              Colors.blue.withOpacity(0.05),
                              Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Police Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _navigateToNearbyMap('police'),
                            child: _buildServiceCard(
                              "Police",
                              _nearbyData != null
                                  ? "${_nearbyData!['counts']['police']} nearby"
                                  : "Loading...",
                              Icons.local_police,
                              Colors.indigo.withOpacity(0.05),
                              Colors.indigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Location Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: AppColors.surface),
                    ),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(
                                17.3850, 78.4867), // Default, will be updated
                            initialZoom: 13,
                            interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.safepulse.app',
                            ),
                            if (_nearbyData != null)
                              MarkerLayer(
                                markers: [
                                  // Hospitals
                                  ...(_nearbyData!['services']['hospitals']
                                          as List)
                                      .map((s) => Marker(
                                            point: LatLng(
                                                (s['lat'] as num).toDouble(),
                                                (s['lon'] as num).toDouble()),
                                            width: 30,
                                            height: 30,
                                            child: const Icon(
                                                Icons.local_hospital,
                                                color: Colors.red,
                                                size: 20),
                                          )),
                                  // Police
                                  ...(_nearbyData!['services']['police']
                                          as List)
                                      .map((s) => Marker(
                                            point: LatLng(
                                                (s['lat'] as num).toDouble(),
                                                (s['lon'] as num).toDouble()),
                                            width: 30,
                                            height: 30,
                                            child: const Icon(
                                                Icons.local_police,
                                                color: Colors.blue,
                                                size: 20),
                                          )),
                                ],
                              ),
                          ],
                        ),
                        // Overlay Location Text
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4)
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    color: AppColors.primary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentLocation,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: const Icon(Icons.person, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(phone,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _makeCall(name, phone),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.blue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
      String label, String dist, IconData icon, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            dist,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
