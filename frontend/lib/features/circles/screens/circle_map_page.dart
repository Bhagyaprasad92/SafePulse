import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/circle_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/theme/app_colors.dart';

class CircleMapPage extends StatefulWidget {
  final String circleId;
  final String circleName;

  const CircleMapPage({
    super.key,
    required this.circleId,
    required this.circleName,
  });

  @override
  State<CircleMapPage> createState() => _CircleMapPageState();
}

class _CircleMapPageState extends State<CircleMapPage> {
  final MapController _mapController = MapController();
  final Battery _battery = Battery();

  LatLng? _myLocation;
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  List<Map<String, dynamic>> _members = [];
  Timer? _locationTimer;
  Timer? _fetchMembersTimer;
  int _selectedMemberIndex = -1;

  late CircleRepository _circleRepo;
  late UserRepository _userRepo;

  @override
  void initState() {
    super.initState();
    _circleRepo = context.read<CircleRepository>();
    _userRepo = context.read<UserRepository>();
    _init();
  }

  Future<void> _init() async {
    await _getUserLocation();
    await _fetchMembers();

    _locationTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _updateMyLocationOnServer());
    _fetchMembersTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _fetchMembers());
  }

  Future<void> _getUserLocation() async {
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() { _hasLocationPermission = false; _isLoading = false; });
        return;
      }
      setState(() => _hasLocationPermission = true);

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _myLocation = LatLng(pos.latitude, pos.longitude); _isLoading = false; });
      _updateMyLocationOnServer();
    } catch (e) {
      debugPrint('[MAP] Location error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMyLocationOnServer() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));

      int batteryLevel = 100;
      try { batteryLevel = await _battery.batteryLevel; } catch (_) {}

      await _circleRepo.updateMemberLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        batteryLevel: batteryLevel,
      );
      debugPrint('[MAP] Location + battery($batteryLevel%) updated');
    } catch (e) {
      debugPrint('[MAP] Location update error: $e');
    }
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await _circleRepo.getCircleMemberLocations(widget.circleId);
      if (mounted) {
        setState(() => _members = members);
      }
    } catch (e) {
      debugPrint('[MAP] Fetch members error: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _fetchMembersTimer?.cancel();
    super.dispose();
  }

  void _fitAllMembers() {
    final points = [
      if (_myLocation != null) _myLocation!,
      ..._members.map(_getMemberLocation).whereType<LatLng>(),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) { _mapController.move(points[0], 14); return; }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
  }

  LatLng? _getMemberLocation(Map<String, dynamic> member) {
    for (final key in ['lastLocation', 'location']) {
      final loc = member[key];
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        if (lat != 0 || lng != 0) return LatLng(lat, lng);
      }
    }
    return null;
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'Not available') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available')));
      return;
    }
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$waNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Unknown';
    try {
      final dt = DateTime.parse(lastSeen.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return 'Unknown'; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.circleName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${_members.length} member${_members.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined, color: AppColors.primary),
            tooltip: 'Show all members',
            onPressed: _fitAllMembers,
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            tooltip: 'My location',
            onPressed: () { if (_myLocation != null) _mapController.move(_myLocation!, 15); },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : !_hasLocationPermission
              ? _buildPermissionDenied()
              : Stack(children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _myLocation ?? const LatLng(17.0005, 81.8040),
                      initialZoom: 13,
                      minZoom: 4,
                      maxZoom: 18,
                      onMapReady: _fitAllMembers,
                      onTap: (_, __) => setState(() => _selectedMemberIndex = -1),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.safepulse.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(markers: _buildAllMarkers()),
                    ],
                  ),
                  if (_selectedMemberIndex >= 0 && _selectedMemberIndex < _members.length)
                    Positioned(
                      top: 16, left: 16, right: 16,
                      child: _buildMemberInfoCard(_members[_selectedMemberIndex]),
                    ),
                  Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomStrip()),
                ]),
    );
  }

  List<Marker> _buildAllMarkers() {
    final markers = <Marker>[];
    if (_myLocation != null) {
      markers.add(Marker(
        point: _myLocation!, width: 64, height: 74,
        child: _AvatarMarker(label: 'You', imageUrl: null, isMe: true, onTap: null),
      ));
    }
    for (int i = 0; i < _members.length; i++) {
      final point = _getMemberLocation(_members[i]);
      if (point == null) continue;
      markers.add(Marker(
        point: point, width: 64, height: 74,
        child: _AvatarMarker(
          label: (_members[i]['name'] ?? 'Member').toString().split(' ')[0],
          imageUrl: _members[i]['profilePic'],
          isMe: false,
          isSelected: _selectedMemberIndex == i,
          onTap: () { setState(() => _selectedMemberIndex = i); _mapController.move(point, 15); },
        ),
      ));
    }
    return markers;
  }

  Widget _buildBottomStrip() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          _members.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No members have shared their location yet',
                      style: TextStyle(color: AppColors.textSecondary)))
              : SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _members.length,
                    itemBuilder: (_, i) {
                      final m = _members[i];
                      final hasLoc = _getMemberLocation(m) != null;
                      final isSelected = _selectedMemberIndex == i;
                      return GestureDetector(
                        onTap: () {
                          final loc = _getMemberLocation(m);
                          if (loc != null) { _mapController.move(loc, 15); setState(() => _selectedMemberIndex = i); }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent, width: 1.5),
                          ),
                          child: Row(children: [
                            Stack(children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.background,
                                backgroundImage: m['profilePic'] != null ? NetworkImage(m['profilePic']) : null,
                                child: m['profilePic'] == null
                                    ? Text((m['name'] ?? 'M')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    color: hasLoc ? AppColors.safe : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.cardBg, width: 1.5),
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (m['name'] ?? 'Member').split(' ')[0],
                                  style: TextStyle(
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(hasLoc ? 'Location on' : 'No location',
                                    style: TextStyle(color: hasLoc ? AppColors.safe : Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMemberInfoCard(Map<String, dynamic> member) {
    final loc = _getMemberLocation(member);
    final bool isDriving = member['isDriving'] == true;
    final int speed = (member['currentSpeed'] ?? 0).toInt();
    final String battery = member['batteryLevel'] ?? '??';
    final String phone = member['phone'] ?? '';
    final int batteryNum = int.tryParse(battery.replaceAll('%', '').trim()) ?? 100;
    final Color batteryColor = batteryNum <= 20 ? Colors.red : batteryNum <= 50 ? Colors.orange : AppColors.safe;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surface),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.surface,
              backgroundImage: member['profilePic'] != null ? NetworkImage(member['profilePic']) : null,
              child: member['profilePic'] == null
                  ? Text((member['name'] ?? 'M')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member['name'] ?? 'Member',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(isDriving ? Icons.directions_car : Icons.access_time,
                      size: 12, color: isDriving ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    isDriving ? 'Driving @ $speed km/h' : 'Last seen: ${_formatLastSeen(member['lastSeen'])}',
                    style: TextStyle(
                        color: isDriving ? AppColors.primary : AppColors.textSecondary, fontSize: 12),
                  ),
                ]),
              ],
            )),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
              onPressed: () => setState(() => _selectedMemberIndex = -1),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(color: AppColors.surface, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Row(children: [
              Icon(batteryNum <= 20 ? Icons.battery_alert : batteryNum <= 50 ? Icons.battery_3_bar : Icons.battery_full,
                  size: 14, color: batteryColor),
              const SizedBox(width: 3),
              Text(battery, style: TextStyle(color: batteryColor, fontSize: 12)),
            ]),
            const SizedBox(width: 12),
            if (loc != null)
              Flexible(child: Text(
                '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              )),
            const Spacer(),
            GestureDetector(
              onTap: () => _openWhatsApp(phone),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.5)),
                ),
                child: const Row(children: [
                  Icon(Icons.message, color: Color(0xFF25D366), size: 14),
                  SizedBox(width: 4),
                  Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: AppColors.primary.withOpacity(0.4)),
            const SizedBox(height: 24),
            const Text('Location Permission Required',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Please allow location access to see your circle members on the map.',
                style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarMarker extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isMe;
  final bool isSelected;
  final VoidCallback? onTap;

  const _AvatarMarker({
    required this.label,
    required this.imageUrl,
    required this.isMe,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isMe ? AppColors.primary : isSelected ? Colors.white : AppColors.surface;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2.5),
              boxShadow: [BoxShadow(
                color: isMe ? AppColors.primary.withOpacity(0.5) : Colors.black.withOpacity(0.4),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 3 : 1,
              )],
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.cardBg,
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
              child: imageUrl == null
                  ? Text(label[0].toUpperCase(),
                      style: TextStyle(
                          color: isMe ? AppColors.primary : Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 16))
                  : null,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
            ),
            child: Text(label,
                style: TextStyle(
                    color: isMe ? Colors.black : Colors.white,
                    fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}