// NEW FILE
import 'package:flutter/material.dart';
import '../../../core/models/circle_member.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/member_detail_page.dart';

class CircleMemberTile extends StatelessWidget {
  final CircleMember member;
  final String circleId;
  final String circleName;
  final bool isSelf;
  final int? deviceBattery;
  final dynamic batteryState;

  const CircleMemberTile({
    super.key,
    required this.member,
    required this.circleId,
    required this.circleName,
    required this.isSelf,
    this.deviceBattery,
    this.batteryState,
  });

  @override
  Widget build(BuildContext context) {
    final String battery = isSelf && deviceBattery != null
        ? '$deviceBattery%'
        : member.batteryLevel ?? '--';
    
    final int batteryNum = int.tryParse(battery.replaceAll('%', '').trim()) ?? 0;
    final Color batteryColor = batteryNum <= 20
        ? Colors.red
        : batteryNum <= 50
            ? Colors.orange
            : AppColors.safe;

    String statusText;
    Color statusColor;
    if (member.isDriving == true) {
      statusText = "Driving";
      statusColor = AppColors.primary;
    } else if (batteryNum <= 20) {
      statusText = "Low Battery";
      statusColor = Colors.orange;
    } else {
      statusText = isSelf ? "You • Active" : "Active";
      statusColor = AppColors.safe;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailPage(
              memberData: member.toJson(),
              circleId: circleId,
              circleName: circleName,
              isSelf: isSelf,
              deviceBattery: isSelf ? deviceBattery : null,
              deviceBatteryState: isSelf ? batteryState : null,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surface, width: 1),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    member.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBg, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelf ? "${member.name} (You)" : member.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (member.isDriving == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.directions_car, size: 13, color: AppColors.primary),
                        ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(_getBatteryIcon(battery), size: 14, color: batteryColor),
                    const SizedBox(width: 2),
                    Text(battery, style: TextStyle(color: batteryColor, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBatteryIcon(String battery) {
    final num = int.tryParse(battery.replaceAll('%', '').trim()) ?? 100;
    if (num <= 20) return Icons.battery_alert;
    if (num <= 50) return Icons.battery_3_bar;
    return Icons.battery_full;
  }
}
