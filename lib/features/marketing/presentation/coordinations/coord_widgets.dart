import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// The small pieces every Coordinations tab is built from: colours for statuses, day and money formatting, the header filters (date range,
// Departments, brand), a debounced search box, the form shell (a dialog on a laptop, a sheet on a phone) and the CSV export.

// ── colours ───────────────────────────────────────────────────────────────────

Color requestStatusColor(String s) => switch (s) {
      'completed' => Mkt.good,
      'in_progress' => Mkt.good,
      'open' => Mkt.primaryLight,
      'waiting_input' => Mkt.warn,
      'in_review' => Mkt.blue,
      'pending_approval' => Mkt.warn,
      'cancelled' => Mkt.grey,
      _ => Mkt.grey,
    };

Color priorityColor(String p) => switch (p) {
      'high' => Mkt.bad,
      'medium' => Mkt.warn,
      _ => Mkt.blue,
    };

Color approvalStatusColor(String s) => switch (s) {
      'approved' => Mkt.good,
      'rejected' => Mkt.bad,
      'in_review' => Mkt.primaryLight,
      'escalated' => Mkt.bad,
      _ => Mkt.warn,
    };

Color meetingStateColor(String s) => switch (s) {
      'live' => Mkt.good,
      'completed' => Mkt.blue,
      'to_close' => Mkt.warn,
      'cancelled' => Mkt.grey,
      _ => Mkt.good,
    };

Color followUpStateColor(String s) => switch (s) {
      'overdue' => Mkt.bad,
      'due_today' => Mkt.warn,
      'completed' => Mkt.good,
      _ => Mkt.blue,
    };

Color toneColor(String tone) => switch (tone) {
      'good' => Mkt.good,
      'bad' => Mkt.bad,
      'warn' => Mkt.warn,
      _ => Mkt.blue,
    };

/// A team gets the same tint everywhere (the position in the fixed list).
Color deptColor(String dept) {
  final i = kCoordDepartments.indexOf(dept);
  return Mkt.series(i < 0 ? kCoordDepartments.length : i);
}

// ── formatting ────────────────────────────────────────────────────────────────

String _day(DateTime d) => TeamFilter.day(d);
String todayDay([DateTime? now]) => _day(now ?? DateTime.now());

/// "10 Nov 2026" for a 'YYYY-MM-DD' day (the text itself when it is not one).
String coordDay(String? day, {String pattern = 'd MMM yyyy'}) {
  if (day == null || day.isEmpty) return '—';
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat(pattern).format(d);
}

/// A due day for a table: "Today", else "10 Nov 2026"; nothing is "—".
String dueLabel(String? day, {DateTime? now}) => day == null || day.isEmpty ? '—' : (day == todayDay(now) ? 'Today' : coordDay(day));

/// "Today, 11:00 – 12:00" / "Tomorrow …" / "5 Nov, 3:00 PM" style day label for a meeting row.
String meetingWhen(String day, String time, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = DateTime.tryParse(day);
  if (d == null) return time;
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  final label = diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : DateFormat('d MMM').format(d));
  return time.isEmpty ? label : '$label, $time';
}

/// "32 mins ago" for a moment.
String coordAgo(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
  return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
}

/// ₹20,000 — whole rupees unless there are paise.
String inr(num amount) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: whole ? 0 : 2).format(amount);
}

String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The IST wall time on [day] as the instant the server stores (IST is UTC+5:30).
String istInstant(DateTime day, TimeOfDay t) => DateTime.utc(day.year, day.month, day.day, t.hour, t.minute).subtract(const Duration(hours: 5, minutes: 30)).toIso8601String();

/// What the person wrote, with the team's own wording for an unknown value.
String orDash(String s) => s.trim().isEmpty ? '—' : s;

// ── small widgets ─────────────────────────────────────────────────────────────

class DeptChip extends StatelessWidget {
  const DeptChip(this.dept, {super.key});
  final String dept;
  @override
  Widget build(BuildContext context) => MktChip(dept, color: deptColor(dept));
}

/// "Marketing → Production" in two short lines of text that never overflow.
class FromTo extends StatelessWidget {
  const FromTo(this.from, this.to, {super.key});
  final String from, to;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: FontWeight.w700, color: deptColor(from)))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 11, color: Mkt.inkSoft)),
        Flexible(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: FontWeight.w700, color: deptColor(to)))),
      ]);
}

class PersonCell extends StatelessWidget {
  const PersonCell(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => name.isEmpty
      ? Text('—', style: mktText(12, color: Mkt.inkSoft))
      : Row(children: [MktAvatar(name, size: 24), const SizedBox(width: 6), Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600)))]);
}

/// A day in a table: red "Today" / overdue, otherwise quiet.
class DueText extends StatelessWidget {
  const DueText(this.day, {super.key, this.overdue = false});
  final String? day;
  final bool overdue;
  @override
  Widget build(BuildContext context) {
    final label = dueLabel(day);
    final hot = overdue || label == 'Today';
    return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: hot ? FontWeight.w800 : FontWeight.w500, color: hot ? Mkt.bad : Mkt.ink));
  }
}

/// The rounded white toolbar field the lists search with: waits for a pause in typing before it asks the server.
class CoordSearchField extends StatefulWidget {
  const CoordSearchField({super.key, required this.fieldKey, required this.initial, required this.hint, required this.onChanged});
  final Key fieldKey;
  final String initial, hint;
  final ValueChanged<String> onChanged;

  @override
  State<CoordSearchField> createState() => _CoordSearchFieldState();
}

class _CoordSearchFieldState extends State<CoordSearchField> {
  late final _c = TextEditingController(text: widget.initial);
  Timer? _wait;

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: widget.fieldKey,
        controller: _c,
        onChanged: (v) {
          _wait?.cancel();
          _wait = Timer(const Duration(milliseconds: 300), () => widget.onChanged(v));
        },
        style: mktText(13),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          hintText: widget.hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
        ),
      );
}

/// "Showing 1–10 of 68" with previous / next.
class CoordPager extends StatelessWidget {
  const CoordPager({super.key, required this.keyPrefix, required this.total, required this.page, required this.pageSize, required this.shown, required this.onPage});
  final String keyPrefix;
  final int total, page, pageSize, shown;
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

/// One count box of a strip that also filters the list below it when tapped.
Widget coordKpi({required String keyName, required IconData icon, required String value, required String label, Color tint = Mkt.primary, String? note, bool? good, VoidCallback? onTap}) =>
    MktKpiCard(key: Key(keyName), icon: icon, value: value, label: label, tint: tint, note: note, good: good, onTap: onTap);

/// "↑ +33% vs last period" for a change figure (null = nothing to compare with).
({String? note, bool? good}) changeNote(int? change, {bool higherIsGood = true}) {
  if (change == null) return (note: null, good: null);
  if (change == 0) return (note: '— same as last period', good: null);
  final up = change > 0;
  return (note: '${up ? '↑ +' : '↓ −'}${change.abs()}% vs last period', good: up == higherIsGood);
}

// ── header ────────────────────────────────────────────────────────────────────

/// The header's filters: the date range, the Departments pill ("All Departments") and the brand — all three narrow every tab.
List<Widget> coordFilterActions(BuildContext context, WidgetRef ref) {
  final dept = ref.watch(coordDeptProvider);
  final base = teamFilterActions(context, ref, showMember: false);
  return [
    if (base.isNotEmpty) base.first,
    KeyedSubtree(
      key: const Key('co_dept_pill'),
      child: MktDropdownPill<String>(value: dept, icon: Icons.account_tree_outlined, options: [('all', 'All Departments'), for (final d in kCoordDepartments) (d, d)], onChanged: (v) => ref.read(coordDeptProvider.notifier).state = v),
    ),
    ...base.skip(1),
  ];
}

// ── forms ─────────────────────────────────────────────────────────────────────

/// Open [form] as a dialog on a laptop and a bottom sheet on a phone.
Future<T?> showCoordForm<T>(BuildContext context, Widget form, {double maxWidth = 640}) {
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<T>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: form)));
  }
  return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom), child: form));
}

InputDecoration coordDec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

/// Two fields side by side on a laptop, one under the other on a phone (a half-width dropdown does not fit a 390px sheet).
class CoordPair extends StatelessWidget {
  const CoordPair(this.a, this.b, {super.key});
  final Widget a, b;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => box.maxWidth < 420
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 10), b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]),
      );
}

/// The title, scrolling body, inline error and Cancel / Save row every form shares.
class CoordFormFrame extends StatelessWidget {
  const CoordFormFrame({super.key, required this.title, required this.keyPrefix, required this.children, required this.saving, required this.onSave, this.error, this.saveLabel = 'Save'});
  final String title, keyPrefix, saveLabel;
  final List<Widget> children;
  final bool saving;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(title, style: mktText(19, weight: FontWeight.w800)), const SizedBox(height: 12), ...children]),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, key: Key('${keyPrefix}_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
            Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
              OutlinedButton(key: Key('${keyPrefix}_cancel'), onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(key: Key('${keyPrefix}_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: saving ? null : onSave, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(saveLabel)),
            ]),
          ]),
        ),
      ]);
}

/// Run a write: on a server refusal return its words (the form shows them), on any other failure show the friendly snackbar, on success refresh everything.
Future<String?> coordWrite(BuildContext context, WidgetRef ref, Future<void> Function() write) async {
  try {
    await write();
    refreshCoordinations(ref);
    return null;
  } on TeamRefusal catch (r) {
    return r.message;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return 'That did not work. Please try again.';
  }
}

/// A write from a menu or a button (no form to show the refusal in): the refusal is a snackbar.
Future<bool> coordQuickWrite(BuildContext context, WidgetRef ref, Future<void> Function() write) async {
  try {
    await write();
    refreshCoordinations(ref);
    return true;
  } on TeamRefusal catch (r) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
  return false;
}

Future<bool> confirmCoord(BuildContext context, {required String title, required String body, required String confirmLabel, Key? confirmKey}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: confirmKey, onPressed: () => Navigator.pop(c, true), child: Text(confirmLabel))],
    ),
  );
  return yes == true;
}

/// A date the form asks for: a pill that opens the picker (and, when [onClear] is given, a way to take the date away again).
class DatePill extends StatelessWidget {
  const DatePill({super.key, required this.pillKey, required this.label, required this.value, required this.onPick, this.onClear, this.first, this.last});
  final Key pillKey;
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback? onClear;
  final DateTime? first, last;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MktPill(
        key: pillKey,
        label: value == null ? label : DateFormat('EEE d MMM yyyy').format(value!),
        icon: Icons.calendar_today_outlined,
        trailing: false,
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: first ?? DateTime(now.year - 2), lastDate: last ?? DateTime(now.year + 3));
          if (d != null) onPick(d);
        },
      ),
      if (value != null && onClear != null) IconButton(key: Key('${(pillKey as ValueKey).value}_clear'), tooltip: 'Clear', visualDensity: VisualDensity.compact, onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 16)),
    ]);
  }
}

/// A button that saves the tab's own rows as a CSV (the same records, cut the way the tab is cut).
class ExportButton extends ConsumerWidget {
  const ExportButton({super.key, required this.type, this.extra});
  final String type;
  final Map<String, dynamic>? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
        key: Key('co_export_$type'),
        onPressed: () async {
          try {
            final x = await ref.read(marketingCoordinationServiceProvider).export(type, ref.read(teamFilterProvider), ref.read(coordDeptProvider), extra: extra);
            await downloadCsv('coordinations_$type.csv', [x.columns, ...x.rows]);
          } catch (e) {
            if (context.mounted) showErrorSnackBar(context, e);
          }
        },
        icon: const Icon(Icons.download_rounded, size: 16),
        label: const Text('Export CSV'),
      );
}

/// The shared loading / error / data skeleton of a tab's scrolling list.
Widget coordLoading() => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
Widget coordError(Object e, WidgetRef ref) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCoordinations(ref))]);
