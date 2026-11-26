import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/stylist_client.dart';
import '../../services/stylist_client_service.dart';
import '../widgets/stylist_client_ui.dart';

/// Royal package clients: upcoming Team N Royal bookings (the package
/// includes a stylist). "Waiting" = no client file yet — a stylist takes one
/// in a tap and every detail fills in from the booking; "Taken" = already
/// someone's client. Adding clients by hand (New client) is unchanged.
class RoyalClientsScreen extends ConsumerStatefulWidget {
  const RoyalClientsScreen({super.key});

  @override
  ConsumerState<RoyalClientsScreen> createState() => _RoyalClientsScreenState();
}

class _RoyalClientsScreenState extends ConsumerState<RoyalClientsScreen> {
  final _search = TextEditingController();
  String _q = '';
  bool _showTaken = false;
  final _busy = <String>{}; // bookingIds being added

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(RoyalBooking b) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    final digits = _q.replaceAll(RegExp(r'\D'), '');
    return b.name.toLowerCase().contains(q) ||
        b.bookingNumber.toLowerCase().contains(q) ||
        (digits.length >= 3 && b.phone.replaceAll(RegExp(r'\D'), '').contains(digits));
  }

  /// A stylist lead may give the client to someone else; null = cancelled.
  Future<String?> _pickOwner(RoyalBooking b) async {
    final myId = ref.read(authSessionProvider)?.userId ?? '';
    final stylists = await ref.read(consultationStylistsProvider.future);
    if (!mounted) return null;
    var chosen = myId;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Add ${b.name.isEmpty ? 'client' : b.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Whose client should this be?'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: chosen,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stylist', border: OutlineInputBorder(), isDense: true),
              items: [
                DropdownMenuItem(value: myId, child: const Text('Me')),
                for (final s in stylists.where((s) => s.id != myId))
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setD(() => chosen = v ?? myId),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, chosen), child: const Text('Add client')),
          ],
        ),
      ),
    );
  }

  Future<void> _take(RoyalBooking b) async {
    final isLead = ref.read(effectiveAccessProvider).canSeeConsultationReports;
    String? stylistId;
    if (isLead) {
      final picked = await _pickOwner(b);
      if (picked == null) return;
      final myId = ref.read(authSessionProvider)?.userId ?? '';
      stylistId = picked == myId ? null : picked;
    }
    setState(() => _busy.add(b.bookingId));
    try {
      final saved = await ref
          .read(stylistClientServiceProvider)
          .createTeamN(from: b.toCandidate(), stylistId: stylistId);
      ref.refreshData.consultations();
      if (!mounted) return;
      showSuccessSnackBar(context, '${saved.name.isEmpty ? 'Client' : saved.name} added — details filled from the booking');
      context.push('/stylist/clients/${saved.id}');
    } on ClientExistsException catch (e) {
      ref.refreshData.consultations();
      if (mounted) showWarningSnackBar(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(b.bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(royalBookingsProvider);
    final all = async.value ?? const <RoyalBooking>[];
    final waiting = all.where((b) => !b.hasClient).length;
    final taken = all.length - waiting;
    final rows = all.where((b) => b.hasClient == _showTaken && _matches(b)).toList();

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.workspace_premium_outlined, color: crm.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Royal package clients',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: crm.textPrimary)),
                      Text('Upcoming Team N Royal bookings — the package includes a stylist',
                          style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: false, label: Text('Waiting · $waiting')),
                      ButtonSegment(value: true, label: Text('Taken · $taken')),
                    ],
                    selected: {_showTaken},
                    onSelectionChanged: (s) => setState(() => _showTaken = s.first),
                  ),
                  ConstrainedBox(
                    // Fills the line on phones; capped on wide screens.
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Name, phone or booking no.',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: crm.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(royalBookingsProvider)),
            data: (_) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(royalBookingsProvider),
              child: rows.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 70),
                      Icon(
                          _q.isNotEmpty
                              ? Icons.search_off
                              : (!_showTaken && taken > 0 ? Icons.task_alt : Icons.workspace_premium_outlined),
                          size: 48,
                          color: !_showTaken && taken > 0 && _q.isEmpty ? crm.success : crm.textSecondary),
                      const SizedBox(height: 10),
                      Text(
                        _q.isNotEmpty
                            ? 'No match for "$_q"'
                            : _showTaken
                                ? 'No Royal clients taken yet'
                                : taken > 0
                                    ? 'All caught up — every Royal client has a stylist'
                                    : 'No upcoming Royal bookings',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          _q.isNotEmpty
                              ? 'Try a name, phone or booking number.'
                              : 'New Royal bookings appear here automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
                      if (!_showTaken && taken > 0 && _q.isEmpty) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() => _showTaken = true),
                            child: Text('See the $taken taken'),
                          ),
                        ),
                      ],
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: _card(crm, rows[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _card(CrmTheme crm, RoyalBooking b) {
    final today = DateTime.now();
    final daysTo = b.nextEventDay == null
        ? null
        : DateTime(b.nextEventDay!.year, b.nextEventDay!.month, b.nextEventDay!.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
    final busy = _busy.contains(b.bookingId);
    final meta = [
      if (b.eventDates.isNotEmpty) fmtEventDays(b.eventDates),
      if (b.eventSlot.isNotEmpty) b.eventSlot,
      if (b.venue.isNotEmpty) b.venue,
      if (b.district.isNotEmpty) b.district,
      if (b.bookingNumber.isNotEmpty) '#${b.bookingNumber}',
      if (b.phone.isNotEmpty) b.phone,
    ].join(' · ');

    Widget action;
    if (!b.hasClient) {
      action = FilledButton.icon(
        onPressed: busy ? null : () => _take(b),
        icon: busy
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.person_add_alt_1_outlined, size: 18),
        label: const Text('Add as client'),
      );
    } else if (b.clientIsOwn) {
      action = OutlinedButton.icon(
        onPressed: () => context.push('/stylist/clients/${b.clientId}'),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open client'),
      );
    } else {
      action = const SizedBox.shrink();
    }

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(b.name.isEmpty ? 'Client' : b.name,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: crm.textPrimary)),
        _tag(b.packageName.isEmpty ? 'Team N Royal' : b.packageName, crm.primary),
        if (daysTo != null) _tag(fmtDaysToEvent(daysTo), daysTo <= 7 ? crm.warning : crm.accent),
        if (b.hasClient) _tag(b.stylistName.isEmpty ? 'Taken' : 'Stylist: ${b.stylistName}', crm.success),
      ]),
      if (meta.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(meta, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ),
      if (b.artistNames.isNotEmpty)
        Text('Artists: ${b.artistNames.join(', ')}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
    ]);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 600) {
          return Row(children: [Expanded(child: info), const SizedBox(width: 12), action]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          info,
          if (action is! SizedBox) ...[const SizedBox(height: 10), action],
        ]);
      }),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}

/// Banner for My Clients: how many Royal bookings are waiting for a stylist.
class RoyalWaitingBanner extends ConsumerWidget {
  const RoyalWaitingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final waiting = (ref.watch(royalBookingsProvider).value ?? const <RoyalBooking>[])
        .where((b) => !b.hasClient)
        .length;
    if (waiting == 0) return const SizedBox.shrink();
    return Material(
      color: crm.primary.withValues(alpha: 0.07),
      child: InkWell(
        onTap: () => context.go('/stylist/royal'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.workspace_premium_outlined, size: 20, color: crm.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$waiting Royal package ${waiting == 1 ? 'client is' : 'clients are'} waiting for a stylist',
                style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            Text('View', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w700)),
            Icon(Icons.chevron_right, color: crm.primary),
          ]),
        ),
      ),
    );
  }
}
