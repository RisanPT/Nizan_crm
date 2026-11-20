import 'package:flutter/material.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_list_kit.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show NameOption;

/// Desktop Artist Finance → Collections: four totals, then ONE card with the filters across the top
/// (search · Filters · sort · page size, status chips, what is switched on), the breakdown and the
/// table. Real data only, and no horizontal scrolling — see [ArtistFinanceExpensesView], which is
/// built the same way.
class ArtistFinanceCollectionsView extends StatelessWidget {
  final FinancePage<ArtistCollection>? data;
  final FinanceQuery query;
  final ValueChanged<FinanceQuery> onQueryChanged;

  /// The artists the list can be narrowed to (empty = an artist sees only their own, no picker).
  final List<NameOption> artists;
  final VoidCallback onExport;
  final ValueChanged<ArtistCollection> onVerify;
  final ValueChanged<ArtistCollection> onReject;
  final ValueChanged<ArtistCollection> onEdit;
  final ValueChanged<ArtistCollection> onDelete;
  final ValueChanged<String> onViewReceipt;
  final bool canVerify;

  /// A page is being fetched / failed to load (the last page that did load stays on screen).
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  /// The totals of the period just before this one, for "vs Oct"; null = nothing to compare.
  final FinanceSummary? previous;
  final String previousLabel;

  const ArtistFinanceCollectionsView({
    super.key,
    required this.data,
    required this.query,
    required this.onQueryChanged,
    required this.artists,
    required this.onExport,
    required this.onVerify,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onViewReceipt,
    this.canVerify = true,
    this.loading = false,
    this.error,
    this.onRetry,
    this.previous,
    this.previousLabel = 'last period',
  });

  static const _columns = [
    AfColumn('Date', width: 104),
    AfColumn('Artist', flex: 3),
    AfColumn('Client / Booking', flex: 3),
    AfColumn('Payment', width: 120),
    AfColumn('Notes', flex: 2),
    AfColumn('Amount', width: 96, right: true),
    AfColumn('Status', width: 112),
    AfColumn('', width: 44),
  ];

  @override
  Widget build(BuildContext context) {
    final s = data?.summary;
    final total = s?.allAmount ?? 0.0;
    String pct(double part) => '${total > 0 ? (part / total * 100).round() : 0}% of total';
    final delta = s == null
        ? null
        : afDeltaText(current: total, previous: previous?.allAmount, previousLabel: previousLabel, higherIsGood: true);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfKpiRow(
            cards: [
              AfKpiCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AfTheme.green,
                iconBgColor: AfTheme.greenLight,
                title: 'Total Collections',
                value: AfTheme.formatCurrency(total),
                subtext: delta?.text ?? (s == null ? null : '${s.allCount} ${s.allCount == 1 ? 'collection' : 'collections'}'),
                subtextColor: delta?.color ?? AfTheme.textSecondary,
              ),
              AfKpiCard(
                icon: Icons.verified_outlined,
                iconColor: AfTheme.green,
                iconBgColor: AfTheme.greenLight,
                title: 'Verified',
                value: AfTheme.formatCurrency(s?.status('verified').amount ?? 0),
                subtext: s == null ? null : '${s.status('verified').count} · ${pct(s.status('verified').amount)}',
                subtextColor: AfTheme.green,
              ),
              AfKpiCard(
                icon: Icons.hourglass_empty,
                iconColor: AfTheme.yellow,
                iconBgColor: AfTheme.yellowLight,
                title: 'Pending',
                value: AfTheme.formatCurrency(s?.status('pending').amount ?? 0),
                subtext: s == null ? null : '${s.status('pending').count} · ${pct(s.status('pending').amount)}',
                subtextColor: AfTheme.yellow,
              ),
              AfKpiCard(
                icon: Icons.cancel_outlined,
                iconColor: AfTheme.red,
                iconBgColor: AfTheme.redLight,
                title: 'Rejected',
                value: AfTheme.formatCurrency(s?.status('rejected').amount ?? 0),
                subtext: s == null ? null : '${s.status('rejected').count} · ${pct(s.status('rejected').amount)}',
                subtextColor: AfTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AfListPanel<ArtistCollection>(
            title: 'Collections',
            noun: 'collections',
            data: data,
            query: query,
            onQueryChanged: onQueryChanged,
            loading: loading,
            error: error,
            onRetry: onRetry,
            onExport: onExport,
            emptyIcon: Icons.payments_outlined,
            emptyHint: 'Payments the artists collect from clients will appear here.',
            controls: AfListControls(
              kind: FinanceKind.collection,
              query: query,
              summary: s,
              onChanged: onQueryChanged,
              artists: artists,
              searchHint: 'Search client, artist, service, booking no., notes or amount',
            ),
            breakdown: s == null
                ? null
                : AfBreakdownTile(
                    storageKey: 'afCollectionBreakdown',
                    groups: [
                      BreakdownGroup(
                        title: 'By payment mode',
                        rows: s.byMode,
                        keyPrefix: 'mode',
                        labels: kCollectionModeLabels,
                        isOn: (r) => query.paymentModes.contains(r.key),
                        onTap: (r) => onQueryChanged(query.refiltered(paymentModes: _toggle(query.paymentModes, r.key))),
                      ),
                      if (artists.isNotEmpty)
                        BreakdownGroup(
                          title: 'By artist',
                          rows: s.byArtist,
                          keyPrefix: 'artist',
                          isOn: (r) => query.employeeId == r.key,
                          onTap: (r) => onQueryChanged(query.refiltered(employeeId: query.employeeId == r.key ? null : r.key)),
                        ),
                    ],
                  ),
            table: (items) => AfTable<ArtistCollection>(
              columns: _columns,
              items: items,
              rowKey: (c) => Key('afCollectionRow_${c.id}'),
              cells: _cells,
              card: _card,
            ),
          ),
        ],
      ),
    );
  }

  static Set<String> _toggle(Set<String> current, String key) {
    final next = {...current};
    next.contains(key) ? next.remove(key) : next.add(key);
    return next;
  }

  // ── what a row says ────────────────────────────────────────────────────────

  String _artist(ArtistCollection c) => c.employee?.name ?? 'Artist';

  String _client(ArtistCollection c) => c.booking?.customerName ?? c.trial?.clientName ?? 'Direct client';

  /// Booking / trial number, and the service for a booking.
  String _ref(ArtistCollection c) {
    final b = c.booking;
    if (b != null) return [if (b.bookingNumber.isNotEmpty) b.bookingNumber, if (b.service.isNotEmpty) b.service].join(' · ');
    final t = c.trial;
    return t == null ? '' : [if (t.trialNumber.isNotEmpty) t.trialNumber, 'Trial'].join(' · ');
  }

  String _mode(ArtistCollection c) => kCollectionModeLabels[c.paymentMode] ?? c.paymentMode;

  List<Widget> _cells(ArtistCollection c) {
    final ref = _ref(c);
    final notes = c.notes.trim();
    return [
      AfCellText(afDay(c.date), muted: true),
      Row(
        children: [
          AfInitialsAvatar(name: _artist(c), size: 26),
          const SizedBox(width: 8),
          Expanded(child: AfCellText(_artist(c), strong: true)),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfCellText(_client(c), strong: true),
          if (ref.isNotEmpty) AfCellText(ref, muted: true),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payment, size: 13, color: AfTheme.textSecondary),
          const SizedBox(width: 5),
          Flexible(child: AfCellText(_mode(c), muted: true)),
        ],
      ),
      AfCellText(notes.isEmpty ? '—' : notes, muted: true),
      AfCellText(AfTheme.formatCurrency(c.amount), strong: true),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfFit(AfStatusBadge(status: c.status)),
          if (c.status == 'verified' && (c.verifiedByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            AfCellText('by ${c.verifiedByName}', muted: true),
          ],
        ],
      ),
      _menu(c),
    ];
  }

  Widget _card(ArtistCollection c) {
    final ref = _ref(c);
    final notes = c.notes.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AfInitialsAvatar(name: _artist(c), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AfCellText(_artist(c), strong: true),
                  AfCellText([_client(c), if (ref.isNotEmpty) ref].join(' · '), muted: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AfCellText(AfTheme.formatCurrency(c.amount), strong: true),
            _menu(c),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AfCellText(afDay(c.date), muted: true),
            AfCellText(_mode(c), muted: true),
            AfStatusBadge(status: c.status),
          ],
        ),
        if (notes.isNotEmpty) ...[const SizedBox(height: 6), AfCellText(notes, muted: true, maxLines: 2)],
      ],
    );
  }

  Widget _menu(ArtistCollection c) => PopupMenuButton<String>(
        key: Key('afCollectionMenu_${c.id}'),
        tooltip: 'Actions',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz, size: 18, color: AfTheme.textSecondary),
        onSelected: (v) {
          switch (v) {
            case 'receipt':
              onViewReceipt(c.attachmentUrl!);
            case 'verify':
              onVerify(c);
            case 'reject':
              onReject(c);
            case 'edit':
              onEdit(c);
            case 'delete':
              onDelete(c);
          }
        },
        itemBuilder: (_) => [
          if (c.attachmentUrl != null && c.attachmentUrl!.isNotEmpty) const PopupMenuItem(value: 'receipt', child: Text('View attachment')),
          if (canVerify && c.status == 'pending') ...const [
            PopupMenuItem(value: 'verify', child: Text('Verify collection')),
            PopupMenuItem(value: 'reject', child: Text('Reject collection')),
          ],
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
}
