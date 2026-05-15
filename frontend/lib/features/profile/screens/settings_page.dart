import 'dart:async';

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:safepulse/features/safepulse/engine/safepulse_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/screens/login_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = 'SafePulse User';
  String _userPhone = 'Loading...';
  String _userEmail = 'Not set';
  String _loginType = 'phone';
  bool _crashDetectionEnabled = true;
  bool _speedAlertsEnabled = false;
  bool _notificationsEnabled = true;
  List<Map<String, String>> _emergencyContacts = [];
  double currentSpeedRawMs = 0.0;
  int distractionSeconds = 0;
  EngineState engineState = EngineState.idle;
  bool useMs = true;

  late UserRepository _userRepo;

  @override
  void initState() {
    super.initState();
    _userRepo = context.read<UserRepository>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    setState(() {
      _userName = prefs.getString('userName') ?? 'SafePulse User';
      _userPhone = prefs.getString('userPhone') ?? 'Not set';
      _userEmail = prefs.getString('userEmail') ?? 'Not set';
      _loginType = prefs.getString('loginType') ?? 'phone';
      _crashDetectionEnabled = prefs.getBool('crash_detection') ?? true;
      _speedAlertsEnabled = prefs.getBool('speed_alerts') ?? false;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _emergencyContacts = contactsJson.map((c) {
        final parts = c.split('|');
        return {'name': parts[0], 'phone': parts.length > 1 ? parts[1] : ''};
      }).toList();
      final isMonitoring = prefs.getBool('isMonitoring') ?? false;
      engineState = isMonitoring ? EngineState.monitoring : EngineState.idle;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final json =
        _emergencyContacts.map((c) => '${c['name']}|${c['phone']}').toList();
    await prefs.setStringList('emergency_contacts', json);
    await _userRepo.syncEmergencyContacts(_emergencyContacts);
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  Future<void> _logout(BuildContext context) async {
    await _userRepo.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title:
            const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Name',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.surface)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.length < 2) return;
              setState(() => _userName = newName);
              await _saveSetting('user_name', newName);
              // Sync name to backend
              final headers = await _userRepo.authHeaders();
              // via update-name endpoint
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _manageEmergencyContacts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Emergency Contacts',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: _emergencyContacts.length >= 3
                          ? null
                          : () async {
                              final status =
                                  await Permission.contacts.request();
                              if (status.isGranted &&
                                  await FlutterContacts.requestPermission()) {
                                final contact =
                                    await FlutterContacts.openExternalPick();
                                if (contact != null) {
                                  final full = await FlutterContacts.getContact(
                                      contact.id);
                                  if (full != null && full.phones.isNotEmpty) {
                                    setModal(() {
                                      _emergencyContacts.add({
                                        'name': full.displayName,
                                        'phone': full.phones.first.number,
                                      });
                                    });
                                    setState(() {});
                                    await _saveContacts();
                                  }
                                }
                              }
                            },
                      child: Text(
                        _emergencyContacts.length >= 3 ? 'Max 3' : 'Add',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_emergencyContacts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('No contacts added yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ..._emergencyContacts.map((c) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(c['name'] ?? '',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(c['phone'] ?? '',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.risk),
                          onPressed: () async {
                            setModal(() => _emergencyContacts.remove(c));
                            setState(() {});
                            await _saveContacts();
                          },
                        ),
                      )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyPermissions() async {
    final location = await Permission.location.status;
    final notifications = await Permission.notification.status;
    final contacts = await Permission.contacts.status;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy & Permissions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage how SafePulse accesses your data',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  _buildPermissionToggle(
                    'Location Access',
                    'Required for crash detection & SOS',
                    location.isGranted,
                    (v) async {
                      if (v) {
                        await Permission.location.request();
                        setModalState(() {});
                      } else {
                        openAppSettings();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionToggle(
                    'Notifications',
                    'Alerts for risks and safety updates',
                    notifications.isGranted,
                    (v) async {
                      if (v) {
                        await Permission.notification.request();
                        setModalState(() {});
                      } else {
                        openAppSettings();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionToggle(
                    'Contacts',
                    'Required to add emergency contacts',
                    contacts.isGranted,
                    (v) async {
                      if (v) {
                        await Permission.contacts.request();
                        setModalState(() {});
                      } else {
                        openAppSettings();
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionToggle(
      String title, String subtitle, bool isGranted, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: isGranted,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showHelpCenter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Help Center',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('How can we help you today?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildFaqItem(
                        'How does crash detection work?',
                        'SafePulse uses your phone\'s accelerometer and gyroscope to detect high-G impacts. When an impact is detected, the app starts a countdown. If you don\'t cancel it, an SOS is automatically triggered.'),
                    _buildFaqItem(
                        'Will it drain my battery?',
                        'The background engine is highly optimized for low power consumption. However, active GPS tracking during monitoring may use slightly more battery than usual.'),
                    _buildFaqItem(
                        'How do I add emergency contacts?',
                        'Go to Safety Settings > SOS Emergency Contacts. You can add up to 3 contacts who will receive SMS alerts with your live location during an SOS.'),
                    _buildFaqItem(
                        'What are Circles?',
                        'Circles allow you to share your safety status with friends and family. You can see each other on a map and receive alerts if someone in your circle triggers an SOS.'),
                    _buildFaqItem(
                        'How do I cancel a false alarm?',
                        'If a crash is detected, you have 15 seconds to tap "Cancel" on the countdown screen before alerts are sent.'),
                  ],
                ),
              ),
              const Divider(color: AppColors.surface, height: 32),
              const Text('Need more help?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _showSupportForm();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.email_outlined, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Send us a message',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportForm() {
    final messageController = TextEditingController();
    final subjectController = TextEditingController(text: 'Support Request');
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We\'ll reply to your registered account',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: subjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surface),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surface),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Describe your issue...',
                    alignLabelWithHint: true,
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surface),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.surface),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            final msg = messageController.text.trim();
                            if (msg.length < 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please write at least 10 characters.'),
                                  backgroundColor: AppColors.risk,
                                ),
                              );
                              return;
                            }
                            setModalState(() => isSending = true);
                            final success = await ApiService.sendSupportEmail(
                              name: _userName,
                              phone: _userPhone,
                              loginType: _loginType,
                              subject: subjectController.text.trim(),
                              message: msg,
                            );
                            setModalState(() => isSending = false);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Message sent! We\'ll get back to you soon.'
                                        : 'Failed to send. Please try again.',
                                  ),
                                  backgroundColor: success ? AppColors.primary : AppColors.risk,
                                ),
                              );
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(isSending ? 'Sending...' : 'Send Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(question,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(answer,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMonitoring = engineState == EngineState.monitoring;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile card
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surface),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_userName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          if (_loginType == 'email') ...[
                            Text(_userEmail,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(_userPhone,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ] else ...[
                            Text(_userPhone,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Login: ${_loginType.toUpperCase()}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.primary),
                      onPressed: _editProfile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            _buildSection('Safety Settings', [
              _buildTile(Icons.emergency_outlined, 'SOS Emergency Contacts',
                  '${_emergencyContacts.length}/3 contacts added',
                  onTap: _manageEmergencyContacts),
              _buildSwitch(
                icon: Icons.notification_important_outlined,
                title: 'Crash Detection',
                subtitle: 'Auto alert on high impact',
                value: _crashDetectionEnabled,
                onChanged: (v) async {
                  setState(() => _crashDetectionEnabled = v);
                  _saveSetting('crash_detection', v);

                  final prefs = await SharedPreferences.getInstance();
                  final service = FlutterBackgroundService();

                  if (!v) {
                    await prefs.setBool("isMonitoring", false);
                    service.invoke('stopService');
                    setState(() => engineState = EngineState.idle);
                  } else {
                    await prefs.setBool("isMonitoring", true);
                    if (!await Permission.location.isGranted) {
                      await Permission.location.request();
                    }
                    if (!await Permission.notification.isGranted) {
                      await Permission.notification.request();
                    }
                    if (!(await service.isRunning())) {
                      await service.startService();
                    }
                    setState(() => engineState = EngineState.monitoring);
                  }
                },
              ),
              _buildSwitch(
                icon: Icons.speed_outlined,
                title: 'Speed Alerts',
                subtitle: 'Warn when exceeding 65 km/h',
                value: _speedAlertsEnabled,
                onChanged: (v) {
                  setState(() => _speedAlertsEnabled = v);
                  _saveSetting('speed_alerts', v);
                },
              ),
            ]),
            const SizedBox(height: 24),

            _buildSection('Account', [
              _buildTile(Icons.person_outline, 'Personal Information',
                  'Edit your profile',
                  onTap: _editProfile),
              _buildTile(Icons.privacy_tip_outlined, 'Privacy & Permissions',
                  'Location and data sharing', onTap: _showPrivacyPermissions),
              _buildSwitch(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'App alerts and sounds',
                value: _notificationsEnabled,
                onChanged: (v) {
                  setState(() => _notificationsEnabled = v);
                  _saveSetting('notifications', v);
                },
              ),
            ]),
            const SizedBox(height: 24),

            _buildSection('Support', [
              _buildTile(Icons.help_outline, 'Help Center', 'FAQs and guides', onTap: _showHelpCenter),
              _buildTile(
                  Icons.info_outline, 'About SafePulse', 'Version 2.0.0'),
            ]),
            const SizedBox(height: 40),

            OutlinedButton(
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: AppColors.risk),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Logout',
                  style: TextStyle(
                      color: AppColors.risk, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 10),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surface),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textSecondary, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}
