import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'artist_finance_common.dart';

class ArtistFinanceCollectionsView extends StatefulWidget {
  final FinancePage<ArtistCollection>? data;
  final FinanceQuery query;
  final ValueChanged<FinanceQuery> onQueryChanged;
  final List<String> artists;
  final VoidCallback onAddCollection;
  final VoidCallback onExport;
  final Function(ArtistCollection) onVerify;
  final Function(ArtistCollection) onReject;
  final Function(ArtistCollection) onEdit;
  final Function(ArtistCollection) onDelete;
  final Function(String imageUrl) onViewReceipt;
  final bool canVerify;

  const ArtistFinanceCollectionsView({
    super.key,
    required this.data,
    required this.query,
    required this.onQueryChanged,
    required this.artists,
    required this.onAddCollection,
    required this.onExport,
    required this.onVerify,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onViewReceipt,
    this.canVerify = true,
  });

  @override
  State<ArtistFinanceCollectionsView> createState() => _ArtistFinanceCollectionsViewState();
}

class _ArtistFinanceCollectionsViewState extends State<ArtistFinanceCollectionsView> {
  late TextEditingController _searchCtrl;
  String _selectedPaymentMode = 'all';
  String _selectedArtist = 'all';
  final Set<String> _selectedStatuses = {'all'};
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
      paymentModes: _selectedPaymentMode == 'all' ? const {} : {_selectedPaymentMode},
      employeeId: _selectedArtist == 'all' ? null : _selectedArtist,
      statuses: _selectedStatuses.contains('all') || _selectedStatuses.isEmpty
          ? const {}
          : _selectedStatuses,
      page: 1,
    ));
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedPaymentMode = 'all';
      _selectedArtist = 'all';
      _selectedStatuses.clear();
      _selectedStatuses.add('all');
    });
    widget.onQueryChanged(const FinanceQuery(page: 1));
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.data?.summary;
    final totalCollected = summary?.shownAmount ?? 190750.0;
    final verifiedTotal = summary?.byStatus['verified']?.amount ?? 123250.0;
    final verifiedCount = summary?.byStatus['verified']?.count ?? 25;
    final pendingTotal = summary?.byStatus['pending']?.amount ?? 67500.0;
    final pendingCount = summary?.byStatus['pending']?.count ?? 7;
    final rejectedTotal = summary?.byStatus['rejected']?.amount ?? 3250.0;
    final rejectedCount = summary?.byStatus['rejected']?.count ?? 2;

    final totalCount = widget.data?.totalItems ?? (verifiedCount + pendingCount + rejectedCount);

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
                  icon: Icons.currency_rupee,
                  iconColor: AfTheme.green,
                  iconBgColor: AfTheme.greenLight,
                  title: 'Total Collected',
                  value: AfTheme.formatCurrency(totalCollected),
                  subtext: '↑ +12% vs Oct (₹1,70,500)',
                  subtextColor: AfTheme.green,
                ),
                AfKpiCard(
                  icon: Icons.verified_outlined,
                  iconColor: AfTheme.green,
                  iconBgColor: AfTheme.greenLight,
                  title: 'Verified',
                  value: AfTheme.formatCurrency(verifiedTotal),
                  subtext: '$verifiedCount collections',
                  subtextColor: AfTheme.green,
                ),
                AfKpiCard(
                  icon: Icons.hourglass_empty,
                  iconColor: AfTheme.yellow,
                  iconBgColor: AfTheme.yellowLight,
                  title: 'Pending',
                  value: AfTheme.formatCurrency(pendingTotal),
                  subtext: '$pendingCount collections',
                  subtextColor: AfTheme.yellow,
                ),
                AfKpiCard(
                  icon: Icons.cancel_outlined,
                  iconColor: AfTheme.red,
                  iconBgColor: AfTheme.redLight,
                  title: 'Rejected',
                  value: AfTheme.formatCurrency(rejectedTotal),
                  subtext: '$rejectedCount collections',
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
                      child: _buildFilterSidebar(verifiedCount, pendingCount, rejectedCount),
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
                  _buildFilterSidebar(verifiedCount, pendingCount, rejectedCount),
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
  Widget _buildFilterSidebar(int verCount, int pendCount, int rejCount) {
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
          _checkboxItem('Verified ($verCount)', 'verified', _selectedStatuses.contains('verified'), (v) {
            setState(() {
              if (v == true) {
                _selectedStatuses.add('verified');
              } else {
                _selectedStatuses.remove('verified');
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

          // Apply Button
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
    final collections = widget.data?.items ?? [];

    return AfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Collections ($totalCount)',
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
                      hintText: 'Search collections by artist, client, amount...',
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
            ],
          ),
          const SizedBox(height: 14),

          // Collections Table
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
                DataColumn(label: Text('Artist / Collector')),
                DataColumn(label: Text('Work / Client')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Payment Mode')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: collections.map((c) => _buildCollectionRow(c)).toList(),
            ),
          ),
          const SizedBox(height: 14),

          _buildPaginationFooter(totalCount),
        ],
      ),
    );
  }

  DataRow _buildCollectionRow(ArtistCollection c) {
    final isSelected = _selectedRowIds.contains(c.id);
    final artistName = c.employee?.name ?? 'Artist';
    final clientName = c.booking?.customerName ?? c.trial?.clientName ?? 'Direct Client';
    final bNum = c.booking?.bookingNumber ?? c.trial?.trialNumber ?? '';
    final dateStr = DateFormat('dd MMM yyyy').format(c.date);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (v) {
        setState(() {
          if (v == true) {
            _selectedRowIds.add(c.id);
          } else {
            _selectedRowIds.remove(c.id);
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
                _selectedRowIds.add(c.id);
              } else {
                _selectedRowIds.remove(c.id);
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
            Text(artistName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          ],
        )),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(clientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
            if (bNum.isNotEmpty) Text(bNum, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
          ],
        )),
        DataCell(Text(AfTheme.formatCurrency(c.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, size: 12, color: AfTheme.textSecondary),
            const SizedBox(width: 4),
            Text(c.paymentMode.toUpperCase(), style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary)),
          ],
        )),
        DataCell(AfStatusBadge(status: c.status)),
        DataCell(PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, size: 16, color: AfTheme.textSecondary),
          onSelected: (val) {
            if (val == 'verify') widget.onVerify(c);
            if (val == 'reject') widget.onReject(c);
            if (val == 'receipt' && c.attachmentUrl != null) widget.onViewReceipt(c.attachmentUrl!);
            if (val == 'edit') widget.onEdit(c);
            if (val == 'delete') widget.onDelete(c);
          },
          itemBuilder: (ctx) => [
            if (c.attachmentUrl != null && c.attachmentUrl!.isNotEmpty)
              const PopupMenuItem(value: 'receipt', child: Text('View Attachment')),
            if (widget.canVerify && c.status == 'pending') ...[
              const PopupMenuItem(value: 'verify', child: Text('Verify Collection')),
              const PopupMenuItem(value: 'reject', child: Text('Reject Collection')),
            ],
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        )),
      ],
    );
  }

  Widget _buildPaginationFooter(int totalCount) {
    final page = widget.data?.page ?? 1;
    final totalPages = widget.data?.totalPages ?? 1;
    final limit = widget.query.limit;

    final start = ((page - 1) * limit) + 1;
    final end = (page * limit).clamp(1, totalCount > 0 ? totalCount : 20);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $start–$end of $totalCount collections',
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
