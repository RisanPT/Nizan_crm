import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/stylist_client.dart';
import '../../services/stylist_client_service.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/stylist_client_ui.dart';

/// Wide enough for the one-line filter bar and the table layout.
const _wideBreakpoint = 900.0;

const _statuses = {'Active': 'Active', 'Completed': 'Completed', 'Cancelled': 'Cancelled', 'all': 'All'};
const _sorts = {'event': 'Event soonest', 'recent': 'Recently updated'};

/// My Clients: every client file the stylist works with (a stylist lead sees
/// the whole team). Desktop: one filter bar (search, status, company, sort)
/// over a table of clients. Phone: search, a status switch and a Filters
/// button (company, sort) over short client cards.
class StylistClientsScreen extends ConsumerStatefulWidget {
  const StylistClientsScreen({super.key});

  @override
  ConsumerState<StylistClientsScreen> createState() => _StylistClientsScreenState();
}

class _StylistClientsScreenState extends ConsumerState<StylistClientsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';
  String _company = '';
  String _status = 'Active';
  String _sort = 'event';

  ClientQuery get _query => (q: _q, company: _company, status: _status, sort: _sort);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _q = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isLead = ref.watch(effectiveAccessProvider).canSeeConsultationReports;
    final query = _query;
    final async = ref.watch(stylistClientsProvider(query));

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wideBreakpoint;
      return Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            _header(crm, isLead, async.value?.length, wide),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(stylistClientsProvider(query))),
                data: (list) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(stylistClientsProvider(query)),
                  child: list.isEmpty
                      ? _empty(crm)
                      : wide
                          ? _table(crm, list, isLead)
                          : _cards(list, isLead),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Header and filters ───────────────────────────────────────────────────
  String _countLine(int count) => switch (_status) {
        'all' => '$count ${count == 1 ? 'client' : 'clients'}',
        _ => '$count ${_status.toLowerCase()}',
      };

  Widget _header(CrmTheme crm, bool isLead, int? count, bool wide) {
    final searchField = TextField(
      controller: _search,
      onChanged: _onSearch,
      decoration: InputDecoration(
        hintText: wide ? 'Search name, phone, booking or client number' : 'Search name, phone or booking',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: crm.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _search.clear();
                  setState(() => _q = '');
                },
              ),
      ),
    );
    final status = SegmentedButton<String>(
      showSelectedIcon: false,
      // Tighter padding on a phone so four labels fit one line.
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: wide ? null : const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
      ),
      segments: [
        for (final e in _statuses.entries)
          ButtonSegment(
            value: e.key,
            label: Text(!wide && e.key == 'Completed' ? 'Done' : e.value, maxLines: 1, softWrap: false),
          ),
      ],
      selected: {_status},
      onSelectionChanged: (s) => setState(() => _status = s.first),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isLead ? 'All clients' : 'My clients',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: crm.textPrimary)),
                        if (count != null)
                          Text(_countLine(count), style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.push('/stylist/clients/new'),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('New client'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wide)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: 280, child: searchField),
                    status,
                    _companySwitch(),
                    _sortMenu(crm),
                  ],
                )
              else ...[
                // Phone: search with Filters beside it, then the status switch full width.
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _company.isNotEmpty,
                      smallSize: 8,
                      child: IconButton.outlined(
                        tooltip: 'Filters',
                        style: IconButton.styleFrom(side: BorderSide(color: crm.border)),
                        onPressed: () => _openFilters(crm),
                        icon: const Icon(Icons.tune, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: status),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _companySwitch() => SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          const ButtonSegment(value: '', label: Text('Both')),
          for (final c in kClientCompanies) ButtonSegment(value: c, label: Text(c)),
        ],
        selected: {_company},
        onSelectionChanged: (s) => setState(() => _company = s.first),
      );

  Widget _sortMenu(CrmTheme crm) => PopupMenuButton<String>(
        tooltip: 'Sort',
        initialValue: _sort,
        onSelected: (v) => setState(() => _sort = v),
        itemBuilder: (_) => [for (final e in _sorts.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: crm.border), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sort: ${_sorts[_sort]}', style: TextStyle(color: crm.textPrimary, fontSize: 13)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: crm.textSecondary),
            ],
          ),
        ),
      );

  /// Phone: company and sort in a bottom sheet.
  Future<void> _openFilters(CrmTheme crm) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) {
            void update(VoidCallback f) {
              setState(f);
              setSheet(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Company', style: TextStyle(fontWeight: FontWeight.bold, color: crm.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in ['', ...kClientCompanies])
                          ChoiceChip(
                            label: Text(c.isEmpty ? 'Both' : c),
                            selected: _company == c,
                            onSelected: (_) => update(() => _company = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Sort', style: TextStyle(fontWeight: FontWeight.bold, color: crm.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in _sorts.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _sort == e.key,
                            onSelected: (_) => update(() => _sort = e.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _empty(CrmTheme crm) {
    final filtered = _q.isNotEmpty || _company.isNotEmpty || _status != 'Active';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.people_outline, size: 48, color: crm.textSecondary),
        const SizedBox(height: 12),
        Center(
          child: Text(filtered ? 'No clients match these filters.' : 'Add your first client',
              style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              filtered
                  ? 'Try another search or filter.'
                  : 'Pick a Team N client from an enquiry or booking, or add a Nizan client.',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  // ── Desktop: table ───────────────────────────────────────────────────────
  Widget _table(CrmTheme crm, List<StylistClient> list, bool isLead) {
    Widget head(String t, int flex) => Expanded(
          flex: flex,
          child: Text(t, style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
        );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        head('Client', 3),
                        head('Event', 3),
                        if (isLead) head('Stylist', 2),
                        head('Calls', 2),
                        head('Next call', 3),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  for (final c in list) _TableRow(client: c, showStylist: isLead),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phone: cards ─────────────────────────────────────────────────────────
  Widget _cards(List<StylistClient> list, bool isLead) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ClientCard(client: list[i], showStylist: isLead),
      );
}

// ── Shared row pieces ────────────────────────────────────────────────────────
bool _needsCall(StylistClient c) => c.isActive && c.progress.booked == 0 && !c.progress.seriesDone;

Widget _noCallBadge(CrmTheme crm, {bool short = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: crm.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(short ? 'No call' : 'No call booked',
          style: TextStyle(color: crm.warning, fontSize: 11, fontWeight: FontWeight.w700)),
    );

/// "Wedding · 22 Nov".
String _eventShort(StylistClient c) {
  final day = c.nextEventDay ?? (c.eventDays.isEmpty ? null : c.eventDays.first);
  return [
    if (c.eventType.isNotEmpty) c.eventType,
    if (day != null) fmtShortDay(day),
  ].join(' · ');
}

Widget _progress(CrmTheme crm, StylistClient c) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CallProgressDots(done: c.progress.done, required: c.requiredCalls, booked: c.progress.booked),
        const SizedBox(width: 6),
        Text('${c.progress.done}/${c.requiredCalls}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      ],
    );

class _TableRow extends StatelessWidget {
  const _TableRow({required this.client, required this.showStylist});

  final StylistClient client;
  final bool showStylist;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = client;
    final p = c.progress;
    final days = c.daysToEvent;
    final soon = days != null && days <= 14 && c.isActive;
    final when = [
      if (days != null) fmtDaysToEvent(days).toLowerCase(),
      if (c.venue.isNotEmpty) c.venue.split(',').last.trim(),
    ].join(' · ');

    final Widget next = p.nextCallAt != null
        ? Text(DateFormat('EEE d MMM, h:mm a').format(p.nextCallAt!), style: TextStyle(color: crm.textPrimary))
        : _needsCall(c)
            ? Align(alignment: Alignment.centerLeft, child: _noCallBadge(crm))
            : Text(p.seriesDone ? 'All calls done' : '—',
                style: TextStyle(color: p.seriesDone ? crm.success : crm.textSecondary, fontSize: 13));

    return InkWell(
      onTap: () => context.push('/stylist/clients/${c.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(c.name.isEmpty ? 'Client' : c.name,
                      style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  CompanyTag(c.company),
                  if (!c.isActive) ConsultationStatusChip(c.status, color: clientStatusTone(crm, c.status)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_eventShort(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (when.isNotEmpty)
                    Text(when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: soon ? crm.warning : crm.textSecondary)),
                ],
              ),
            ),
            if (showStylist)
              Expanded(
                flex: 2,
                child: Text(c.stylistName.isEmpty ? '—' : c.stylistName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _progress(crm, c))),
            Expanded(flex: 3, child: next),
            Icon(Icons.chevron_right, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.showStylist});

  final StylistClient client;
  final bool showStylist;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = client;
    final p = c.progress;
    final days = c.daysToEvent;
    final soon = days != null && days <= 14 && c.isActive;

    final Widget right = !c.isActive
        ? ConsultationStatusChip(c.status, color: clientStatusTone(crm, c.status))
        : _needsCall(c)
            ? _noCallBadge(crm, short: true)
            : p.nextCallAt != null
                ? Text('Next ${fmtShortDay(p.nextCallAt!)}', style: TextStyle(fontSize: 12, color: crm.textSecondary))
                : Text(p.seriesDone ? 'All done' : '',
                    style: TextStyle(fontSize: 12, color: crm.success, fontWeight: FontWeight.w600));

    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/stylist/clients/${c.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.name.isEmpty ? 'Client' : c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  right,
                ],
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: _eventShort(c)),
                  if (days != null)
                    TextSpan(
                      text: '${_eventShort(c).isEmpty ? '' : '  ·  '}${fmtDaysToEvent(days).toLowerCase()}',
                      style: TextStyle(color: soon ? crm.warning : crm.textSecondary,
                          fontWeight: soon ? FontWeight.w600 : null),
                    ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _progress(crm, c),
                  const SizedBox(width: 10),
                  CompanyTag(c.company),
                  if (showStylist && c.stylistName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(c.stylistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
