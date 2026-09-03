import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(v);

/// Finance → Expenses by Category. A multi-tier drill-down:
///   Tier 2  Summary — expenses grouped by category (total + GST).
///   Tier 3  Category — the transactions inside the clicked category.
///   Tier 4  Detail — one transaction's full metadata + receipt preview.
/// Users move back up via the breadcrumb at the top.
class ExpensesByCategoryScreen extends ConsumerStatefulWidget {
  const ExpensesByCategoryScreen({super.key});

  @override
  ConsumerState<ExpensesByCategoryScreen> createState() =>
      _ExpensesByCategoryScreenState();
}

class _ExpensesByCategoryScreenState
    extends ConsumerState<ExpensesByCategoryScreen> {
  DateRangePreset _preset = DateRangePreset.allTime;
  DateTime? _from;
  DateTime? _to;

  String? _category; // Tier 3
  AdminExpense? _selected; // Tier 4

  bool _inRange(DateTime d) {
    if (_from != null && d.isBefore(_from!)) return false;
    if (_to != null && d.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  Future<void> _applyPreset(DateRangePreset p) async {
    if (p == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1),
        initialDateRange: _from != null && _to != null
            ? DateTimeRange(start: _from!, end: _to!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _preset = p;
          _from = picked.start;
          _to = picked.end;
        });
      }
      return;
    }
    final r = rangeForPreset(p, DateTime.now());
    setState(() {
      _preset = p;
      _from = r.from;
      _to = r.to;
    });
  }

  String _catOf(AdminExpense e) =>
      e.category.trim().isNotEmpty ? e.category.trim() : 'Uncategorised';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(adminExpensesProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Business Overview',
        title: 'Expenses by Category',
        preset: _preset,
        from: _from,
        to: _to,
        onPreset: _applyPreset,
        onExport:
            async.hasValue ? () => _exportCsv(context, async.value!) : null,
        onRefresh: () async => ref.invalidate(adminExpensesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                  child: Text(friendlyErrorMessage(e),
                      style: TextStyle(color: crm.destructive))),
            ),
          ]),
          data: (all) {
            // Approved-only: a department head's pending submission is not a
            // booked expense until Accounts approves it.
            final expenses = all
                .where((e) => e.status == 'approved' && _inRange(e.date))
                .toList();

            final Widget tier;
            if (_selected != null) {
              tier = _detailView(crm, _selected!);
            } else if (_category != null) {
              tier = _categoryView(crm, _category!, expenses);
            } else {
              tier = _summaryView(crm, expenses);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
              children: [
                _breadcrumb(crm),
                12.h,
                tier,
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Breadcrumb ─────────────────────────────────────────────────────────────
  Widget _breadcrumb(CrmTheme crm) {
    final crumbs = <_Crumb>[
      _Crumb('Expenses by Category',
          () => setState(() {
                _category = null;
                _selected = null;
              })),
      if (_category != null)
        _Crumb(_category!, () => setState(() => _selected = null)),
      if (_selected != null) _Crumb(_selected!.title, null),
    ];
    return Row(
      children: [
        if (_category != null || _selected != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => setState(() {
              if (_selected != null) {
                _selected = null;
              } else {
                _category = null;
              }
            }),
          ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < crumbs.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 16, color: crm.textSecondary),
                  ),
                InkWell(
                  onTap: crumbs[i].onTap,
                  child: Text(
                    crumbs[i].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          i == crumbs.length - 1 ? FontWeight.w800 : FontWeight.w600,
                      color: crumbs[i].onTap != null
                          ? crm.primary
                          : crm.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Tier 2: Summary by category ─────────────────────────────────────────────
  Widget _summaryView(CrmTheme crm, List<AdminExpense> expenses) {
    final byCat = <String, ({double amount, double gst, int count})>{};
    for (final e in expenses) {
      final k = _catOf(e);
      final cur = byCat[k] ?? (amount: 0.0, gst: 0.0, count: 0);
      byCat[k] = (
        amount: cur.amount + e.amount,
        gst: cur.gst + e.gstAmount,
        count: cur.count + 1,
      );
    }
    final rows = byCat.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);

    if (rows.isEmpty) return _empty(crm, 'No expenses in this period.');

    return Container(
      decoration: _cardDeco(crm),
      child: Column(
        children: [
          _tableHead(crm, 'CATEGORY', 'GST', 'AMOUNT'),
          Divider(height: 1, color: crm.border),
          for (final r in rows)
            InkWell(
              onTap: () => setState(() => _category = r.key),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary)),
                        Text('${r.value.count} transaction${r.value.count == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                      flex: 3,
                      child: Text(_money(r.value.gst),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12.5, color: crm.textSecondary))),
                  Expanded(
                      flex: 3,
                      child: Text(_money(r.value.amount),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700))),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: crm.textSecondary),
                ]),
              ),
            ),
          Divider(height: 1, color: crm.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Expanded(
                  child: Text('TOTAL',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary))),
              Text(_money(total),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: crm.primary)),
              const SizedBox(width: 18),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Tier 3: transactions in a category ──────────────────────────────────────
  Widget _categoryView(
      CrmTheme crm, String category, List<AdminExpense> expenses) {
    final txns = expenses.where((e) => _catOf(e) == category).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = txns.fold<double>(0, (s, e) => s + e.amount);

    if (txns.isEmpty) return _empty(crm, 'No transactions in this category.');

    return Container(
      decoration: _cardDeco(crm),
      child: Column(
        children: [
          _tableHead(crm, 'DATE · VENDOR', '', 'AMOUNT'),
          Divider(height: 1, color: crm.border),
          for (final e in txns)
            InkWell(
              onTap: () => setState(() => _selected = e),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title.isEmpty ? '(No title)' : e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary)),
                        Text(
                          '${DateFormat('dd MMM yyyy').format(e.date)}'
                          '${e.vendor.trim().isNotEmpty ? '  ·  ${e.vendor.trim()}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                      flex: 3,
                      child: Text(_money(e.amount),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700))),
                  if (e.receiptImage.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.attach_file_rounded,
                          size: 14, color: crm.textSecondary),
                    ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: crm.textSecondary),
                ]),
              ),
            ),
          Divider(height: 1, color: crm.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Expanded(
                  child: Text('CATEGORY TOTAL',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary))),
              Text(_money(total),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: crm.primary)),
              const SizedBox(width: 18),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Tier 4: transaction detail + receipt preview ────────────────────────────
  Widget _detailView(CrmTheme crm, AdminExpense e) {
    final meta = <(String, String)>[
      ('Category', _catOf(e)),
      if (e.expenseHead.trim().isNotEmpty) ('Expense head', e.expenseHead),
      if (e.department.trim().isNotEmpty) ('Department', e.department),
      if (e.vendor.trim().isNotEmpty) ('Vendor / payee', e.vendor),
      ('Date', DateFormat('dd MMM yyyy').format(e.date)),
      if (e.invoiceNumber.trim().isNotEmpty) ('Invoice no.', e.invoiceNumber),
      ('Payment method', e.paymentMethod.isEmpty ? '—' : e.paymentMethod),
      if (e.paidByName.trim().isNotEmpty) ('Paid by', e.paidByName),
      ('GST', '${e.gstType.toUpperCase()} · ${_money(e.gstAmount)}'),
      ('Status', e.status),
      if (e.costTag.trim().isNotEmpty) ('Cost tag', e.costTag),
      if (e.notes.trim().isNotEmpty) ('Notes', e.notes),
    ];

    final detail = Container(
      decoration: _cardDeco(crm),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.title.isEmpty ? '(No title)' : e.title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
          6.h,
          Text(_money(e.amount),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: crm.primary)),
          14.h,
          for (final m in meta)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(m.$1,
                        style: TextStyle(
                            fontSize: 12.5, color: crm.textSecondary)),
                  ),
                  Expanded(
                    child: Text(m.$2,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: crm.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final hasDoc = e.receiptImage.trim().isNotEmpty;
    final doc = _ReceiptPreview(url: e.receiptImage.trim(), crm: crm);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 720;
      if (wide && hasDoc) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: detail),
            16.w,
            Expanded(child: doc),
          ],
        );
      }
      return Column(children: [
        detail,
        if (hasDoc) ...[16.h, doc],
      ]);
    });
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  BoxDecoration _cardDeco(CrmTheme crm) => BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      );

  Widget _tableHead(CrmTheme crm, String a, String b, String c) {
    TextStyle s() => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: crm.textSecondary,
        letterSpacing: 0.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 32, 10),
      child: Row(children: [
        Expanded(flex: 5, child: Text(a, style: s())),
        Expanded(
            flex: 3, child: Text(b, textAlign: TextAlign.right, style: s())),
        Expanded(
            flex: 3, child: Text(c, textAlign: TextAlign.right, style: s())),
      ]),
    );
  }

  Widget _empty(CrmTheme crm, String msg) => Container(
        decoration: _cardDeco(crm),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(msg, style: TextStyle(color: crm.textSecondary)),
        ),
      );

  Future<void> _exportCsv(BuildContext context, List<AdminExpense> all) async {
    final expenses =
        all.where((e) => e.status == 'approved' && _inRange(e.date)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final rows = <List<Object?>>[
      ['Expenses by Category'],
      ['Date', 'Category', 'Title', 'Vendor', 'GST', 'Amount', 'Status'],
      for (final e in expenses)
        [
          DateFormat('yyyy-MM-dd').format(e.date),
          _catOf(e),
          e.title,
          e.vendor,
          csvNum(e.gstAmount),
          csvNum(e.amount),
          e.status,
        ],
    ];
    try {
      await downloadCsv('expenses_by_category.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expenses exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}

class _Crumb {
  final String label;
  final VoidCallback? onTap;
  _Crumb(this.label, this.onTap);
}

/// Side-by-side receipt/invoice preview. Images render inline; anything else
/// (e.g. a PDF) shows an "Open document" action.
class _ReceiptPreview extends StatelessWidget {
  final String url;
  final CrmTheme crm;
  const _ReceiptPreview({required this.url, required this.crm});

  bool get _isImage {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp') ||
        u.endsWith('.gif');
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Icon(Icons.description_outlined, size: 16, color: crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Source document',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
              ),
              TextButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Open'),
              ),
            ]),
          ),
          Divider(height: 1, color: crm.border),
          if (_isImage)
            InkWell(
              onTap: _open,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _docFallback(),
              ),
            )
          else
            _docFallback(),
        ],
      ),
    );
  }

  Widget _docFallback() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 44, color: crm.textSecondary),
              8.h,
              Text('Preview not available',
                  style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
              8.h,
              OutlinedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open document'),
              ),
            ],
          ),
        ),
      );
}
