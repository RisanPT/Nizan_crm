import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/marketing/data/content_item.dart';
import 'package:nizan_crm/features/marketing/services/content_service.dart';

// ── Platform styling (shared with the dashboard) ─────────────────────────────
Color platformColor(String p) => switch (p) {
      'instagram' => const Color(0xFFC13584),
      'youtube' => const Color(0xFFD32F2F),
      'facebook' => const Color(0xFF1877F2),
      'whatsapp' => const Color(0xFF25D366),
      'website' => const Color(0xFF00897B),
      _ => Colors.blueGrey,
    };

IconData platformIcon(String p) => switch (p) {
      'instagram' => Icons.camera_alt_outlined,
      'youtube' => Icons.play_circle_outline,
      'facebook' => Icons.facebook_outlined,
      'whatsapp' => Icons.chat_outlined,
      'website' => Icons.language_outlined,
      _ => Icons.public,
    };

Color contentStatusColor(String s) => switch (s) {
      'published' => const Color(0xFF2E8B57),
      'scheduled' => Colors.blue.shade600,
      'in-progress' => Colors.orange.shade700,
      'planned' => Colors.indigo.shade400,
      'cancelled' => Colors.red.shade400,
      _ => Colors.grey, // idea
    };

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ContentCalendarScreen extends HookConsumerWidget {
  const ContentCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final now = DateTime.now();
    final monthFocus = useState<DateTime>(DateTime(now.year, now.month, 1));
    final rangeKey = monthGridRange(monthFocus.value);
    final async = ref.watch(contentByMonthProvider(rangeKey));
    final isMobile = MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.mobile;

    void refresh() => ref.invalidate(contentByMonthProvider);

    void goMonth(int delta) {
      monthFocus.value =
          DateTime(monthFocus.value.year, monthFocus.value.month + delta, 1);
    }

    Future<void> pickMonth() async {
      final picked = await showMonthPicker(context, initial: monthFocus.value);
      if (picked != null) monthFocus.value = DateTime(picked.year, picked.month, 1);
    }

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showContentEditor(context, ref, initialDate: now);
          if (ok == true) { refresh(); ref.invalidate(contentStatsProvider); }
        },
        backgroundColor: crm.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Content'),
      ),
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.event_note_outlined, color: crm.primary),
            const SizedBox(width: 10),
            if (!isMobile)
              Text('Content Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const Spacer(),
            IconButton(onPressed: () => goMonth(-1), icon: const Icon(Icons.chevron_left)),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: pickMonth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  Text('${_months[monthFocus.value.month - 1]} ${monthFocus.value.year}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: crm.textSecondary),
                ]),
              ),
            ),
            IconButton(onPressed: () => goMonth(1), icon: const Icon(Icons.chevron_right)),
            TextButton(
              onPressed: () => monthFocus.value = DateTime(now.year, now.month, 1),
              child: const Text('Today'),
            ),
            IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
            data: (items) => _monthGrid(context, ref, crm, monthFocus.value, now, items, isMobile, refresh),
          ),
        ),
      ]),
    );
  }

  Widget _monthGrid(BuildContext context, WidgetRef ref, CrmTheme crm, DateTime month,
      DateTime now, List<ContentItem> items, bool isMobile, VoidCallback refresh) {
    // Bucket items by local day.
    final byDay = <String, List<ContentItem>>{};
    for (final it in items) {
      byDay.putIfAbsent(_dayKey(it.scheduledDate), () => []).add(it);
    }

    final monthStart = DateTime(month.year, month.month, 1);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday % 7));
    final days = List.generate(42, (i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i));
    const weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(isMobile ? 14 : 24),
          border: Border.all(color: crm.border),
        ),
        child: Column(children: [
          Row(
            children: weekdayLabels
                .map((l) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 16),
                        child: Text(l, textAlign: TextAlign.center,
                            style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w700, letterSpacing: .6, fontSize: isMobile ? 11 : 13)),
                      ),
                    ))
                .toList(),
          ),
          Divider(height: 1, color: crm.border),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: isMobile ? 0.72 : 1.05,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == month.month;
              final isToday = _sameDay(day, now);
              final dayItems = inMonth ? (byDay[_dayKey(day)] ?? const <ContentItem>[]) : const <ContentItem>[];
              final maxPills = isMobile ? 2 : 3;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: crm.border),
                    bottom: BorderSide(color: crm.border),
                  ),
                  color: inMonth ? crm.surface : crm.background.withValues(alpha: 0.5),
                ),
                child: !inMonth
                    ? const SizedBox.shrink()
                    : InkWell(
                        onTap: () async {
                          await _showDaySheet(context, ref, crm, day, dayItems, refresh);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: isMobile ? 26 : 34,
                                height: isMobile ? 26 : 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isToday ? crm.primary : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text('${day.day}',
                                    style: TextStyle(fontSize: isMobile ? 12 : 15, fontWeight: FontWeight.w700,
                                        color: isToday ? Colors.white : crm.textPrimary)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...dayItems.take(maxPills).map((it) => _pill(crm, it, isMobile)),
                            if (dayItems.length > maxPills)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('+${dayItems.length - maxPills} more',
                                    style: TextStyle(fontSize: isMobile ? 8.5 : 10, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                          ]),
                        ),
                      ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _pill(CrmTheme crm, ContentItem it, bool isMobile) {
    final c = platformColor(it.platform);
    final published = it.status == 'published';
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6, vertical: isMobile ? 2 : 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Row(children: [
        Icon(published ? Icons.check_circle : platformIcon(it.platform), size: isMobile ? 9 : 11, color: c),
        const SizedBox(width: 3),
        Expanded(
          child: Text(it.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: isMobile ? 8.5 : 10.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
        ),
      ]),
    );
  }

  Future<void> _showDaySheet(BuildContext context, WidgetRef ref, CrmTheme crm,
      DateTime day, List<ContentItem> items, VoidCallback refresh) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: crm.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_note_outlined, color: crm.primary),
            const SizedBox(width: 8),
            Text('${_months[day.month - 1]} ${day.day}, ${day.year}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${items.length} item${items.length == 1 ? '' : 's'}', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No content planned for this day.', style: TextStyle(color: crm.textSecondary)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: SingleChildScrollView(
                child: Column(children: [for (final it in items) _dayItemTile(context, ctx, ref, crm, it, refresh)]),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await showContentEditor(context, ref, initialDate: day);
                if (ok == true) { refresh(); ref.invalidate(contentStatsProvider); }
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add content on ${_months[day.month - 1]} ${day.day}'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dayItemTile(BuildContext screenCtx, BuildContext sheetCtx, WidgetRef ref, CrmTheme crm, ContentItem it, VoidCallback refresh) {
    final c = platformColor(it.platform);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: crm.border)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(platformIcon(it.platform), color: c, size: 20)),
        title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${platformLabel(it.platform)} · ${contentTypeLabel(it.contentType)}'
            '${it.assignedToName.isEmpty ? '' : ' · ${it.assignedToName}'}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: contentStatusColor(it.status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
          child: Text(contentStatusLabel(it.status), style: TextStyle(color: contentStatusColor(it.status), fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
        onTap: () async {
          Navigator.pop(sheetCtx);
          final ok = await showContentEditor(screenCtx, ref, existing: it);
          if (ok == true) { refresh(); ref.invalidate(contentStatsProvider); }
        },
      ),
    );
  }
}

// Overload-friendly wrapper so both positional-context and named calls work.
Future<bool?> showContentEditor(
  BuildContext context,
  WidgetRef ref, {
  ContentItem? existing,
  DateTime? initialDate,
}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final desc = TextEditingController(text: existing?.description ?? '');
  final caption = TextEditingController(text: existing?.caption ?? '');
  final hashtags = TextEditingController(text: existing?.hashtags.join(', ') ?? '');
  final campaign = TextEditingController(text: existing?.campaign ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  String platform = existing?.platform ?? 'instagram';
  String contentType = existing?.contentType ?? 'reel';
  String status = existing?.status ?? 'idea';
  DateTime scheduled = existing?.scheduledDate ?? initialDate ?? DateTime.now();
  String? assigneeId = (existing?.assignedToId.isEmpty ?? true) ? null : existing!.assignedToId;
  final messenger = ScaffoldMessenger.of(context);
  final isEdit = existing != null;

  final employees = (ref.read(employeesProvider).value ?? const <Employee>[])
      .where((e) => e.status.toLowerCase() == 'active')
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var busy = false;
      final crm = ctx.crmColors;
      return StatefulBuilder(builder: (ctx, setSheet) {
        Widget dd(String label, String value, List<String> opts, String Function(String) fmt, ValueChanged<String> onCh) =>
            DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label, isDense: true),
              items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(fmt(o)))],
              onChanged: (v) => onCh(v ?? value),
            );

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.post_add_outlined, color: crm.primary),
                const SizedBox(width: 8),
                Text(isEdit ? 'Edit content' : 'New content', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (isEdit)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: busy ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: const Text('Delete this content?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        await ref.read(contentServiceProvider).deleteItem(existing.id);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(controller: title, textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Bridal transformation reel')),
              const SizedBox(height: 10),
              TextField(controller: desc, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Brief / idea', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: dd('Platform', platform, contentPlatforms, platformLabel, (v) => setSheet(() => platform = v))),
                const SizedBox(width: 10),
                Expanded(child: dd('Type', contentType, contentTypes, contentTypeLabel, (v) => setSheet(() => contentType = v))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: dd('Status', status, contentStatuses, contentStatusLabel, (v) => setSheet(() => status = v))),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: scheduled,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035, 12, 31),
                      );
                      if (picked != null) setSheet(() => scheduled = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Scheduled date *', isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
                      child: Text('${scheduled.day}/${scheduled.month}/${scheduled.year}'),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              EmployeePickerField(
                employees: employees,
                selectedId: assigneeId,
                selectedName: existing?.assignedToName,
                label: 'Assign to',
                onChanged: (e) => setSheet(() => assigneeId = e?.id),
              ),
              const SizedBox(height: 10),
              TextField(controller: campaign, decoration: const InputDecoration(labelText: 'Campaign (optional)')),
              const SizedBox(height: 10),
              TextField(controller: caption, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Caption', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              TextField(controller: hashtags, decoration: const InputDecoration(labelText: 'Hashtags', hintText: '#bridal, #makeup, #teamn')),
              const SizedBox(height: 10),
              TextField(controller: notes, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : () async {
                    if (title.text.trim().isEmpty) {
                      messenger.showSnackBar(const SnackBar(content: Text('Please enter a title')));
                      return;
                    }
                    setSheet(() => busy = true);
                    final assigneeName = assigneeId == null
                        ? ''
                        : employees.firstWhere((e) => e.id == assigneeId, orElse: () => employees.first).name;
                    final body = {
                      'title': title.text.trim(),
                      'description': desc.text.trim(),
                      'platform': platform,
                      'contentType': contentType,
                      'status': status,
                      'scheduledDate': DateTime(scheduled.year, scheduled.month, scheduled.day, 12).toIso8601String(),
                      'assignedTo': assigneeId,
                      'assignedToName': assigneeName,
                      'campaign': campaign.text.trim(),
                      'caption': caption.text,
                      'hashtags': hashtags.text.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty).toList(),
                      'notes': notes.text,
                    };
                    try {
                      final svc = ref.read(contentServiceProvider);
                      if (isEdit) {
                        await svc.updateItem(existing.id, body);
                      } else {
                        await svc.createItem(body);
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                    }
                  },
                  child: Text(busy ? 'Saving…' : (isEdit ? 'Save changes' : 'Add content')),
                ),
              ),
            ]),
          ),
        );
      });
    },
  );
  return result;
}
