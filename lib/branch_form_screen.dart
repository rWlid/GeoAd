import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branch_status.dart';
import 'otp_screen.dart'; // fakeCode
import 'pick_location_screen.dart';

// Add or edit a branch.
// Fixed: name, phone, address, place on the map and working hours.
// Mobile: name, the driver's phone and a short description.
class BranchFormScreen extends StatefulWidget {
  const BranchFormScreen({super.key, this.branch, this.type = 'fixed'});

  final Map<String, dynamic>? branch; // null = add a new branch
  final String type; // 'fixed' or 'mobile', used when adding

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _db = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _driverPhone = TextEditingController();
  final _address = TextEditingController();

  late final bool _isFixed = (widget.branch?['type'] ?? widget.type) == 'fixed';
  LatLng? _place;
  bool _showPlaceError = false;
  bool _saving = false;

  // Working hours, one entry per day (index 0 = Sunday).
  late final List<bool> _isOpen = List.filled(7, widget.branch == null);
  final _opens = List.filled(7, const TimeOfDay(hour: 9, minute: 0));
  final _closes = List.filled(7, const TimeOfDay(hour: 22, minute: 0));
  // The times shown in the "all days" row.
  TimeOfDay _allOpens = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _allCloses = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    // When editing: fill the fields from the branch.
    final branch = widget.branch;
    if (branch == null) return;
    _name.text = branch['name'] ?? '';
    _phone.text = branch['phone'] ?? '';
    _driverPhone.text = branch['driver_phone'] ?? '';
    _address.text = branch['address'] ?? '';
    if (!_isFixed) return; // a mobile branch has no fixed place or hours
    _place = LatLng(
      (branch['lat'] as num).toDouble(),
      (branch['lng'] as num).toDouble(),
    );
    for (final row in branch['branch_hours']) {
      final day = row['day_of_week'] as int;
      _isOpen[day] = true;
      _opens[day] = parseTime(row['opens_at']);
      _closes[day] = parseTime(row['closes_at']);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _driverPhone.dispose();
    _address.dispose();
    super.dispose();
  }

  // Checks a phone field: 10 digits starting with 05.
  String? phoneError(String? value) {
    return RegExp(r'^05\d{8}$').hasMatch(value!.trim())
        ? null
        : 'الرقم ١٠ أرقام ويبدأ بـ 05';
  }

  // Opens the map picker and keeps the place the owner confirms.
  Future<void> pickPlace() async {
    final place = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => PickLocationScreen(start: _place)),
    );
    if (place == null) return;
    setState(() {
      _place = place;
      _showPlaceError = false;
    });
  }

  // Opens the time picker for one day, or for every open day when day is null.
  Future<void> pickTime(int? day, bool isOpening) async {
    final TimeOfDay current;
    if (day == null) {
      current = isOpening ? _allOpens : _allCloses;
    } else {
      current = isOpening ? _opens[day] : _closes[day];
    }
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;

    // One day, or (for the "all days" row) every open day.
    final days = day == null
        ? [
            for (var d = 0; d < 7; d++)
              if (_isOpen[d]) d,
          ]
        : [day];

    setState(() {
      if (day == null && isOpening) _allOpens = picked;
      if (day == null && !isOpening) _allCloses = picked;
      for (final d in days) {
        if (isOpening) {
          _opens[d] = picked;
        } else {
          _closes[d] = picked;
        }
      }
    });
  }

  // "16:30" for the database.
  String timeText(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Saves the branch. A fixed branch also gets its hours replaced.
  Future<void> saveBranch() async {
    FocusScope.of(context).unfocus();
    final fieldsOk = _formKey.currentState!.validate();
    setState(() => _showPlaceError = _isFixed && _place == null);
    if (!fieldsOk || _showPlaceError) return;

    // A new driver number is confirmed with the code sent to the driver.
    final driverPhone = _driverPhone.text.trim();
    if (!_isFixed && driverPhone != widget.branch?['driver_phone']) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _DriverCodeDialog(phone: driverPhone),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> data = {
        'type': _isFixed ? 'fixed' : 'mobile',
        'name': _name.text.trim(),
        'address': _address.text.trim(),
      };
      if (_isFixed) {
        data['phone'] = _phone.text.trim();
        data['lat'] = _place!.latitude;
        data['lng'] = _place!.longitude;
      } else {
        data['driver_phone'] = driverPhone;
      }

      var id = widget.branch?['id'];
      if (id == null) {
        final row = await _db
            .from('locations')
            .insert(data)
            .select('id')
            .single();
        id = row['id'];
      } else {
        await _db.from('locations').update(data).eq('id', id);
      }

      // Hours: delete the old rows, write the open days.
      if (_isFixed) {
        await _db.from('branch_hours').delete().eq('location_id', id);
        final hours = [
          for (var day = 0; day < 7; day++)
            if (_isOpen[day])
              {
                'location_id': id,
                'day_of_week': day,
                'opens_at': timeText(_opens[day]),
                'closes_at': timeText(_closes[day]),
              },
        ];
        if (hours.isNotEmpty) await _db.from('branch_hours').insert(hours);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ الفرع، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    final String title;
    if (widget.branch != null) {
      title = 'تعديل الفرع';
    } else {
      title = _isFixed ? 'فرع ثابت جديد' : 'فرع متنقل جديد';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'اسم الفرع',
                hintText: _isFixed ? 'مثال: فرع العليا' : 'مثال: عربة القهوة',
                border: const OutlineInputBorder(),
              ),
              maxLength: 40,
              textInputAction: TextInputAction.next,
              validator: (v) => v!.trim().isEmpty ? 'اكتب اسم الفرع' : null,
            ),
            gap,
            TextFormField(
              controller: _isFixed ? _phone : _driverPhone,
              decoration: InputDecoration(
                labelText: _isFixed ? 'رقم جوال الفرع' : 'رقم جوال السائق',
                hintText: '05XXXXXXXX',
                helperText: _isFixed ? null : 'يظهر له الفرع عند دخوله بهذا الرقم. إذا كنت تقوده بنفسك اكتب رقمك',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 10,
              validator: phoneError,
            ),
            gap,
            TextFormField(
              controller: _address,
              decoration: InputDecoration(
                labelText: _isFixed
                    ? 'العنوان أو وصف المكان (اختياري)'
                    : 'وصف قصير (اختياري)',
                hintText: _isFixed
                    ? 'مثال: طريق الملك فهد، بجوار البنك'
                    : 'مثال: قهوة مختصة وحلويات',
                border: const OutlineInputBorder(),
              ),
              maxLength: 120,
              textInputAction: TextInputAction.done,
            ),
            if (_isFixed) ...placeAndHours(),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : saveBranch,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ الفرع'),
            ),
          ],
        ),
      ),
    );
  }

  // The fixed branch's extra parts: place on the map and working hours.
  List<Widget> placeAndHours() {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 24),
      Text('مكان الفرع', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('سنفتح الخريطة على موقعك الحالي لتختار مكان الفرع'),
      const SizedBox(height: 12),
      if (_place != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 160,
            // AbsorbPointer: a preview only, the map does not move.
            child: AbsorbPointer(
              child: GoogleMap(
                key: ValueKey(_place),
                initialCameraPosition: CameraPosition(
                  target: _place!,
                  zoom: 16,
                ),
                markers: {
                  Marker(markerId: const MarkerId('place'), position: _place!),
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        icon: const Icon(Icons.map_outlined),
        label: Text(_place == null ? 'تحديد على الخريطة' : 'تغيير المكان'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _saving ? null : pickPlace,
      ),
      if (_showPlaceError)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'اختر مكان الفرع على الخريطة',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      const SizedBox(height: 24),
      Text('أوقات العمل', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _DayHoursRow(
                label: 'كل الأيام',
                isOpen: true,
                opens: _allOpens,
                closes: _allCloses,
                onPick: (isOpening) => pickTime(null, isOpening),
              ),
              const Divider(height: 24),
              for (var day = 0; day < 7; day++)
                _DayHoursRow(
                  label: dayNames[day],
                  isOpen: _isOpen[day],
                  opens: _opens[day],
                  closes: _closes[day],
                  onPick: (isOpening) => pickTime(day, isOpening),
                  onOpenChanged: (open) => setState(() => _isOpen[day] = open),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

// Asks the owner for the code we "sent" to the driver's phone; the owner
// gets it from the driver. Fake for now: no SMS is sent and the code is
// always fakeCode. Later: send a real SMS here and check it on the server.
class _DriverCodeDialog extends StatefulWidget {
  const _DriverCodeDialog({required this.phone});

  final String phone;

  @override
  State<_DriverCodeDialog> createState() => _DriverCodeDialogState();
}

class _DriverCodeDialogState extends State<_DriverCodeDialog> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  // Closes with true when the code is right, else shows an error.
  void checkCode() {
    if (_code.text.trim() == fakeCode) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _error = 'الرمز غير صحيح');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد رقم السائق'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أرسلنا رمز تحقق إلى ${widget.phone}. اطلبه من السائق واكتبه هنا',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            maxLength: 4,
            onSubmitted: (_) => checkCode(),
            decoration: InputDecoration(
              labelText: 'الرمز',
              helperText: 'للتجربة: $fakeCode',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: checkCode, child: const Text('تأكيد')),
      ],
    );
  }
}

// One line of the hours editor: day name, open/closed switch, from and to.
// Without onOpenChanged there is no switch (used for the "all days" row).
class _DayHoursRow extends StatelessWidget {
  const _DayHoursRow({
    required this.label,
    required this.isOpen,
    required this.opens,
    required this.closes,
    required this.onPick,
    this.onOpenChanged,
  });

  final String label;
  final bool isOpen;
  final TimeOfDay opens;
  final TimeOfDay closes;
  final void Function(bool isOpening) onPick;
  final ValueChanged<bool>? onOpenChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          if (onOpenChanged != null)
            Switch(value: isOpen, onChanged: onOpenChanged),
          const SizedBox(width: 8),
          Expanded(
            child: isOpen
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onPick(true),
                          child: Text(opens.format(context)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('–'),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onPick(false),
                          child: Text(closes.format(context)),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'مغلق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
