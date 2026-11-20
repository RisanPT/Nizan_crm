import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/marketing/data/content_item.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/content_service.dart';

// ── Platform styling (shared with the dashboard) ─────────────────────────────
Color platformColor(String p) => switch (p) {
      'instagram' => Mkt.pink,
      'youtube' => Mkt.bad,
      'facebook' => Mkt.blue,
      'whatsapp' => Mkt.good,
      'website' => Mkt.teal,
      _ => Mkt.grey,
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
      'published' => Mkt.good,
      'scheduled' => Mkt.blue,
      'in-progress' => Mkt.warn,
      'planned' => Mkt.primaryLight,
      'cancelled' => Mkt.bad,
      _ => Mkt.grey, // idea
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

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: MktHeader(
              icon: Icons.event_note_outlined,
              title: 'Content Calendar',
              subtitle: 'Plan posts, reels and stories by day',
              actions: [
                _NavIcon(icon: Icons.chevron_left, tooltip: 'Previous month', onTap: () => goMonth(-1)),
                MktPill(label: '${_months[monthFocus.value.month - 1]} ${monthFocus.value.year}', onTap: pickMonth),
                _NavIcon(icon: Icons.chevron_right, tooltip: 'Next month', onTap: () => goMonth(1)),
                MktPill(label: 'Today', trailing: false, onTap: () => monthFocus.value = DateTime(now.year, now.month, 1)),
                MktPill(label: 'Refresh', icon: Icons.refresh, trailing: false, onTap: refresh),
                MktPrimaryButton(
                  label: 'Add Content',
                  onPressed: () async {
                    final ok = await showContentEditor(context, ref, initialDate: now);
                    if (ok == true) refresh(); // the editor already refreshed content + stats
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e, onRetry: refresh),
              data: (items) => _monthGrid(context, ref, monthFocus.value, now, items, isMobile, refresh),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _monthGrid(BuildContext context, WidgetRef ref, DateTime month,
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Mkt.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Mkt.border),
        ),
        child: Column(children: [
          Row(
            children: weekdayLabels
                .map((l) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 14),
                        child: Text(l, textAlign: TextAlign.center,
                            style: mktText(isMobile ? 11 : 12, weight: FontWeight.w700, color: Mkt.inkSoft, spacing: .6)),
                      ),
                    ))
                .toList(),
          ),
          const Divider(height: 1, color: Mkt.border),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: isMobile ? 0.5 : 1.05,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == month.month;
              final isToday = _sameDay(day, now);
              final dayItems = inMonth ? (byDay[_dayKey(day)] ?? const <ContentItem>[]) : const <ContentItem>[];
              final maxPills = isMobile ? 2 : 3;

              return Container(
                decoration: BoxDecoration(
                  border: const Border(
                    right: BorderSide(color: Mkt.border),
                    bottom: BorderSide(color: Mkt.border),
                  ),
                  color: inMonth ? Mkt.card : Mkt.bg,
                ),
                child: !inMonth
                    ? const SizedBox.shrink()
                    : InkWell(
                        onTap: () async {
                          await _showDaySheet(context, ref, day, dayItems, refresh);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: isMobile ? 26 : 30,
                                height: isMobile ? 26 : 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isToday ? Mkt.primary : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text('${day.day}',
                                    style: mktText(isMobile ? 12 : 13.5, weight: FontWeight.w700,
                                        color: isToday ? Colors.white : Mkt.ink)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...dayItems.take(maxPills).map((it) => _pill(it, isMobile)),
                            if (dayItems.length > maxPills)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('+${dayItems.length - maxPills} more',
                                    style: mktText(isMobile ? 8.5 : 10, weight: FontWeight.w600, color: Mkt.inkSoft)),
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

  Widget _pill(ContentItem it, bool isMobile) {
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
              style: mktText(isMobile ? 8.5 : 10.5, weight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Future<void> _showDaySheet(BuildContext context, WidgetRef ref,
      DateTime day, List<ContentItem> items, VoidCallback refresh) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Mkt.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_note_outlined, color: Mkt.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${_months[day.month - 1]} ${day.day}, ${day.year}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(17, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Text('${items.length} item${items.length == 1 ? '' : 's'}', style: mktText(13, color: Mkt.inkSoft)),
          ]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const MktEmpty('No content planned for this day.', icon: Icons.event_note_outlined, height: 80)
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: SingleChildScrollView(
                child: Column(children: [for (final it in items) _dayItemTile(context, ctx, ref, it, refresh)]),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: MktPrimaryButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await showContentEditor(context, ref, initialDate: day);
                if (ok == true) refresh(); // the editor already refreshed content + stats
              },
              label: 'Add content on ${_months[day.month - 1]} ${day.day}',
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dayItemTile(BuildContext screenCtx, BuildContext sheetCtx, WidgetRef ref, ContentItem it, VoidCallback refresh) {
    final c = platformColor(it.platform);
    return Card(
      elevation: 0,
      color: Mkt.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Mkt.border)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(platformIcon(it.platform), color: c, size: 20)),
        title: Text(it.title, style: mktText(14, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${platformLabel(it.platform)} · ${contentTypeLabel(it.contentType)}'
            '${it.assignedToName.isEmpty ? '' : ' · ${it.assignedToName}'}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, color: Mkt.inkSoft)),
        trailing: MktChip(contentStatusLabel(it.status), color: contentStatusColor(it.status)),
        onTap: () async {
          Navigator.pop(sheetCtx);
          final ok = await showContentEditor(screenCtx, ref, existing: it);
          if (ok == true) refresh(); // the editor already refreshed content + stats
        },
      ),
    );
  }
}

/// A small square icon button for the header (month back / forward).
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Mkt.card,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: Mkt.border)),
              child: Icon(icon, size: 20, color: Mkt.ink),
            ),
          ),
        ),
      );
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
                const Icon(Icons.post_add_outlined, color: Mkt.primary),
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
                        ref.refreshData.content();
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: Mkt.bad),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: Mkt.maroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
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
                      ref.refreshData.content();
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
