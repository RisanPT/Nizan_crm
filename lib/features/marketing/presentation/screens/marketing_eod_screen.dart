import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import '../../data/marketing_eod_models.dart';
import '../../services/marketing_eod_service.dart';
import '../../utils/marketing_eod_pdf.dart';
import '../widgets/marketing_eod_panels.dart';

class MarketingEodScreen extends ConsumerStatefulWidget {
  const MarketingEodScreen({super.key});

  @override
  ConsumerState<MarketingEodScreen> createState() => _MarketingEodScreenState();
}

class _MarketingEodScreenState extends ConsumerState<MarketingEodScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;
  late String _selectedMonth; // YYYY-MM
  String? _selectedMemberId; // For manager viewing other members

  // Form state for daily EOD entry
  final Map<String, TextEditingController> _metricControllers = {};
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  double _liveTotalOutput = 0;
  bool _isSaving = false;
  // The payload the form controllers were last filled from. Controllers are
  // refilled only when a new payload arrives, never on an ordinary rebuild
  // (otherwise every stepper tap would be overwritten by the server value).
  MarketingEodEntryPayload? _syncedPayload;
  String _draftNotice = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _selectedDate = DateTime.now();
    _selectedMonth = DateFormat('yyyy-MM').format(_selectedDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _metricControllers.values) {
      c.dispose();
    }
    _hoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  void _changeDate(int dayDelta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: dayDelta));
      _selectedMonth = DateFormat('yyyy-MM').format(_selectedDate);
    });
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      final parts = _selectedMonth.split('-');
      var y = int.parse(parts[0]);
      var m = int.parse(parts[1]) + monthDelta;
      if (m > 12) {
        y++;
        m = 1;
      } else if (m < 1) {
        y--;
        m = 12;
      }
      _selectedMonth = '$y-${m.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final accessAsync = ref.watch(marketingEodAccessProvider);
    final access = accessAsync.value ?? const MarketingEodAccess();
    final isManagerOrAdmin = access.isManager;
    final canViewTeam = access.canViewTeam;
    final accessReady = accessAsync.hasValue || accessAsync.hasError;

    return Scaffold(
      backgroundColor: crm.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(crm, isMobile, isManagerOrAdmin),
            Expanded(
              child: !accessReady
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildEodEntryTab(crm, isMobile, isManagerOrAdmin),
                        _buildIndividualDashboardTab(crm, isMobile, forSelf: true),
                        canViewTeam
                            ? _buildIndividualDashboardTab(crm, isMobile, forSelf: false)
                            : _restricted(crm, 'Team dashboards are for the Marketing Manager and Management.'),
                        canViewTeam
                            ? _buildTeamSummaryTab(crm, isMobile)
                            : _restricted(crm, 'The Team Summary is for the Marketing Manager and Management.'),
                        canViewTeam
                            ? _buildMissedEodsTab(crm, isMobile, isManagerOrAdmin)
                            : _restricted(crm, 'Missed-EOD tracking is for the Marketing Manager and Management.'),
                        _buildWeeklyStatsTab(crm, isMobile, access),
                        isManagerOrAdmin
                            ? _buildSetupTab(crm, isMobile)
                            : _restricted(crm, 'Setup is for the Marketing Manager and Admin.'),
                        isManagerOrAdmin
                            ? _buildMonthCloseTab(crm, isMobile)
                            : _restricted(crm, 'Month close is for the Marketing Manager.'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restricted(CrmTheme crm, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: crm.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(CrmTheme crm, bool isMobile, bool isManagerOrAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 14, isMobile ? 12 : 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assessment_outlined, color: crm.primary, size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Marketing EOD & Team Dashboard',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: crm.textPrimary,
                              ),
                            ),
                          ),
                          // The version tag is dropped on phones, where the title needs the room.
                          if (!isMobile) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: crm.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'v1.1 SRS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: crm.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Daily activity logging · Role profiles · Individual dashboards · Team summary',
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Month switcher widget in top bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: crm.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 18),
                        onPressed: () => _changeMonth(-1),
                        tooltip: 'Previous Month',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedMonth,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: crm.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        onPressed: () => _changeMonth(1),
                        tooltip: 'Next Month',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: crm.primary,
            unselectedLabelColor: crm.textSecondary,
            indicatorColor: crm.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.edit_calendar_outlined, size: 18), text: 'EOD Entry'),
              Tab(icon: Icon(Icons.person_outline, size: 18), text: 'My Dashboard'),
              Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Team Dashboards'),
              Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Team Summary'),
              Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Missed EODs'),
              Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Weekly Stats'),
              Tab(icon: Icon(Icons.tune_outlined, size: 18), text: 'Setup'),
              Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Month Close'),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: DAILY EOD ENTRY (FR-5, FR-6, FR-7)
  // ==========================================================================

  Widget _buildEodEntryTab(CrmTheme crm, bool isMobile, bool isManager) {
    final setupAsync = ref.watch(marketingEodSetupProvider);
    final members = setupAsync.value?.members ?? [];
    // A manager starts on their own row (server resolves it); others are fixed to themselves.
    final effectiveMemberId = isManager ? _selectedMemberId : null;
    final entryQuery = (date: _dateStr, memberId: effectiveMemberId);
    final entryAsync = ref.watch(marketingEodEntryProvider(entryQuery));

    return entryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading EOD entry: $e', style: TextStyle(color: crm.destructive)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(marketingEodEntryProvider(entryQuery)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (payload) {
        // Fill the form once per freshly loaded payload (after the frame, so
        // the text fields are never mutated mid-build).
        if (!identical(_syncedPayload, payload)) {
          _syncedPayload = payload;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && identical(_syncedPayload, payload)) _syncControllers(payload);
          });
        }

        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          children: [
            // Date Selector Bar + Manager Member Switcher
            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                // Wrap, not Row: member picker + date + chips run past a phone width.
                child: Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isManager && members.isNotEmpty) ...[
                      Text('Member: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: crm.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: crm.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: members.any((m) => m.id == (effectiveMemberId ?? payload.member.id))
                                ? (effectiveMemberId ?? payload.member.id)
                                : members.first.id,
                            dropdownColor: crm.surface,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: crm.textPrimary),
                            items: members
                                .where((m) => m.isActive || m.id == payload.member.id)
                                .map((m) => DropdownMenuItem(
                                      value: m.id,
                                      child: _memberName(m.shortName, crm),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMemberId = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _changeDate(-1),
                      tooltip: 'Previous Day',
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2026, 1, 1),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _selectedMonth = DateFormat('yyyy-MM').format(_selectedDate);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: crm.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: crm.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                          ? () => _changeDate(1)
                          : null,
                      tooltip: 'Next Day',
                    ),
                    const SizedBox(width: 8),
                    // Live Total Output Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Total Output: ${_liveTotalOutput.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Check Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (payload.checkStatus == 'OK' ? crm.success : crm.warning).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (payload.checkStatus == 'OK' ? crm.success : crm.warning).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            payload.checkStatus == 'OK' ? Icons.check_circle : Icons.warning_amber_rounded,
                            size: 14,
                            color: payload.checkStatus == 'OK' ? crm.success : crm.warning,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            payload.checkStatus,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: payload.checkStatus == 'OK' ? crm.success : crm.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Notice banner if locked or warning
            if (!payload.canEdit || payload.editNotice.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: crm.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: crm.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: crm.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payload.editNotice.isNotEmpty
                            ? payload.editNotice
                            : 'This entry is view-only.',
                        style: TextStyle(color: crm.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            if (_draftNotice.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: crm.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_draftNotice, style: TextStyle(color: crm.textPrimary, fontSize: 13))),
                    TextButton(
                      onPressed: () async {
                        await _clearDraft(payload);
                        if (mounted) _syncControllers(payload);
                      },
                      child: const Text('Discard draft'),
                    ),
                  ],
                ),
              ),

            // Hours Worked & Notes Card (Section 4 FR-5)
            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day Log Summary (Mandatory)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _hoursController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: payload.canEdit,
                            onChanged: (_) => _saveDraft(),
                            decoration: InputDecoration(
                              labelText: 'Hours Worked *',
                              hintText: 'e.g. 8',
                              prefixIcon: const Icon(Icons.schedule, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick hour chips
                        if (payload.canEdit) ...[
                          _quickHourChip(4),
                          const SizedBox(width: 8),
                          _quickHourChip(6),
                          const SizedBox(width: 8),
                          _quickHourChip(8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      enabled: payload.canEdit,
                      onChanged: (_) => _saveDraft(),
                      decoration: InputDecoration(
                        labelText: 'Notes / Highlights (Optional)',
                        hintText: 'Add brief note on accomplishments, blockers or leaves...',
                        prefixIcon: const Icon(Icons.edit_note, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Member-Specific Activities Grouped by Category (FR-5, FR-17)
            Text(
              'Your Activities for $_selectedMonth (Grouped)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: crm.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Only metrics configured in your role/profile appear below. Unreported activities default to 0.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
            const SizedBox(height: 12),

            if (payload.groupedMetrics.isEmpty)
              Card(
                color: crm.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No activities assigned to your profile for this month. Please configure in Setup.',
                      style: TextStyle(color: crm.textSecondary),
                    ),
                  ),
                ),
              )
            else
              for (final group in payload.groupedMetrics)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 14),
                  color: crm.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: crm.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: crm.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group.groupName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: crm.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${group.metrics.length} metrics',
                              style: TextStyle(fontSize: 11, color: crm.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final metric in group.metrics)
                          _buildMetricStepperRow(crm, metric, payload.canEdit),
                      ],
                    ),
                  ),
                ),

            // Submit Button
            if (payload.canEdit)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _submitEod(payload),
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving Entry...' : 'Save & Submit EOD Log'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crm.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _quickHourChip(double hrs) {
    final crm = context.crmColors;
    return InkWell(
      onTap: () {
        setState(() {
          _hoursController.text = hrs.toStringAsFixed(0);
        });
        _saveDraft();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: crm.border),
        ),
        child: Text('${hrs.toInt()}h', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: crm.primary)),
      ),
    );
  }

  Widget _buildMetricStepperRow(CrmTheme crm, MarketingMetricModel metric, bool canEdit) {
    final controller = _metricControllers.putIfAbsent(
      metric.id,
      () => TextEditingController(text: '0'),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        metric.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: crm.textPrimary),
                      ),
                    ),
                    if (metric.inTotalOutput) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'In Total',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: crm.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  metric.unitType == 'currency'
                      ? 'Currency (₹)'
                      : (metric.maxPerDay == null ? 'Count' : 'Count · usual max ${metric.maxPerDay!.toStringAsFixed(0)}/day'),
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ],
            ),
          ),
          // Stepper Controls
          if (canEdit && metric.unitType != 'currency')
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  onPressed: () {
                    final current = int.tryParse(controller.text) ?? 0;
                    if (current > 0) {
                      controller.text = (current - 1).toString();
                      _recalculateLiveTotal();
                    }
                  },
                ),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculateLiveTotal(),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  onPressed: () {
                    final current = int.tryParse(controller.text) ?? 0;
                    controller.text = (current + 1).toString();
                    _recalculateLiveTotal();
                  },
                ),
              ],
            )
          else
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: controller,
                enabled: canEdit,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _recalculateLiveTotal(),
                decoration: InputDecoration(
                  prefixText: metric.unitType == 'currency' ? '₹ ' : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _syncControllers(MarketingEodEntryPayload payload) {
    _hoursController.text = payload.hoursWorked > 0 ? payload.hoursWorked.toStringAsFixed(0) : '';
    _notesController.text = payload.notes;

    for (final group in payload.groupedMetrics) {
      for (final metric in group.metrics) {
        final val = payload.values[metric.id] ?? 0.0;
        final c = _metricControllers.putIfAbsent(
          metric.id,
          () => TextEditingController(),
        );
        c.text = val > 0 ? (metric.unitType == 'currency' ? val.toStringAsFixed(0) : val.toInt().toString()) : '0';
      }
    }
    _recalculateLiveTotal(fromUser: false);
    _restoreDraft(payload);
  }

  // ── Local draft (FR-5 / NFR: keep the form if the connection drops) ───────

  String _draftKey(MarketingEodEntryPayload payload) =>
      'mkt_eod_draft_${payload.member.id}_${payload.entryDate}';

  Future<void> _saveDraft() async {
    final payload = _syncedPayload;
    if (payload == null || !payload.canEdit) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey(payload),
        jsonEncode({
          'hours': _hoursController.text,
          'notes': _notesController.text,
          'values': {for (final e in _metricControllers.entries) e.key: e.value.text},
        }),
      );
    } catch (_) {
      // Drafts are a convenience; never block entry on storage problems.
    }
  }

  Future<void> _clearDraft(MarketingEodEntryPayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey(payload));
    } catch (_) {}
    if (mounted) setState(() => _draftNotice = '');
  }

  Future<void> _restoreDraft(MarketingEodEntryPayload payload) async {
    if (!payload.canEdit) {
      if (_draftNotice.isNotEmpty && mounted) setState(() => _draftNotice = '');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey(payload));
      if (raw == null || !mounted || !identical(_syncedPayload, payload)) {
        if (_draftNotice.isNotEmpty && mounted) setState(() => _draftNotice = '');
        return;
      }
      final draft = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _hoursController.text = draft['hours']?.toString() ?? '';
      _notesController.text = draft['notes']?.toString() ?? '';
      final values = (draft['values'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final e in values.entries) {
        final c = _metricControllers[e.key];
        if (c != null) c.text = e.value?.toString() ?? '0';
      }
      _recalculateLiveTotal(fromUser: false);
      if (mounted) setState(() => _draftNotice = 'Restored your unsaved draft for this day. Save to submit it.');
    } catch (_) {}
  }

  void _recalculateLiveTotal({bool fromUser = true}) {
    double sum = 0;
    final payload = _syncedPayload;
    if (payload != null) {
      for (final group in payload.groupedMetrics) {
        for (final m in group.metrics) {
          if (m.inTotalOutput) {
            final val = double.tryParse(_metricControllers[m.id]?.text ?? '0') ?? 0;
            sum += val;
          }
        }
      }
    }
    setState(() {
      _liveTotalOutput = sum;
    });
    if (fromUser) _saveDraft();
  }

  Future<String?> _askReason(String title, String hint) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    final text = c.text.trim();
    c.dispose();
    if (ok != true || text.isEmpty) return null;
    return text;
  }

  Future<void> _submitEod(MarketingEodEntryPayload payload) async {
    final hours = double.tryParse(_hoursController.text) ?? 0.0;
    final values = <Map<String, dynamic>>[];
    for (final group in payload.groupedMetrics) {
      for (final metric in group.metrics) {
        final val = double.tryParse(_metricControllers[metric.id]?.text ?? '') ?? 0.0;
        if (val > 0) values.add({'metricId': metric.id, 'value': val});
      }
    }

    if (hours <= 0 && values.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the hours worked. A day with counts but no hours is not counted as reported.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // FR-15: a manager editing another member's row, or a late row, gives a reason.
    String? reason;
    if (payload.reasonRequired) {
      reason = await _askReason('Reason for this edit', 'e.g. Member was on shoot; entered on their behalf');
      if (reason == null) return;
    }

    setState(() => _isSaving = true);
    try {
      final warnings = await ref.read(marketingEodServiceProvider).saveEodEntry({
        'memberId': payload.member.id,
        'entryDate': _dateStr,
        'hoursWorked': hours,
        'notes': _notesController.text.trim(),
        'values': values,
        'overrideReason': ?reason,
      });
      await _clearDraft(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warnings.isEmpty ? 'EOD Entry saved successfully!' : 'Saved. Please double-check: ${warnings.join(' ')}'),
          backgroundColor: warnings.isEmpty ? Colors.green : Colors.orange,
          duration: Duration(seconds: warnings.isEmpty ? 3 : 8),
        ),
      );

      // Invalidate relevant providers to refresh live data
      ref.invalidate(marketingEodEntryProvider((date: _dateStr, memberId: _selectedMemberId)));
      ref.invalidate(marketingIndividualDashboardProvider((month: _selectedMonth, memberId: _selectedMemberId)));
      ref.invalidate(marketingTeamSummaryProvider(_selectedMonth));
      ref.invalidate(marketingMissedEodsProvider(_selectedMonth));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save EOD: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================================================
  // TAB 2 & 3: INDIVIDUAL DASHBOARD (FR-8)
  // ==========================================================================

  Widget _buildIndividualDashboardTab(CrmTheme crm, bool isMobile, {required bool forSelf}) {
    final setupAsync = ref.watch(marketingEodSetupProvider);
    final members = setupAsync.value?.members ?? [];
    final effectiveMemberId = forSelf
        ? null
        : (_selectedMemberId ?? (members.isNotEmpty ? members.first.id : null));
    final query = (month: _selectedMonth, memberId: effectiveMemberId);
    final dashAsync = ref.watch(marketingIndividualDashboardProvider(query));

    return dashAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading dashboard: $e', style: TextStyle(color: crm.destructive)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(marketingIndividualDashboardProvider(query)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final showPicker = !forSelf && setupAsync.hasValue;
        final picker = <Widget>[
          Text('Member: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.textPrimary)),
          if (members.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crm.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: members.any((m) => m.id == (effectiveMemberId ?? data.member.id))
                      ? (effectiveMemberId ?? data.member.id)
                      : members.first.id,
                  dropdownColor: crm.surface,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: crm.textPrimary),
                  items: members.map((m) {
                    return DropdownMenuItem(
                      value: m.id,
                      child: _memberName(m.shortName, crm),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMemberId = val;
                      });
                    }
                  },
                ),
              ),
            ),
        ];
        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          children: [
            // Header Bar with Member Switcher (for Manager view) + PDF actions.
            // On phones the picker gets its own line above the name.
            if (isMobile && showPicker)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: picker),
              ),
            Row(
              children: [
                if (!isMobile && showPicker) ...[
                  ...picker,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.member.name} (${data.member.role ?? ""})',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: crm.textPrimary),
                      ),
                      Text('Period: ${data.period}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => downloadIndividualDashboardPdf(data),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('PDF'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => printIndividualDashboardPdf(data),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: crm.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4 Summary KPI Tiles (FR-8)
            Row(
              children: [
                _kpiTile(crm, 'Days Reported', data.summaryTiles['daysReported']?.toString() ?? '—', Icons.today),
                const SizedBox(width: 8),
                _kpiTile(crm, 'Total Output', data.summaryTiles['totalOutput']?.toString() ?? '0', Icons.done_all),
                const SizedBox(width: 8),
                _kpiTile(
                  crm,
                  'Target Achieved',
                  '${data.summaryTiles['targetAchievedPct'] ?? 0}%',
                  Icons.stars,
                  color: _scoreColor(data.summaryTiles['targetAchievedPct'] as int? ?? 0),
                ),
                const SizedBox(width: 8),
                _kpiTile(
                  crm,
                  'MTD vs Expected (${data.summaryTiles['workingDaysElapsed'] ?? 0}/${data.summaryTiles['workingDays'] ?? 0} days)',
                  data.summaryTiles['mtdPacePct'] != null ? '${data.summaryTiles['mtdPacePct']}%' : '—',
                  Icons.speed,
                  color: data.summaryTiles['mtdPacePct'] != null
                      ? _scoreColor((data.summaryTiles['mtdPacePct'] as num).toInt())
                      : null,
                ),
                const SizedBox(width: 8),
                _kpiTile(crm, 'Hours Worked', data.summaryTiles['hoursWorked']?.toString() ?? '—', Icons.schedule),
              ],
            ),
            const SizedBox(height: 12),

            // Table 1: Activity Numbers — Target vs Achieved (FR-8)
            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Numbers - Target vs Achieved',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(crm.background),
                        columns: const [
                          DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Target', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Achieved', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Achieved %', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Expected by Today', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('MTD vs Expected', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Daily Avg', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Best Day', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: data.activityNumbers.map((row) {
                          return DataRow(cells: [
                            DataCell(Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(row.groupName)),
                            DataCell(Text(row.target != null ? row.target!.toStringAsFixed(0) : '—')),
                            DataCell(Text(row.achieved.toStringAsFixed(0))),
                            DataCell(Text(row.achievedPct != null ? '${row.achievedPct}%' : '—')),
                            DataCell(Text(row.expectedToDate != null ? row.expectedToDate!.toStringAsFixed(1) : '—')),
                            DataCell(row.pacePct != null
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('${row.pacePct}%  '),
                                    _statusBadge(crm, row.paceStatus),
                                  ])
                                : const Text('—')),
                            DataCell(Text(row.dailyAvg)),
                            DataCell(Text(row.bestDay['count'] != null && row.bestDay['count'] > 0
                                ? '${row.bestDay['count']} (${row.bestDay['date']?.toString().split('-').last ?? ""})'
                                : '—')),
                            DataCell(_statusBadge(crm, row.status)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Table 2: Week-wise Activity Numbers (FR-8)
            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week-wise Activity Numbers (Fixed Date Blocks)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(crm.background),
                        columns: const [
                          DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('W1 (01-07)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('W2 (08-14)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('W3 (15-21)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('W4 (22-28)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('W5 (29-31)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Month Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        ],
                        rows: [
                          ...data.weekWiseRows.map((w) {
                            return DataRow(cells: [
                              DataCell(Text(w.name)),
                              DataCell(Text(w.w1.toStringAsFixed(0))),
                              DataCell(Text(w.w2.toStringAsFixed(0))),
                              DataCell(Text(w.w3.toStringAsFixed(0))),
                              DataCell(Text(w.w4.toStringAsFixed(0))),
                              DataCell(Text(w.w5.toStringAsFixed(0))),
                              DataCell(Text(w.monthTotal.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ]);
                          }),
                          // Total Output Row
                          DataRow(
                            color: WidgetStateProperty.all(crm.primary.withValues(alpha: 0.08)),
                            cells: [
                              DataCell(Text('TOTAL OUTPUT', style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary))),
                              DataCell(Text(data.totalOutputRow.w1.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(data.totalOutputRow.w2.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(data.totalOutputRow.w3.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(data.totalOutputRow.w4.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(data.totalOutputRow.w5.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(data.totalOutputRow.monthTotal.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Daily Calendar Output Grid (FR-8)
            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Daily Output Calendar Grid',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _gridLegendItem(crm, Colors.green, 'Reported'),
                            _gridLegendItem(crm, Colors.red, 'Missed EOD'),
                            _gridLegendItem(crm, Colors.grey, 'Off / Sunday'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.dailyGrid.map((d) {
                        Color tileColor = crm.background;
                        Color textColor = crm.textPrimary;
                        if (d.color == 'green') {
                          tileColor = Colors.green.withValues(alpha: 0.15);
                          textColor = Colors.green.shade800;
                        } else if (d.color == 'red') {
                          tileColor = Colors.red.withValues(alpha: 0.15);
                          textColor = Colors.red.shade800;
                        } else if (d.color == 'grey') {
                          tileColor = Colors.grey.withValues(alpha: 0.12);
                          textColor = Colors.grey.shade600;
                        }

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDate = DateTime.parse(d.date);
                              _tabController.animateTo(0); // Jump to EOD Entry for that day!
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tileColor.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${d.day}', style: TextStyle(fontSize: 10, color: textColor)),
                                // Shrinks a 5+ digit output instead of wrapping it out of the 52px tile.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    d.output > 0 ? d.output.toStringAsFixed(0) : (d.color == 'grey' ? 'OFF' : '0'),
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Highlights & Remarks Card (FR-12)
            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Highlights & Manager Remarks',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.remarks['managerRemarks']?.toString().isNotEmpty == true
                          ? data.remarks['managerRemarks'].toString()
                          : 'No remarks published yet.',
                      style: TextStyle(fontSize: 13, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              data.remarks['memberAckAt'] != null
                                  ? 'Acknowledged on: ${DateFormat('d MMM yyyy').format(DateTime.parse(data.remarks['memberAckAt']))}'
                                  : 'Not yet acknowledged',
                              style: TextStyle(fontSize: 12, color: crm.textSecondary),
                            ),
                            if (forSelf && data.remarks['memberAckAt'] == null)
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await ref.read(marketingEodServiceProvider).signOffMonth(
                                          memberId: data.member.id,
                                          month: _selectedMonth,
                                          action: 'member_ack',
                                        );
                                    ref.invalidate(marketingIndividualDashboardProvider(query));
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not acknowledge: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: const Text('Acknowledge'),
                              ),
                          ],
                        ),
                        Text(
                          data.remarks['managerSignedAt'] != null
                              ? 'Signed off on: ${DateFormat('d MMM yyyy').format(DateTime.parse(data.remarks['managerSignedAt']))}'
                              : 'Pending Manager Sign-off',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiTile(CrmTheme crm, String title, String value, IconData icon, {Color? color}) {
    final c = color ?? crm.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: c),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// A member's name in a picker, capped so a long name can't push the
  /// dropdown past the screen edge.
  Widget _memberName(String name, CrmTheme crm) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: crm.textPrimary)),
    );
  }

  /// Title block with action buttons: one Row on wide screens, the buttons on
  /// their own wrapping line under the title on phones.
  Widget _headerWithActions(bool isMobile, Widget title, List<Widget> actions) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    );
  }

  Widget _gridLegendItem(CrmTheme crm, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ],
    );
  }

  Color _scoreColor(int pct) {
    if (pct >= 100) return Colors.green.shade700;
    if (pct >= 70) return Colors.amber.shade800;
    return Colors.red.shade700;
  }

  Widget _statusBadge(CrmTheme crm, String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    String label = status.toUpperCase();

    if (status == 'green') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (status == 'amber') {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade900;
    } else if (status == 'red') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ==========================================================================
  // TAB 4: TEAM SUMMARY (FR-9)
  // ==========================================================================

  Future<void> _exportRecordsCsv() async {
    try {
      final data = await ref.read(marketingEodServiceProvider).exportRecords(_selectedMonth);
      if (data.rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No EOD records for this month yet.')),
        );
        return;
      }
      await ExportUtils.exportCsv('marketing-eod-records-$_selectedMonth.csv', [data.headers, ...data.rows]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTeamSummaryTab(CrmTheme crm, bool isMobile) {
    final summaryAsync = ref.watch(marketingTeamSummaryProvider(_selectedMonth));

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading team summary: $e', style: TextStyle(color: crm.destructive)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(marketingTeamSummaryProvider(_selectedMonth)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        final ov = data.overviewRows;

        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          children: [
            _headerWithActions(
              isMobile,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketing Team Summary - $_selectedMonth',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: crm.textPrimary),
                  ),
                  Text('All members side-by-side with team totals', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
              [
                OutlinedButton.icon(
                  onPressed: _exportRecordsCsv,
                  icon: const Icon(Icons.table_view, size: 16),
                  label: const Text('Export records (CSV)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => downloadTeamSummaryPdf(data),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export PDF (Landscape)'),
                ),
                ElevatedButton.icon(
                  onPressed: () => printTeamSummaryPdf(data),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: crm.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(crm.background),
                    columns: [
                      const DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...data.members.map((m) => DataColumn(
                            label: Text(m.shortName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                          )),
                      const DataColumn(label: Text('TEAM TOTAL', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: [
                      // Overview Rows
                      _teamOverviewRow(crm, 'OVERVIEW', 'Days Reported', ov['daysReported'], data.members),
                      _teamOverviewRow(crm, 'OVERVIEW', 'Hours Worked', ov['hoursWorked'], data.members),
                      _teamOverviewRow(crm, 'OVERVIEW', 'Total Output', ov['totalOutput'], data.members),
                      _teamOverviewRow(crm, 'OVERVIEW', 'Avg Target Achieved', ov['avgTargetAchieved'], data.members),
                      _teamOverviewRow(crm, 'OVERVIEW', 'MTD vs Expected', ov['mtdPace'], data.members),
                      _teamOverviewRow(crm, 'OVERVIEW', 'Working Days (so far / month)', ov['workingDaysElapsed'], data.members),

                      // Metric Rows
                      ...data.metricRows.map((m) {
                        return DataRow(cells: [
                          DataCell(Text(m.groupName, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          ...data.members.map((mem) {
                            final val = m.memberValues[mem.id];
                            return DataCell(Text(val != null ? val.toString() : '—'));
                          }),
                          DataCell(m.teamExpected != null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(m.teamTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      'exp ${m.teamExpected!.toStringAsFixed(1)}'
                                      '${m.teamPacePct != null ? ' · ${m.teamPacePct}%' : ''}',
                                      style: TextStyle(fontSize: 10, color: crm.textSecondary),
                                    ),
                                  ],
                                )
                              : Text(m.teamTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ]);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  DataRow _teamOverviewRow(
    CrmTheme crm,
    String group,
    String label,
    dynamic obj,
    List<MarketingTeamMemberModel> members,
  ) {
    final mVals = (obj is Map ? obj['memberValues'] as Map? : null) ?? {};
    final tTotal = (obj is Map ? obj['teamTotal'] : null) ?? '—';

    return DataRow(
      color: WidgetStateProperty.all(crm.primary.withValues(alpha: 0.05)),
      cells: [
        DataCell(Text(group, style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary, fontSize: 11))),
        DataCell(Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary))),
        ...members.map((mem) => DataCell(
              Text(mVals[mem.id]?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
        DataCell(Text(tTotal.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary))),
      ],
    );
  }

  // ==========================================================================
  // TAB 5: MISSED EODs TRACKER (FR-11)
  // ==========================================================================

  Widget _buildMissedEodsTab(CrmTheme crm, bool isMobile, bool isManager) {
    final missedAsync = ref.watch(marketingMissedEodsProvider(_selectedMonth));

    return missedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
      data: (data) {
        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missed EODs Tracking - $_selectedMonth',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: crm.textPrimary),
                      ),
                      Text('List of past working days without filed hours', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${data.totalMissedCount} Missed Reports',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (data.missedList.isEmpty)
              Card(
                color: crm.surface,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                        const SizedBox(height: 12),
                        Text('Awesome! No missed EOD logs for this month.', style: TextStyle(color: crm.textPrimary)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                color: crm.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: crm.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.missedList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final item = data.missedList[idx];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFEBEE),
                        child: Icon(Icons.warning, color: Colors.red, size: 20),
                      ),
                      title: Text(item.memberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Missed Working Day: ${item.date}'),
                      trailing: isManager
                          ? ElevatedButton(
                              onPressed: () async {
                                try {
                                  final message = await ref
                                      .read(marketingEodServiceProvider)
                                      .sendReminder(memberId: item.memberId, date: item.date);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: const Text('Send Reminder'),
                            )
                          : null,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 6: WEEKLY PAGE STATS (FR-18)
  // ==========================================================================

  Widget _buildWeeklyStatsTab(CrmTheme crm, bool isMobile, MarketingEodAccess access) {
    return ListView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      children: [
        Text(
          'Weekly Social Media Page Performance (FR-18)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: crm.textPrimary),
        ),
        Text(
          'Posts, reach and engagement per week for both pages (Team N Makeovers & Team N Kerala)',
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
        const SizedBox(height: 12),
        EodWeeklyStatsPanel(month: _selectedMonth, access: access),
      ],
    );
  }

  // ==========================================================================
  // TAB 7: SETUP & MASTER DATA (FR-1 to FR-4, FR-17)
  // ==========================================================================

  Widget _buildSetupTab(CrmTheme crm, bool isMobile) {
    final setupAsync = ref.watch(marketingEodSetupProvider);

    return setupAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
      data: (setup) {
        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marketing EOD Setup (FR-1 to FR-4, FR-17)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: crm.textPrimary),
                      ),
                      Text(
                        'Settings, targets, groups, activities, roles, role profiles and team members — no developer needed.',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showEodAuditLog(context, ref),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Audit log'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            EodSettingsPanel(setup: setup),
            EodTargetsPanel(setup: setup, month: _selectedMonth),
            EodCataloguePanel(setup: setup),
            EodRoleProfilesPanel(setup: setup, month: _selectedMonth),
            EodMembersPanel(setup: setup, month: _selectedMonth),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // TAB 8: MONTH CLOSE & SIGN-OFF (FR-12)
  // ==========================================================================

  Widget _buildMonthCloseTab(CrmTheme crm, bool isMobile) {
    final setupAsync = ref.watch(marketingEodSetupProvider);
    final members = setupAsync.value?.members ?? [];
    final effectiveMemberId = _selectedMemberId ?? (members.isNotEmpty ? members.first.id : null);
    final dashQuery = (month: _selectedMonth, memberId: effectiveMemberId);
    final dashAsync = ref.watch(marketingIndividualDashboardProvider(dashQuery));
    final remarksController = TextEditingController();

    return dashAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
      data: (data) {
        remarksController.text = data.remarks['managerRemarks']?.toString() ?? '';
        final isClosed = data.remarks['monthStatus'] == 'closed';

        return ListView(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          children: [
            _headerWithActions(
              isMobile,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Month Close & Digital Sign-off - $_selectedMonth',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: crm.textPrimary),
                  ),
                  Text(
                    'Publish manager remarks, sign off dashboard, and close the month against further edits.',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
              [
                if (members.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Member: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: crm.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: crm.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: members.any((m) => m.id == effectiveMemberId) ? effectiveMemberId : members.first.id,
                            dropdownColor: crm.surface,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: crm.textPrimary),
                            items: members.map((m) {
                              return DropdownMenuItem(
                                value: m.id,
                                child: _memberName(m.shortName, crm),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMemberId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              color: crm.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: crm.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Month Status: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isClosed ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isClosed ? 'CLOSED / LOCKED' : 'OPEN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isClosed ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Manager Highlights & Remarks',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(marketingEodServiceProvider).saveRemarks({
                              'memberId': data.member.id,
                              'month': _selectedMonth,
                              'managerRemarks': remarksController.text.trim(),
                              'published': true,
                            });
                            ref.invalidate(marketingIndividualDashboardProvider(dashQuery));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Remarks published!')),
                            );
                          },
                          icon: const Icon(Icons.publish),
                          label: const Text('Save & Publish Remarks'),
                        ),
                        if (!isClosed)
                          ElevatedButton.icon(
                            onPressed: () async {
                              await ref.read(marketingEodServiceProvider).signOffMonth(
                                    memberId: data.member.id,
                                    month: _selectedMonth,
                                    action: 'manager_sign',
                                  );
                              ref.invalidate(marketingIndividualDashboardProvider(dashQuery));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Month signed off and closed!')),
                              );
                            },
                            icon: const Icon(Icons.lock),
                            label: const Text('Sign-off & Lock Month'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () async {
                              final reason = await _askReason('Reopen this month?', 'Reason for reopening (kept in the audit log)');
                              if (reason == null) return;
                              try {
                                await ref.read(marketingEodServiceProvider).reopenMonth(
                                      memberId: data.member.id,
                                      month: _selectedMonth,
                                      reason: reason,
                                    );
                                ref.invalidate(marketingIndividualDashboardProvider(dashQuery));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Month reopened for editing!')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Reopen Month'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
