import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../data/stylist_client.dart';
import '../../services/consultation_service.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/stylist_client_ui.dart';

/// Schedule a call. Opened from a client page (`?clientId=…`, client fixed),
/// from the lead card (`?leadId=…`, a Team N enquiry — the server finds or
/// makes its client file), or from the calendar / dashboard, where the stylist
/// picks one of their clients or adds a new one on the spot.
///
/// Wide screens show the form beside a live summary; phones put the summary
/// and the Schedule button in a bar at the bottom.
class ConsultationFormScreen extends ConsumerStatefulWidget {
  const ConsultationFormScreen({super.key, this.leadId, this.clientId, this.initialDay});

  final String? leadId;

  /// Day to start on (from the calendar's "Schedule on this day"); the time
  /// still defaults to 11 AM.
  final DateTime? initialDay;

  /// A stylist client file — takes precedence over [leadId].
  final String? clientId;

  @override
  ConsumerState<ConsultationFormScreen> createState() => _ConsultationFormScreenState();
}

/// Common start times offered as one tap.
const _quickTimes = [(10, 0), (11, 0), (12, 0), (14, 0), (15, 0), (16, 0), (17, 0), (18, 0)];
const _quickDurations = [15, 30, 45, 60, 90];

class _ConsultationFormScreenState extends ConsumerState<ConsultationFormScreen> {
  late String? _clientId = widget.clientId;
  bool get _clientFixed => widget.clientId != null;
  bool get _byLead => _clientId == null && widget.leadId != null;

  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';

  late DateTime _when = widget.initialDay == null
      ? _defaultStart()
      : DateTime(widget.initialDay!.year, widget.initialDay!.month, widget.initialDay!.day, 11);
  int _duration = 45;
  String? _stylistId;
  String _mode = 'Video';
  final _link = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;

  static DateTime _defaultStart() {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, 11);
  }

  DateTime get _day => DateTime(_when.year, _when.month, _when.day);
  DateTime get _ends => _when.add(Duration(minutes: _duration));

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _link.dispose();
    _location.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _q = v.trim());
    });
  }

  /// The stylist the call is for: chosen (leads), else the signed-in user.
  String _ownerId(List<ConsultationStylist> stylists, String myId) {
    return _stylistId ?? (stylists.any((s) => s.id == myId) || stylists.isEmpty ? myId : stylists.first.id);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit({bool force = false}) async {
    final lead = _byLead ? ref.read(leadConsultationsProvider(widget.leadId!)).value?.lead : null;
    if (_clientId == null && (lead == null || lead.id.isEmpty)) {
      showWarningSnackBar(context, 'Choose the client first');
      return;
    }
    if (!force && _when.isBefore(DateTime.now())) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Time is in the past'),
          content: const Text('That date and time has already passed. Book it anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Change it')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Book anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      final created = await ref.read(consultationServiceProvider).create(
            clientId: _clientId,
            leadId: _clientId == null ? lead?.id : null,
            scheduledAt: _when,
            durationMins: _duration,
            stylistId: _stylistId,
            mode: _mode,
            meetingLink: _mode == 'Video' ? _link.text.trim() : '',
            location: _mode == 'In-person' ? _location.text.trim() : '',
            force: force,
          );
      ref.refreshData.consultations();
      if (!mounted) return;
      showSuccessSnackBar(context, created.callLabel.isEmpty ? 'Call scheduled' : '${created.callLabel} scheduled');
      context.pushReplacement('/consultations/${created.id}');
    } on ScheduleConflictException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final isLead = ref.read(effectiveAccessProvider).canSeeConsultationReports;
      final bookAnyway = await showConflictDialog(context, e, canOverride: isLead);
      if (bookAnyway && mounted) await _submit(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  Future<void> _addNewClient() async {
    final id = await context.push<String>('/stylist/clients/new?pick=1');
    if (id != null && id.isNotEmpty && mounted) setState(() => _clientId = id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = ref.watch(effectiveAccessProvider);
    final isLead = access.canSeeConsultationReports;
    final stylists = ref.watch(consultationStylistsProvider).value ?? const <ConsultationStylist>[];
    final owner = _ownerId(stylists, ref.watch(authSessionProvider)?.userId ?? '');
    final client = _clientId == null ? null : ref.watch(stylistClientProvider(_clientId!)).value;
    final lead = _byLead ? ref.watch(leadConsultationsProvider(widget.leadId!)).value?.lead : null;

    // That stylist's other scheduled calls on the chosen day (clash preview).
    final dayCalls = ref
            .watch(consultationsProvider((
              from: dayKey(_day),
              to: dayKey(_day),
              status: 'Scheduled',
              stylistId: isLead ? owner : null,
            )))
            .value ??
        const <Consultation>[];
    final clashes = dayCalls.where((c) => c.scheduledAt.isBefore(_ends) && c.endsAt.isAfter(_when)).toList();

    final summary = _Summary(
      clientName: client?.name ?? lead?.name ?? '',
      company: client?.company ?? (lead != null ? 'Team N' : ''),
      callLabel: client == null ? '' : _nextCallLabel(client),
      when: _when,
      ends: _ends,
      mode: _mode,
      stylistName: stylists.where((s) => s.id == owner).firstOrNull?.name ?? '',
      clashes: clashes.length,
      inPast: _when.isBefore(DateTime.now()),
      saving: _saving,
      onSubmit: () => _submit(),
    );

    final sections = [
      _section(crm, 'Client', Icons.person_outline, _clientSection(crm, client, lead)),
      _section(crm, 'When', Icons.event_outlined, _whenSection(crm, dayCalls, clashes)),
      _section(crm, 'Meeting', Icons.videocam_outlined, _meetingSection(crm)),
      if (isLead && stylists.length > 1)
        _section(
          crm,
          'Stylist',
          Icons.spa_outlined,
          DropdownButtonFormField<String>(
            initialValue: stylists.any((s) => s.id == owner) ? owner : null,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [for (final s in stylists) DropdownMenuItem(value: s.id, child: Text(s.name))],
            onChanged: _saving ? null : (v) => setState(() => _stylistId = v),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/consultations'),
        ),
        title: const Text('Schedule call'),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final form = ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (final s in sections) ...[s, const SizedBox(height: 16)],
            ],
          );
          if (!wide) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: form),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  SizedBox(
                    width: 340,
                    child: Padding(padding: const EdgeInsets.fromLTRB(0, 16, 16, 16), child: summary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // Wide screens show the summary beside the form instead.
      bottomNavigationBar:
          MediaQuery.sizeOf(context).width >= 900 ? null : SafeArea(top: false, child: summary.compact(context)),
    );
  }

  String _nextCallLabel(StylistClient c) {
    final next = c.calls.where((x) => x.callNumber != null).length + 1;
    return next <= c.requiredCalls ? 'Call $next of ${c.requiredCalls}' : 'Extra call $next';
  }

  Widget _section(CrmTheme crm, String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: crm.primary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: crm.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Client ────────────────────────────────────────────────────────────────
  Widget _clientSection(CrmTheme crm, StylistClient? client, ConsultationLead? lead) {
    if (_clientId != null) {
      final async = ref.watch(stylistClientProvider(_clientId!));
      if (client == null) {
        return async.hasError
            ? AppErrorView(
                error: async.error,
                compact: true,
                onRetry: () => ref.invalidate(stylistClientProvider(_clientId!)),
              )
            : const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
      }
      return _chosenClient(crm, client);
    }

    if (_byLead) {
      if (lead == null) {
        final async = ref.watch(leadConsultationsProvider(widget.leadId!));
        return async.hasError
            ? AppErrorView(
                error: async.error,
                compact: true,
                onRetry: () => ref.invalidate(leadConsultationsProvider(widget.leadId!)),
              )
            : const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _clientLine(crm, lead.name, 'Team N', [lead.phone, if (lead.eventType.isNotEmpty) lead.eventType].join('  ·  ')),
          const SizedBox(height: 8),
          Text("The client's file is created from this enquiry if they don't have one yet.",
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
      );
    }

    return _clientPicker(crm);
  }

  Widget _clientLine(CrmTheme crm, String name, String company, String sub, {Widget? trailing}) => Row(
        children: [
          CircleAvatar(
            backgroundColor: companyColor(company).withValues(alpha: 0.12),
            foregroundColor: companyColor(company),
            child: Text(name.isEmpty ? '?' : name.trim()[0].toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name.isEmpty ? 'Client' : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    CompanyTag(company),
                  ],
                ),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: crm.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          ?trailing,
        ],
      );

  Widget _chosenClient(CrmTheme crm, StylistClient c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _clientLine(
          crm,
          c.name,
          c.company,
          clientEventLine(c),
          trailing: _clientFixed
              ? null
              : TextButton(onPressed: _saving ? null : () => setState(() => _clientId = null), child: const Text('Change')),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CallProgressDots(done: c.progress.done, required: c.requiredCalls),
            Text('${c.progress.done} of ${c.requiredCalls} done  ·  this will be',
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            Text(_nextCallLabel(c), style: TextStyle(fontSize: 12, color: crm.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        if (c.status != 'Active')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              c.status == 'Cancelled'
                  ? 'This client is cancelled. Reopen them on the client page before booking.'
                  : 'This client is marked completed.',
              style: TextStyle(fontSize: 12, color: c.status == 'Cancelled' ? crm.destructive : crm.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _clientPicker(CrmTheme crm) {
    final async = ref.watch(stylistClientsProvider((q: _q, company: '', status: 'Active', sort: 'recent')));
    final list = async.value ?? const <StylistClient>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: const InputDecoration(
            hintText: 'Search your clients by name, phone or booking',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        if (async.isLoading && list.isEmpty)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (async.hasError)
          AppErrorView(
            error: async.error,
            compact: true,
            onRetry: () => ref.invalidate(stylistClientsProvider((q: _q, company: '', status: 'Active', sort: 'recent'))),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_q.isEmpty ? 'You have no active clients yet.' : 'No active client matches "$_q".',
                style: TextStyle(color: crm.textSecondary)),
          )
        else
          for (final c in list.take(8))
            InkWell(
              onTap: () => setState(() => _clientId = c.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _clientLine(
                  crm,
                  c.name,
                  c.company,
                  clientEventLine(c),
                  trailing: CallProgressDots(done: c.progress.done, required: c.requiredCalls, size: 8),
                ),
              ),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _saving ? null : _addNewClient,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('New client'),
        ),
      ],
    );
  }

  // ── When ──────────────────────────────────────────────────────────────────
  Widget _whenSection(CrmTheme crm, List<Consultation> dayCalls, List<Consultation> clashes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
    final dayInList = days.contains(_day);
    final timeQuick = _quickTimes.any((t) => t.$1 == _when.hour && t.$2 == _when.minute);

    String dayLabel(DateTime d) {
      final diff = d.difference(today).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      return DateFormat('EEE d').format(d);
    }

    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: _saving ? null : (_) => onTap(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Day', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in days)
              chip(dayLabel(d), _day == d, () => setState(() => _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute))),
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(dayInList ? 'Other date' : fmtDay(_when)),
              backgroundColor: dayInList ? null : crm.primary.withValues(alpha: 0.12),
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _when,
                        firstDate: now.subtract(const Duration(days: 60)),
                        lastDate: now.add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) {
                        setState(() => _when = DateTime(picked.year, picked.month, picked.day, _when.hour, _when.minute));
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Start time', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in _quickTimes)
              chip(
                fmtTime(DateTime(2000, 1, 1, t.$1, t.$2)),
                _when.hour == t.$1 && _when.minute == t.$2,
                () => setState(() => _when = DateTime(_when.year, _when.month, _when.day, t.$1, t.$2)),
              ),
            ActionChip(
              avatar: const Icon(Icons.access_time, size: 16),
              label: Text(timeQuick ? 'Other time' : fmtTime(_when)),
              backgroundColor: timeQuick ? null : crm.primary.withValues(alpha: 0.12),
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
                      if (picked != null) {
                        setState(() => _when = DateTime(_when.year, _when.month, _when.day, picked.hour, picked.minute));
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Length', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in {..._quickDurations, _duration}.toList()..sort())
              chip(d < 60 ? '$d min' : (d % 60 == 0 ? '${d ~/ 60} h' : '${d ~/ 60} h ${d % 60} min'), _duration == d,
                  () => setState(() => _duration = d)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (clashes.isEmpty ? crm.background : crm.destructive.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: clashes.isEmpty ? crm.border : crm.destructive.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayCalls.isEmpty
                    ? 'No other calls on ${fmtDay(_when)} — free all day'
                    : 'Other calls on ${fmtDay(_when)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
              ),
              for (final c in dayCalls)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(clashes.contains(c) ? Icons.warning_amber_rounded : Icons.schedule,
                          size: 14, color: clashes.contains(c) ? crm.destructive : crm.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${fmtRange(c)}  ·  ${c.clientName.isEmpty ? 'Client' : c.clientName}'
                          '${clashes.contains(c) ? '  ·  clashes' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: clashes.contains(c) ? crm.destructive : crm.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Meeting ───────────────────────────────────────────────────────────────
  Widget _meetingSection(CrmTheme crm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Video', label: Text('Video'), icon: Icon(Icons.videocam_outlined)),
            ButtonSegment(value: 'In-person', label: Text('In-person'), icon: Icon(Icons.place_outlined)),
          ],
          selected: {_mode},
          onSelectionChanged: _saving ? null : (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 12),
        if (_mode == 'Video')
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Meet / Zoom link',
              hintText: 'Paste it now or add it later',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          )
        else
          TextField(
            controller: _location,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'Studio, client\'s home…',
              prefixIcon: Icon(Icons.place_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
      ],
    );
  }
}

/// What will be booked, with the Schedule button: a side card on wide
/// screens, a bottom bar on phones ([compact]).
class _Summary extends StatelessWidget {
  const _Summary({
    required this.clientName,
    required this.company,
    required this.callLabel,
    required this.when,
    required this.ends,
    required this.mode,
    required this.stylistName,
    required this.clashes,
    required this.inPast,
    required this.saving,
    required this.onSubmit,
  });

  final String clientName;
  final String company;
  final String callLabel;
  final DateTime when;
  final DateTime ends;
  final String mode;
  final String stylistName;
  final int clashes;
  final bool inPast;
  final bool saving;
  final VoidCallback onSubmit;

  String get _warning => clashes > 0
      ? 'Clashes with ${clashes == 1 ? 'another call' : '$clashes calls'}'
      : inPast
          ? 'This time has already passed'
          : '';

  Widget _button() => FilledButton.icon(
        onPressed: saving ? null : onSubmit,
        icon: saving
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.event_available_outlined, size: 18),
        label: const Text('Schedule call'),
      );

  /// The phone bottom bar.
  Widget compact(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [if (callLabel.isNotEmpty) callLabel, if (clientName.isNotEmpty) clientName].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  _warning.isNotEmpty ? _warning : '${DateFormat('EEE d MMM').format(when)}, ${fmtTime(when)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _warning.isNotEmpty ? crm.destructive : crm.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _button(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: crm.textPrimary))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, color: crm.textPrimary)),
          const SizedBox(height: 12),
          if (callLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(callLabel, style: TextStyle(color: crm.primary, fontWeight: FontWeight.w700)),
            ),
          Row(
            children: [
              Flexible(
                child: Text(clientName.isEmpty ? 'Choose a client' : clientName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: clientName.isEmpty ? crm.textSecondary : crm.textPrimary)),
              ),
              const SizedBox(width: 6),
              CompanyTag(company),
            ],
          ),
          const SizedBox(height: 12),
          line(Icons.calendar_today_outlined, DateFormat('EEEE, d MMMM yyyy').format(when)),
          line(Icons.access_time, '${fmtTime(when)} – ${fmtTime(ends)}  (${ends.difference(when).inMinutes} min)'),
          line(mode == 'Video' ? Icons.videocam_outlined : Icons.place_outlined, mode),
          if (stylistName.isNotEmpty) line(Icons.spa_outlined, stylistName),
          if (_warning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: crm.destructive),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_warning, style: TextStyle(color: crm.destructive))),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _button()),
        ],
      ),
    );
  }
}
