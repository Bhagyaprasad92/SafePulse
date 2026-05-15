import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animate_do/animate_do.dart';

import '../../../core/providers/circle_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/circle.dart';
import '../../../core/models/circle_member.dart';

import '../widgets/circle_member_tile.dart';
import '../widgets/add_members_sheet.dart';
import 'circle_map_page.dart';

class CirclePage extends StatefulWidget {
  const CirclePage({super.key});

  @override
  State<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends State<CirclePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  int? _deviceBattery;
  BatteryState? _batteryState;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDeviceBattery();
  }

  Future<void> _loadDeviceBattery() async {
    final battery = Battery();
    try {
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      if (mounted) setState(() { _deviceBattery = level; _batteryState = state; });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    context.read<CircleProvider>().loadCircles();
  }

  // ── SCANNER LOGIC ──────────────────────────────────────────────────────────
  void _showScanner() async {
    final status = await Permission.camera.request();
    if (status.isDenied) return;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => Column(
        children: [
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Scan Invite QR", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: MobileScanner(
              controller: MobileScannerController(
                facing: CameraFacing.back,
                torchEnabled: false,
              ),
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? "";
                  if (code.isNotEmpty) {
                    Navigator.pop(ctx);
                    final success = await context.read<CircleProvider>().joinCircle(code);
                    if (mounted) {
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Join failed or invalid code")));
                      }
                    }
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _showCreateCircleDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => Consumer<CircleProvider>(
        builder: (context, provider, child) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Create New Circle", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Circle Name",
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: provider.isLoading ? null : () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final name = _nameController.text.trim();
                      if (name.isNotEmpty) {
                        final success = await provider.createCircle(name);
                        if (mounted) {
                          Navigator.pop(context);
                          if (!success) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create circle")));
                          }
                        }
                      }
                    },
              child: provider.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text("CREATE"),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinCircleDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (context) => Consumer<CircleProvider>(
        builder: (context, provider, child) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Join a Circle", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Invite Code",
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surface)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: provider.isLoading ? null : () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final code = _codeController.text.trim().toUpperCase();
                      if (code.isNotEmpty) {
                        final success = await provider.joinCircle(code);
                        if (mounted) {
                          Navigator.pop(context);
                          if (!success) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text("Invalid code or already joined")));
                          }
                        }
                      }
                    },
              child: provider.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text("JOIN"),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareCodeDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text("Invite to Circle", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(data: code, size: 180.0, foregroundColor: Colors.black),
          ),
          const SizedBox(height: 24),
          Text(code, style: const TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Share.share("Join my SafePulse Circle! Code: $code"),
            icon: const Icon(Icons.share),
            label: const Text("SHARE INVITE CODE"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CircleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Circles", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            onPressed: _showScanner,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: _showCreateCircleDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: provider.isLoading && provider.circles.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : provider.circles.isEmpty 
                ? _buildEmptyState() 
                : _buildCircleList(provider.circles),
      ),
      floatingActionButton: provider.circles.isNotEmpty ? FloatingActionButton(
        onPressed: _showJoinCircleDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ) : null,
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              child: const Icon(Icons.group_outlined, size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              child: const Text(
                "Your Circles",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: const Text(
                "Create a circle to start tracking your family and friends, or join an existing one using a code.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Column(
                children: [
                  _buildActionCard(
                    icon: Icons.qr_code_scanner,
                    label: "Scan QR Code",
                    color: AppColors.primary,
                    onTap: _showScanner,
                  ),
                  const SizedBox(height: 16),
                  _buildActionCard(
                    icon: Icons.group_add,
                    label: "Join with Code",
                    color: AppColors.secondary,
                    onTap: _showJoinCircleDialog,
                  ),
                  const SizedBox(height: 16),
                  _buildActionCard(
                    icon: Icons.add,
                    label: "Create New Circle",
                    color: AppColors.cardBg,
                    onTap: _showCreateCircleDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleList(List<Circle> circles) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: circles.length,
      itemBuilder: (context, index) {
        final circle = circles[index];
        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCircleHeader(circle),
              const SizedBox(height: 12),
              ...circle.members.map((member) => CircleMemberTile(
                member: member,
                circleId: circle.id,
                circleName: circle.name,
                isSelf: member.id == context.read<AuthProvider>().userId,
                deviceBattery: _deviceBattery,
                batteryState: _batteryState,
              )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleHeader(Circle circle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary.withOpacity(0.8), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(circle.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("${circle.members.length} Members", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24), 
          onPressed: () => _showDeleteConfirmation(circle)
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 28), 
          onPressed: () => _showShareCodeDialog(circle.inviteCode)
        ),
      ]),
    );
  }

  void _showDeleteConfirmation(Circle circle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Circle?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Consensus Deletion: All members must vote to delete for the circle to be removed. Your vote will be recorded.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await context.read<CircleProvider>().requestDeleteCircle(circle.id);
              if (mounted) {
                if (result['success'] == true) {
                  final msg = result['deleted'] == true 
                    ? "Circle deleted successfully!" 
                    : "Vote recorded. ${result['votes']}/${result['totalNeeded']} votes.";
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? "Failed to vote")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("VOTE DELETE"),
          ),
        ],
      ),
    );
  }
}
