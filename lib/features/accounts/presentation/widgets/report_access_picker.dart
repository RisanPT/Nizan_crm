import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/services/user_service.dart';
import 'package:nizan_crm/core/error/errors.dart';

/// Shows a dialog to choose which users may view a report. Returns the selected
/// user ids, or null if cancelled. The owner is never listed (they always have
/// access); admins can always view regardless of this list.
Future<List<String>?> showReportAccessPicker(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> initial,
  String? ownerId,
  String title = 'Who can view this report',
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _ReportAccessPicker(
      initial: initial,
      ownerId: ownerId,
      title: title,
    ),
  );
}

class _ReportAccessPicker extends ConsumerStatefulWidget {
  const _ReportAccessPicker({
    required this.initial,
    required this.ownerId,
    required this.title,
  });
  final Set<String> initial;
  final String? ownerId;
  final String title;

  @override
  ConsumerState<_ReportAccessPicker> createState() => _ReportAccessPickerState();
}

class _ReportAccessPickerState extends ConsumerState<_ReportAccessPicker> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final usersAsync = ref.watch(crmUsersProvider);

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_person_outlined, color: crm.primary, size: 20),
                8.w,
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                ),
              ],
            ),
            4.h,
            Text(
              'Only you (the uploader) and the people you tick can open this file. Admins can always view it.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
            12.h,
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Search people…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            12.h,
            Flexible(
              child: usersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AppErrorView(
                  error: e,
                  compact: true,
                  onRetry: () => ref.invalidate(crmUsersProvider),
                ),
                data: (users) {
                  final people = users
                      .where((u) => u.id != widget.ownerId)
                      .where((u) =>
                          _query.isEmpty ||
                          u.name.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query) ||
                          u.role.toLowerCase().contains(_query))
                      .toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  if (people.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No matching users',
                          style: TextStyle(color: crm.textSecondary)),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final u = people[i];
                      final checked = _selected.contains(u.id);
                      return CheckboxListTile(
                        value: checked,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: crm.primary,
                        title: Text(u.name,
                            style: TextStyle(
                                fontSize: 14, color: crm.textPrimary)),
                        subtitle: Text(
                          '${u.role}${u.email.isNotEmpty ? ' · ${u.email}' : ''}',
                          style: TextStyle(
                              fontSize: 11.5, color: crm.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(u.id);
                          } else {
                            _selected.remove(u.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            12.h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_selected.length} selected',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    8.w,
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _selected.toList()),
                      style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
