import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import 'circle_map_page.dart';

class MemberDetailPage extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final String circleId;
  final String circleName;

  /// True when the user is viewing their own entry in the circle.
  final bool isSelf;

  /// Pre-loaded device battery level passed from CirclePage (only for self).
  final int? deviceBattery;
  final BatteryState? deviceBatteryState;

  const MemberDetailPage({
    super.key,
    required this.memberData,
    required this.circleId,
    required this.circleName,
    this.isSelf = false,
    this.deviceBattery,
    this.deviceBatteryState,
  });

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  // ── WhatsApp ───────────────────────────────────────────────────────────────
  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'Not available') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')));
      return;
    }
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$waNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')));
      }
    }
  }

  // ── Phone call ─────────────────────────────────────────────────────────────
  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'Not available') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open dialer')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.memberData['name'] ?? 'Member';
    final String? profilePic = widget.memberData['profilePic'];

    // Battery: for self → use device battery; for others → use backend value
    final int batteryNum;
    final String batteryDisplay;

    if (widget.isSelf && widget.deviceBattery != null) {
      batteryNum = widget.deviceBattery!;
      batteryDisplay = '$batteryNum%';
    } else {
      final String raw = (widget.memberData['batteryLevel'] != null &&
              widget.memberData['batteryLevel'].toString().isNotEmpty)
          ? widget.memberData['batteryLevel'].toString()
          : '0%';
      batteryNum = int.tryParse(raw.replaceAll('%', '').trim()) ?? 0;
      batteryDisplay = raw;
    }

    final Color batteryColor = batteryNum <= 20
        ? Colors.red
        : batteryNum <= 50
            ? Colors.orange
            : AppColors.safe;

    final bool isDriving = widget.memberData['isDriving'] == true;
    final int speed = (widget.memberData['currentSpeed'] ?? 0).toInt();
    final String phone = widget.memberData['phone'] ?? '';
    final String lastSeen = _formatLastSeen(widget.memberData['lastSeen']);

    final loc =
        widget.memberData['lastLocation'] ?? widget.memberData['location'];
    final bool hasLocation =
        loc != null && loc['lat'] != null && loc['lng'] != null;
    final String locationText = hasLocation
        ? '${(loc['lat'] as num).toStringAsFixed(5)}, ${(loc['lng'] as num).toStringAsFixed(5)}'
        : 'Location not shared';

    // Battery subtitle: if charging show it, otherwise Normal / Low battery
    String batterySubtitle = batteryNum <= 20 ? 'Low battery!' : 'Normal';
    if (widget.isSelf && widget.deviceBatteryState == BatteryState.charging) {
      batterySubtitle = 'Charging ⚡';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: AppColors.primary),
            tooltip: 'View on map',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CircleMapPage(
                    circleId: widget.circleId, circleName: widget.circleName),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile header ──────────────────────────────────────────────
            Center(
              child: Column(children: [
                Stack(alignment: Alignment.bottomRight, children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surface,
                    backgroundImage:
                        profilePic != null ? NetworkImage(profilePic) : null,
                    child: profilePic == null
                        ? Text(name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 36))
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: isDriving ? AppColors.primary : AppColors.safe,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.background, width: 2)),
                    child: Icon(isDriving ? Icons.directions_car : Icons.check,
                        color: Colors.white, size: 14),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(isDriving ? 'Currently Driving' : 'Active',
                    style: TextStyle(
                        color: isDriving ? AppColors.primary : AppColors.safe,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text('Last seen: $lastSeen',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Status cards (single battery card — no duplicate) ───────────
            Row(children: [
              Expanded(
                child: _buildStatusCard(
                  icon: _getBatteryIcon(batteryNum),
                  iconColor: batteryColor,
                  label: 'Battery',
                  value: batteryDisplay,
                  valueColor: batteryColor,
                  subtitle: batterySubtitle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  icon: isDriving
                      ? Icons.directions_car
                      : Icons.directions_car_outlined,
                  iconColor:
                      isDriving ? AppColors.primary : AppColors.textSecondary,
                  label: 'Driving',
                  value: isDriving ? '$speed km/h' : 'Not driving',
                  valueColor:
                      isDriving ? AppColors.primary : AppColors.textSecondary,
                  subtitle: isDriving ? 'In motion' : 'Stationary',
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // ── Location card ───────────────────────────────────────────────
            _buildInfoCard(
              icon: Icons.location_on,
              iconColor: AppColors.primary,
              title: 'Current Location',
              content: locationText,
              trailing: hasLocation
                  ? TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CircleMapPage(
                                  circleId: widget.circleId,
                                  circleName: widget.circleName))),
                      child: const Text('View on map',
                          style: TextStyle(color: AppColors.primary)))
                  : null,
            ),

            const SizedBox(height: 12),

            // ── Phone card ──────────────────────────────────────────────────
            _buildInfoCard(
              icon: Icons.phone,
              iconColor: AppColors.safe,
              title: 'Phone',
              content: phone.isNotEmpty ? phone : 'Not available',
              trailing: phone.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.call,
                          color: AppColors.safe, size: 20),
                      onPressed: () => _callPhone(phone),
                    )
                  : null,
            ),

            const SizedBox(height: 28),

            // ── Action buttons ──────────────────────────────────────────────
            const Text('Quick Actions',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                  child: _buildActionButton(
                icon: Icons.map_outlined,
                label: 'Open Map',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CircleMapPage(
                            circleId: widget.circleId,
                            circleName: widget.circleName))),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildActionButton(
                icon: Icons.message,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _openWhatsApp(phone),
              )),
            ]),

            const SizedBox(height: 12),

            // Call button (full width)
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(
                icon: Icons.call,
                label: 'Call ${name.split(' ').first}',
                color: AppColors.safe,
                onTap: () => _callPhone(phone),
              ),
            ),

            const SizedBox(height: 12),

            // "Check on this person" — opens WhatsApp with a pre-filled message
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _sendCheckInMessage(name, phone),
                icon: const Icon(Icons.health_and_safety_outlined,
                    color: Colors.orangeAccent),
                label: Text('Check on ${name.split(' ').first}',
                    style: const TextStyle(color: Colors.orangeAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCheckInMessage(String name, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')));
      return;
    }
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final message = Uri.encodeComponent(
        'Hey ${name.split(' ').first}, just checking in on you! Are you okay? 😊');
    final uri = Uri.parse('https://wa.me/$waNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')));
      }
    }
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surface)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 8),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surface)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(content,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ])),
        if (trailing != null) trailing,
      ]),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Unknown';
    try {
      final dt = DateTime.parse(lastSeen.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hr ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  IconData _getBatteryIcon(int level) {
    if (level <= 20) return Icons.battery_alert;
    if (level <= 50) return Icons.battery_3_bar;
    return Icons.battery_full;
  }
}
