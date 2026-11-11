import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../data/stylist_client.dart';
import '../../services/stylist_client_service.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/reference_images.dart';
import '../widgets/stylist_client_ui.dart';

/// Wide enough for the call strip, inline actions and two columns.
const _wideBreakpoint = 900.0;

/// One client. The header card leads with the event and holds labelled
/// actions: the main one books the next free call; Call, WhatsApp and the
/// report PDF sit beside it; the rest (edit, refresh from booking, status) are
/// in More. Then the call series, grouped details and reference images. On a
/// phone the main action and More are pinned to the bottom, and details and
/// images start closed.
class StylistClientScreen extends ConsumerWidget {
  const StylistClientScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(stylistClientProvider(clientId));
    final c = async.value;

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wideBreakpoint;
      return Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/stylist/clients'),
          ),
          title: c == null
              ? const Text('Client')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name.isEmpty ? 'Client' : c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (c.clientNo.isNotEmpty)
                      Text('Client no. ${c.clientNo}',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w400)),
                  ],
                ),
        ),
        bottomNavigationBar: !wide && c != null ? _BottomActions(client: c) : null,
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(stylistClientProvider(clientId))),
          data: (c) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(stylistClientProvider(clientId)),
            child: _Body(client: c, wide: wide),
          ),
        ),
      );
    });
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────
/// The call slots of a client: every required call plus any extra ones booked.
class _Slots {
  _Slots(StylistClient c)
      : numbered = {for (final call in c.calls) if (call.callNumber != null) call.callNumber!: call},
        notCounted = c.calls.where((x) => x.callNumber == null).toList(),
        required = c.requiredCalls,
        canBook = c.status != 'Cancelled' {
    final highest = numbered.keys.fold<int>(0, (m, n) => n > m ? n : m);
    count = highest > required ? highest : required;
    firstFree = [for (var n = 1; n <= count; n++) n].where((n) => !numbered.containsKey(n)).firstOrNull;
  }

  final Map<int, Consultation> numbered;
  final List<Consultation> notCounted;
  final int required;
  final bool canBook;
  late final int count;
  late final int? firstFree;

  /// The number the next booking gets: the first free slot, else an extra.
  int get nextNumber => firstFree ?? count + 1;
  String label(int n) => n <= required ? 'Call $n' : 'Extra call $n';

  /// "Schedule call 3" or "Schedule extra call 5".
  String get scheduleLabel => 'Schedule ${label(nextNumber).toLowerCase()}';
}

void _schedule(BuildContext context, StylistClient c) => context.push('/consultations/new?clientId=${c.id}');

Future<void> _refresh(BuildContext context, WidgetRef ref, StylistClient c) async {
  try {
    await ref.read(stylistClientServiceProvider).refresh(c.id);
    ref.refreshData.consultations();
    if (context.mounted) showSuccessSnackBar(context, 'Updated from the booking');
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

Future<void> _setStatus(BuildContext context, WidgetRef ref, StylistClient c, String status) async {
  final (title, body) = switch (status) {
    'Completed' => ('Mark ${c.name} completed?', 'Use this when their event is done. You can reopen the client later.'),
    'Cancelled' => ('Cancel ${c.name}?', 'They leave your active clients and no new calls can be booked until reopened.'),
    _ => ('Reopen ${c.name}?', 'They will show in your active clients again.'),
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(stylistClientServiceProvider).update(c.id, {'status': status});
    ref.refreshData.consultations();
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

/// The main button: book the next call (not for a cancelled client).
Widget? _primaryButton(BuildContext context, StylistClient c, {bool expand = false}) {
  final slots = _Slots(c);
  if (!slots.canBook) return null;
  return FilledButton.icon(
    onPressed: () => _schedule(context, c),
    style: expand ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)) : null,
    icon: const Icon(Icons.event_available_outlined, size: 18),
    label: Text(slots.scheduleLabel),
  );
}

/// "More ▾": edit, refresh from booking, then the client's status (Cancel last, in red).
class _MoreButton extends ConsumerWidget {
  const _MoreButton({required this.client, this.up = false});

  final StylistClient client;
  final bool up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final c = client;
    PopupMenuItem<String> item(String value, IconData icon, String text, {bool danger = false}) => PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18, color: danger ? crm.destructive : crm.textSecondary),
              const SizedBox(width: 10),
              Flexible(child: Text(text, style: TextStyle(color: danger ? crm.destructive : crm.textPrimary))),
            ],
          ),
        );
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      position: up ? PopupMenuPosition.over : PopupMenuPosition.under,
      onSelected: (v) => switch (v) {
        'edit' => context.push('/stylist/clients/${c.id}/edit'),
        'refresh' => _refresh(context, ref, c),
        _ => _setStatus(context, ref, c, v),
      },
      itemBuilder: (_) => [
        item('edit', Icons.edit_outlined, 'Edit details'),
        if (c.isTeamN) item('refresh', Icons.sync, 'Refresh from booking'),
        const PopupMenuDivider(),
        if (c.status != 'Completed') item('Completed', Icons.task_alt, 'Mark client completed'),
        if (c.status != 'Active') item('Active', Icons.replay, 'Reopen client'),
        if (c.status != 'Cancelled') item('Cancelled', Icons.cancel_outlined, 'Cancel client', danger: true),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('More', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(up ? Icons.expand_less : Icons.expand_more, size: 18, color: crm.primary),
          ],
        ),
      ),
    );
  }
}

/// Downloads the client report PDF (save on a computer, share on a phone).
class _ReportButton extends ConsumerStatefulWidget {
  const _ReportButton({required this.client, this.label = 'Report PDF'});

  final StylistClient client;
  final String label;

  @override
  ConsumerState<_ReportButton> createState() => _ReportButtonState();
}

class _ReportButtonState extends ConsumerState<_ReportButton> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(stylistClientServiceProvider).downloadReport(widget.client.id);
      final safe = widget.client.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
      await Printing.sharePdf(bytes: bytes, filename: 'Client_Report_${safe.isEmpty ? 'Client' : safe}.pdf');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _download,
      icon: _busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(widget.label),
    );
  }
}

/// Phone: the main button and More, pinned to the bottom.
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.client});

  final StylistClient client;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final primary = _primaryButton(context, client, expand: true);
    return Container(
      decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (primary != null) ...[Expanded(child: primary), const SizedBox(width: 10)] else const Spacer(),
              _MoreButton(client: client, up: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body({required this.client, required this.wide});

  final StylistClient client;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final details = _DetailsCard(client: c, collapsible: !wide);
    final images = _ImagesCard(client: c, collapsible: !wide);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _HeaderCard(client: c, wide: wide),
            const SizedBox(height: 16),
            _CallsCard(client: c, wide: wide),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: details),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: images),
                ],
              )
            else ...[
              details,
              const SizedBox(height: 16),
              images,
            ],
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardBox(CrmTheme crm) => BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: crm.border),
    );

Widget _title(CrmTheme crm, String text) =>
    Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary));

/// A card whose body can start closed (phone) behind a tappable header.
class _Section extends StatefulWidget {
  const _Section({required this.title, this.trailing, required this.collapsible, required this.child});

  final String title;
  final Widget? trailing;
  final bool collapsible;
  final Widget child;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _open = !widget.collapsible;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final header = Row(
      children: [
        Expanded(child: _title(crm, widget.title)),
        ?widget.trailing,
        if (widget.collapsible) ...[
          const SizedBox(width: 6),
          Icon(_open ? Icons.expand_less : Icons.expand_more, color: crm.textSecondary),
        ],
      ],
    );
    return Container(
      width: double.infinity,
      decoration: _cardBox(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.collapsible
              ? InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 12, 14), child: header),
                )
              : Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 12), child: header),
          if (_open) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: widget.child),
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.client, required this.wide});

  final StylistClient client;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = client;
    final days = c.daysToEvent;
    final event = [
      if (c.eventType.isNotEmpty) c.eventType,
      if (c.eventDays.isNotEmpty) fmtEventDays(c.eventDays),
      if (c.eventSlot.isNotEmpty) c.eventSlot,
    ].join('  ·  ');
    final where = [
      if (c.venue.isNotEmpty) c.venue,
      if (c.stylistName.isNotEmpty) 'Stylist ${c.stylistName}',
    ].join('  ·  ');
    void call() => launchUrl(Uri.parse('tel:${c.phone}'));
    void chat() => launchUrl(Uri.https('wa.me', '/${whatsAppNumber(c.phone)}'), mode: LaunchMode.externalApplication);
    final iconStyle = IconButton.styleFrom(
      foregroundColor: crm.primary,
      backgroundColor: crm.surface,
      side: BorderSide(color: crm.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final primary = wide ? _primaryButton(context, c) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardBox(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CompanyTag(c.company),
              ConsultationStatusChip(c.status, color: clientStatusTone(crm, c.status)),
              if (days != null && c.isActive)
                ConsultationStatusChip(
                  '${c.eventType.isEmpty ? 'Event' : c.eventType} ${fmtDaysToEvent(days).toLowerCase()}',
                  color: days <= 14 ? crm.warning : crm.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(event.isEmpty ? 'No event date yet' : event,
              style: TextStyle(fontSize: wide ? 20 : 17, fontWeight: FontWeight.bold, color: crm.textPrimary)),
          if (where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.place_outlined, size: 16, color: crm.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(where, style: TextStyle(color: crm.textSecondary, fontSize: 13))),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ?primary,
              if (c.phone.isNotEmpty && wide) ...[
                OutlinedButton.icon(
                    onPressed: call, icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call')),
                OutlinedButton.icon(
                    onPressed: chat, icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('WhatsApp')),
              ],
              if (c.phone.isNotEmpty && !wide) ...[
                IconButton.outlined(
                    tooltip: 'Call', style: iconStyle, onPressed: call, icon: const Icon(Icons.call_outlined, size: 20)),
                IconButton.outlined(
                    tooltip: 'WhatsApp',
                    style: iconStyle,
                    onPressed: chat,
                    icon: const Icon(Icons.chat_outlined, size: 20)),
              ],
              _ReportButton(client: c, label: wide ? 'Report PDF' : 'Report'),
              if (wide) _MoreButton(client: c),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Calls ────────────────────────────────────────────────────────────────────
class _CallsCard extends StatefulWidget {
  const _CallsCard({required this.client, required this.wide});

  final StylistClient client;
  final bool wide;

  @override
  State<_CallsCard> createState() => _CallsCardState();
}

class _CallsCardState extends State<_CallsCard> {
  bool _showNotCounted = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = widget.client;
    final s = _Slots(c);
    final slots = [
      for (var n = 1; n <= s.count; n++)
        _SlotData(
          label: s.label(n),
          call: s.numbered[n],
          onSchedule: s.canBook && n == s.firstFree ? () => _schedule(context, c) : null,
        ),
    ];
    final notCounted = s.notCounted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _cardBox(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title(crm, 'Calls')),
              Text('${c.progress.done} of ${c.requiredCalls} done',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.wide)
            LayoutBuilder(builder: (context, box) {
              const gap = 10.0;
              final perRow = slots.length.clamp(1, 6);
              final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final d in slots) SizedBox(width: w, child: _SlotTile(data: d))],
              );
            })
          else
            Column(
              children: [
                for (final (i, d) in slots.indexed) _SlotRow(data: d, first: i == 0),
              ],
            ),
          if (s.canBook && s.firstFree == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                onPressed: () => _schedule(context, c),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Schedule extra call ${s.count + 1}'),
              ),
            ),
          if (notCounted.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _showNotCounted = !_showNotCounted),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Not counted: ${notCounted.length} cancelled or no-show',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                    ),
                    Icon(_showNotCounted ? Icons.expand_less : Icons.expand_more, size: 18, color: crm.textSecondary),
                  ],
                ),
              ),
            ),
            if (_showNotCounted)
              for (final (i, call) in notCounted.indexed)
                _SlotRow(data: _SlotData(label: call.status, call: call, muted: true), first: i == 0),
          ],
        ],
      ),
    );
  }
}

class _SlotData {
  const _SlotData({required this.label, this.call, this.onSchedule, this.muted = false});

  final String label;
  final Consultation? call;
  final VoidCallback? onSchedule;
  final bool muted;
}

(IconData, Color) _slotIcon(CrmTheme crm, _SlotData d) {
  final call = d.call;
  if (call == null) return (Icons.radio_button_unchecked, crm.textSecondary.withValues(alpha: 0.6));
  if (call.status == 'Completed') return (Icons.check_circle, crm.success);
  if (d.muted) return (Icons.remove_circle_outline, crm.textSecondary);
  return (Icons.schedule, crm.primary);
}

String _slotWhen(Consultation call) => call.status == 'Completed'
    ? [fmtShortDay(call.scheduledAt), if (call.stylistName.isNotEmpty) call.stylistName].join(' · ')
    : DateFormat('EEE d MMM, h:mm a').format(call.scheduledAt);

/// Desktop: one slot in the strip.
class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.data});

  final _SlotData data;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = data;
    final call = d.call;
    final (icon, color) = _slotIcon(crm, d);
    final borderColor = call == null
        ? crm.border
        : call.status == 'Completed'
            ? crm.success.withValues(alpha: 0.4)
            : crm.primary.withValues(alpha: 0.6);

    return Material(
      color: call == null ? crm.background : crm.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: call != null ? () => context.push('/consultations/${call.id}') : d.onSchedule,
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(d.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: call == null ? crm.textSecondary : color)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (call != null)
                Text(_slotWhen(call),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary))
              else
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Not booked'),
                    if (d.onSchedule != null)
                      TextSpan(
                        text: '  ·  Schedule',
                        style: TextStyle(color: crm.primary, fontWeight: FontWeight.w600),
                      ),
                  ]),
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone (and the "not counted" list): one slot as a row.
class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.data, required this.first});

  final _SlotData data;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = data;
    final call = d.call;
    final (icon, color) = _slotIcon(crm, d);
    return InkWell(
      onTap: call == null ? null : () => context.push('/consultations/${call.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: crm.border.withValues(alpha: 0.7))),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: d.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: call == null || d.muted ? crm.textSecondary : crm.textPrimary),
                  ),
                  TextSpan(
                    text: '  ·  ${call == null ? 'Not booked' : _slotWhen(call)}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (call == null && d.onSchedule != null)
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: d.onSchedule,
                child: const Text('Schedule'),
              )
            else if (call != null)
              Icon(Icons.chevron_right, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Details, grouped ─────────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.client, required this.collapsible});

  final StylistClient client;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = client;
    List<(String, String)> keep(List<(String, String)> items) => items.where((e) => e.$2.isNotEmpty).toList();
    final groups = <(String, List<(String, String)>)>[
      ('Contact', keep([('Phone', c.phone), ('Alternate phone', c.altPhone), ('Email', c.email)])),
      ('Event', keep([('Culture', c.culture), ('District', c.district)])),
      (
        'Booking',
        keep([
          ('Booking', c.bookingNumber),
          ('Package', c.packageName),
          ('Artists', c.artistNames.join(', ')),
        ])
      ),
    ].where((g) => g.$2.isNotEmpty).toList();
    final wideItems = keep([('Outfit details', c.outfitDetails), ('Notes', c.notes)]);

    Widget item(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              const SizedBox(height: 1),
              SelectableText(value, style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w500)),
            ],
          ),
        );
    Widget group((String, List<(String, String)>) g) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.$1.toUpperCase(),
                style: TextStyle(fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: crm.textSecondary)),
            const SizedBox(height: 6),
            for (final e in g.$2) item(e.$1, e.$2),
          ],
        );

    return _Section(
      title: 'Details',
      collapsible: collapsible,
      trailing: c.isTeamN && c.syncedAt != null
          ? Text(
              collapsible ? 'From booking, ${fmtShortDay(c.syncedAt!)}' : 'From booking · updated ${fmtShortDay(c.syncedAt!)}',
              style: TextStyle(fontSize: 11, color: crm.textSecondary),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth >= 480 ? 3 : 1;
          final w = (box.maxWidth - (cols - 1) * 16) / cols;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groups.isEmpty && wideItems.isEmpty)
                Text('No details yet. Use Edit details to add them.', style: TextStyle(color: crm.textSecondary)),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [for (final g in groups) SizedBox(width: w, child: group(g))],
              ),
              if (wideItems.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final e in wideItems) item(e.$1, e.$2),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Images ───────────────────────────────────────────────────────────────────
class _ImagesCard extends StatelessWidget {
  const _ImagesCard({required this.client, required this.collapsible});

  final StylistClient client;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final images = client.images;
    // Show which call each image came from when it has no caption of its own.
    final shown = [
      for (final i in images)
        ConsultationImage(
          id: i.image.id,
          url: i.image.url,
          caption: i.image.caption.isNotEmpty
              ? i.image.caption
              : (i.callNumber == null ? '' : 'From call ${i.callNumber}'),
          uploadedByName: i.image.uploadedByName,
          uploadedAt: i.image.uploadedAt,
        ),
    ];
    return _Section(
      title: 'Reference images · ${images.length}',
      collapsible: collapsible,
      child: images.isEmpty
          ? Text('Images added to any call show here.', style: TextStyle(color: crm.textSecondary))
          : ReferenceImageGrid(images: shown, size: 88),
    );
  }
}
