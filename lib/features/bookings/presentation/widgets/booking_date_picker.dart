import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/models/blocked_date.dart';
import 'package:nizan_crm/services/blocked_date_service.dart';

/// Date picker for a booking's WORK date: HR-blocked dates (Slot Capacity →
/// Blocked Dates) are greyed out and can't be picked. [initialDate] always
/// stays pickable, so a booking already on a day that was blocked later can
/// still be opened and kept. The server refuses blocked dates too
/// (bookingController create/update), this just stops them being chosen.
Future<DateTime?> showWorkDatePicker(
  BuildContext context,
  WidgetRef ref, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  List<BlockedDate> blocked;
  try {
    blocked = await ref.read(blockedDatesProvider.future);
  } catch (_) {
    blocked = const []; // the server still checks on save
  }
  if (!context.mounted) return null;

  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  final blockedDays = {
    for (final b in blocked)
      if (b.active) key(b.date),
  };
  final initialKey = key(initialDate);

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: blockedDays.isEmpty ? null : 'SELECT DATE · BLOCKED DATES ARE GREYED OUT',
    selectableDayPredicate: blockedDays.isEmpty
        ? null
        : (d) => key(d) == initialKey || !blockedDays.contains(key(d)),
  );
}
