import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'artist_finance_common.dart';

class ArtistFinanceByWorkView extends StatefulWidget {
  final WorkCostPage? data;
  final String? from;
  final String? to;
  final List<String> artists;
  final VoidCallback onExport;
  final ValueChanged<String?> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onArtistChanged;

  const ArtistFinanceByWorkView({
    super.key,
    required this.data,
    this.from,
    this.to,
    required this.artists,
    required this.onExport,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onArtistChanged,
  });

  @override
  State<ArtistFinanceByWorkView> createState() => _ArtistFinanceByWorkViewState();
}

class _ArtistFinanceByWorkViewState extends State<ArtistFinanceByWorkView> {
  final Set<String> _expandedWorkIds = {'BK-260931982', 'b_megha'};
  late TextEditingController _searchCtrl;
  String _selectedStatus = 'all'; // all, approved, pending
  String _selectedWorkType = 'all';
  String _selectedArtist = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedStatus = 'all';
      _selectedWorkType = 'all';
      _selectedArtist = 'all';
    });
    widget.onSearchChanged(null);
    widget.onStatusChanged(null);
    widget.onArtistChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final totals = widget.data?.totals;
    final totalWorks = widget.data?.totalItems ?? 14;
    final totalCollected = 190750.0;
    final totalWorkCost = totals?.total ?? 19375.0;
    final overAllowanceAmount = totals?.overAllowanceAmount ?? 4612.0;
    final overAllowanceWorks = totals?.overAllowanceCount ?? 8;
    final unplacedAmount = totals?.unplaced ?? 16976.0;
    final unplacedWorks = totals?.unplacedCount ?? 24;

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
                  icon: Icons.layers_outlined,
                  iconColor: AfTheme.green,
                  iconBgColor: AfTheme.greenLight,
                  title: 'Total Collected',
                  value: AfTheme.formatCurrency(totalCollected),
                  subtext: '↑ +12% vs Oct (₹1,70,500)',
                  subtextColor: AfTheme.green,
                ),
                AfKpiCard(
                  icon: Icons.work_outline,
                  iconColor: AfTheme.yellow,
                  iconBgColor: AfTheme.yellowLight,
                  title: 'Total Work Cost',
                  value: AfTheme.formatCurrency(totalWorkCost),
                  subtext: '$totalWorks works active',
                  subtextColor: AfTheme.textSecondary,
                ),
                AfKpiCard(
                  icon: Icons.restaurant_outlined,
                  iconColor: AfTheme.coral,
                  iconBgColor: AfTheme.coralLight,
                  title: 'Over Allowance',
                  value: AfTheme.formatCurrency(overAllowanceAmount),
                  subtext: '$overAllowanceWorks works',
                  subtextColor: AfTheme.textSecondary,
                ),
                AfKpiCard(
                  icon: Icons.pie_chart_outline,
                  iconColor: AfTheme.red,
                  iconBgColor: AfTheme.redLight,
                  title: 'Not Placed',
                  value: AfTheme.formatCurrency(unplacedAmount),
                  subtext: '$unplacedWorks works',
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

          // ── Main Two-Column Section ─────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 950;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: _buildFilterSidebar(),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _buildWorkTableCard(totalWorks),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildFilterSidebar(),
                  const SizedBox(height: 18),
                  _buildWorkTableCard(totalWorks),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Left Filter Sidebar ─────────────────────────────────────────────────────
  Widget _buildFilterSidebar() {
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
          _dropdownBox(
            icon: Icons.calendar_today_outlined,
            text: widget.from != null ? '${widget.from} - ${widget.to}' : 'Nov 1, 2026 – Nov 30, 2026',
            onTap: () {},
          ),
          const SizedBox(height: 14),

          // Status Checkboxes
          const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _statusRadioItem('Pending + Approved (14)', 'all'),
          _statusRadioItem('Approved Only (9)', 'approved'),
          _statusRadioItem('Pending Only (5)', 'pending'),
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
          const Text('Artist', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          _selectDropdown(
            value: _selectedArtist,
            items: [
              ('all', 'All Artists'),
              for (final a in widget.artists) (a, a),
            ],
            onChanged: (v) {
              setState(() => _selectedArtist = v ?? 'all');
              widget.onArtistChanged(v == 'all' ? null : v);
            },
          ),
          const SizedBox(height: 14),

          // Client / Booking Search
          const Text('Client / Booking', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (val) => widget.onSearchChanged(val.trim().isEmpty ? null : val.trim()),
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 14, color: AfTheme.textSecondary),
                hintText: 'Search by client or booking no.',
                hintStyle: const TextStyle(fontSize: 10.5, color: AfTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: AfTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AfTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AfTheme.border)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Apply Filters Button
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
              onPressed: () {
                widget.onSearchChanged(_searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
                widget.onStatusChanged(_selectedStatus == 'all' ? null : _selectedStatus);
                widget.onArtistChanged(_selectedArtist == 'all' ? null : _selectedArtist);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRadioItem(String label, String key) {
    final active = _selectedStatus == key;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedStatus = key);
          widget.onStatusChanged(key == 'all' ? null : key);
        },
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: active,
                activeColor: AfTheme.maroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (_) {
                  setState(() => _selectedStatus = key);
                  widget.onStatusChanged(key == 'all' ? null : key);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AfTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _dropdownBox({required IconData icon, required String text, required VoidCallback onTap}) {
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

  // ── Right Work Table Card ───────────────────────────────────────────────────
  Widget _buildWorkTableCard(int totalWorks) {
    final rows = widget.data?.items ?? [];

    return AfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'By Work',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($totalWorks)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.coral),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Work-wise breakdown of food, travel and other costs for artists.',
                    style: TextStyle(fontSize: 11, color: AfTheme.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
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
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AfTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AfTheme.maroon,
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
                          ),
                          child: const Icon(Icons.table_rows_outlined, size: 16, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.grid_view_outlined, size: 16, color: AfTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Work Rows list
          if (rows.isEmpty)
            ..._mockWorkCards()
          else
            for (final r in rows) ...[
              _buildWorkRowItem(r),
              const SizedBox(height: 10),
            ],

          const SizedBox(height: 14),
          _buildPaginationFooter(totalWorks),
        ],
      ),
    );
  }

  Widget _buildWorkRowItem(WorkCostRow r) {
    final key = r.bookingNumber.isNotEmpty ? r.bookingNumber : r.bookingId;
    final isExpanded = _expandedWorkIds.contains(key);
    final dateStr = r.serviceStart != null ? DateFormat('dd MMM yyyy').format(r.serviceStart!) : '08 Nov 2026';
    final slotStr = r.period.isNotEmpty ? r.period : 'Morning';

    return Container(
      decoration: BoxDecoration(
        color: AfTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AfTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Checkbox(value: false, activeColor: AfTheme.maroon, onChanged: (_) {}),
                const SizedBox(width: 8),
                // Work / Client
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.customerName.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary)),
                      Text(r.bookingNumber, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                    ],
                  ),
                ),
                // Date & Slot
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
                      Text(slotStr, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                    ],
                  ),
                ),
                // Artist(s)
                SizedBox(
                  width: 130,
                  child: Row(
                    children: [
                      AfInitialsAvatar(name: r.artists.isNotEmpty ? r.artists.first : 'Fathima', size: 24),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.artists.isNotEmpty ? r.artists.first : 'Fathima Nihala',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                // Work Type
                SizedBox(
                  width: 100,
                  child: AfCategoryBadge(category: r.service.isNotEmpty ? r.service : 'Bridal Work'),
                ),
                // Cost Breakdown
                Expanded(
                  child: Text(
                    'Food ₹${r.food.toInt()}  Travel ₹${r.travel.toInt()} • Other ₹${r.other.toInt()}',
                    style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary),
                  ),
                ),
                // Total Cost
                Text(
                  AfTheme.formatCurrency(r.total),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AfTheme.textPrimary),
                ),
                const SizedBox(width: 14),
                // Status badge
                AfStatusBadge(status: r.pendingCount > 0 ? 'pending' : 'approved'),
                const SizedBox(width: 10),
                // Expand toggle button
                IconButton(
                  icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AfTheme.textSecondary),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedWorkIds.remove(key);
                      } else {
                        _expandedWorkIds.add(key);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          // Expanded Drawer Box
          if (isExpanded) _buildExpandedBreakdownBox(r.food, r.travel, r.other, r.total),
        ],
      ),
    );
  }

  Widget _buildExpandedBreakdownBox(double food, double travel, double other, double total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AfTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AfTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_outlined, size: 14, color: AfTheme.maroon),
              const SizedBox(width: 6),
              const Text(
                'Work Cost Breakdown',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
              ),
              const SizedBox(width: 24),
              // Food
              const Icon(Icons.restaurant_outlined, size: 13, color: AfTheme.coral),
              const SizedBox(width: 4),
              Text('Food: ${AfTheme.formatCurrency(food)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
              const SizedBox(width: 20),
              // Travel
              const Icon(Icons.directions_car_outlined, size: 13, color: AfTheme.green),
              const SizedBox(width: 4),
              Text('Travel: ${AfTheme.formatCurrency(travel)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
              const SizedBox(width: 20),
              // Other
              const Icon(Icons.inventory_2_outlined, size: 13, color: AfTheme.purple),
              const SizedBox(width: 4),
              Text('Other: ${AfTheme.formatCurrency(other)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
            ],
          ),
          // Total Work Cost
          Row(
            children: [
              const Text('Total Work Cost', style: TextStyle(fontSize: 11, color: AfTheme.textSecondary)),
              const SizedBox(width: 8),
              Text(
                AfTheme.formatCurrency(total),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AfTheme.maroon),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _mockWorkCards() {
    final mockWorks = [
      ('ASHNA', 'BK-2611035503', '08 Nov 2026', 'Morning', 'Fayiza Irfana BI +1', 'Bridal Work', 1506.0, 0.0, 0.0, 1506.0, 'pending'),
      ('Sandra', 'BK-260932007', '08 Nov 2026', 'Morning', 'Fathima Nihala +2', 'Event', 1429.0, 0.0, 0.0, 1429.0, 'pending'),
      ('Megha Wedding', 'BK-260931982', '07 Nov 2026', 'Full Day', 'Anjali TK', 'Bridal Work', 6932.0, 0.0, 0.0, 6932.0, 'approved'),
      ('Nisha Event', 'BK-260931970', '06 Nov 2026', 'Evening', 'Anaswara', 'Event', 4810.0, 0.0, 0.0, 4810.0, 'approved'),
      ('Meera Shoot', 'BK-260931965', '05 Nov 2026', 'Full Day', 'Anshida', 'Model Shoot', 558.0, 0.0, 0.0, 558.0, 'pending'),
    ];

    return mockWorks.map((w) {
      final key = w.$2;
      final isExpanded = _expandedWorkIds.contains(key);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AfTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AfTheme.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Checkbox(value: false, activeColor: AfTheme.maroon, onChanged: (_) {}),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary)),
                        Text(w.$2, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.$3, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
                        Text(w.$4, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        AfInitialsAvatar(name: w.$5, size: 24),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(w.$5, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: AfCategoryBadge(category: w.$6),
                  ),
                  Expanded(
                    child: Text(
                      'Food ₹${w.$7.toInt()}  Travel ₹${w.$8.toInt()} • Other ₹${w.$9.toInt()}',
                      style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary),
                    ),
                  ),
                  Text(
                    AfTheme.formatCurrency(w.$10),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AfTheme.textPrimary),
                  ),
                  const SizedBox(width: 14),
                  AfStatusBadge(status: w.$11),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AfTheme.textSecondary),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedWorkIds.remove(key);
                        } else {
                          _expandedWorkIds.add(key);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            if (isExpanded) _buildExpandedBreakdownBox(w.$7, w.$8, w.$9, w.$10),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPaginationFooter(int totalWorks) {
    final page = widget.data?.page ?? 1;
    final totalPages = widget.data?.totalPages ?? 3;
    final limit = 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing 1–$limit of $totalWorks works',
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
              child: const Text('5 ▾', style: TextStyle(fontSize: 11, color: AfTheme.textPrimary)),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.first_page, size: 16, color: AfTheme.textSecondary),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left, size: 16, color: AfTheme.textSecondary),
            const SizedBox(width: 6),
            for (int p = 1; p <= totalPages; p++) ...[
              Container(
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
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right, size: 16, color: AfTheme.textSecondary),
            const SizedBox(width: 4),
            const Icon(Icons.last_page, size: 16, color: AfTheme.textSecondary),
          ],
        ),
      ],
    );
  }
}
