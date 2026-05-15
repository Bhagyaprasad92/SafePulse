// NEW FILE
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class AddMembersSheet extends StatefulWidget {
  final List<Contact> contacts;
  final String inviteCode;
  const AddMembersSheet({super.key, required this.contacts, required this.inviteCode});

  @override
  State<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<AddMembersSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Contact> _filtered = [];
  final Set<String> _invitedNumbers = {};

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.contacts
          : widget.contacts
              .where((c) =>
                  c.displayName.toLowerCase().contains(q) ||
                  c.phones.any((p) => p.number.contains(q)))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite(Contact contact) async {
    final phone = contact.phones.first.number;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final waNumber = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

    final firstName = contact.displayName.split(' ').first;
    final message = Uri.encodeComponent(
      'Hey $firstName! 👋\n\n'
      'I\'m using SafePulse to stay connected with family & friends.\n\n'
      'Join my SafePulse circle using this invite code: *${widget.inviteCode}*'
    );

    final uri = Uri.parse('https://wa.me/$waNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _invitedNumbers.add(cleaned));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.87,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text("Add Members", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(widget.inviteCode, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              fillColor: AppColors.cardBg,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final c = _filtered[i];
              final phone = c.phones.first.number;
              final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
              final isInvited = _invitedNumbers.contains(cleaned);
              return ListTile(
                leading: CircleAvatar(child: Text(c.displayName[0])),
                title: Text(c.displayName, style: const TextStyle(color: Colors.white)),
                subtitle: Text(phone, style: const TextStyle(color: AppColors.textSecondary)),
                trailing: ElevatedButton(
                  onPressed: isInvited ? null : () => _invite(c),
                  child: Text(isInvited ? 'Sent' : 'Invite'),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
