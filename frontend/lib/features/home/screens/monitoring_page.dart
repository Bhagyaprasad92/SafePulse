import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'driving_mode_page.dart';

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("SafeRide Live"),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.safe.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                CircleAvatar(backgroundColor: AppColors.safe, radius: 4),
                SizedBox(width: 6),
                Text("LIVE", style: TextStyle(color: AppColors.safe, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header: Member Name
            FadeInDown(
              child: const Row(
                children: [
                  Text(
                    "Monitoring: ",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    "Surya (Student)",
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top Quick Stats
            FadeInUp(
              child: Row(
                children: [
                  _buildStatCard("DURATION", "14m 22s"),
                  _buildStatCard("DISTANCE", "4.2 km"),
                  _buildStatCard("AVG SPEED", "42 km/h"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Map Card
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DrivingModePage(
                    selectedRoute: {
                      'type': 'SAFEST',
                      'distance': '4.2 km',
                      'duration': '14m',
                      'points': [],
                    },
                  )));
                },
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    image: const DecorationImage(
                      image: NetworkImage("https://via.placeholder.com/600x400?text=Live+Route+Map"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.safe,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text("ROUTE B RECOMMENDED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Middle Row: Speed & Phone Usage
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "CURRENT SPEED",
                    value: "54",
                    unit: "km/h",
                    subtitle: "SAFE SPEED",
                    statusColor: AppColors.safe,
                    icon: Icons.speed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: "PHONE USAGE",
                    value: "ON",
                    unit: "",
                    subtitle: "WARNING ISSUED",
                    statusColor: AppColors.risk,
                    icon: Icons.phone_android,
                    extraInfo: "App: Instagram",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Integrated Alerts Section
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surface),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "INTEGRATED ALERTS (LAST 5 MIN)",
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _buildAlertItem("Unsafe Phone Use", "12:44 PM • Mom alerted", AppColors.idle),
                    const Divider(color: AppColors.surface, height: 24),
                    _buildAlertItem("Entered High-Risk Zone", "12:35 PM • Safety Core monitoring", AppColors.safe),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Bottom Buttons
            Row(
              children: [
                Expanded(
                  child: _buildPrimaryButton(
                    onPressed: () {},
                    label: "Call Surya",
                    color: const Color(0xFF0D9488), // Teal
                    icon: Icons.call,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPrimaryButton(
                    onPressed: () {},
                    label: "SOS Help",
                    color: AppColors.risk,
                    icon: Icons.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required Color statusColor,
    required IconData icon,
    String? extraInfo,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const Spacer(),
          Center(
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      if (unit.isNotEmpty)
                        TextSpan(
                          text: " $unit",
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (extraInfo != null)
                   Text(extraInfo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(subtitle, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String title, String time, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ],
    );
  }

  Widget _buildPrimaryButton({required VoidCallback onPressed, required String label, required Color color, required IconData icon}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
