import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'my_position.dart';

// "فرعي المتنقل" in حسابي: the mobile branches assigned to my phone number,
// each with a "مشاركة الموقع" switch. While sharing, my position is sent
// every 30 seconds as long as the app is open. Shows nothing for people
// who drive no branch.
class DriverCard extends StatefulWidget {
  const DriverCard({super.key, required this.phone});

  final String phone; // my phone number, matched with driver_phone

  @override
  State<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<DriverCard> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _branches = [];
  bool _loadFailed = false;
  bool _sendFailed = false; // the last position update did not go through
  bool _saving = false; // a switch change is being saved
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadBranches();
    // Does nothing while no branch is sharing.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => sendPosition());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Loads the mobile branches I drive.
  Future<void> loadBranches() async {
    try {
      final rows = await _db
          .from('locations')
          .select('id, name, is_sharing, shared_at')
          .eq('type', 'mobile')
          .eq('driver_phone', widget.phone)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _branches = rows;
        _loadFailed = false;
      });
      sendPosition(); // sharing left on last time continues right away
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  // Saves my position (or none) and the sharing state for one branch.
  Future<void> shareLocation(
    Map<String, dynamic> branch,
    Position? position,
    bool sharing,
  ) async {
    await _db.rpc(
      'share_location',
      params: {
        'branch_id': branch['id'],
        'new_lat': position?.latitude,
        'new_lng': position?.longitude,
        'sharing': sharing,
      },
    );
    branch['shared_at'] = DateTime.now().toIso8601String();
  }

  // Sends my current position for every branch that is sharing.
  Future<void> sendPosition() async {
    final sharing = [
      for (final branch in _branches)
        if (branch['is_sharing'] == true) branch,
    ];
    if (sharing.isEmpty) return;

    final position = await getMyPosition();
    var ok = position != null;
    if (ok) {
      try {
        for (final branch in sharing) {
          await shareLocation(branch, position, true);
        }
      } catch (_) {
        ok = false;
      }
    }
    if (!mounted) return;
    setState(() => _sendFailed = !ok);
  }

  // Turns sharing on or off. The switch moves at once and moves back
  // if we cannot get the position or save the change.
  Future<void> toggleSharing(Map<String, dynamic> branch, bool on) async {
    setState(() {
      branch['is_sharing'] = on;
      _saving = true;
    });

    Position? position;
    if (on) position = await getMyPosition();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (on && position == null) {
      setState(() {
        branch['is_sharing'] = false;
        _saving = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('اسمح للتطبيق بالوصول لموقعك حتى يراك العملاء'),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: Geolocator.openAppSettings,
          ),
        ),
      );
      return;
    }

    try {
      await shareLocation(branch, position, on);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _sendFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        branch['is_sharing'] = !on;
        _saving = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ التغيير، تحقق من الاتصال')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off),
          title: const Text('تعذّر تحميل فرعك المتنقل'),
          trailing: TextButton(
            onPressed: loadBranches,
            child: const Text('إعادة المحاولة'),
          ),
        ),
      );
    }
    if (_branches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            'فرعي المتنقل',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final branch in _branches)
          _ShareCard(
            branch: branch,
            sendFailed: _sendFailed,
            onChanged: _saving ? null : (on) => toggleSharing(branch, on),
          ),
      ],
    );
  }
}

// One mobile branch: name, the big share switch, and a status line that
// always tells the driver whether customers can see them.
class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.branch,
    required this.sendFailed,
    required this.onChanged,
  });

  final Map<String, dynamic> branch;
  final bool sendFailed;
  final ValueChanged<bool>? onChanged; // null while saving

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSharing = branch['is_sharing'] == true;

    final Color dotColor;
    final String status;
    if (!isSharing) {
      dotColor = colors.outline;
      status = 'موقعك مخفي عن العملاء';
    } else if (sendFailed) {
      dotColor = colors.error;
      status = 'تعذّر تحديث موقعك، سنحاول مرة أخرى';
    } else {
      final sharedAt = branch['shared_at'] == null
          ? DateTime.now()
          : DateTime.parse(branch['shared_at']).toLocal();
      dotColor = colors.primary;
      status =
          'موقعك ظاهر للعملاء · آخر تحديث ${TimeOfDay.fromDateTime(sharedAt).format(context)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
              title: Text(
                branch['name'] ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SwitchListTile(
              title: const Text('مشاركة الموقع'),
              subtitle: const Text(
                'يظهر موقع جوالك للعملاء على الخريطة أثناء فتح التطبيق',
              ),
              value: isSharing,
              onChanged: onChanged,
            ),
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(status),
                  children: [
                    Icon(Icons.circle, size: 12, color: dotColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
