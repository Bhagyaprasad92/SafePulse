// UPDATED
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/safepulse_provider.dart';
import '../../../core/enums.dart';
import '../../../core/theme/app_colors.dart';

class SafePulseHomeScreen extends StatefulWidget {
  const SafePulseHomeScreen({super.key});

  @override
  State<SafePulseHomeScreen> createState() => _SafePulseHomeScreenState();
}

class _SafePulseHomeScreenState extends State<SafePulseHomeScreen> {
  bool useMs = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SafePulseProvider>();
    final double overspeedLimitMs = 2.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SafePulse AI Monitoring', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(provider),
            const SizedBox(height: 20),
            _buildSpeedCard(provider, overspeedLimitMs),
            const SizedBox(height: 20),
            if (provider.distractionSeconds > 0) _buildDistractionWarning(provider),
            const SizedBox(height: 10),
            _buildControls(provider),
            const SizedBox(height: 20),
            _buildLogSection(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(SafePulseProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("System Health", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(provider.isMonitoring ? "ACTVE" : "IDLE", 
                 style: TextStyle(color: provider.isMonitoring ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          isSelected: [!useMs, useMs],
          onPressed: (int index) => setState(() => useMs = index == 1),
          fillColor: AppColors.primary.withOpacity(0.2),
          selectedColor: AppColors.primary,
          color: Colors.grey,
          children: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("km/h")),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("m/s")),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedCard(SafePulseProvider provider, double limit) {
    bool isOverspeed = provider.currentSpeed > limit;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isOverspeed ? Colors.red.withOpacity(0.1) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isOverspeed ? Colors.red : AppColors.surface, width: 2),
      ),
      child: Column(
        children: [
          const Text("REAL-TIME VELOCITY", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            useMs ? "${provider.currentSpeed.toStringAsFixed(1)} m/s" : "${(provider.currentSpeed * 3.6).toStringAsFixed(1)} km/h",
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: isOverspeed ? Colors.red : AppColors.textPrimary,
            ),
          ),
          Text("Safe Threshold: ${useMs ? "${limit.toStringAsFixed(1)} m/s" : "${(limit * 3.6).toStringAsFixed(1)} km/h"}",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDistractionWarning(SafePulseProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Distraction detected for ${provider.distractionSeconds}s",
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(SafePulseProvider provider) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: provider.isProcessing ? null : () {
            if (provider.isMonitoring) {
              provider.stopMonitoring();
            } else {
              provider.startMonitoring();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: provider.isMonitoring ? Colors.red : Colors.green,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(provider.isMonitoring ? Icons.stop : Icons.play_arrow, color: Colors.white),
          label: Text(
            provider.isMonitoring ? "DEACTIVATE AI" : "ACTIVATE AI PROTECTION",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        if (provider.isProcessing) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(color: Colors.red),
          const SizedBox(height: 8),
          const Text("AI is processing emergency sequence...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildLogSection(SafePulseProvider provider) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("System Telemetry", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.builder(
                itemCount: provider.logs.length,
                itemBuilder: (context, index) {
                  final log = provider.logs[index];
                  Color color = Colors.white70;
                  if (log.level == LogLevel.warning) color = Colors.orange;
                  if (log.level == LogLevel.critical) color = Colors.redAccent;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      "[${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second}] ${log.text}",
                      style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
