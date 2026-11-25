import 'package:flutter/material.dart';

// Day names in database order: day_of_week 0 = Sunday … 6 = Saturday.
const dayNames = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

// Turns a database time like "16:00:00" into a TimeOfDay.
TimeOfDay parseTime(String text) {
  return TimeOfDay(
    hour: int.parse(text.substring(0, 2)),
    minute: int.parse(text.substring(3, 5)),
  );
}

// True when a branch with these branch_hours rows is open right now.
bool isOpenNow(List hours) {
  final now = DateTime.now();
  final today = now.weekday % 7; // Dart: Monday = 1 … Sunday = 7 → Sunday = 0
  final yesterday = (today + 6) % 7;
  final nowMinutes = now.hour * 60 + now.minute;

  for (final row in hours) {
    final opens = _minutes(row['opens_at']);
    final closes = _minutes(row['closes_at']);
    final closesAfterMidnight = closes <= opens; // e.g. 16:00 → 01:00
    final day = row['day_of_week'];

    if (day == today &&
        nowMinutes >= opens &&
        (closesAfterMidnight || nowMinutes < closes)) {
      return true;
    }
    // After midnight, yesterday's late shift may still be running.
    if (day == yesterday && closesAfterMidnight && nowMinutes < closes) {
      return true;
    }
  }
  return false;
}

// Minutes since midnight for a database time: "16:30:00" → 990.
int _minutes(String text) {
  final time = parseTime(text);
  return time.hour * 60 + time.minute;
}

// True when a mobile branch is sharing and sent its position in the last
// 10 minutes. Older than that (e.g. the app was closed) = hidden.
bool isVisibleNow(Map branch) {
  if (branch['is_sharing'] != true || branch['shared_at'] == null) return false;
  final sharedAt = DateTime.parse(branch['shared_at']);
  return DateTime.now().difference(sharedAt) < const Duration(minutes: 10);
}

// A small colored dot with a status text, e.g. "● مفتوح الآن".
class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key, required this.isActive, required this.text});

  final bool isActive; // colored dot when true, grey when false
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 8,
          color: isActive ? colors.primary : colors.outline,
        ),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}
