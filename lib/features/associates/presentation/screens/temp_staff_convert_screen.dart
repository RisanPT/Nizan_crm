import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/auth/workspace.dart' show effectiveAccessProvider;
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/associates/data/temp_staff.dart';
import 'package:nizan_crm/features/associates/services/associate_works_service.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/services/employee_service.dart';

/// CONVERT THE OLD "TEMPORARY STAFF" BOX. Before associates existed, Operations typed the outside artists who worked an event into one
/// free-text box on the booking ("reem", "hiba & thasliya", "ajila saree drapist"). This reads those texts into one row per person and lets
/// a person say what each is — a new associate, one already registered, the same person as another row (spellings differ: thesliya /
/// thasliya), or not an associate at all — then adds them to those bookings' teams, so the works reach the Associate Works report.
/// Nothing is guessed or changed until Convert is pressed; the typed text itself is never edited.
class TempStaffConvertScreen extends ConsumerStatefulWidget {
  const TempStaffConvertScreen({super.key});

  @override
  ConsumerState<TempStaffConvertScreen> createState() => _TempStaffConvertScreenState();
}

class _TempStaffConvertScreenState extends ConsumerState<TempStaffConvertScreen> {
  /// What the person has decided so far, by row key. Kept across refreshes for the rows that are still there.
  final Map<String, TempStaffDraft> _drafts = {};
  Map<String, String> _errors = {};
  bool _busy = false;

  /// Match the drafts to the rows the server sent: new rows start from their default, rows that are gone are dropped.
  void _sync(TempStaffScan scan) {
    final keys = {for (final r in scan.rows) r.key};
    _drafts.removeWhere((k, _) => !keys.contains(k));
    for (final r in scan.rows) {
      _drafts.putIfAbsent(r.key, () => TempStaffDraft.initial(r));
    }
  }

  Future<void> _convert(TempStaffPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert these names?'),
        content: Text(
          '${plan.count(TempStaffAction.create)} new ${plan.count(TempStaffAction.create) == 1 ? 'associate' : 'associates'} · '
          '${plan.count(TempStaffAction.link)} already registered · '
          '${plan.count(TempStaffAction.merge)} same as another name · '
          '${plan.count(TempStaffAction.skip)} ignored.\n\n'
          'Each person is added to the team of every booking whose box names them (on the booking and on each of its packages). '
          'The text in the box is kept as it was. You can remove someone from a booking’s team later in Manage booking.',
        ),
        actions: [
          TextButton(key: const Key('tsCancel'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const Key('tsConfirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(associateWorksServiceProvider).convertTempStaff(plan.request);
      if (!mounted) return;
      setState(() => _errors = result.errors);
      messenger.showSnackBar(SnackBar(content: Text(result.errors.isEmpty ? result.summary : '${result.summary} ${result.errors.length} could not be converted — see the notes.')));
      // the works, the staff list and the calendar all changed
      ref.invalidate(tempStaffProvider);
      ref.invalidate(associateWorksProvider);
      ref.invalidate(employeesProvider);
      ref.invalidate(bookingProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final access = ref.watch(effectiveAccessProvider);
    if (!access.canConvertTempStaff) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Converting temporary staff is for Operations and managers.', key: const Key('tsNotAllowed'), style: TextStyle(color: crm.textSecondary))));
    }
    final async = ref.watch(tempStaffProvider);
    final scan = async.value;
    if (scan == null) {
      if (async.hasError) return AppErrorView(error: async.error!, onRetry: () => ref.invalidate(tempStaffProvider));
      return const Center(child: CircularProgressIndicator());
    }
    _sync(scan);
    final plan = TempStaffPlan(_drafts);
    final problems = plan.problems;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 16),
            children: [
              if (async.isLoading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 3)),
              _header(crm, isMobile),
              14.h,
              if (scan.rows.isEmpty) _empty(crm) else ...[
                _intro(crm, scan),
                12.h,
                for (final r in scan.rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RowCard(
                      key: Key('tsRow_${r.key}'),
                      draft: _drafts[r.key]!,
                      drafts: _drafts,
                      associates: scan.associates,
                      problem: problems[r.key],
                      serverError: _errors[r.key],
                      onChanged: () => setState(() => _errors = {..._errors}..remove(r.key)),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (scan.rows.isNotEmpty) _footer(crm, isMobile, plan, problems),
      ],
    );
  }

  Widget _header(CrmTheme crm, bool isMobile) => Row(children: [
        IconButton(key: const Key('tsBack'), tooltip: 'Back to Associate Works', onPressed: () => context.go('/associate-works'), icon: const Icon(Icons.arrow_back_rounded)),
        4.w,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Convert old temporary staff', key: const Key('tsTitle'), style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            4.h,
            Text('Names typed into the old “Temporary staff” box, made into registered associates so their works reach the Associate Works report.', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          ]),
        ),
        IconButton(key: const Key('tsRefresh'), tooltip: 'Refresh', onPressed: () => ref.invalidate(tempStaffProvider), icon: const Icon(Icons.refresh_rounded)),
      ]);

  Widget _empty(CrmTheme crm) => Container(
        key: const Key('tsEmpty'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: crm.success),
          12.w,
          Expanded(child: Text('Nothing to convert. Every name typed into the old Temporary staff box has been reviewed.', style: TextStyle(fontSize: 13, color: crm.textSecondary, height: 1.4))),
        ]),
      );

  Widget _intro(CrmTheme crm, TempStaffScan scan) => Container(
        key: const Key('tsIntro'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: crm.accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.accent.withValues(alpha: 0.25))),
        child: Text(
          '${scan.pendingBookings} ${scan.pendingBookings == 1 ? 'booking has' : 'bookings have'} names in the box — ${scan.rows.length} ${scan.rows.length == 1 ? 'person' : 'people'}. '
          'Spellings differ (“thesliya”, “thasliya”), so please check each: say who it is, and join spellings of the same person with “The same person as another name”. '
          'Nothing changes until you press Convert, and the typed text is never edited.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: crm.textPrimary),
        ),
      );

  Widget _footer(CrmTheme crm, bool isMobile, TempStaffPlan plan, Map<String, String> problems) {
    final bad = problems.length;
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 10, isMobile ? 16 : 24, 12),
      decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
      child: Row(children: [
        Expanded(
          child: Text(
            bad > 0
                ? '$bad ${bad == 1 ? 'name needs' : 'names need'} an answer before converting.'
                : '${plan.count(TempStaffAction.create)} new · ${plan.count(TempStaffAction.link)} registered · ${plan.count(TempStaffAction.merge)} same as another · '
                    '${plan.count(TempStaffAction.skip)} ignored · ${plan.count(TempStaffAction.later)} for later',
            key: const Key('tsSummary'),
            style: TextStyle(fontSize: 12.5, color: bad > 0 ? crm.warning : crm.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        12.w,
        FilledButton.icon(
          key: const Key('tsConvert'),
          onPressed: _busy || !plan.ready ? null : () => _convert(plan),
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Convert'),
        ),
      ]),
    );
  }
}

/// One person: who they are, how it was typed, and what to do with them.
class _RowCard extends StatefulWidget {
  const _RowCard({super.key, required this.draft, required this.drafts, required this.associates, required this.problem, required this.serverError, required this.onChanged});
  final TempStaffDraft draft;
  final Map<String, TempStaffDraft> drafts;
  final List<TempStaffAssociate> associates;
  final String? problem, serverError;
  final VoidCallback onChanged;

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _examples = false;

  TempStaffDraft get d => widget.draft;
  TempStaffRow get row => d.row;

  void _set(void Function() change) {
    setState(change);
    widget.onChanged();
  }

  static String _day(String iso) {
    final t = DateTime.tryParse(iso);
    return t == null ? iso : DateFormat('d MMM yyyy').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final others = [for (final o in widget.drafts.values) if (o.row.key != row.key && (o.action == TempStaffAction.create || o.action == TempStaffAction.link)) o];
    final lookalikes = [for (final k in row.similar) if (widget.drafts[k] != null) widget.drafts[k]!];
    final suggestion = row.suggestion;
    final settled = d.action == TempStaffAction.skip || d.action == TempStaffAction.later;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (widget.problem ?? widget.serverError) != null ? crm.warning : crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(row.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: settled ? crm.textSecondary : crm.textPrimary)),
          _pill(crm, '${row.count} ${row.count == 1 ? 'booking' : 'bookings'}', crm.accent),
          if (row.roleHint.isNotEmpty) _pill(crm, row.roleHint, crm.primary),
          if (row.variants.length > 1 || (row.variants.isNotEmpty && row.variants.first.name != row.name))
            Text('typed as ${row.variants.map((v) => '“${v.name.toLowerCase()}” ×${v.count}').join(', ')}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ]),
        8.h,
        if (row.samples.isNotEmpty)
          InkWell(
            key: Key('tsExamples_${row.key}'),
            onTap: () => setState(() => _examples = !_examples),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final s in (_examples ? row.samples : row.samples.take(1)))
                  Text('${s.bookingNumber.isEmpty ? '' : '${s.bookingNumber} · '}${s.customerName}${s.day.isEmpty ? '' : ' · ${_day(s.day)}'} — “${s.text.replaceAll('\n', ' / ')}”', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (row.count > 1 && !_examples) Text('and ${row.count - 1} more — tap to see examples', style: TextStyle(fontSize: 11, color: crm.accent)),
              ]),
            ),
          ),
        10.h,
        if (lookalikes.isNotEmpty || (suggestion != null && !(d.action == TempStaffAction.link && d.employeeId == suggestion.employeeId)))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              if (suggestion != null && !(d.action == TempStaffAction.link && d.employeeId == suggestion.employeeId))
                ActionChip(
                  key: Key('tsSuggest_${row.key}'),
                  avatar: const Icon(Icons.how_to_reg_outlined, size: 16),
                  label: Text('${suggestion.exact ? 'Registered' : 'Looks like registered'}: ${suggestion.name} — link?'),
                  onPressed: () => _set(() {
                    d.action = TempStaffAction.link;
                    d.employeeId = suggestion.employeeId;
                  }),
                ),
              for (final o in lookalikes)
                if (d.action != TempStaffAction.merge || d.into != o.row.key)
                  ActionChip(
                    key: Key('tsSimilar_${row.key}_${o.row.key}'),
                    avatar: const Icon(Icons.call_merge_rounded, size: 16),
                    label: Text('Looks like ${o.row.name} (${o.row.count}) — same person?'),
                    onPressed: () => _set(() {
                      d.action = TempStaffAction.merge;
                      d.into = o.row.key;
                    }),
                  ),
            ]),
          ),
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.start, children: [
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<TempStaffAction>(
              key: Key('tsAction_${row.key}'),
              initialValue: d.action,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'This is', isDense: true, border: OutlineInputBorder()),
              items: [for (final a in TempStaffAction.values) DropdownMenuItem(value: a, child: Text(a.label, overflow: TextOverflow.ellipsis))],
              onChanged: (a) => _set(() {
                if (a == null) return;
                d.action = a;
                if (a == TempStaffAction.merge && d.into == null) d.into = others.isEmpty ? null : others.first.row.key;
                if (a == TempStaffAction.link && d.employeeId == null && widget.associates.isNotEmpty) d.employeeId = suggestion?.employeeId ?? widget.associates.first.id;
              }),
            ),
          ),
          if (d.action == TempStaffAction.create) ...[
            _field('tsName_${row.key}', 'Name', d.name, (v) => d.name = v, width: 220),
            _field('tsPhone_${row.key}', 'Phone (optional)', d.phone, (v) => d.phone = v, width: 170, keyboard: TextInputType.phone),
            _field('tsRole_${row.key}', 'What they do (optional)', d.role, (v) => d.role = v, width: 200),
          ],
          if (d.action == TempStaffAction.link) ...[
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: Key('tsLink_${row.key}'),
                initialValue: widget.associates.any((a) => a.id == d.employeeId) ? d.employeeId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Registered associate', isDense: true, border: OutlineInputBorder()),
                items: [for (final a in widget.associates) DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => _set(() => d.employeeId = v),
              ),
            ),
            _field('tsRole_${row.key}', 'What they do (optional)', d.role, (v) => d.role = v, width: 200),
          ],
          if (d.action == TempStaffAction.merge)
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: Key('tsInto_${row.key}'),
                initialValue: others.any((o) => o.row.key == d.into) ? d.into : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Same person as', isDense: true, border: OutlineInputBorder()),
                items: [for (final o in others) DropdownMenuItem(value: o.row.key, child: Text('${o.row.name} (${o.row.count})', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => _set(() => d.into = v),
              ),
            ),
        ]),
        if (d.action == TempStaffAction.skip) _note(crm, 'Ignored: nothing is added, and these bookings’ boxes are marked as reviewed.'),
        if (d.action == TempStaffAction.later) _note(crm, 'Stays in this list for another time.'),
        if (widget.problem != null) _note(crm, widget.problem!, warn: true, key: Key('tsProblem_${row.key}')),
        if (widget.serverError != null) _note(crm, widget.serverError!, warn: true, key: Key('tsError_${row.key}')),
      ]),
    );
  }

  Widget _field(String key, String label, String value, void Function(String) onChanged, {double width = 200, TextInputType? keyboard}) => SizedBox(
        width: width,
        child: TextFormField(
          key: Key(key),
          initialValue: value,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
          onChanged: (v) => _set(() => onChanged(v)),
        ),
      );

  Widget _pill(CrmTheme crm, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _note(CrmTheme crm, String text, {bool warn = false, Key? key}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, key: key, style: TextStyle(fontSize: 11.5, color: warn ? crm.warning : crm.textSecondary)),
      );
}
