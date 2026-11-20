import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show FinancePeriod, NameOption, rupeesWhole;
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';

// The pieces the desktop Artist Finance lists (Expenses, Collections) are built from. They exist
// so that a list NEVER needs a horizontal scrollbar:
//   • the filters are one toolbar above the table (search · Filters · sort · page size · status
//     chips · what is switched on) — the same real controls the phone uses — not a side panel
//     that eats a fifth of the width;
//   • the table is a row of flexible columns that share whatever width there is, and on a window
//     too narrow for that it turns into a list of cards.

/// KPI cards: one row on a wide window, wrapping on a narrow one.
class AfKpiRow extends StatelessWidget {
  final List<Widget> cards;
  const AfKpiRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        // two to a row on a narrow window
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

/// The stretch of days just before the period on screen — the month before a month, the same number
/// of days before a custom range — to put a total next to ("vs Oct"). Null for "All time" (nothing
/// comes before it) and for a custom range that has not been picked yet.
({String from, String to, String label})? priorStretch(FinancePeriod period, DateTime month, DateTimeRange? range) {
  String d(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  switch (period) {
    case FinancePeriod.all:
      return null;
    case FinancePeriod.month:
      final before = DateTime(month.year, month.month - 1);
      final (from, to) = FinanceQuery.monthBounds(before);
      return (from: from, to: to, label: DateFormat('MMM').format(before));
    case FinancePeriod.range:
      if (range == null) return null;
      final days = range.end.difference(range.start).inDays + 1;
      final end = DateTime(range.start.year, range.start.month, range.start.day - 1);
      final start = DateTime(end.year, end.month, end.day - (days - 1));
      return (from: d(start), to: d(end), label: 'the $days days before');
  }
}

/// "↑ 12% vs Oct (₹38,120)" — how this period's total compares with the one before it; null when
/// there is nothing to compare against (no earlier period, or it had no entries). [higherIsGood]
/// decides the colour: more collected is good, more spent is not.
({String text, Color color})? afDeltaText({
  required double current,
  required double? previous,
  required String previousLabel,
  required bool higherIsGood,
}) {
  if (previous == null || previous <= 0) return null;
  final pct = ((current - previous) / previous * 100).round();
  if (pct == 0) return (text: 'Same as $previousLabel (${rupeesWhole(previous)})', color: AfTheme.textSecondary);
  final up = pct > 0;
  final good = up == higherIsGood;
  return (
    text: '${up ? '↑ +' : '↓ '}${pct.abs()}% vs $previousLabel (${rupeesWhole(previous)})',
    color: good ? AfTheme.green : AfTheme.red,
  );
}

/// The search / filters / sort / page-size toolbar, the status chips and the chips for what is
/// switched on — for one list. Every change goes back through [onChanged] as the next query.
class AfListControls extends StatelessWidget {
  final FinanceKind kind;
  final FinanceQuery query;
  final FinanceSummary? summary;
  final ValueChanged<FinanceQuery> onChanged;

  /// The artists the list can be narrowed to (empty = the artist picker is hidden).
  final List<NameOption> artists;
  final String searchHint;

  const AfListControls({
    super.key,
    required this.kind,
    required this.query,
    required this.summary,
    required this.onChanged,
    this.artists = const [],
    required this.searchHint,
  });

  /// Everything but the period.
  FinanceQuery get _cleared => FinanceQuery(from: query.from, to: query.to, sort: query.sort, limit: query.limit, withWorks: query.withWorks);

  Future<void> _openFilters(BuildContext context) async {
    final next = await showFinanceFilters(
      context,
      kind: kind,
      current: query,
      artists: artists.isEmpty ? null : artists,
    );
    if (next != null) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceToolbar(
          search: query.search,
          onSearch: (t) => onChanged(query.refiltered(search: t)),
          hint: searchHint,
          advancedCount: query.advancedCount,
          onFilters: () => _openFilters(context),
          sort: query.sort,
          onSort: (v) => onChanged(query.refiltered(sort: v)),
          limit: query.limit,
          onLimit: (n) => onChanged(query.refiltered(limit: n)),
        ),
        const SizedBox(height: 10),
        FinanceStatusChips(
          summary: summary,
          selected: query.statuses,
          onChanged: (st) => onChanged(query.refiltered(statuses: st)),
        ),
        if (query.isFiltered) ...[
          const SizedBox(height: 10),
          FinanceActiveChips(
            query: query,
            kind: kind,
            artistName: artists.where((a) => a.id == query.employeeId).map((a) => a.name).firstOrNull,
            onChanged: onChanged,
            onClearAll: () => onChanged(_cleared),
          ),
        ],
      ],
    );
  }
}

/// "Breakdown": where the money went across the whole filtered list; tapping a chip filters to it.
/// Open by default on a desktop; folds away to leave room for the table.
class AfBreakdownTile extends StatelessWidget {
  final String storageKey;
  final List<BreakdownGroup> groups;
  const AfBreakdownTile({super.key, required this.storageKey, required this.groups});

  @override
  Widget build(BuildContext context) {
    if (groups.every((g) => g.rows.isEmpty)) return const SizedBox.shrink();
    // A Material of its own: the card around it is a coloured box, which would hide the tile's ink.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(storageKey),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          initiallyExpanded: true,
          dense: true,
          title: const Text(
            'Breakdown',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
          ),
          children: [FinanceBreakdown(groups: groups)],
        ),
      ),
    );
  }
}

/// One column of an [AfTable]: [width] fixed, or else a share ([flex]) of what is left.
class AfColumn {
  final String label;
  final int flex;
  final double? width;
  final bool right;
  const AfColumn(this.label, {this.flex = 1, this.width, this.right = false});
}

/// A table whose columns share the width there is, so it never scrolls sideways. Below [minWidth]
/// it lists [card]s instead — one per item — which also suits a phone-sized window.
class AfTable<T> extends StatelessWidget {
  final List<AfColumn> columns;
  final List<T> items;

  /// One widget per column, in order. Each must cope with a narrow cell (ellipsis, not overflow).
  final List<Widget> Function(T item) cells;
  final Widget Function(T item) card;
  final Key Function(T item) rowKey;
  final double minWidth;

  const AfTable({
    super.key,
    required this.columns,
    required this.items,
    required this.cells,
    required this.card,
    required this.rowKey,
    this.minWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < minWidth) {
          return Column(
            children: [
              for (final item in items)
                Container(
                  key: rowKey(item),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AfTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AfTheme.border),
                  ),
                  child: card(item),
                ),
            ],
          );
        }
        Widget cell(AfColumn col, Widget child) {
          final aligned = Align(alignment: col.right ? Alignment.centerRight : Alignment.centerLeft, child: child);
          return col.width != null ? SizedBox(width: col.width, child: aligned) : Expanded(flex: col.flex, child: aligned);
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: const BoxDecoration(
                color: AfTheme.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(bottom: BorderSide(color: AfTheme.border)),
              ),
              child: Row(
                children: [
                  for (final col in columns)
                    cell(
                      col,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          col.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AfTheme.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final item in items)
              Container(
                key: rowKey(item),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AfTheme.border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final (i, w) in cells(item).indexed)
                      cell(columns[i], Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: w)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A line of text in a table cell: one line, ellipsis, never overflowing its column.
class AfCellText extends StatelessWidget {
  final String text;
  final bool strong;
  final bool muted;
  final Color? color;
  final int maxLines;
  const AfCellText(this.text, {super.key, this.strong = false, this.muted = false, this.color, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: strong ? 12.5 : (muted ? 11 : 12),
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          color: color ?? (muted ? AfTheme.textSecondary : AfTheme.textPrimary),
        ),
      );
}

/// A badge in a fixed-width cell: shrinks a little rather than overflowing the column.
class AfFit extends StatelessWidget {
  final Widget child;
  const AfFit(this.child, {super.key});

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child);
}

/// "08 Nov 2026" — the day an entry is for.
String afDay(DateTime d) => DateFormat('dd MMM yyyy').format(d);

/// What to show instead of a list that has nothing in it (or nothing that matches).
class AfEmptyList extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AfEmptyList({super.key, required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AfTheme.textMuted),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AfTheme.textSecondary)),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The card a desktop list sits in: a header (title, how many and how much, Export), the controls,
/// the breakdown, then the table — or a spinner / an empty message — and the pager under it.
/// The one place the loading, failed-to-load and empty states of both lists are decided.
class AfListPanel<T> extends StatelessWidget {
  final String title;

  /// Plural, lower case: 'expenses' — for "134 expenses · ₹1,23,456" and the empty message.
  final String noun;
  final FinancePage<T>? data;
  final FinanceQuery query;
  final ValueChanged<FinanceQuery> onQueryChanged;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback onExport;
  final Widget controls;
  final Widget? breakdown;
  final IconData emptyIcon;

  /// Said under "No (noun) in this period" when nothing is filtered.
  final String emptyHint;

  /// The table for one page of items.
  final Widget Function(List<T> items) table;

  const AfListPanel({
    super.key,
    required this.title,
    required this.noun,
    required this.data,
    required this.query,
    required this.onQueryChanged,
    required this.onExport,
    required this.controls,
    required this.table,
    required this.emptyIcon,
    required this.emptyHint,
    this.loading = false,
    this.error,
    this.onRetry,
    this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    final filtered = query.isFiltered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 3)),
        if (error != null && !loading && onRetry != null)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: FinanceLoadError(error: error!, onRetry: onRetry!)),
        AfCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AfTheme.textPrimary)),
                  const SizedBox(width: 12),
                  // takes the rest of the row, so Export sits at the right edge
                  Expanded(
                    child: d == null
                        ? const SizedBox.shrink()
                        : Text(
                            financeTotalText(total: d.totalItems, amount: d.summary?.shownAmount, noun: noun),
                            key: const Key('afListTotal'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AfTheme.textSecondary),
                          ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('afListExport'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AfTheme.textPrimary,
                      side: const BorderSide(color: AfTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: onExport,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              controls,
              if (breakdown != null) ...[const SizedBox(height: 6), breakdown!],
              const SizedBox(height: 8),
              if (d == null)
                const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
              else if (d.items.isEmpty)
                AfEmptyList(
                  icon: emptyIcon,
                  title: filtered ? 'No matching $noun' : 'No $noun in this period',
                  subtitle: filtered ? 'Try a different search or clear the filters.' : emptyHint,
                  actionLabel: filtered ? 'Clear filters' : null,
                  onAction: filtered
                      ? () => onQueryChanged(FinanceQuery(from: query.from, to: query.to, sort: query.sort, limit: query.limit, withWorks: query.withWorks))
                      : null,
                )
              else
                table(d.items),
            ],
          ),
        ),
        if (d != null && d.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          PaginatedFooter(
            page: d.page,
            limit: d.limit,
            totalPages: d.totalPages,
            totalItems: d.totalItems,
            currentItemCount: d.items.length,
            onPrevious: d.page > 1 ? () => onQueryChanged(query.copyWith(page: d.page - 1)) : null,
            onNext: d.page < d.totalPages ? () => onQueryChanged(query.copyWith(page: d.page + 1)) : null,
          ),
        ],
      ],
    );
  }
}
