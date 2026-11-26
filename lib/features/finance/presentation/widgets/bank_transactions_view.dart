import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

// The STATEMENT of one bank / cash account, as it is shown on the Bank & Cash Balance screen (a
// short page beside the accounts) and on the full Transactions screen (the whole list). One widget for
// both, so they always read the same: the balance the list starts from, filters (money in / out,
// category, person, search), a table that never scrolls sideways — cards on a narrow window — a pager,
// and a tap on any row for everything known about it (who, which work, the bill, the voucher).

/// ₹1,23,456 — whole rupees unless there are paise, Indian grouping.
String bankInr(double v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: v % 1 == 0 ? 0 : 2).format(v);

/// "15 Nov 2026" ('—' for nothing).
String bankDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d.toLocal());

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The days a statement is for: a range, or (nothing set) "since the last balance entered" — the
/// transactions the live balance is made of.
@immutable
class BankPeriod {
  final DateTime? from;
  final DateTime? to;
  const BankPeriod({this.from, this.to});

  /// Since the last balance entered.
  static const sinceBalance = BankPeriod();

  factory BankPeriod.month(DateTime anyDay) => BankPeriod(from: DateTime(anyDay.year, anyDay.month, 1), to: DateTime(anyDay.year, anyDay.month + 1, 0));

  bool get isSinceBalance => from == null && to == null;
  String? get fromIso => from == null ? null : _iso(from!);
  String? get toIso => to == null ? null : _iso(to!);

  String get label => isSinceBalance
      ? 'Since last balance'
      : '${from == null ? '…' : DateFormat('dd MMM yyyy').format(from!)} – ${to == null ? '…' : DateFormat('dd MMM yyyy').format(to!)}';

  @override
  bool operator ==(Object other) => other is BankPeriod && other.fromIso == fromIso && other.toIso == toIso;

  @override
  int get hashCode => Object.hash(fromIso, toIso);
}

/// The period picker in the header: since the last balance, this month, last month, or any dates.
class BankPeriodButton extends StatelessWidget {
  final BankPeriod period;
  final ValueChanged<BankPeriod> onChanged;
  const BankPeriodButton({super.key, required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    return PopupMenuButton<String>(
      key: const Key('bankPeriod'),
      tooltip: 'Period',
      onSelected: (v) async {
        switch (v) {
          case 'since':
            onChanged(BankPeriod.sinceBalance);
          case 'this':
            onChanged(BankPeriod.month(now));
          case 'last':
            onChanged(BankPeriod.month(DateTime(now.year, now.month - 1)));
          case 'custom':
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDateRange: period.from != null && period.to != null ? DateTimeRange(start: period.from!, end: period.to!) : null,
            );
            if (picked != null) onChanged(BankPeriod(from: picked.start, to: picked.end));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'since', child: Text('Since last balance')),
        PopupMenuItem(value: 'this', child: Text('This month')),
        PopupMenuItem(value: 'last', child: Text('Last month')),
        PopupMenuItem(value: 'custom', child: Text('Custom dates…')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: crm.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                period.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// The headers and one row per transaction of a statement export.
const kBankStatementHeaders = ['Date', 'Particulars', 'Who / work', 'Reference / voucher', 'Type', 'Money in', 'Money out', 'Balance', 'Notes'];

List<List<String>> bankStatementRows(List<BankTxn> rows) => [
      for (final t in rows)
        [
          bankDate(t.date),
          t.heading,
          t.whoLine,
          [t.voucherNo, t.reference].where((x) => x.isNotEmpty).join(' / '),
          t.kindLabel,
          t.moneyIn > 0 ? t.moneyIn.toStringAsFixed(2) : '',
          t.moneyOut > 0 ? t.moneyOut.toStringAsFixed(2) : '',
          t.balance == null ? '' : t.balance!.toStringAsFixed(2),
          t.notes,
        ],
    ];

/// Downloads every transaction that matches [query] — CSV or PDF.
Future<void> exportBankStatement(BuildContext context, WidgetRef ref, BankAccount account, BankTxnQuery query, {required bool pdf}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final all = await ref.read(bankAccountServiceProvider).exportStatement(query);
    if (all.rows.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('No transactions to export for this period.')));
      return;
    }
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final name = account.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final data = bankStatementRows(all.rows);
    if (pdf) {
      await ExportUtils.exportPdf('statement_${name}_$stamp.pdf', '${account.name} — transactions', kBankStatementHeaders, data);
    } else {
      await ExportUtils.exportCsv('statement_${name}_$stamp.csv', [kBankStatementHeaders, ...data]);
    }
    messenger.showSnackBar(SnackBar(content: Text('Exported ${all.rows.length} transaction${all.rows.length == 1 ? '' : 's'}.')));
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

class BankTransactionsView extends ConsumerStatefulWidget {
  final BankAccount account;
  final BankPeriod period;

  /// Rows per page: a short page beside the accounts, a long one on the full screen.
  final int pageSize;

  /// Shown under the list ("View all transactions") when this is the short version.
  final VoidCallback? onViewAll;

  /// Told the query on screen whenever it changes, so the screen's Export uses the same filters.
  final ValueChanged<BankTxnQuery>? onQueryChanged;

  /// The strip saying which balance the list starts from. Off where the screen already says it.
  final bool showOpening;

  const BankTransactionsView({
    super.key,
    required this.account,
    this.period = BankPeriod.sinceBalance,
    this.pageSize = 25,
    this.onViewAll,
    this.onQueryChanged,
    this.showOpening = true,
  });

  @override
  ConsumerState<BankTransactionsView> createState() => _BankTransactionsViewState();
}

class _BankTransactionsViewState extends ConsumerState<BankTransactionsView> {
  String? _direction;
  String? _group;
  String? _person;
  String _search = '';
  int _page = 1;
  BankTxnResult? _last;
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  BankTxnQuery get _query => BankTxnQuery(
        accountId: widget.account.id,
        from: widget.period.fromIso,
        to: widget.period.toIso,
        direction: _direction,
        group: _group,
        person: _person,
        search: _search,
        page: _page,
        limit: widget.pageSize,
      );

  @override
  void initState() {
    super.initState();
    _tell();
  }

  @override
  void didUpdateWidget(BankTransactionsView old) {
    super.didUpdateWidget(old);
    if (old.account.id != widget.account.id) {
      // another account: its own list, from the top, with no filters carried over
      _direction = null;
      _group = null;
      _person = null;
      _search = '';
      _searchCtrl.clear();
      _page = 1;
      _last = null;
      _tell();
    } else if (old.period != widget.period || old.pageSize != widget.pageSize) {
      _page = 1;
      _tell();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _tell() {
    final q = _query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onQueryChanged?.call(q);
    });
  }

  void _set(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
    _tell();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && text.trim() != _search) _set(() => _search = text.trim());
    });
    setState(() {}); // the clear button
  }

  void _clear() {
    _searchCtrl.clear();
    _set(() {
      _direction = null;
      _group = null;
      _person = null;
      _search = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(bankStatementProvider(_query));
    if (async.hasValue) _last = async.value;
    final data = async.value ?? _last;

    if (data == null) {
      if (async.hasError) {
        return AppErrorView(error: async.error!, compact: true, onRetry: () => ref.invalidate(bankStatementProvider));
      }
      return const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()));
    }

    final filtered = _query.isFiltered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (async.isLoading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 3)),
        if (async.hasError && !async.isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(friendlyErrorMessage(async.error!), style: TextStyle(fontSize: 12.5, color: crm.destructive)),
          ),
        if (widget.showOpening) ...[
          _openingStrip(crm, data),
          const SizedBox(height: 14),
        ],
        _filters(crm, data),
        if (data.truncated)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'There are more transactions than can be read at once — choose a shorter period.',
              key: const Key('bankTxnTruncated'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.warning),
            ),
          ),
        const SizedBox(height: 12),
        if (data.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: crm.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  filtered
                      ? 'No transactions match these filters.'
                      : (widget.period.isSinceBalance ? 'No transactions since that balance.' : 'No transactions in this period.'),
                  key: const Key('bankTxnEmpty'),
                  style: TextStyle(color: crm.textSecondary),
                ),
                if (filtered) TextButton(key: const Key('bankTxnClear'), onPressed: _clear, child: const Text('Clear filters')),
              ],
            ),
          )
        else
          _StatementTable(rows: data.rows, onTap: (t) => showBankTxnDetail(context, t, accountName: widget.account.name)),
        const SizedBox(height: 12),
        _footer(crm, data),
      ],
    );
  }

  /// "Balance entered · 31 Oct 2026 · ₹3,87,068", or the opening balance of the chosen dates.
  Widget _openingStrip(CrmTheme crm, BankTxnResult data) {
    final since = widget.period.isSinceBalance;
    final label = since ? 'Balance entered' : 'Opening balance';
    final sub = since ? bankDate(data.since ?? widget.account.asOf) : 'before ${bankDate(widget.period.from)}';
    return Container(
      key: const Key('bankOpeningStrip'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, size: 20, color: crm.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                Text(sub, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              ],
            ),
          ),
          Text(
            data.opening == null ? 'Not recorded' : bankInr(data.opening!),
            key: const Key('bankOpeningAmount'),
            style: TextStyle(fontSize: data.opening == null ? 13 : 18, fontWeight: FontWeight.w800, color: data.opening == null ? crm.textSecondary : crm.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _filters(CrmTheme crm, BankTxnResult data) {
    String groupLabel() => data.groups.where((g) => g.key == _group).map((g) => g.label).firstOrNull ?? 'All Categories';
    String personLabel() => data.people.where((p) => p.key == _person).map((p) => p.label).firstOrNull ?? 'All People';
    final direction = _FilterMenu(
      key: const Key('bankFilterDirection'),
      icon: Icons.swap_vert,
      label: switch (_direction) { 'in' => 'Money in', 'out' => 'Money out', _ => 'All Transactions' },
      active: _direction != null,
      items: const [(null, 'All Transactions'), ('in', 'Money in'), ('out', 'Money out')],
      onSelected: (v) => _set(() => _direction = v),
    );
    final group = _FilterMenu(
      key: const Key('bankFilterGroup'),
      icon: Icons.layers_outlined,
      label: groupLabel(),
      active: _group != null,
      items: [(null, 'All Categories'), for (final g in data.groups) (g.key, '${g.label}  (${g.count})')],
      onSelected: (v) => _set(() => _group = v),
    );
    final person = _FilterMenu(
      key: const Key('bankFilterPerson'),
      icon: Icons.person_outline,
      label: personLabel(),
      active: _person != null,
      items: [(null, 'All People'), for (final p in data.people) (p.key, '${p.label}  (${p.count})')],
      onSelected: (v) => _set(() => _person = v),
    );
    final search = TextField(
      key: const Key('bankSearch'),
      controller: _searchCtrl,
      onChanged: _onSearch,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search client, artist, voucher, ref no…',
        hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _searchCtrl.clear();
                  _set(() => _search = '');
                },
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        // one row when there is room; otherwise the menus wrap and the search takes its own line
        if (c.maxWidth >= 760) {
          // each menu is as wide as its label (up to a limit); the search takes whatever is left
          Widget menu(Widget m) => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 210), child: m);
          return Row(
            children: [
              menu(direction),
              const SizedBox(width: 10),
              menu(group),
              const SizedBox(width: 10),
              menu(person),
              const SizedBox(width: 10),
              Expanded(child: search),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [direction, group, person]),
            const SizedBox(height: 8),
            search,
          ],
        );
      },
    );
  }

  Widget _footer(CrmTheme crm, BankTxnResult data) {
    final start = data.totalItems == 0 ? 0 : (data.page - 1) * data.limit + 1;
    final end = data.totalItems == 0 ? 0 : start + data.rows.length - 1;
    void go(int p) {
      setState(() => _page = p);
      _tell();
    }

    // up to five page numbers around the current one
    final first = (data.page - 2).clamp(1, (data.totalPages - 4).clamp(1, data.totalPages));
    final pages = [for (var p = first; p <= data.totalPages && p < first + 5; p++) p];
    Widget arrow(IconData icon, int target, Key key) => IconButton(
          key: key,
          onPressed: target < 1 || target > data.totalPages ? null : () => go(target),
          icon: Icon(icon, size: 18),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(side: BorderSide(color: crm.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        // separate items, so on a narrow window the link drops under the count instead of overflowing
        Text(
          data.totalItems == 0 ? 'No transactions' : 'Showing $start – $end of ${data.totalItems} transaction${data.totalItems == 1 ? '' : 's'}',
          key: const Key('bankTxnShowing'),
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
        ),
        if (widget.onViewAll != null && data.totalItems > 0)
          TextButton.icon(
            key: const Key('bankViewAll'),
            onPressed: widget.onViewAll,
            icon: const Icon(Icons.open_in_full, size: 15),
            label: const Text('View all transactions'),
          ),
        if (data.totalPages > 1)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrow(Icons.chevron_left, data.page - 1, const Key('bankPagePrev')),
              const SizedBox(width: 4),
              for (final p in pages)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    key: Key('bankPage_$p'),
                    onTap: p == data.page ? null : () => go(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p == data.page ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Text('$p', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p == data.page ? Colors.white : crm.textPrimary)),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              arrow(Icons.chevron_right, data.page + 1, const Key('bankPageNext')),
            ],
          ),
      ],
    );
  }
}

/// A filter shown as a pill: what is chosen now, and a menu to change it.
class _FilterMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final List<(String?, String)> items;
  final ValueChanged<String?> onSelected;
  const _FilterMenu({super.key, required this.icon, required this.label, required this.active, required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return PopupMenuButton<String>(
      tooltip: '',
      // null cannot be a menu value, so "all" travels as ''
      onSelected: (v) => onSelected(v.isEmpty ? null : v),
      itemBuilder: (_) => [for (final (value, text) in items) PopupMenuItem(value: value ?? '', child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? crm.primary.withValues(alpha: 0.06) : crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? crm.primary : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? crm.primary : crm.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// The colour of a transaction's badge and amount: money in, money out, or a move between accounts.
Color _toneOf(CrmTheme crm, BankTxn t) => t.kind == 'transfer' ? crm.accent : (t.isIn ? crm.success : crm.destructive);

class _TypeBadge extends StatelessWidget {
  final BankTxn txn;
  const _TypeBadge(this.txn);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tone = _toneOf(crm, txn);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(
        txn.kindLabel.isEmpty ? (txn.isIn ? 'Money in' : 'Money out') : txn.kindLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tone),
      ),
    );
  }
}

String _signedText(BankTxn t) => '${t.isIn ? '+' : '−'}${bankInr(t.isIn ? t.moneyIn : t.moneyOut)}';

/// The rows: a table whose columns share the width (no sideways scrolling), or cards when narrow.
class _StatementTable extends StatelessWidget {
  final List<BankTxn> rows;
  final ValueChanged<BankTxn> onTap;
  const _StatementTable({required this.rows, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Text small(String s, {Color? color, FontWeight weight = FontWeight.w500}) =>
        Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color ?? crm.textSecondary, fontWeight: weight));
    Text strong(String s, {Color? color}) =>
        Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? crm.textPrimary));

    Widget particulars(BankTxn t) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            strong(t.heading),
            if (t.whoLine.isNotEmpty) small(t.whoLine),
          ],
        );
    Widget amount(BankTxn t, {CrossAxisAlignment align = CrossAxisAlignment.end}) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            strong(_signedText(t), color: _toneOf(crm, t)),
            if (t.loggedAmount != null) small('logged ${bankInr(t.loggedAmount!)}', color: crm.warning, weight: FontWeight.w700),
          ],
        );

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 720) {
            return Column(
              children: [
                for (final t in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      key: Key('bankTxn_${t.id}'),
                      onTap: () => onTap(t),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: particulars(t)),
                                const SizedBox(width: 8),
                                amount(t),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                small(bankDate(t.date)),
                                _TypeBadge(t),
                                if (t.voucherNo.isNotEmpty) small(t.voucherNo),
                                small('Balance ${t.balance == null ? '—' : bankInr(t.balance!)}', weight: FontWeight.w700),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          const pad = EdgeInsets.symmetric(horizontal: 8);
          Widget header(String s, {bool right = false}) => Padding(
                padding: pad,
                child: Text(s, textAlign: right ? TextAlign.right : TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
              );
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    SizedBox(width: 108, child: header('Date')),
                    Expanded(flex: 5, child: header('Particulars')),
                    Expanded(flex: 3, child: header('Reference / Voucher')),
                    SizedBox(width: 132, child: header('Type')),
                    SizedBox(width: 118, child: header('Amount', right: true)),
                    SizedBox(width: 118, child: header('Balance', right: true)),
                  ],
                ),
              ),
              for (final t in rows)
                InkWell(
                  key: Key('bankTxn_${t.id}'),
                  onTap: () => onTap(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: crm.border))),
                    child: Row(
                      children: [
                        SizedBox(width: 108, child: Padding(padding: pad, child: small(bankDate(t.date), color: crm.textPrimary))),
                        Expanded(flex: 5, child: Padding(padding: pad, child: particulars(t))),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: pad,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                small(t.voucherNo.isEmpty ? '—' : t.voucherNo, color: crm.textPrimary),
                                if (t.reference.isNotEmpty) small(t.reference),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 132,
                          child: Padding(padding: pad, child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _TypeBadge(t)))),
                        ),
                        SizedBox(width: 118, child: Padding(padding: pad, child: amount(t))),
                        SizedBox(
                          width: 118,
                          child: Padding(
                            padding: pad,
                            child: Align(alignment: Alignment.centerRight, child: small(t.balance == null ? '—' : bankInr(t.balance!), color: crm.textPrimary, weight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Everything known about one transaction: the amount, what it was for, who, which work, how it was
/// paid, the voucher it sits in and the balance after it.
Future<void> showBankTxnDetail(BuildContext context, BankTxn t, {required String accountName}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final crm = ctx.crmColors;
      final tone = _toneOf(crm, t);
      return AlertDialog(
        key: const Key('bankTxnDetail'),
        backgroundColor: crm.surface,
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.heading, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${bankDate(t.date)}  ·  $accountName', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: crm.textSecondary)),
                ],
              ),
            ),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: tone.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.isIn ? 'Money in' : 'Money out', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                            Text(_signedText(t), key: const Key('bankTxnDetailAmount'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: tone)),
                            if (t.loggedAmount != null)
                              Text('Logged ${bankInr(t.loggedAmount!)} — approved for less', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.warning)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Balance after', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                          Text(t.balance == null ? '—' : bankInr(t.balance!), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (t.details.isEmpty)
                  Text(t.narration.isEmpty ? 'No further details were recorded.' : t.narration, style: TextStyle(fontSize: 13, color: crm.textSecondary))
                else
                  for (final d in t.details)
                    Padding(
                      key: Key('bankTxnDetail_${d.label}'),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 150, child: Text(d.label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                          Expanded(child: Text(d.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary))),
                        ],
                      ),
                    ),
                if (t.attachmentUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('bankTxnAttachment'),
                    onPressed: () async {
                      final uri = Uri.tryParse(t.attachmentUrl);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Open the bill / receipt'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
