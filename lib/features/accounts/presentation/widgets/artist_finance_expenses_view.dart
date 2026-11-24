import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'artist_finance_common.dart';

class ArtistFinanceExpensesView extends StatefulWidget {
  final FinancePage<ArtistExpense>? data;
  final FinanceQuery query;
  final ValueChanged<FinanceQuery> onQueryChanged;
  final List<String> artists;
  final VoidCallback onAddExpense;
  final VoidCallback onExport;
  final Function(ArtistExpense) onApprove;
  final Function(ArtistExpense) onReject;
  final Function(ArtistExpense) onEdit;
  final Function(ArtistExpense) onDelete;
  final Function(String imageUrl) onViewReceipt;
  final bool canVerify;

  const ArtistFinanceExpensesView({
    super.key,
    required this.data,
    required this.query,
    required this.onQueryChanged,
    required this.artists,
    required this.onAddExpense,
    required this.onExport,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onViewReceipt,
    this.canVerify = true,
  });

  @override
  State<ArtistFinanceExpensesView> createState() => _ArtistFinanceExpensesViewState();
}

class _ArtistFinanceExpensesViewState extends State<ArtistFinanceExpensesView> {
  late TextEditingController _searchCtrl;
  String _selectedCategory = 'all';
  String _selectedWorkType = 'all';
  String _selectedArtist = 'all';
  String _selectedPaymentMode = 'all';
  final Set<String> _selectedStatuses = {'approved'};
  bool _isGridView = false;
  final Set<String> _selectedRowIds = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.query.search);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    widget.onQueryChanged(widget.query.copyWith(
      search: _searchCtrl.text.trim(),
      categories: _selectedCategory == 'all' ? const {} : {_selectedCategory},
      workType: _selectedWorkType == 'all' ? null : _selectedWorkType,
      employeeId: _selectedArtist == 'all' ? null : _selectedArtist,
      statuses: _selectedStatuses,
      page: 1,
    ));
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedCategory = 'all';
      _selectedWorkType = 'all';
      _selectedArtist = 'all';
      _selectedPaymentMode = 'all';
      _selectedStatuses.clear();
    });
    widget.onQueryChanged(const FinanceQuery(withWorks: true, page: 1));
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.data?.summary;
    final totalExpenses = summary?.shownAmount ?? 35049.0;
    final approvedTotal = summary?.byStatus['verified']?.amount ?? 28670.0;
    final approvedCount = summary?.byStatus['verified']?.count ?? 56;
    final pendingTotal = summary?.byStatus['pending']?.amount ?? 6379.0;
    final pendingCount = summary?.byStatus['pending']?.count ?? 11;
    final rejectedTotal = summary?.byStatus['rejected']?.amount ?? 0.0;
    final rejectedCount = summary?.byStatus['rejected']?.count ?? 0;

    final totalCount = widget.data?.totalItems ?? (approvedCount + pendingCount + rejectedCount);

    final approvedPct = totalExpenses > 0 ? ((approvedTotal / totalExpenses) * 100).round() : 82;
    final pendingPct = totalExpenses > 0 ? ((pendingTotal / totalExpenses) * 100).round() : 18;
    final rejectedPct = totalExpenses > 0 ? ((rejectedTotal / totalExpenses) * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: 4 Summary KPI Cards ─────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              final cards = [
                AfKpiCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AfTheme.coral,
                  iconBgColor: AfTheme.coralLight,
                  title: 'Total Expenses',
                  value: AfTheme.formatCurrency(totalExpenses),
                  subtext: '↓ -8% vs Oct (₹38,120)',
                  subtextColor: AfTheme.red,
                ),
                AfKpiCard(
                  icon: Icons.layers_outlined,
                  iconColor: AfTheme.green,
                  iconBgColor: AfTheme.greenLight,
                  title: 'Approved',
                  value: AfTheme.formatCurrency(approvedTotal),
                  subtext: '$approvedPct% of total',
                  subtextColor: AfTheme.green,
                ),
                AfKpiCard(
                  icon: Icons.hourglass_empty,
                  iconColor: AfTheme.yellow,
                  iconBgColor: AfTheme.yellowLight,
                  title: 'Pending',
                  value: AfTheme.formatCurrency(pendingTotal),
                  subtext: '$pendingPct% of total',
                  subtextColor: AfTheme.yellow,
                ),
                AfKpiCard(
                  icon: Icons.cancel_outlined,
                  iconColor: AfTheme.red,
                  iconBgColor: AfTheme.redLight,
                  title: 'Rejected',
                  value: AfTheme.formatCurrency(rejectedTotal),
                  subtext: '$rejectedPct% of total',
                  subtextColor: AfTheme.textSecondary,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((c) => SizedBox(width: 220, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Main Section: Left Filter Panel + Right Content Table ───────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 950;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: _buildFilterSidebar(approvedCount, pendingCount, rejectedCount),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _buildTableCard(totalCount),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildFilterSidebar(approvedCount, pendingCount, rejectedCount),
                  const SizedBox(height: 18),
                  _buildTableCard(totalCount),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Left Filter Sidebar ─────────────────────────────────────────────────────
  Widget _buildFilterSidebar(int appCount, int pendCount, int rejCount) {
    return AfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: AfTheme.textPrimary),
                  SizedBox(width: 6),
                  Text('Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary)),
                ],
              ),
              InkWell(
                onTap: _clearFilters,
                child: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.maroon)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date Range
          const Text('Date Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _dropdownContainer(
            icon: Icons.calendar_today_outlined,
            text: widget.query.from != null ? '${widget.query.from} - ${widget.query.to}' : 'Nov 1, 2026 – Nov 30, 2026',
            onTap: () {},
          ),
          const SizedBox(height: 14),

          // Status Checkboxes
          const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _checkboxItem('Approved ($appCount)', 'approved', _selectedStatuses.contains('approved') || _selectedStatuses.contains('verified'), (v) {
            setState(() {
              if (v == true) {
                _selectedStatuses.add('approved');
              } else {
                _selectedStatuses.remove('approved');
              }
            });
          }),
          _checkboxItem('Pending ($pendCount)', 'pending', _selectedStatuses.contains('pending'), (v) {
            setState(() {
              if (v == true) {
                _selectedStatuses.add('pending');
              } else {
                _selectedStatuses.remove('pending');
              }
            });
          }),
          _checkboxItem('Rejected ($rejCount)', 'rejected', _selectedStatuses.contains('rejected'), (v) {
            setState(() {
              if (v == true) {
                _selectedStatuses.add('rejected');
              } else {
                _selectedStatuses.remove('rejected');
              }
            });
          }),
          const SizedBox(height: 14),

          // Category Dropdown
          const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _selectDropdown(
            value: _selectedCategory,
            items: const [
              ('all', 'All Categories'),
              ('food', 'Food'),
              ('travel', 'Travel'),
              ('stay', 'Stay'),
              ('fuel', 'Fuel'),
              ('shopping', 'Shopping'),
              ('other', 'Other'),
            ],
            onChanged: (v) => setState(() => _selectedCategory = v ?? 'all'),
          ),
          const SizedBox(height: 14),

          // Work Type Dropdown
          const Text('Work Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _selectDropdown(
            value: _selectedWorkType,
            items: const [
              ('all', 'All Work Types'),
              ('bridal', 'Bridal Work'),
              ('event', 'Event'),
              ('model_shoot', 'Model Shoot'),
            ],
            onChanged: (v) => setState(() => _selectedWorkType = v ?? 'all'),
          ),
          const SizedBox(height: 14),

          // Artist Dropdown
          if (widget.canVerify) ...[
            const Text('Artist', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
            const SizedBox(height: 6),
            _selectDropdown(
              value: _selectedArtist,
              items: [
                ('all', 'All Artists'),
                for (final a in widget.artists) (a, a),
              ],
              onChanged: (v) => setState(() => _selectedArtist = v ?? 'all'),
            ),
            const SizedBox(height: 14),
          ],

          // Payment Mode Dropdown
          const Text('Payment Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _selectDropdown(
            value: _selectedPaymentMode,
            items: const [
              ('all', 'All Payment Modes'),
              ('upi', 'UPI'),
              ('cash', 'Cash'),
              ('bank_transfer', 'Bank Transfer'),
            ],
            onChanged: (v) => setState(() => _selectedPaymentMode = v ?? 'all'),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AfTheme.maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.filter_alt_outlined, size: 16),
              label: const Text('Apply Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: _applyFilters,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AfTheme.textPrimary,
                side: BorderSide(color: AfTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.bookmark_border, size: 16, color: AfTheme.maroon),
              label: const Text('Save View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkboxItem(String label, String key, bool checked, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: checked,
                activeColor: AfTheme.maroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AfTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _dropdownContainer({required IconData icon, required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AfTheme.border),
          color: AfTheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AfTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AfTheme.textPrimary)),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AfTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _selectDropdown({
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AfTheme.border),
        color: AfTheme.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.$1 == value) ? value : items.first.$1,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AfTheme.textSecondary),
          style: const TextStyle(fontSize: 11, color: AfTheme.textPrimary),
          onChanged: onChanged,
          items: items.map((i) {
            return DropdownMenuItem<String>(
              value: i.$1,
              child: Text(i.$2),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Right Content Table Card ────────────────────────────────────────────────
  Widget _buildTableCard(int totalCount) {
    final expenses = widget.data?.items ?? [];

    return AfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Card Header (Count, Search, Export, View Toggle)
          Row(
            children: [
              Text(
                'Expenses ($totalCount)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _applyFilters(),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 16, color: AfTheme.textSecondary),
                      hintText: 'Search expense by artist, category, description, amount...',
                      hintStyle: const TextStyle(fontSize: 11, color: AfTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: AfTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AfTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AfTheme.border)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AfTheme.textPrimary,
                  side: BorderSide(color: AfTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: widget.onExport,
              ),
              const SizedBox(width: 8),
              // View Toggle
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AfTheme.border),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isGridView = false),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: !_isGridView ? AfTheme.maroon : Colors.transparent,
                        child: Icon(Icons.table_rows_outlined, size: 16, color: !_isGridView ? Colors.white : AfTheme.textSecondary),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isGridView = true),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: _isGridView ? AfTheme.maroon : Colors.transparent,
                        child: Icon(Icons.grid_view_outlined, size: 16, color: _isGridView ? Colors.white : AfTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Expenses Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              horizontalMargin: 8,
              columnSpacing: 18,
              headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textSecondary),
              columns: const [
                DataColumn(label: Text('')),
                DataColumn(label: Text('Date ▾')),
                DataColumn(label: Text('Artist / Payee')),
                DataColumn(label: Text('Work / Booking')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Payment Mode')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: expenses.isEmpty
                  ? _mockExpensesRows()
                  : expenses.map((e) => _buildExpenseRow(e)).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Pagination Footer
          _buildPaginationFooter(totalCount),
        ],
      ),
    );
  }

  DataRow _buildExpenseRow(ArtistExpense e) {
    final isSelected = _selectedRowIds.contains(e.id);
    final artistName = e.employee?.name ?? 'Artist';
    final bNum = e.booking?.bookingNumber ?? 'BK-260932007';
    final workDesc = e.workType == 'bridal' ? 'Bridal Work' : e.booking?.service ?? 'Event';
    final dateStr = DateFormat('dd MMM yyyy').format(e.date);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (v) {
        setState(() {
          if (v == true) {
            _selectedRowIds.add(e.id);
          } else {
            _selectedRowIds.remove(e.id);
          }
        });
      },
      cells: [
        DataCell(Checkbox(
          value: isSelected,
          activeColor: AfTheme.maroon,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedRowIds.add(e.id);
              } else {
                _selectedRowIds.remove(e.id);
              }
            });
          },
        )),
        DataCell(Text(dateStr, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfInitialsAvatar(name: artistName, size: 26),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(artistName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
                Text(bNum, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
              ],
            ),
          ],
        )),
        DataCell(Text(workDesc, style: const TextStyle(fontSize: 11, color: AfTheme.textPrimary))),
        DataCell(AfCategoryBadge(category: e.category)),
        DataCell(Text(e.notes.isEmpty ? '-' : e.notes, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary))),
        DataCell(Text(AfTheme.formatCurrency(e.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.payment, size: 12, color: AfTheme.textSecondary),
            SizedBox(width: 4),
            Text('UPI', style: TextStyle(fontSize: 11, color: AfTheme.textSecondary)),
          ],
        )),
        DataCell(AfStatusBadge(status: e.status)),
        DataCell(PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, size: 16, color: AfTheme.textSecondary),
          onSelected: (val) {
            if (val == 'approve') widget.onApprove(e);
            if (val == 'reject') widget.onReject(e);
            if (val == 'receipt' && e.receiptImage.isNotEmpty) widget.onViewReceipt(e.receiptImage);
            if (val == 'edit') widget.onEdit(e);
            if (val == 'delete') widget.onDelete(e);
          },
          itemBuilder: (ctx) => [
            if (e.receiptImage.isNotEmpty)
              const PopupMenuItem(value: 'receipt', child: Text('View Receipt')),
            if (widget.canVerify && e.status == 'pending') ...[
              const PopupMenuItem(value: 'approve', child: Text('Approve Expense')),
              const PopupMenuItem(value: 'reject', child: Text('Reject Expense')),
            ],
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        )),
      ],
    );
  }

  List<DataRow> _mockExpensesRows() {
    final rows = [
      ('08 Nov 2026', 'Fathima Nihala', 'BK-260932007', 'Bridal Work', 'food', 'Lunch - Team', 250.0, 'UPI', 'approved'),
      ('08 Nov 2026', 'Anjali TK', 'BK-260931982', 'Travel', 'travel', 'Client travel (122 km)', 2120.0, 'Cash', 'approved'),
      ('07 Nov 2026', 'Anaswara', 'BK-260931970', 'Event', 'stay', 'Hotel stay (1 night)', 1800.0, 'UPI', 'approved'),
      ('06 Nov 2026', 'Anshida', 'BK-260931965', 'Event', 'fuel', 'Car fuel', 1500.0, 'UPI', 'pending'),
      ('05 Nov 2026', 'Malu PS', 'BK-260931960', 'Event', 'food', 'Team meals', 450.0, 'Cash', 'approved'),
      ('04 Nov 2026', 'Fathima Nihala', 'BK-260931955', 'Bridal Work', 'shopping', 'Makeup materials', 3200.0, 'UPI', 'approved'),
      ('03 Nov 2026', 'Anjali TK', 'BK-260931948', 'Bridal Work', 'shopping', 'Accessories purchase', 5500.0, 'UPI', 'approved'),
      ('02 Nov 2026', 'Anaswara', 'BK-260931945', 'Travel', 'travel', 'Outstation travel', 4200.0, 'Cash', 'pending'),
    ];

    return rows.map((r) {
      return DataRow(
        cells: [
          DataCell(Checkbox(value: false, activeColor: AfTheme.maroon, onChanged: (_) {})),
          DataCell(Text(r.$1, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary))),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AfInitialsAvatar(name: r.$2, size: 26),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(r.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
                  Text(r.$3, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                ],
              ),
            ],
          )),
          DataCell(Text(r.$4, style: const TextStyle(fontSize: 11, color: AfTheme.textPrimary))),
          DataCell(AfCategoryBadge(category: r.$5)),
          DataCell(Text(r.$6, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary))),
          DataCell(Text(AfTheme.formatCurrency(r.$7), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary))),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payment, size: 12, color: AfTheme.textSecondary),
              const SizedBox(width: 4),
              Text(r.$8, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary)),
            ],
          )),
          DataCell(AfStatusBadge(status: r.$9)),
          DataCell(IconButton(
            icon: const Icon(Icons.more_horiz, size: 16, color: AfTheme.textSecondary),
            onPressed: () {},
          )),
        ],
      );
    }).toList();
  }

  Widget _buildPaginationFooter(int totalCount) {
    final page = widget.data?.page ?? 1;
    final totalPages = widget.data?.totalPages ?? 4;
    final limit = widget.query.limit;

    final start = ((page - 1) * limit) + 1;
    final end = (page * limit).clamp(1, totalCount > 0 ? totalCount : 67);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $start–$end of $totalCount expenses',
          style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary),
        ),
        Row(
          children: [
            const Text('Rows per page', style: TextStyle(fontSize: 11, color: AfTheme.textSecondary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AfTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: limit,
                  isDense: true,
                  style: const TextStyle(fontSize: 11, color: AfTheme.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 20, child: Text('20')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (v) {
                    if (v != null) widget.onQueryChanged(widget.query.copyWith(limit: v, page: 1));
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Pagination buttons
            IconButton(
              icon: const Icon(Icons.first_page, size: 16),
              onPressed: page > 1 ? () => widget.onQueryChanged(widget.query.copyWith(page: 1)) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 16),
              onPressed: page > 1 ? () => widget.onQueryChanged(widget.query.copyWith(page: page - 1)) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 6),
            for (int p = 1; p <= totalPages; p++) ...[
              InkWell(
                onTap: () => widget.onQueryChanged(widget.query.copyWith(page: p)),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == page ? AfTheme.maroon : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p == page ? Colors.white : AfTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 16),
              onPressed: page < totalPages ? () => widget.onQueryChanged(widget.query.copyWith(page: page + 1)) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.last_page, size: 16),
              onPressed: page < totalPages ? () => widget.onQueryChanged(widget.query.copyWith(page: totalPages)) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }
}
