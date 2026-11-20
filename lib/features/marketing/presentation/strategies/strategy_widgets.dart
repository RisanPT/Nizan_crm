import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';

// The small pieces every Strategies & Developments tab is built from.

/// The colour of an initiative / project status (the document's chips: green On Track, blue In Progress, red At Risk, amber On Hold).
Color workStatusColor(String s) => switch (s) {
      'on_track' => Mkt.good,
      'in_progress' => Mkt.blue,
      'at_risk' => Mkt.bad,
      'on_hold' => Mkt.warn,
      'completed' => Mkt.primary,
      _ => Mkt.grey,
    };

Color planStatusColor(String s) => switch (s) {
      'active' => Mkt.good,
      'in_progress' => Mkt.blue,
      'on_hold' => Mkt.warn,
      'completed' => Mkt.primary,
      _ => Mkt.grey,
    };

Color priorityColor(String p) => switch (p) {
      'high' => Mkt.bad,
      'medium' => Mkt.warn,
      _ => Mkt.good,
    };

Color actionStatusColor(String s) => switch (s) {
      'done' => Mkt.good,
      'in_progress' => Mkt.blue,
      _ => Mkt.grey,
    };

Color outcomeColor(String s) => switch (s) {
      'achieved' => Mkt.good,
      'partial' => Mkt.warn,
      _ => Mkt.bad,
    };

IconData outcomeIcon(String s) => switch (s) {
      'achieved' => Icons.check_circle_rounded,
      'partial' => Icons.timelapse_rounded,
      _ => Icons.cancel_rounded,
    };

IconData findingIcon(String kind) => switch (kind) {
      'report' => Icons.description_outlined,
      'market_insight' => Icons.insights_rounded,
      'competitor' => Icons.compare_arrows_rounded,
      _ => Icons.lightbulb_outline_rounded,
    };

Color findingColor(String kind) => switch (kind) {
      'report' => Mkt.primary,
      'market_insight' => Mkt.blue,
      'competitor' => Mkt.pink,
      _ => Mkt.good,
    };

/// "15 Nov 2026" for a 'YYYY-MM-DD' day; "—" when there is none.
String strategyDay(String? day, {String pattern = 'd MMM yyyy'}) {
  if (day == null || day.isEmpty) return '—';
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat(pattern).format(d);
}

String hoursText(int minutes) => minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}';

/// The first word of a focus area, for a chart's axis ("Brand & Market Positioning" → "Brand").
String shortFocus(String s) {
  final w = s.trim().split(RegExp(r'\s+')).first;
  return w.length > 9 ? '${w.substring(0, 8)}…' : w;
}

class WorkStatusChip extends StatelessWidget {
  const WorkStatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => MktChip(workStatusLabel(status), color: workStatusColor(status));
}

/// An owner: initials and name. A name that was not chosen but worked out from the tasks says so on hover.
class OwnerCell extends StatelessWidget {
  const OwnerCell({super.key, required this.owner});
  final WorkOwner? owner;
  @override
  Widget build(BuildContext context) {
    final o = owner;
    if (o == null || o.name.isEmpty) return Text('—', style: mktText(12, color: Mkt.inkSoft));
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      MktAvatar(o.name, size: 22),
      const SizedBox(width: 6),
      Flexible(child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12))),
    ]);
    return o.source == 'tasks' ? Tooltip(message: 'Worked out from the tasks tied to it', child: row) : row;
  }
}

/// The progress of a piece of work: a bar and a percentage — or "not set" (never a made-up 0%). The note says where it came from.
class WorkProgressCell extends StatelessWidget {
  const WorkProgressCell({super.key, required this.item, this.showNote = true});
  final WorkItem item;
  final bool showNote;
  @override
  Widget build(BuildContext context) {
    if (!item.hasProgress) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Not set', style: mktText(12, color: Mkt.inkSoft)),
        if (showNote) Text(item.progressNote, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft)),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      MktProgress(pct: item.progress, color: item.status == 'at_risk' ? Mkt.bad : (item.status == 'completed' ? Mkt.primary : Mkt.good), labelWidth: 36),
      if (showNote) Text(item.progressNote, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft)),
    ]);
  }
}

InputDecoration strategyDec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

InputDecoration strategySearchDec(String hint) => InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded, size: 18),
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
    );

/// A form opens as a dialog on a wide screen and a bottom sheet on a phone.
Future<T?> showStrategySheet<T>(BuildContext context, Widget form, {double maxWidth = 640}) {
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<T>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: form)));
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom), child: form),
  );
}

/// The footer of every form: the refusal (inline), Cancel and Save (disabled while saving).
class StrategyFormFooter extends StatelessWidget {
  const StrategyFormFooter({super.key, required this.keyPrefix, required this.saving, required this.error, required this.onSave, required this.saveLabel});
  final String keyPrefix, saveLabel;
  final bool saving;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, key: Key('${keyPrefix}_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
          Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
            OutlinedButton(key: Key('${keyPrefix}_cancel'), onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              key: Key('${keyPrefix}_save'),
              style: FilledButton.styleFrom(backgroundColor: Mkt.maroon),
              onPressed: saving ? null : onSave,
              child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(saveLabel),
            ),
          ]),
        ]),
      );
}

/// A day picker pill for an optional date: tap to choose, the × clears it.
class DayPickerField extends StatelessWidget {
  const DayPickerField({super.key, required this.label, required this.value, required this.onChanged, this.firstYearsBack = 3, this.lastYearsAhead = 3});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final int firstYearsBack, lastYearsAhead;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        MktPill(
          label: value == null ? label : '$label: ${DateFormat('d MMM yyyy').format(value!)}',
          icon: Icons.calendar_today_outlined,
          trailing: false,
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: DateTime(now.year - firstYearsBack), lastDate: DateTime(now.year + lastYearsAhead));
            if (d != null) onChanged(d);
          },
        ),
        if (value != null) IconButton(visualDensity: VisualDensity.compact, tooltip: 'Clear', onPressed: () => onChanged(null), icon: const Icon(Icons.close_rounded, size: 16)),
      ]);
}

/// "Showing 1–10 of 24" with the previous / next arrows.
class StrategyPager extends StatelessWidget {
  const StrategyPager({super.key, required this.keyPrefix, required this.page, required this.pageSize, required this.total, required this.shown, required this.onPage});
  final String keyPrefix;
  final int page, pageSize, total, shown;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = (page - 1) * pageSize + shown;
    final pages = (total / pageSize).ceil().clamp(1, 999);
    return Row(children: [
      Flexible(child: Text(total == 0 ? 'Nothing to show' : 'Showing $from–$to of $total', key: Key('${keyPrefix}_showing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft))),
      const Spacer(),
      IconButton(key: Key('${keyPrefix}_prev'), visualDensity: VisualDensity.compact, onPressed: page > 1 ? () => onPage(page - 1) : null, icon: const Icon(Icons.chevron_left_rounded, size: 20)),
      Text('$page / $pages', style: mktText(11.5, weight: FontWeight.w700)),
      IconButton(key: Key('${keyPrefix}_next'), visualDensity: VisualDensity.compact, onPressed: page < pages ? () => onPage(page + 1) : null, icon: const Icon(Icons.chevron_right_rounded, size: 20)),
    ]);
  }
}

/// Asks before something is deleted; true = go ahead.
Future<bool> confirmStrategyDelete(BuildContext context, {required String title, required String body}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(key: const Key('st_delete_cancel'), onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(key: const Key('st_delete_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ),
  );
  return yes == true;
}

/// A manager, or the person the record is given to, may change it (the server checks again).
bool canChangeWork(StrategySetup s, WorkItem w) => s.canManage || (s.meId != null && w.owner != null && w.owner!.source == 'set' && w.owner!.id == s.meId);

/// Who is looking and what the forms can offer. It keeps the last answer while it is read again (so a button does not blink off after
/// every save), and says nothing-special (a plain member with no team list) until the first answer comes.
StrategySetup strategySetupOf(WidgetRef ref) => ref.watch(strategySetupProvider).value ?? const StrategySetup();

/// A form needs the setup (the team, the plans): until the first answer arrives it shows a spinner, and if it cannot be read the form
/// still opens with what it knows (the server decides what may be saved).
Widget withStrategySetup(WidgetRef ref, Widget Function(StrategySetup setup) build) {
  final async = ref.watch(strategySetupProvider);
  if (!async.hasValue && async.isLoading) return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
  return build(async.value ?? const StrategySetup());
}

/// The Strategies log types counted from logs, as chips ("First drafts prepared 2 · Strategy meetings held 1"), or [emptyText].
class StrategyWorkChips extends StatelessWidget {
  const StrategyWorkChips({super.key, required this.work, required this.emptyText, this.showAllTypes = false});
  final StrategyWork work;
  final String emptyText;

  /// List every type (a step nobody logged reads 0) — the Overview's card does.
  final bool showAllTypes;

  @override
  Widget build(BuildContext context) {
    final rows = showAllTypes && work.types.isNotEmpty ? [for (final t in work.types) (metric: t, total: work.of(t))] : work.counts;
    if (rows.isEmpty) return Text(emptyText, key: const Key('strategy_work_empty'), style: mktText(12, color: Mkt.inkSoft));
    return Wrap(key: const Key('strategy_work_chips'), spacing: 6, runSpacing: 6, children: [
      for (final r in rows) MktChip('${r.metric}  ${r.total}', color: r.total > 0 ? Mkt.primaryLight : Mkt.grey),
    ]);
  }
}

