import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/image_download_service.dart';
import 'package:dio/dio.dart';
import '../../core/auth/app_role.dart';
import '../../core/extensions/space_extension.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import '../../services/employee_service.dart';
import '../../core/models/employee.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import '../../services/upload_service.dart';
import '../../services/report_service.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import '../../core/utils/booking_print_service.dart';
import '../../core/providers/trial_provider.dart';
import '../../core/models/trial.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart' show TeamAmount;
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/meal_placement.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_day_timeline.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/expense_allocation_line.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/food_allowance_manager.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/work_costs_tab.dart';
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';


class ArtistFinanceScreen extends HookConsumerWidget {
  const ArtistFinanceScreen({super.key});

  static const _paymentModes = [
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('bank_transfer', 'Bank Transfer'),
    ('other', 'Other'),
    ('split', 'Split Payment (Cash + UPI)'),
  ];

  /// What the spend was for. Separate from category (kind of spend) so bridal
  /// client work and internal model shoots report independently.
  static const _workTypes = [
    ('bridal', 'Bridal Work', Icons.diamond_outlined),
    ('model_shoot', 'Model Shoot', Icons.camera_alt_outlined),
  ];

  static const _expenseCategories = [
    ('food', 'Food'),
    ('travel', 'Travel'),
    ('stay', 'Stay'),
    ('materials', 'Materials'),
    ('fuel', 'Fuel'),
    ('other', 'Other'),
  ];

  /// Small total card used for the bridal / model-shoot expense split.
  static Widget _workTypeTotalCard(
      CrmTheme crm, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          8.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                2.h,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: crm.textPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _currency(double v) => '₹ ${v.toStringAsFixed(0)}';



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    // ── Role + identity ──────────────────────────────────────────────────────
    final session = ref.watch(authSessionProvider);
    final role = AppRole.fromString(session?.role);
    final myEmployeeId = session?.employeeId ?? '';
    final canVerify = role.canVerifyFinance;
    final isScopedToOwn = role.isScopedToOwnEntries;
    // Accounts also gets "Work costs": what each work cost, with the artists' food placed under it.
    final tabCtrl = useTabController(initialLength: canVerify ? 3 : 2);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncTrials = ref.watch(allTrialsProvider);

    // Filter bookings for this artist if scoped.
    // An artist may be assigned at the BOOKING level OR on an individual package
    // (bookingItem) of a multi-package booking. The booking-level `assignedStaff`
    // is only a rolled-up summary and isn't always populated for per-package
    // assignments, so match either level — mirroring the backend's own
    // `$or: [assignedStaff.employeeId, bookingItems.assignedStaff.employeeId]`.
    // Without the item-level check, a newly assigned package's client never
    // shows up in the collection picker.
    final myBookings = (asyncBookings.value ?? []).where((b) {
      if (!isScopedToOwn) return true;
      final assignedAtBooking =
          b.assignedStaff.any((s) => s.employeeId == myEmployeeId);
      final assignedAtItem = b.bookingItems.any(
        (item) => item.assignedStaff.any((s) => s.employeeId == myEmployeeId),
      );
      return assignedAtBooking || assignedAtItem;
    }).toList();

    // Filter trials for this artist if scoped
    final myTrials = (asyncTrials.value ?? []).where((t) {
      if (!isScopedToOwn) return true;
      return t.assignedStaff.any((s) => s.employeeId == myEmployeeId);
    }).toList();

    // ── What is being looked at ──────────────────────────────────────────────
    // The period is shared; each tab keeps its OWN filters, search, sort and page
    // (a payment mode means nothing to expenses, a category nothing to collections).
    // Filtering, sorting and paging all happen on the SERVER, so the totals and the
    // page counts are right however many entries there are. An artist only ever gets
    // their own entries — the server scopes them.
    final asyncEmployees = ref.watch(employeesProvider);
    final period = useState(FinancePeriod.month);
    final month = useState(FinancePeriodBar.thisMonth());
    final range = useState<DateTimeRange?>(null);

    FinanceQuery inPeriod(FinanceQuery q, FinancePeriod p, DateTime m, DateTimeRange? r) {
      String d(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
      switch (p) {
        case FinancePeriod.all:
          return q.refiltered(from: null, to: null);
        case FinancePeriod.range:
          return q.refiltered(from: r == null ? null : d(r.start), to: r == null ? null : d(r.end));
        case FinancePeriod.month:
          final (from, to) = FinanceQuery.monthBounds(m);
          return q.refiltered(from: from, to: to);
      }
    }

    final collectionQuery = useState<FinanceQuery>(inPeriod(const FinanceQuery(), period.value, month.value, range.value));
    final expenseQuery = useState<FinanceQuery>(inPeriod(const FinanceQuery(withWorks: true), period.value, month.value, range.value));

    void setPeriod(FinancePeriod p, {DateTime? newMonth, DateTimeRange? newRange}) {
      final m = newMonth == null ? month.value : DateTime(newMonth.year, newMonth.month);
      final r = newRange ?? range.value;
      period.value = p;
      month.value = m;
      range.value = r;
      collectionQuery.value = inPeriod(collectionQuery.value, p, m, r);
      expenseQuery.value = inPeriod(expenseQuery.value, p, m, r);
    }

    final asyncCollections = ref.watch(financeCollectionsPageProvider(collectionQuery.value));
    final asyncExpenses = ref.watch(financeExpensesPageProvider(expenseQuery.value));
    // The last page that loaded stays on screen while the next one is fetched.
    final lastCollections = useRef<FinancePage<ArtistCollection>?>(null);
    final lastExpenses = useRef<FinancePage<ArtistExpense>?>(null);
    if (asyncCollections.hasValue) lastCollections.value = asyncCollections.value;
    if (asyncExpenses.hasValue) lastExpenses.value = asyncExpenses.value;
    final collectionData = asyncCollections.value ?? lastCollections.value;
    final expenseData = asyncExpenses.value ?? lastExpenses.value;

    // Approving / deleting the only entry on the last page leaves that page empty:
    // step back to the last page that still exists.
    void clampPage(FinancePage<dynamic>? d, ValueNotifier<FinanceQuery> q) {
      if (d != null && d.page == q.value.page && d.page > d.totalPages && d.totalPages >= 1) {
        Future.microtask(() => q.value = q.value.copyWith(page: d.totalPages));
      }
    }

    useEffect(() {
      clampPage(collectionData, collectionQuery);
      return null;
    }, [collectionData]);
    useEffect(() {
      clampPage(expenseData, expenseQuery);
      return null;
    }, [expenseData]);

    final collSummary = collectionData?.summary;
    final expSummary = expenseData?.summary;
    // "Collected" is what Accounts has verified — pending and rejected never count.
    final totalCollected = collSummary?.status('verified').amount ?? 0.0;
    final verifiedCount = collSummary?.status('verified').count ?? 0;
    final pendingCollections = collSummary?.status('pending').count ?? 0;
    final pendingExpenses = expSummary?.status('pending').count ?? 0;
    final pendingCount = pendingCollections + pendingExpenses;
    // Split by what the spend was for, so the two streams can be read independently.
    double workTotal(String type) =>
        expSummary?.byWorkType.where((w) => w.key == type).fold<double>(0, (a, w) => a + w.amount) ?? 0.0;
    final bridalExpenseTotal = workTotal('bridal');
    final modelShootExpenseTotal = workTotal('model_shoot');
    final periodText = switch (period.value) {
      FinancePeriod.all => 'All time',
      FinancePeriod.range => 'Custom range',
      FinancePeriod.month => '${_getMonthName(month.value.month)} ${month.value.year}',
    };

    List<NameOption> artistOptionsFor(String? selected) => <NameOption>[
          for (final e in asyncEmployees.value ?? const <Employee>[])
            if ((e.isActive && e.isArtist) || e.id == selected) (id: e.id, name: e.name),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    Future<void> openFilters(FinanceKind kind) async {
      final isColl = kind == FinanceKind.collection;
      final holder = isColl ? collectionQuery : expenseQuery;
      final next = await showFinanceFilters(
        context,
        kind: kind,
        current: holder.value,
        // An artist sees only their own, so there is nobody to pick.
        artists: isScopedToOwn ? null : artistOptionsFor(holder.value.employeeId),
      );
      if (next != null) holder.value = next;
    }

    // ── Split Payment Prompt Dialog ─────────────────────────────────────────
    Future<bool?> showSplitPaymentDialog(BuildContext ctx) {
      return showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (dCtx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_split_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                16.h,
                Text(
                  'Split Payment?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                12.h,
                Text(
                  'Did the client pay using another method for the same booking?\n\n'
                  'Example: ₹5,000 Cash already logged → now add ₹3,000 via UPI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                24.h,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text(
                          'No, Done',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text(
                          'Yes, Add More',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> addCollectionDialogSplit({
      required BuildContext context,
      required WidgetRef ref,
      required ThemeData theme,
      required CrmTheme crm,
      required bool isScopedToOwn,
      required String myEmployeeId,
      // Concretely typed so the EmployeeSelection extension (isActive/isArtist)
      // resolves — a `dynamic` element silently loses extension members and
      // crashes at runtime with "NoSuchMethodError: 'isActive'".
      required AsyncValue<List<Employee>> asyncEmployees,
      required List<Booking> myBookings,
      required List<Trial> myTrials,
      String? prefilledBookingId,
      String? prefilledTrialId,
      String? prefilledEmployeeId,
      DateTime? prefilledDate,
    }) async {
      final amountCtrl = TextEditingController();
      final cashAmountCtrl = TextEditingController();
      final upiAmountCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      var selEmployee = prefilledEmployeeId ?? (isScopedToOwn ? myEmployeeId : '');
      var selBooking = prefilledBookingId ?? '';
      var selTrial = prefilledTrialId ?? '';
      var collectType = prefilledTrialId != null ? 'trial' : 'booking';
      var payMode = 'cash';
      var selDate = prefilledDate ?? DateTime.now();
      XFile? attachmentFile;
      bool isUploading = false;
      // Split payments are two requests; if the cash half saved but the UPI
      // half failed, a retry must not log the cash half a second time.
      bool splitCashSaved = false;
      final formKey = GlobalKey<FormState>();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final employees = asyncEmployees.value ?? [];
            final artists = employees
                .where((e) => (e.isActive && e.artistRole != 'driver') || e.id == selEmployee)
                .toList();
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          24.h,
                          if (prefilledBookingId != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: crm.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.call_split, color: crm.primary),
                                  12.w,
                                  const Expanded(child: Text("Split payment in progress. Recording a partial amount for the selected booking.")),
                                ],
                              ),
                            ),
                          if (prefilledTrialId != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: crm.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.call_split, color: crm.primary),
                                  12.w,
                                  const Expanded(child: Text("Split payment in progress. Recording a partial amount for the selected trial.")),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: crm.success.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_chart_outlined,
                                  size: 24,
                                  color: crm.success,
                                ),
                              ),
                              16.w,
                              Text(
                                'Log Fund Collection',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          16.h,
                          const Text(
                            'Select the booking or trial and enter the amount received from the client.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          24.h,
                          if (prefilledBookingId == null && prefilledTrialId == null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('Booking Work', style: TextStyle(fontWeight: FontWeight.bold))),
                                    selected: collectType == 'booking',
                                    selectedColor: crm.primary.withValues(alpha: 0.15),
                                    checkmarkColor: crm.primary,
                                    labelStyle: TextStyle(
                                      color: collectType == 'booking' ? crm.primary : crm.textSecondary,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => collectType = 'booking');
                                    },
                                  ),
                                ),
                                12.w,
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('Trial Appointment', style: TextStyle(fontWeight: FontWeight.bold))),
                                    selected: collectType == 'trial',
                                    selectedColor: crm.primary.withValues(alpha: 0.15),
                                    checkmarkColor: crm.primary,
                                    labelStyle: TextStyle(
                                      color: collectType == 'trial' ? crm.primary : crm.textSecondary,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => collectType = 'trial');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            16.h,
                          ],
                          if (!isScopedToOwn) ...[
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Artist / Staff Member *',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              initialValue: selEmployee.isEmpty ? null : selEmployee,
                              items: artists.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.name))).toList(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Select artist' : null,
                              onChanged: (v) => setState(() => selEmployee = v ?? ''),
                            ),
                            16.h,
                          ],
                          if (collectType == 'booking') ...[
                            // ── Searchable booking picker ──────────────────────────
                            Builder(builder: (ctx2) {
                              final selBookingObj = myBookings.where((b) => b.id == selBooking).firstOrNull;
                              final displayLabel = selBookingObj != null
                                  ? selBookingObj.customerName
                                  : 'Select Booking / Client *';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      final picked = await _showBookingSearchDialog(
                                        context: ctx,
                                        bookings: myBookings,
                                        fmtDate: _fmt,
                                        initialSelected: selBooking.isEmpty ? null : selBooking,
                                      );
                                      if (picked != null) setState(() => selBooking = picked);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Select Booking / Client *',
                                        prefixIcon: const Icon(Icons.book_online_outlined),
                                        helperText: 'Tap to search your assigned works',
                                        suffixIcon: const Icon(Icons.arrow_drop_down),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        displayLabel,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selBookingObj != null ? FontWeight.bold : FontWeight.normal,
                                          color: selBookingObj != null ? null : Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (selBooking.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 12),
                                      child: Text(
                                        'Please select a booking',
                                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ] else ...[
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              itemHeight: 80,
                              decoration: InputDecoration(
                                labelText: 'Select Trial / Client *',
                                prefixIcon: const Icon(Icons.star_outline),
                                helperText: 'Only your assigned trials are shown here',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              initialValue: selTrial.isEmpty ? null : selTrial,
                              items: myTrials.map<DropdownMenuItem<String>>((t) {
                                final total = t.trialItems.fold<double>(0, (s, i) => s + i.price);
                                return DropdownMenuItem<String>(
                                  value: t.id,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(t.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('${t.trialNumber} • ₹${total.toStringAsFixed(0)} Price', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                );
                              }).toList(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Select a trial' : null,
                              onChanged: (v) => setState(() => selTrial = v ?? ''),
                            ),
                          ],
                          16.h,
                          if (payMode == 'split') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: cashAmountCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'Cash Amount (₹) *',
                                      prefixIcon: const Icon(Icons.money, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onChanged: (v) => setState(() {}),
                                    validator: (v) {
                                      final cash = double.tryParse(cashAmountCtrl.text.trim()) ?? 0;
                                      final upi = double.tryParse(upiAmountCtrl.text.trim()) ?? 0;
                                      if (cash <= 0 && upi <= 0) return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                                12.w,
                                Expanded(
                                  child: TextFormField(
                                    controller: upiAmountCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'UPI Amount (₹) *',
                                      prefixIcon: const Icon(Icons.phone_android, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onChanged: (v) => setState(() {}),
                                    validator: (v) {
                                      final cash = double.tryParse(cashAmountCtrl.text.trim()) ?? 0;
                                      final upi = double.tryParse(upiAmountCtrl.text.trim()) ?? 0;
                                      if (cash <= 0 && upi <= 0) return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            TextFormField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Amount Collected (₹) *',
                                prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                                filled: true,
                                fillColor: crm.success.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: crm.success.withValues(alpha: 0.3)),
                                ),
                              ),
                              onChanged: (v) => setState(() {}),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter amount' : null,
                            ),
                          ],
                          16.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Payment Mode',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            initialValue: payMode,
                            items: _paymentModes.map<DropdownMenuItem<String>>((m) => DropdownMenuItem<String>(value: m.$1, child: Text(m.$2))).toList(),
                            onChanged: (v) => setState(() => payMode = v ?? 'cash'),
                          ),
                          16.h,
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(context: ctx, initialDate: selDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                              if (picked != null) setState(() => selDate = picked);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(labelText: 'Date', prefixIcon: const Icon(Icons.calendar_today_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              child: Text(_fmt(selDate)),
                            ),
                          ),
                          16.h,
                          TextFormField(
                            controller: notesCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(labelText: 'Internal Notes', prefixIcon: const Icon(Icons.note_alt_outlined), hintText: 'e.g. Received via GPay from husband', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                          16.h,
                          if (payMode == 'upi' || (payMode == 'split' && (double.tryParse(upiAmountCtrl.text.trim()) ?? 0) > 0)) ...[
                            const Text('UPI Payment Screenshot *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            8.h,
                            InkWell(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 50,
                                  maxWidth: 1080,
                                );
                                if (picked != null) setState(() => attachmentFile = picked);
                              },
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: attachmentFile == null ? Colors.grey.shade300 : crm.success),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade50,
                                ),
                                child: attachmentFile == null
                                    ? const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [Icon(Icons.add_a_photo_outlined, color: Colors.grey), Text('Tap to add screenshot', style: TextStyle(color: Colors.grey, fontSize: 12))],
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: kIsWeb ? Image.network(attachmentFile!.path, fit: BoxFit.cover) : Image.file(File(attachmentFile!.path), fit: BoxFit.cover),
                                      ),
                              ),
                            ),
                            16.h,
                          ],
                          32.h,
                          SizedBox(
                            width: double.infinity,
                            child: isUploading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: crm.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      if (!formKey.currentState!.validate()) return;
                                      final upiAmt = payMode == 'split' ? (double.tryParse(upiAmountCtrl.text.trim()) ?? 0) : 0.0;
                                      if ((payMode == 'upi' || (payMode == 'split' && upiAmt > 0)) && attachmentFile == null) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please upload the UPI payment screenshot'),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => isUploading = true);
                                      try {
                                        String? uploadedUrl;
                                        if (attachmentFile != null) {
                                          uploadedUrl = await ref
                                              .read(uploadServiceProvider)
                                              .uploadImage(attachmentFile!);
                                        }

                                        if (payMode == 'split') {
                                          final cashAmt = double.tryParse(cashAmountCtrl.text.trim()) ?? 0;
                                          if (cashAmt > 0 && !splitCashSaved) {
                                            await ref
                                                .read(collectionServiceProvider)
                                                .createCollection(
                                                  bookingId: collectType == 'booking'
                                                      ? (selBooking.isNotEmpty ? selBooking : '000000000000000000000000')
                                                      : null,
                                                  trialId: collectType == 'trial'
                                                      ? (selTrial.isNotEmpty ? selTrial : '000000000000000000000000')
                                                      : null,
                                                  employeeId: selEmployee.isNotEmpty ? selEmployee : myEmployeeId,
                                                  amount: cashAmt,
                                                  date: selDate,
                                                  paymentMode: 'cash',
                                                  notes: '${notesCtrl.text.trim()} (Split Cash)'.trim(),
                                                  attachmentUrl: null,
                                                );
                                            splitCashSaved = true;
                                            ref.refreshData.collections();
                                            ref.refreshData.trials(); // trial paid / balance
                                          }
                                          if (upiAmt > 0) {
                                            await ref
                                                .read(collectionServiceProvider)
                                                .createCollection(
                                                  bookingId: collectType == 'booking'
                                                      ? (selBooking.isNotEmpty ? selBooking : '000000000000000000000000')
                                                      : null,
                                                  trialId: collectType == 'trial'
                                                      ? (selTrial.isNotEmpty ? selTrial : '000000000000000000000000')
                                                      : null,
                                                  employeeId: selEmployee.isNotEmpty ? selEmployee : myEmployeeId,
                                                  amount: upiAmt,
                                                  date: selDate,
                                                  paymentMode: 'upi',
                                                  notes: '${notesCtrl.text.trim()} (Split UPI)'.trim(),
                                                  attachmentUrl: uploadedUrl,
                                                );
                                          }
                                        } else {
                                          await ref
                                              .read(collectionServiceProvider)
                                              .createCollection(
                                                bookingId: collectType == 'booking'
                                                    ? (selBooking.isNotEmpty ? selBooking : '000000000000000000000000')
                                                    : null,
                                                trialId: collectType == 'trial'
                                                    ? (selTrial.isNotEmpty ? selTrial : '000000000000000000000000')
                                                    : null,
                                                employeeId: selEmployee.isNotEmpty ? selEmployee : myEmployeeId,
                                                amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                                                date: selDate,
                                                paymentMode: payMode,
                                                notes: notesCtrl.text.trim(),
                                                attachmentUrl: uploadedUrl,
                                              );
                                        }

                                        ref.refreshData.collections();
                                        ref.refreshData.trials(); // trial paid / balance

                                        if (ctx.mounted) {
                                          if (payMode == 'split') {
                                            final savedBookingId =
                                                collectType == 'booking' && selBooking.isNotEmpty
                                                    ? selBooking
                                                    : null;
                                            final savedTrialId =
                                                collectType == 'trial' && selTrial.isNotEmpty
                                                    ? selTrial
                                                    : null;
                                            final savedEmployeeId =
                                                selEmployee.isNotEmpty
                                                    ? selEmployee
                                                    : myEmployeeId;
                                            final savedDate = selDate;

                                            final addMore =
                                                await showSplitPaymentDialog(ctx);
                                            if (ctx.mounted) Navigator.pop(ctx);

                                            if (addMore == true &&
                                                context.mounted) {
                                              await Future.delayed(const Duration(
                                                  milliseconds: 350));
                                              if (context.mounted) {
                                                addCollectionDialogSplit(
                                                  context: context,
                                                  ref: ref,
                                                  theme: theme,
                                                  crm: crm,
                                                  isScopedToOwn: isScopedToOwn,
                                                  myEmployeeId: myEmployeeId,
                                                  asyncEmployees: asyncEmployees,
                                                  myBookings: myBookings,
                                                  myTrials: myTrials,
                                                  prefilledBookingId: savedBookingId,
                                                  prefilledTrialId: savedTrialId,
                                                  prefilledEmployeeId: savedEmployeeId,
                                                  prefilledDate: savedDate,
                                                );
                                              }
                                            }
                                            return;
                                          }

                                          Navigator.pop(ctx);
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setState(() => isUploading = false);
                                          if (splitCashSaved) {
                                            showWarningSnackBar(
                                              ctx,
                                              'Cash part saved, but the UPI part failed: '
                                              '${friendlyErrorMessage(e)} Tap again to retry the UPI part.',
                                            );
                                          } else {
                                            showErrorSnackBar(ctx, e);
                                          }
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'LOG COLLECTION',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    Future<void> addCollectionDialog() {
      return addCollectionDialogSplit(
        context: context,
        ref: ref,
        theme: theme,
        crm: crm,
        isScopedToOwn: isScopedToOwn,
        myEmployeeId: myEmployeeId,
        asyncEmployees: asyncEmployees,
        myBookings: myBookings,
        myTrials: myTrials,
      );
    }

    /// Logs a new expense, or edits [existing] when one is supplied. An
    /// artist may only edit their own entry while it is still pending — the
    /// backend enforces the same rule.
    Future<void> addExpenseDialog({ArtistExpense? existing}) async {
      final isEditing = existing != null;
      final amountCtrl = TextEditingController(
          text: isEditing ? existing.amount.toStringAsFixed(0) : '');
      final notesCtrl = TextEditingController(text: existing?.notes ?? '');
      var selEmployee = isEditing
          ? (existing.employee?.id ?? myEmployeeId)
          : (isScopedToOwn ? myEmployeeId : '');
      var selCategory = existing?.category ?? 'food';
      var selWorkType = existing?.workType ?? 'bridal';
      final startedAt = existing?.date.toLocal() ?? DateTime.now();
      var selDate = startedAt;
      // Food is filed under a MEAL (or several, on one bill) and its time, so Accounts can put it
      // under the work it was eaten for. A new entry starts at the meal it most likely is.
      var selMeals = <String>{
        if (existing != null) ...existing.effectiveMeals else guessMeal(startedAt),
      };
      var selTime = TimeOfDay.fromDateTime(startedAt);
      var timeTouched = false;
      // The work the artist chose for it (null = let the app pick by time).
      String? pinnedBookingId = existing?.booking?.id;
      // The amount the app worked out for the team (heads × the allowance per head) and put in the
      // field. While the field still holds exactly that (or is empty) a change of work/meal/time
      // re-fills it; anything the artist types or picks is theirs and is never overwritten.
      var autoAmountText = '';
      XFile? attachmentFile;
      bool isUploading = false;
      final formKey = GlobalKey<FormState>();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final employees = asyncEmployees.value ?? [];
            final artists = employees
                .where((e) => (e.isActive && e.artistRole != 'driver') || e.id == selEmployee)
                .toList();
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          24.h,
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: crm.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 24,
                                  color: crm.primary,
                                ),
                              ),
                              16.w,
                              Text(
                                isEditing
                                    ? 'Edit Expense'
                                    : 'Log Artist Expense',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          16.h,
                          if (!isScopedToOwn) ...[
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Artist *',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              initialValue: selEmployee.isEmpty
                                  ? null
                                  : selEmployee,
                              items: artists
                                  .map<DropdownMenuItem<String>>(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.id,
                                      child: Text(e.name),
                                    ),
                                  )
                                  .toList(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Select artist'
                                  : null,
                              onChanged: (v) =>
                                  setState(() => selEmployee = v ?? ''),
                            ),
                            16.h,
                          ],
                          // What the spend was FOR — asked first because it
                          // determines whether a client booking applies.
                          Text(
                            'WHAT IS THIS FOR?',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: crm.textSecondary,
                            ),
                          ),
                          8.h,
                          Row(
                            children: [
                              for (final w in _workTypes) ...[
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () =>
                                        setState(() => selWorkType = w.$1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: selWorkType == w.$1
                                            ? crm.primary
                                                .withValues(alpha: 0.10)
                                            : null,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selWorkType == w.$1
                                              ? crm.primary
                                              : crm.border,
                                          width: selWorkType == w.$1 ? 1.6 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(w.$3,
                                              size: 16,
                                              color: selWorkType == w.$1
                                                  ? crm.primary
                                                  : crm.textSecondary),
                                          6.w,
                                          Flexible(
                                            child: Text(
                                              w.$2,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight:
                                                    selWorkType == w.$1
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                color: selWorkType == w.$1
                                                    ? crm.primary
                                                    : crm.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (w != _workTypes.last) 10.w,
                              ],
                            ],
                          ),
                          16.h,
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            initialValue: selCategory,
                            items: _expenseCategories
                                .map<DropdownMenuItem<String>>(
                                  (c) => DropdownMenuItem<String>(
                                    value: c.$1,
                                    child: Text(c.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              selCategory = v ?? 'other';
                              if (selCategory == 'food' && selMeals.isEmpty) {
                                selMeals = {guessMeal(DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute))};
                              }
                            }),
                          ),
                          if (selCategory == 'food' && selWorkType == 'bridal') ...[
                            16.h,
                            Text(
                              'WHICH MEAL(S)?',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: crm.textSecondary,
                              ),
                            ),
                            8.h,
                            // One bill can cover several meals (a long day on the road): pick every
                            // meal it was for.
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in kMeals)
                                  FilterChip(
                                    key: Key('meal_${m.$1}'),
                                    avatar: Icon(m.$3, size: 16),
                                    label: Text(m.$2),
                                    selected: selMeals.contains(m.$1),
                                    onSelected: (on) => setState(() {
                                      if (on) {
                                        selMeals = {...selMeals, m.$1};
                                      } else {
                                        selMeals = {...selMeals}..remove(m.$1);
                                      }
                                      // Untouched time that doesn't suit the meals → the earliest
                                      // chosen meal's usual time.
                                      final now = DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute);
                                      final first = orderMeals(selMeals).firstOrNull;
                                      if (!timeTouched && first != null && !selMeals.contains(guessMeal(now))) {
                                        selTime = switch (first) {
                                          'breakfast' => const TimeOfDay(hour: 8, minute: 0),
                                          'lunch' => const TimeOfDay(hour: 13, minute: 30),
                                          'snacks' => const TimeOfDay(hour: 16, minute: 30),
                                          _ => const TimeOfDay(hour: 20, minute: 30),
                                        };
                                      }
                                    }),
                                  ),
                              ],
                            ),
                            if (selMeals.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'One bill for ${mealsLabel(selMeals).toLowerCase()}. Enter the total below.',
                                  key: const Key('mealsOneBill'),
                                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                ),
                              ),
                            12.h,
                            InkWell(
                              key: const Key('mealTime'),
                              onTap: () async {
                                final picked = await showTimePicker(context: ctx, initialTime: selTime);
                                if (picked != null) {
                                  setState(() {
                                    selTime = picked;
                                    timeTouched = true;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: selMeals.length > 1 ? 'Time of the bill' : 'Time of the meal',
                                  prefixIcon: const Icon(Icons.access_time_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(selTime.format(ctx)),
                              ),
                            ),
                            if (selMeals.isNotEmpty && (isScopedToOwn || selEmployee.isNotEmpty)) ...[
                              12.h,
                              MealPlacementCard(
                                at: DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute),
                                meals: orderMeals(selMeals),
                                employeeId: isScopedToOwn ? null : selEmployee,
                                pinnedBookingId: pinnedBookingId,
                                onPin: (id) => setState(() => pinnedBookingId = id),
                                // the team's limit is checked against what is typed, as it is typed
                                amount: double.tryParse(amountCtrl.text.trim()),
                                excludeExpenseId: existing?.id,
                                // a new entry gets the team's amount filled in; an edit keeps its own
                                onAutoAmount: isEditing
                                    ? null
                                    : (suggested) {
                                        final cur = amountCtrl.text.trim();
                                        if (cur.isNotEmpty && cur != autoAmountText) return;
                                        final text = suggested == null ? '' : TeamAmount.fieldText(suggested);
                                        if (text == cur) {
                                          autoAmountText = text;
                                          return;
                                        }
                                        setState(() {
                                          amountCtrl.text = text;
                                          autoAmountText = text;
                                        });
                                      },
                                onUseAmount: (v) => setState(() {
                                  amountCtrl.text = TeamAmount.fieldText(v);
                                  autoAmountText = '';
                                }),
                              ),
                            ],
                          ],
                          16.h,
                          TextFormField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount (₹) *',
                              prefixIcon: const Icon(
                                Icons.currency_rupee,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: crm.primary.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: crm.primary.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            onChanged: (v) => setState(() {}),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter amount'
                                : null,
                          ),
                          16.h,
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => selDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                prefixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(_fmt(selDate)),
                            ),
                          ),
                          16.h,
                          TextFormField(
                            controller: notesCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              prefixIcon: const Icon(Icons.note_alt_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          16.h,
                          // Expense Bill Attachment
                          Builder(
                            builder: (context) {
                              final amt = double.tryParse(amountCtrl.text) ?? 0;
                              if (amt > 100) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bill Attachment *',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    8.h,
                                    InkWell(
                                      onTap: () async {
                                        final picker = ImagePicker();
                                        final picked = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 50,
                                          maxWidth: 1080,
                                        );
                                        if (picked != null) {
                                          setState(() => attachmentFile = picked);
                                        }
                                      },
                                      child: Container(
                                        height: 120,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: attachmentFile == null
                                                ? Colors.grey.shade300
                                                : crm.primary,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.grey.shade50,
                                        ),
                                        child: attachmentFile == null
                                            ? const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.receipt_long_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                  Text(
                                                    'Tap to upload bill photo',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                child: kIsWeb
                                                    ? Image.network(
                                                        attachmentFile!.path,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(
                                                          attachmentFile!.path,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                              ),
                                      ),
                                    ),
                                    16.h,
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: crm.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final isMealEntry = selCategory == 'food' && selWorkType == 'bridal';
                                      if (isMealEntry && selMeals.isEmpty) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(content: Text('Pick which meal(s) this was')),
                                        );
                                        return;
                                      }
                                      final covered = mealFields(isMealEntry ? selMeals : const <String>{});
                                      // Food carries the TIME of the meal; anything else keeps its date.
                                      final when = isMealEntry
                                          ? DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute)
                                          : selDate;

                                      final amt =
                                          double.tryParse(amountCtrl.text) ?? 0;
                                      if (amt > 100 &&
                                          attachmentFile == null &&
                                          (existing == null || existing.receiptImage.isEmpty) &&
                                          !canVerify) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Bill photo required for amounts > 100',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => isUploading = true);
                                      try {
                                        String? uploadedUrl;
                                        if (attachmentFile != null) {
                                          uploadedUrl = await ref
                                              .read(uploadServiceProvider)
                                              .uploadImage(attachmentFile!);
                                        }

                                        final ArtistExpense saved;
                                        if (isEditing) {
                                          saved = await ref
                                              .read(expenseServiceProvider)
                                              .updateExpense(
                                                id: existing.id,
                                                category: selCategory,
                                                amount: amt,
                                                date: when,
                                                notes: notesCtrl.text.trim(),
                                                workType: selWorkType,
                                                meal: covered.meal,
                                                meals: covered.meals,
                                                // '' takes a chosen work back off, so the
                                                // time rule decides again.
                                                bookingId: isMealEntry ? (pinnedBookingId ?? '') : null,
                                                // Keep the old receipt unless
                                                // a new one was attached.
                                                receiptImage: uploadedUrl,
                                              );
                                        } else {
                                          saved = await ref
                                              .read(expenseServiceProvider)
                                              .createExpense(
                                                employeeId: selEmployee.isNotEmpty
                                                    ? selEmployee
                                                    : myEmployeeId,
                                                category: selCategory,
                                                amount: amt,
                                                date: when,
                                                notes: notesCtrl.text.trim(),
                                                workType: selWorkType,
                                                meal: covered.meal,
                                                meals: covered.meals,
                                                bookingId: isMealEntry ? pinnedBookingId : null,
                                                receiptImage: uploadedUrl ?? '',
                                              );
                                        }
                                        ref.refreshData.expenses();
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        // Saved — and if the team is over its limit for this meal, say so
                                        // (Accounts is told too).
                                        final limit = saved.limitCheck;
                                        if (limit != null && limit.isOver && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              key: const Key('teamLimitSnack'),
                                              duration: const Duration(seconds: 8),
                                              backgroundColor: crm.destructive,
                                              behavior: SnackBarBehavior.floating,
                                              content: Text(
                                                'Saved — the team limit for ${(limit.meals.length > 1 ? mealsLabel(limit.meals) : mealLabel(limit.meal)).toLowerCase()} is exceeded by ${TeamLimitBanner.rupees(limit.over)} '
                                                '(${TeamLimitBanner.limitText(limit)}; the team has logged ${TeamLimitBanner.rupees(limit.total)}).',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setState(() => isUploading = false);
                                          showErrorSnackBar(ctx, e);
                                        }
                                      }
                                    },
                                    child: Text(
                                      isEditing
                                          ? 'SAVE CHANGES'
                                          : 'LOG EXPENSE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    /// Edits an existing collection. An artist may only correct their own entry
    /// while it is still pending — the backend enforces the same rule.
    Future<void> editCollectionDialog({required ArtistCollection existing}) async {
      final amountCtrl =
          TextEditingController(text: existing.amount.toStringAsFixed(0));
      final notesCtrl = TextEditingController(text: existing.notes);
      var selPayMode = _paymentModes
              .any((m) => m.$1 == existing.paymentMode)
          ? existing.paymentMode
          : 'cash';
      var selDate = existing.date;
      XFile? attachmentFile;
      bool isUploading = false;
      final formKey = GlobalKey<FormState>();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          24.h,
                          // ── Header ─────────────────────────────────────────
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: crm.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 24,
                                  color: crm.primary,
                                ),
                              ),
                              16.w,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Edit Collection',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    Text(
                                      existing.booking?.customerName ??
                                          existing.trial?.clientName ??
                                          'Unknown Client',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: crm.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          20.h,
                          // ── Amount ─────────────────────────────────────────
                          TextFormField(
                            controller: amountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Amount Collected (₹) *',
                              prefixIcon:
                                  const Icon(Icons.currency_rupee, size: 20),
                              filled: true,
                              fillColor: crm.success.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: crm.success.withValues(alpha: 0.3)),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Enter amount'
                                    : null,
                          ),
                          16.h,
                          // ── Payment Mode ───────────────────────────────────
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Payment Mode',
                              prefixIcon:
                                  const Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            // Filter out 'split' — split payments are recorded
                            // as two separate entries and cannot be re-combined.
                            initialValue: selPayMode == 'split' ? 'cash' : selPayMode,
                            items: _paymentModes
                                .where((m) => m.$1 != 'split')
                                .map<DropdownMenuItem<String>>((m) =>
                                    DropdownMenuItem<String>(
                                        value: m.$1, child: Text(m.$2)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selPayMode = v ?? 'cash'),
                          ),
                          16.h,
                          // ── Date ───────────────────────────────────────────
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => selDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                prefixIcon:
                                    const Icon(Icons.calendar_today_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_fmt(selDate)),
                            ),
                          ),
                          16.h,
                          // ── Notes ──────────────────────────────────────────
                          TextFormField(
                            controller: notesCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              prefixIcon:
                                  const Icon(Icons.note_alt_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          // ── Screenshot (UPI) ───────────────────────────────
                          if (selPayMode == 'upi') ...[
                            16.h,
                            const Text(
                              'UPI Payment Screenshot',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            8.h,
                            InkWell(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 50,
                                  maxWidth: 1080,
                                );
                                if (picked != null) {
                                  setState(() => attachmentFile = picked);
                                }
                              },
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: attachmentFile == null
                                        ? (existing.attachmentUrl != null
                                            ? crm.success
                                            : Colors.grey.shade300)
                                        : crm.success,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade50,
                                ),
                                child: attachmentFile != null
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(11),
                                        child: kIsWeb
                                            ? Image.network(
                                                attachmentFile!.path,
                                                fit: BoxFit.cover)
                                            : Image.file(
                                                File(attachmentFile!.path),
                                                fit: BoxFit.cover),
                                      )
                                    : existing.attachmentUrl != null
                                        ? Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                child: Image.network(
                                                  existing.attachmentUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, _, _) =>
                                                          const SizedBox(),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 6,
                                                right: 6,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'Tap to replace',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_a_photo_outlined,
                                                color: Colors.grey,
                                              ),
                                              Text(
                                                'Tap to add screenshot',
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                              ),
                            ),
                          ],
                          32.h,
                          // ── Save button ────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: isUploading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: crm.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setState(() => isUploading = true);
                                      try {
                                        String? uploadedUrl;
                                        if (attachmentFile != null) {
                                          uploadedUrl = await ref
                                              .read(uploadServiceProvider)
                                              .uploadImage(attachmentFile!);
                                        }
                                        await ref
                                            .read(collectionServiceProvider)
                                            .updateCollection(
                                              id: existing.id,
                                              amount: double.tryParse(
                                                      amountCtrl.text.trim()) ??
                                                  existing.amount,
                                              date: selDate,
                                              paymentMode: selPayMode,
                                              notes: notesCtrl.text.trim(),
                                              // Only send a new URL if a new
                                              // file was actually picked.
                                              attachmentUrl: uploadedUrl,
                                            );
                                        ref.refreshData.collections();
                                        ref.refreshData.trials(); // trial paid / balance
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setState(() => isUploading = false);
                                          showErrorSnackBar(ctx, e);
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'SAVE CHANGES',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    Future<void> verifyItem({
      required String id,
      required bool isCollection,
      required String action,
      double amount = 0,
      String mode = '',
      DateTime? initialDate,
    }) async {
      // Approving asks where the money moved (mode + bank / cash account + approved date).
      MoneyChoice? money;
      if (action == 'verified') {
        money = await showMoneyAccountPicker(
          context,
          title: isCollection ? 'Approve collection' : 'Approve expense',
          amount: amount,
          moneyIn: isCollection,
          modes: kCollectionPayModes,
          initialMode: mode,
          initialDate: initialDate ?? DateTime.now(),
        );
        if (money == null) return; // cancelled
      }
      try {
        final verifiedBy = session?.userId ?? '';
        if (isCollection) {
          await ref
              .read(collectionServiceProvider)
              .verifyCollection(id: id, status: action, verifiedBy: verifiedBy, money: money);
          ref.refreshData.collections();
          ref.refreshData.trials(); // trial paid / balance
        } else {
          await ref
              .read(expenseServiceProvider)
              .verifyExpense(id: id, status: action, verifiedBy: verifiedBy, money: money);
          ref.refreshData.expenses();
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, e);
        }
      }
    }

    Future<void> deleteItem({
      required String id,
      required bool isCollection,
    }) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Entry'),
          content: const Text(
            'Are you sure you want to delete this entry? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: crm.destructive)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      try {
        if (isCollection) {
          await ref.read(collectionServiceProvider).deleteCollection(id);
          ref.refreshData.collections();
          ref.refreshData.trials(); // trial paid / balance
        } else {
          await ref.read(expenseServiceProvider).deleteExpense(id);
          ref.refreshData.expenses();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, e);
        }
      }
    }


    void showImageDialog(String url, {String? label}) {
      showDialog(
        context: context,
        builder: (ctx) => _ImageViewerDialog(url: url, label: label),
      );
    }

    // Everything above the list on one tab: the loading bar, the extra cards, the
    // search / filters / sort / page-size row, the status chips, the active-filter
    // chips, the tap-to-filter breakdown and the "Showing 1–20 of 134" line.
    List<Widget> controlSlivers({
      required FinanceKind kind,
      required ValueNotifier<FinanceQuery> holder,
      required FinancePage<dynamic> data,
      required bool loading,
      required Object? error,
      required VoidCallback retry,
      Widget? cards,
    }) {
      final isColl = kind == FinanceKind.collection;
      final q = holder.value;
      final summary = data.summary;
      final padH = isMobile ? 16.0 : 0.0;
      Widget box(Widget child, [double top = 0]) => SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(padH, top, padH, 0), child: child),
          );
      void set(FinanceQuery next) => holder.value = next;
      void clearAll() => set(FinanceQuery(from: q.from, to: q.to, sort: q.sort, limit: q.limit, withWorks: q.withWorks));
      final artists = isScopedToOwn ? const <NameOption>[] : artistOptionsFor(q.employeeId);
      void toggle(Set<String> current, String key, FinanceQuery Function(Set<String>) apply) {
        final next = {...current};
        next.contains(key) ? next.remove(key) : next.add(key);
        set(apply(next));
      }

      return [
        if (loading) box(const LinearProgressIndicator(minHeight: 3), 8),
        // The page that failed to load is not silently replaced by the old one.
        if (error != null && !loading) box(FinanceLoadError(error: error, onRetry: retry), 10),
        if (cards != null) box(cards, 12),
        box(
          FinanceToolbar(
            search: q.search,
            onSearch: (t) => set(q.refiltered(search: t)),
            hint: isMobile
                ? 'Search client, artist, notes…'
                : (isColl
                    ? 'Search client, artist, service, booking no., notes or amount'
                    : 'Search client, artist, category, booking no., notes or amount'),
            advancedCount: q.advancedCount,
            onFilters: () => openFilters(kind),
            sort: q.sort,
            onSort: (v) => set(q.refiltered(sort: v)),
            limit: q.limit,
            onLimit: (n) => set(q.refiltered(limit: n)),
          ),
          12,
        ),
        box(
          FinanceStatusChips(summary: summary, selected: q.statuses, onChanged: (st) => set(q.refiltered(statuses: st))),
          10,
        ),
        if (q.isFiltered)
          box(
            FinanceActiveChips(
              query: q,
              kind: kind,
              artistName: artists.where((a) => a.id == q.employeeId).map((a) => a.name).firstOrNull,
              onChanged: set,
              onClearAll: clearAll,
            ),
            10,
          ),
        if (summary != null && summary.shownCount > 0)
          box(
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // Its own page-storage key: the tab's scroll view stores a scroll offset under
                // the tab's key, and a tile sharing that slot would read it back as its state.
                key: PageStorageKey<String>(isColl ? 'collectionBreakdownTile' : 'expenseBreakdownTile'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                expandedAlignment: Alignment.centerLeft,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                initiallyExpanded: !isMobile,
                title: Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                children: [
                  FinanceBreakdown(groups: [
                    if (isColl)
                      BreakdownGroup(
                        title: 'By payment mode',
                        rows: summary.byMode,
                        keyPrefix: 'mode',
                        labels: kCollectionModeLabels,
                        isOn: (r) => q.paymentModes.contains(r.key),
                        onTap: (r) => toggle(q.paymentModes, r.key, (n) => q.refiltered(paymentModes: n)),
                      )
                    else ...[
                      BreakdownGroup(
                        title: 'By category',
                        rows: summary.byCategory,
                        keyPrefix: 'category',
                        labels: kArtistExpenseCategoryLabels,
                        isOn: (r) => q.categories.contains(r.key),
                        onTap: (r) => toggle(q.categories, r.key, (n) => q.refiltered(categories: n)),
                      ),
                      BreakdownGroup(
                        title: 'By work type',
                        rows: summary.byWorkType,
                        keyPrefix: 'work',
                        labels: kWorkTypeLabels,
                        isOn: (r) => q.workType == r.key,
                        onTap: (r) => set(q.refiltered(workType: q.workType == r.key ? null : r.key)),
                      ),
                    ],
                    // An artist only ever sees their own, so there is nothing to compare.
                    if (!isScopedToOwn)
                      BreakdownGroup(
                        title: 'By artist',
                        rows: summary.byArtist,
                        keyPrefix: 'artist',
                        isOn: (r) => q.employeeId == r.key,
                        onTap: (r) => set(q.refiltered(employeeId: q.employeeId == r.key ? null : r.key)),
                      ),
                  ]),
                ],
              ),
            ),
            12,
          ),
        box(
          Text(
            financeTotalText(
              total: data.totalItems,
              amount: summary?.shownAmount,
              noun: isColl ? 'collections' : 'expenses',
            ),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
          ),
          12,
        ),
      ];
    }

    Widget pager(FinancePage<dynamic> data, ValueNotifier<FinanceQuery> holder) => Padding(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 0, 8, isMobile ? 16 : 0, 24),
          child: PaginatedFooter(
            page: data.page,
            limit: data.limit,
            totalPages: data.totalPages,
            totalItems: data.totalItems,
            currentItemCount: data.items.length,
            onPrevious: data.page > 1 ? () => holder.value = holder.value.copyWith(page: data.page - 1) : null,
            onNext: data.page < data.totalPages ? () => holder.value = holder.value.copyWith(page: data.page + 1) : null,
          ),
        );

    Widget emptyList({
      required IconData icon,
      required String noun,
      required String unfilteredHint,
      required ValueNotifier<FinanceQuery> holder,
    }) {
      final q = holder.value;
      final filtered = q.isFiltered;
      final title = filtered
          ? 'No matching $noun'
          : switch (period.value) {
              FinancePeriod.all => 'No $noun logged yet',
              FinancePeriod.range => 'No $noun in this date range',
              FinancePeriod.month => 'No $noun in $periodText',
            };
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 12),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              _FinanceEmptyState(
                icon: icon,
                title: title,
                subtitle: filtered ? 'Try a different search or clear the filters.' : unfilteredHint,
              ),
              if (filtered)
                TextButton(
                  onPressed: () => holder.value = FinanceQuery(from: q.from, to: q.to, sort: q.sort, limit: q.limit, withWorks: q.withWorks),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ),
      );
    }

    Widget collectionsTab(FinancePage<ArtistCollection> data) {
      final pageItems = data.items;
      return Builder(
        builder: (context) {
          return CustomScrollView(
            key: const PageStorageKey<String>('collections'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              ...controlSlivers(
                kind: FinanceKind.collection,
                holder: collectionQuery,
                data: data,
                loading: asyncCollections.isLoading,
                error: asyncCollections.hasError ? asyncCollections.error : null,
                retry: () => ref.invalidate(financeCollectionsPageProvider),
              ),
              if (pageItems.isEmpty)
                emptyList(
                  icon: Icons.account_balance_wallet_outlined,
                  noun: 'collections',
                  unfilteredHint: 'Record a collection with the button at the top, or look at another period.',
                  holder: collectionQuery,
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = pageItems[i];
                      final metadataStr = [
                        c.paymentMode.toUpperCase(),
                        if (c.booking != null) c.booking!.service,
                        if (!isScopedToOwn && c.employee != null) c.employee!.name,
                      ].join(' • ');

                      final List<Widget> actionsList = [];
                      if (canVerify && c.status == 'pending') {
                        actionsList.add(
                          IconButton(
                            tooltip: 'Approve',
                            icon: const Icon(Icons.check, size: 14),
                            onPressed: () => verifyItem(
                              id: c.id,
                              isCollection: true,
                              action: 'verified',
                              amount: c.amount,
                              mode: c.paymentMode,
                              initialDate: c.date,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.success,
                              backgroundColor: crm.success.withValues(alpha: 0.05),
                              side: BorderSide(color: crm.success.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                        actionsList.add(8.w);
                        actionsList.add(
                          IconButton(
                            tooltip: 'Reject',
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () => verifyItem(
                              id: c.id,
                              isCollection: true,
                              action: 'rejected',
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.destructive,
                              backgroundColor: crm.destructive.withValues(alpha: 0.05),
                              side: BorderSide(color: crm.destructive.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                        actionsList.add(8.w);
                      }
                      // An artist can correct their own pending collection
                      // until Accounts verifies/rejects it — same rule as
                      // expenses. Accounts and Admins can edit collections anytime.
                      if ((isScopedToOwn && c.status == 'pending') || canVerify) {
                        actionsList.add(
                          IconButton(
                            tooltip: 'Edit this collection',
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            onPressed: () => editCollectionDialog(existing: c),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.primary,
                              backgroundColor:
                                  crm.primary.withValues(alpha: 0.05),
                              side: BorderSide(
                                  color: crm.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                        actionsList.add(8.w);
                      }
                      if (canVerify) {
                        actionsList.add(
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 14),
                            onPressed: () => deleteItem(id: c.id, isCollection: true),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.destructive.withValues(alpha: c.status == 'pending' ? 1.0 : 0.5),
                              backgroundColor: crm.destructive.withValues(alpha: 0.05),
                              side: BorderSide(color: crm.destructive.withValues(alpha: 0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                      }

                      final allBookings = asyncBookings.value ?? <Booking>[];
                      final bookingId = c.booking?.id;
                      Booking? fullBooking;
                      if (bookingId != null && bookingId.isNotEmpty) {
                        for (final b in allBookings) {
                          if (b.id == bookingId) {
                            fullBooking = b;
                            break;
                          }
                        }
                      }

                      if (fullBooking != null) {
                        final balance = (fullBooking.totalPrice - fullBooking.advanceAmount - fullBooking.discountAmount)
                            .clamp(0, double.infinity)
                            .toDouble();
                        if (balance <= 0) {
                          if (actionsList.isNotEmpty) {
                            actionsList.add(8.w);
                          }
                          actionsList.add(
                            IconButton(
                              tooltip: 'Download GST Invoice',
                              icon: const Icon(Icons.receipt_long_rounded, size: 14),
                              onPressed: () async {
                                try {
                                  await printBookingDetails(
                                    fullBooking!,
                                    variant: BookingPrintVariant.clientInvoice,
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    showErrorSnackBar(context, e);
                                  }
                                }
                              },
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF22C55E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                            ),
                          );
                        }
                      }

                      // Prefer the booking's client name; fall back to the trial
                      // client, then a placeholder.
                      final bookingClient = c.booking?.customerName.trim() ?? '';
                      final clientTitle = bookingClient.isNotEmpty
                          ? bookingClient
                          : (c.trial != null
                              ? '${c.trial!.clientName} (Trial)'
                              : 'Unknown Client');

                      return _FinanceEntryCard(
                        title: clientTitle,
                        amount: _currency(c.amount),
                        status: c.status,
                        metadata: metadataStr,
                        note: c.notes.isNotEmpty ? c.notes : null,
                        creatorName: c.employee?.name ?? 'Unknown',
                        date: c.date,
                        verifiedAt: c.verifiedAt,
                        actions: actionsList,
                        onAttachmentTap: (c.attachmentUrl != null && c.attachmentUrl!.isNotEmpty)
                            ? () => showImageDialog(c.attachmentUrl!, label: 'collection_screenshot')
                            : null,
                      );
                    },
                    childCount: pageItems.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: pager(data, collectionQuery)),
            ],
          );
        },
      );
    }

    Widget expensesTab(FinancePage<ArtistExpense> data) {
      final sortedItems = data.items;
      return Builder(
        builder: (context) {
          return CustomScrollView(
            key: const PageStorageKey<String>('expenses'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              ...controlSlivers(
                kind: FinanceKind.expense,
                holder: expenseQuery,
                data: data,
                loading: asyncExpenses.isLoading,
                error: asyncExpenses.hasError ? asyncExpenses.error : null,
                retry: () => ref.invalidate(financeExpensesPageProvider),
                // Bridal vs model-shoot spend at a glance — over the whole filtered set.
                cards: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accounts sets how much may be spent on each meal per head.
                    if (canVerify) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          key: const Key('foodAllowanceButton'),
                          onPressed: () => showFoodAllowanceManager(context),
                          icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                          label: const Text('Food allowance per head'),
                        ),
                      ),
                      10.h,
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _workTypeTotalCard(
                            crm,
                            'Bridal Work',
                            _currency(bridalExpenseTotal),
                            Icons.diamond_outlined,
                            crm.primary,
                          ),
                        ),
                        12.w,
                        Expanded(
                          child: _workTypeTotalCard(
                            crm,
                            'Model Shoot',
                            _currency(modelShootExpenseTotal),
                            Icons.camera_alt_outlined,
                            crm.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (sortedItems.isEmpty)
                emptyList(
                  icon: Icons.receipt_long_outlined,
                  noun: 'expenses',
                  unfilteredHint: 'Receipts and travel costs logged here will appear for review.',
                  holder: expenseQuery,
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final e = sortedItems[i];
                      final catLabel = _expenseCategories
                          .firstWhere(
                            (c) => c.$1 == e.category,
                            orElse: () => ('other', 'Other'),
                          )
                          .$2;
                      final metadataStr = [
                        // Lead with the work type so bridal vs model-shoot
                        // spend is obvious at a glance.
                        e.workType == 'model_shoot'
                            ? 'Model Shoot'
                            : 'Bridal Work',
                        catLabel,
                        if (e.booking != null) e.booking!.customerName,
                      ].join(' • ');

                      final List<Widget> actionsList = [];
                      if (canVerify && e.status == 'pending') {
                        actionsList.add(
                          IconButton(
                            tooltip: 'Approve',
                            icon: const Icon(Icons.check, size: 14),
                            onPressed: () => verifyItem(
                              id: e.id,
                              isCollection: false,
                              action: 'verified',
                              amount: e.amount,
                              mode: 'upi',
                              initialDate: e.date,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.success,
                              backgroundColor: crm.success.withValues(alpha: 0.05),
                              side: BorderSide(color: crm.success.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                        actionsList.add(8.w);
                        actionsList.add(
                          IconButton(
                            tooltip: 'Reject',
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () => verifyItem(
                              id: e.id,
                              isCollection: false,
                              action: 'rejected',
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.destructive,
                              backgroundColor: crm.destructive.withValues(alpha: 0.05),
                              side: BorderSide(color: crm.destructive.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                        actionsList.add(8.w);
                      }
                      // An artist can correct their own entry until Accounts
                      // verifies or rejects it. Accounts and Admins can manage and edit expenses anytime.
                      if ((isScopedToOwn && e.status == 'pending') || canVerify) {
                        actionsList.add(
                          IconButton(
                            tooltip: 'Edit this expense',
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            onPressed: () => addExpenseDialog(existing: e),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.primary,
                              backgroundColor:
                                  crm.primary.withValues(alpha: 0.05),
                              side: BorderSide(
                                  color: crm.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                        actionsList.add(8.w);
                      }
                      if (canVerify) {
                        actionsList.add(
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 14),
                            onPressed: () => deleteItem(id: e.id, isCollection: false),
                            style: IconButton.styleFrom(
                              foregroundColor: crm.destructive.withValues(alpha: e.status == 'pending' ? 1.0 : 0.5),
                              backgroundColor: crm.destructive.withValues(alpha: 0.05),
                              side: BorderSide(color: crm.destructive.withValues(alpha: 0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        );
                      }

                      return _FinanceEntryCard(
                        title: e.employee?.name ?? 'Unknown Artist',
                        amount: _currency(e.amount),
                        status: e.status,
                        metadata: metadataStr,
                        note: e.notes.isNotEmpty ? e.notes : null,
                        creatorName: e.employee?.name ?? 'Unknown',
                        date: e.date,
                        verifiedAt: e.verifiedAt,
                        actions: actionsList,
                        onAttachmentTap: e.receiptImage.isNotEmpty
                            ? () => showImageDialog(e.receiptImage, label: 'expense_bill')
                            : null,
                        // A food expense: which work it was eaten for, by the time of the meal.
                        extra: e.allocation == null
                            ? null
                            : ExpenseAllocationLine(
                                expense: e,
                                onDay: e.employee == null
                                    ? null
                                    : () => showArtistDayTimeline(
                                          context,
                                          employeeId: e.employee!.id,
                                          day: istDay(e.date),
                                          artistName: e.employee!.name,
                                        ),
                              ),
                      );
                    },
                    childCount: sortedItems.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: pager(data, expenseQuery)),
            ],
          );
        },
      );
    }

    void showToast(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    void openReportDialog() {
      var selectedType = 'summary';
      var selectedFormat = 'pdf';
      var selectedMonth = DateTime.now().month;
      var selectedYear = DateTime.now().year;
      var selectedArtist = 'all';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, dialogSetState) {
            return Dialog(
              backgroundColor: theme.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SizedBox(
                width: 400,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Generate Report',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: crm.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        16.h,
                        Text(
                          'SELECT REPORT TYPE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        Row(
                          children: [
                            // Summary
                            Expanded(
                              child: InkWell(
                                onTap: () => dialogSetState(() => selectedType = 'summary'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'summary' ? crm.primary.withValues(alpha: 0.05) : crm.secondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: selectedType == 'summary' ? crm.primary : crm.border, width: 1.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.pie_chart_outline, size: 20, color: selectedType == 'summary' ? crm.primary : crm.textSecondary),
                                      4.h,
                                      Text(
                                        'Summary',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: selectedType == 'summary' ? crm.primary : crm.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            8.w,
                            // Detailed
                            Expanded(
                              child: InkWell(
                                onTap: () => dialogSetState(() => selectedType = 'detailed'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'detailed' ? crm.primary.withValues(alpha: 0.05) : crm.secondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: selectedType == 'detailed' ? crm.primary : crm.border, width: 1.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.format_list_bulleted, size: 20, color: selectedType == 'detailed' ? crm.primary : crm.textSecondary),
                                      4.h,
                                      Text(
                                        'Detailed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: selectedType == 'detailed' ? crm.primary : crm.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        8.h,
                        Row(
                          children: [
                            // Monthly
                            Expanded(
                              child: InkWell(
                                onTap: () => dialogSetState(() => selectedType = 'monthly'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: selectedType == 'monthly' ? crm.primary.withValues(alpha: 0.05) : crm.secondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: selectedType == 'monthly' ? crm.primary : crm.border, width: 1.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_month_outlined, size: 20, color: selectedType == 'monthly' ? crm.primary : crm.textSecondary),
                                      4.h,
                                      Text(
                                        'Monthly',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: selectedType == 'monthly' ? crm.primary : crm.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isScopedToOwn)
                              const Spacer()
                            else ...[
                              8.w,
                              // By Artist
                              Expanded(
                                child: InkWell(
                                  onTap: () => dialogSetState(() => selectedType = 'artist'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 55,
                                    decoration: BoxDecoration(
                                      color: selectedType == 'artist' ? crm.primary.withValues(alpha: 0.05) : crm.secondary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: selectedType == 'artist' ? crm.primary : crm.border, width: 1.5),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.groups_outlined, size: 20, color: selectedType == 'artist' ? crm.primary : crm.textSecondary),
                                        4.h,
                                        Text(
                                          'By Artist',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: selectedType == 'artist' ? crm.primary : crm.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        16.h,
                        Text(
                          'DATE RANGE / MONTH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Month',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                initialValue: selectedMonth,
                                items: List<DropdownMenuItem<int>>.generate(
                                  12,
                                  (i) => DropdownMenuItem<int>(
                                    value: i + 1,
                                    child: Text(_getMonthName(i + 1), style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                                onChanged: (v) => dialogSetState(() => selectedMonth = v!),
                              ),
                            ),
                            10.w,
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Year',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                initialValue: selectedYear,
                                items: [DateTime.now().year - 1, DateTime.now().year]
                                    .map<DropdownMenuItem<int>>((y) => DropdownMenuItem<int>(
                                          value: y,
                                          child: Text(y.toString(), style: const TextStyle(fontSize: 12)),
                                        ))
                                    .toList(),
                                onChanged: (v) => dialogSetState(() => selectedYear = v!),
                              ),
                            ),
                          ],
                        ),
                        if (selectedType == 'artist' || !isScopedToOwn) ...[
                          16.h,
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Select Artist / Staff',
                              prefixIcon: Icon(Icons.person_outline, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            initialValue: selectedArtist,
                            items: <DropdownMenuItem<String>>[
                              const DropdownMenuItem<String>(
                                value: 'all',
                                child: Text('All Artists', style: TextStyle(fontSize: 12)),
                              ),
                              ...(asyncEmployees.value ?? []).map<DropdownMenuItem<String>>(
                                (e) => DropdownMenuItem<String>(
                                  value: e.id,
                                  child: Text(e.name, style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                            onChanged: (v) => dialogSetState(() => selectedArtist = v ?? 'all'),
                          ),
                        ],
                        16.h,
                        Text(
                          'EXPORT FORMAT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        RadioGroup<String>(
                          groupValue: selectedFormat,
                          onChanged: (v) => dialogSetState(() => selectedFormat = v!),
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('PDF', style: TextStyle(fontSize: 12)),
                                  value: 'pdf',
                                  activeColor: crm.primary,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('CSV', style: TextStyle(fontSize: 12)),
                                  value: 'csv',
                                  activeColor: crm.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        24.h,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL'),
                            ),
                            12.w,
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await ref.read(reportServiceProvider).downloadFinanceReport(
                                    month: selectedMonth,
                                    year: selectedYear,
                                    employeeId: isScopedToOwn
                                        ? myEmployeeId
                                        : (selectedType == 'artist' ? selectedArtist : 'all'),
                                    format: selectedFormat,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    showToast('✓ Report Generated (${selectedFormat.toUpperCase()})');
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    showErrorSnackBar(ctx, e);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: crm.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('GENERATE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [crm.background, crm.secondary.withValues(alpha: 0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (isMobile) 16.h else 0.h,
                    // Title Header Block
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Artist Finance',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Track collections & claims',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: crm.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    8.h,
                    // Quick Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: addExpenseDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: crm.secondary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: crm.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, color: crm.primary, size: 16),
                                  8.w,
                                  Text(
                                    'EXPENSE',
                                    style: TextStyle(
                                      color: crm.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: InkWell(
                            onTap: addCollectionDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [crm.primary, crm.primary.withValues(alpha: 0.85)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: crm.primary.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, color: Colors.white, size: 16),
                                  8.w,
                                  const Text(
                                    'COLLECTION',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    12.h,
                    // Metrics Grid Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: crm.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: crm.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: crm.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.currency_rupee, size: 10, color: Colors.white),
                                    ),
                                    6.w,
                                    Flexible(
                                      child: Text(
                                        'TOTAL COLLECTED',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: crm.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                8.h,
                                Text(
                                  _currency(totalCollected),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: crm.textPrimary,
                                    fontSize: 18,
                                  ),
                                ),
                                6.h,
                                Row(
                                  children: [
                                    Icon(Icons.verified_outlined, size: 10, color: crm.success),
                                    4.w,
                                    Flexible(
                                      child: Text(
                                        '$verifiedCount verified · $periodText',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: crm.success,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        12.w,
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: crm.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: crm.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: crm.warning,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.hourglass_empty, size: 10, color: Colors.white),
                                    ),
                                    6.w,
                                    Flexible(
                                      child: Text(
                                        'PENDING',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: crm.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                8.h,
                                Text(
                                  '$pendingCount',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: crm.warning,
                                    fontSize: 18,
                                  ),
                                ),
                                6.h,
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 10, color: crm.warning),
                                    4.w,
                                    Flexible(
                                      child: Text(
                                        '$pendingCollections collections · $pendingExpenses expenses',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: crm.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    12.h,
                    FinancePeriodBar(
                      period: period.value,
                      month: month.value,
                      range: range.value,
                      onMonth: (m) => setPeriod(FinancePeriod.month, newMonth: m),
                      onRange: (r) => setPeriod(FinancePeriod.range, newRange: r),
                      onAll: () => setPeriod(FinancePeriod.all),
                    ),
                    12.h,
                  ]),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                backgroundColor: crm.background,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: crm.border.faded(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            controller: tabCtrl,
                            isScrollable: true,
                            // snug padding so all three tabs fit a 390px phone beside the PDF button
                            tabAlignment: TabAlignment.start,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                            indicatorSize: TabBarIndicatorSize.label,
                            indicator: UnderlineTabIndicator(
                              borderSide: BorderSide(color: crm.primary, width: 2),
                              insets: EdgeInsets.zero,
                            ),
                            dividerColor: Colors.transparent,
                            labelColor: crm.primary,
                            unselectedLabelColor: crm.textSecondary,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                            tabs: [
                              const Tab(text: 'COLLECTIONS'),
                              const Tab(text: 'EXPENSES'),
                              // short enough to fit a phone beside the other two
                              if (canVerify) const Tab(text: 'BY WORK'),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.picture_as_pdf_outlined, color: crm.textSecondary, size: 20),
                            onPressed: openReportDialog,
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: crm.border),
                              ),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                            tooltip: 'Generate Report',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                isMobile: isMobile,
              ),
            ),
          ];
        },
        body: ScrollConfiguration(
          behavior: const _TabPageScrollBehavior(),
          child: TabBarView(
            controller: tabCtrl,
            children: [
              if (collectionData != null)
                collectionsTab(collectionData)
              else if (asyncCollections.hasError)
                AppErrorView(
                  error: asyncCollections.error!,
                  onRetry: () => ref.invalidate(financeCollectionsPageProvider),
                )
              else
                const Center(child: CircularProgressIndicator()),
              if (expenseData != null)
                expensesTab(expenseData)
              else if (asyncExpenses.hasError)
                AppErrorView(
                  error: asyncExpenses.error!,
                  onRetry: () => ref.invalidate(financeExpensesPageProvider),
                )
              else
                const Center(child: CircularProgressIndicator()),
              if (canVerify)
                WorkCostsTab(
                  from: expenseQuery.value.from,
                  to: expenseQuery.value.to,
                  artists: artistOptionsFor(null),
                  inNestedScrollView: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Searchable Booking Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────
Future<String?> _showBookingSearchDialog({
  required BuildContext context,
  required List<Booking> bookings,
  required String Function(DateTime) fmtDate,
  String? initialSelected,
}) async {
  final searchCtrl = TextEditingController();
  String query = '';
  DateTime? filterFrom;
  DateTime? filterTo;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Apply search + date filter
        final filtered = bookings.where((b) {
          // Text filter
          if (query.isNotEmpty) {
            final q = query.toLowerCase();
            if (!b.customerName.toLowerCase().contains(q) &&
                !b.service.toLowerCase().contains(q)) {
              return false;
            }
          }
          // Date range filter
          if (filterFrom != null) {
            final from = DateTime(filterFrom!.year, filterFrom!.month, filterFrom!.day);
            if (b.serviceStart.isBefore(from)) return false;
          }
          if (filterTo != null) {
            final to = DateTime(filterTo!.year, filterTo!.month, filterTo!.day, 23, 59, 59);
            if (b.serviceStart.isAfter(to)) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

        final hasDateFilter = filterFrom != null || filterTo != null;
        final screenH = MediaQuery.of(ctx).size.height;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenH * 0.78),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.book_online_outlined, size: 18,
                          color: Color(0xFF6C3483)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Select Booking / Client',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ── Search box ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search by client name or service…',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchCtrl.clear();
                                setState(() => query = '');
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ── Date filter row ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      // From date chip
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: filterFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              helpText: 'From Date',
                            );
                            if (picked != null) setState(() => filterFrom = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: filterFrom != null
                                      ? const Color(0xFF6C3483)
                                      : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: filterFrom != null
                                  ? const Color(0xFF6C3483).withValues(alpha: 0.07)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 13,
                                    color: filterFrom != null
                                        ? const Color(0xFF6C3483)
                                        : Colors.grey.shade600),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    filterFrom != null
                                        ? fmtDate(filterFrom!)
                                        : 'From date',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: filterFrom != null
                                            ? const Color(0xFF6C3483)
                                            : Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ),
                      // To date chip
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: filterTo ?? DateTime.now(),
                              firstDate: filterFrom ?? DateTime(2020),
                              lastDate: DateTime(2030),
                              helpText: 'To Date',
                            );
                            if (picked != null) setState(() => filterTo = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: filterTo != null
                                      ? const Color(0xFF6C3483)
                                      : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: filterTo != null
                                  ? const Color(0xFF6C3483).withValues(alpha: 0.07)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 13,
                                    color: filterTo != null
                                        ? const Color(0xFF6C3483)
                                        : Colors.grey.shade600),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    filterTo != null
                                        ? fmtDate(filterTo!)
                                        : 'To date',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: filterTo != null
                                            ? const Color(0xFF6C3483)
                                            : Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Clear date filter button
                      if (hasDateFilter)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: IconButton(
                            icon: const Icon(Icons.cancel_outlined,
                                size: 18, color: Colors.redAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear date filter',
                            onPressed: () => setState(() {
                              filterFrom = null;
                              filterTo = null;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey.shade200),
                // Result count badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} booking${filtered.length == 1 ? '' : 's'} found',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // ── Booking list ────────────────────────────────────
                Flexible(
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 36, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                hasDateFilter || query.isNotEmpty
                                    ? 'No bookings match your filters.'
                                    : 'No bookings available.',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final b = filtered[i];
                            final balance =
                                (b.totalPrice - b.advanceAmount - b.discountAmount)
                                    .clamp(0, double.infinity)
                                    .toDouble();
                            final isSelected = b.id == initialSelected;
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, b.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6C3483).withValues(alpha: 0.07)
                                      : i.isOdd
                                          ? Colors.grey.withValues(alpha: 0.03)
                                          : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isSelected)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8, top: 2),
                                        child: const Icon(Icons.check_circle,
                                            size: 15,
                                            color: Color(0xFF6C3483)),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.customerName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.event_outlined,
                                                  size: 12,
                                                  color: Color(0xFF6C3483)),
                                              const SizedBox(width: 4),
                                              Text(
                                                fmtDate(b.serviceStart),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF6C3483),
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '${b.service}  •  ₹${balance.toStringAsFixed(0)} Bal.',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// The tab pages of a [NestedScrollView] all use its one inner scroll controller, so while two
/// pages are on screen (a swipe, a tab change) that controller has two positions. A desktop
/// scrollbar you can drag asserts on the next mouse-wheel event then ("attached to more than one
/// ScrollPosition"), so the pages get a display-only thumb instead.
class _TabPageScrollBehavior extends MaterialScrollBehavior {
  const _TabPageScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) return child;
    switch (getPlatform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(controller: details.controller, interactive: false, child: child);
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool isMobile;
  final Color backgroundColor;

  _SliverTabBarDelegate({
    required this.child,
    required this.isMobile,
    required this.backgroundColor,
  });

  @override
  double get minExtent => 66;

  @override
  double get maxExtent => 66;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 0,
        vertical: 8,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.isMobile != isMobile ||
        oldDelegate.child != child ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _FinanceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FinanceEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: crm.secondary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: crm.primary),
              ),
              12.h,
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: crm.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              6.h,
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: crm.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtCardDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
}

class _FinanceEntryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String status;
  final String metadata;
  final String? note;
  final String creatorName;
  final DateTime date;
  final DateTime? verifiedAt;
  final List<Widget> actions;
  final VoidCallback? onAttachmentTap;

  /// Something shown under the note — a food expense's allocation to a work.
  final Widget? extra;

  const _FinanceEntryCard({
    required this.title,
    required this.amount,
    required this.status,
    required this.metadata,
    this.note,
    required this.creatorName,
    required this.date,
    this.verifiedAt,
    required this.actions,
    this.onAttachmentTap,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;

    Color statusColor;
    String statusText;
    Color statusBg;

    if (status == 'verified' || status == 'approved') {
      statusColor = crm.success;
      statusText = 'APPROVED';
      statusBg = crm.success.withValues(alpha: 0.12);
    } else if (status == 'rejected') {
      statusColor = crm.destructive;
      statusText = 'REJECTED';
      statusBg = crm.destructive.withValues(alpha: 0.12);
    } else {
      statusColor = crm.warning;
      statusText = 'PENDING';
      statusBg = crm.warning.withValues(alpha: 0.12);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: crm.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        4.h,
                        // Date shown clearly next to the client name.
                        Row(
                          children: [
                            Icon(Icons.event_outlined, size: 13, color: crm.primary),
                            4.w,
                            Text(
                              _fmtCardDate(date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: crm.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (verifiedAt != null && (status == 'verified' || status == 'approved')) ...[
                              6.w,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: crm.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Approved: ${_fmtCardDate(verifiedAt!.toLocal())}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: crm.success,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (metadata.isNotEmpty) ...[
                          2.h,
                          Text(
                            metadata,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: crm.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              12.h,
              Text(
                amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: crm.textPrimary,
                  fontFamily: 'JetBrains Mono',
                  letterSpacing: -0.5,
                  fontSize: 20,
                ),
              ),
              if (note != null && note!.isNotEmpty) ...[
                8.h,
                Text(
                  note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: crm.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (extra != null) ...[8.h, extra!],
              12.h,
              Divider(height: 1, color: crm.border.faded(0.5)),
              12.h,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 14,
                        color: crm.textSecondary.withValues(alpha: 0.6),
                      ),
                      6.w,
                      Text(
                        creatorName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: crm.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (onAttachmentTap != null)
                    InkWell(
                      onTap: onAttachmentTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attachment_outlined, size: 10, color: crm.primary),
                            4.w,
                            Text(
                              'VIEW BILL',
                              style: TextStyle(
                                color: crm.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          status == 'verified' ? Icons.check_circle : Icons.access_time,
                          size: 12,
                          color: statusColor,
                        ),
                        4.w,
                        Text(
                          status == 'verified' ? 'Verified' : 'Awaiting verification',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                12.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Full-screen Image Viewer with Download & Share
// ─────────────────────────────────────────────────────────────────────────────
class _ImageViewerDialog extends StatefulWidget {
  final String url;
  final String? label;

  const _ImageViewerDialog({required this.url, this.label});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  bool _isDownloading = false;

  /// Lets network errors propagate (instead of swallowing them) so the
  /// snackbar can say "no internet" rather than a generic failure.
  Future<Uint8List?> _fetchImageBytes() async {
    final dio = Dio();
    final response = await dio.get<List<int>>(
      widget.url,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.statusCode == 200 && response.data != null) {
      return Uint8List.fromList(response.data!);
    }
    return null;
  }

  String _fileName() {
    final base = widget.label ?? 'image';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${base}_$ts.jpg';
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await _fetchImageBytes();
      if (bytes == null) {
        throw const AppException(null, action: 'download the image');
      }
      await downloadImage(
        bytes,
        _fileName(),
        subject: 'Download Image',
        text: widget.label == 'expense_bill'
            ? 'Expense Bill'
            : widget.label == 'collection_screenshot'
            ? 'Collection Screenshot'
            : 'Image',
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _share() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await _fetchImageBytes();
      if (bytes == null) {
        throw const AppException(null, action: 'load the image for sharing');
      }
      final xFile = XFile.fromData(bytes, mimeType: 'image/jpeg', name: _fileName());
      await Share.shareXFiles(
        [xFile],
        text: widget.label == 'expense_bill'
            ? 'Expense Bill'
            : widget.label == 'collection_screenshot'
            ? 'Collection Screenshot'
            : 'Image',
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Frosted glass background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black.withValues(alpha: 0.7)),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Close
                    _GlassButton(
                      icon: Icons.close,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    // Title
                    Text(
                      widget.label == 'expense_bill'
                          ? 'Expense Bill'
                          : widget.label == 'collection_screenshot'
                          ? 'Collection Screenshot'
                          : 'Image',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    // Share
                    _GlassButton(
                      icon: Icons.share_rounded,
                      onTap: _isDownloading ? null : _share,
                    ),
                    const SizedBox(width: 8),
                    // Download
                    _isDownloading
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : _GlassButton(
                            icon: Icons.download_rounded,
                            onTap: _download,
                          ),
                  ],
                ),
              ),
              // ── Image ──────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (ctx, _, _) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: onTap == null ? 0.1 : 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 20),
        ),
      ),
    );
  }
}
