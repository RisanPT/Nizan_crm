import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/auth/app_role.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/artist_collection.dart';
import '../../core/models/artist_expense.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/collection_service.dart';
import '../../services/employee_service.dart';
import '../../services/expense_service.dart';
import '../../core/providers/booking_provider.dart';
import '../../services/upload_service.dart';
import '../../services/report_service.dart';

class ArtistFinanceScreen extends HookConsumerWidget {
  const ArtistFinanceScreen({super.key});

  static const _paymentModes = [
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('bank_transfer', 'Bank Transfer'),
    ('other', 'Other'),
  ];

  static const _expenseCategories = [
    ('food', 'Food'),
    ('travel', 'Travel'),
    ('stay', 'Stay'),
    ('materials', 'Materials'),
    ('fuel', 'Fuel'),
    ('other', 'Other'),
  ];

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

  Color _statusColor(String s, CrmTheme c) {
    if (s == 'verified') return c.success;
    if (s == 'rejected') return c.destructive;
    return c.warning;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final tabCtrl = useTabController(initialLength: 2);

    // ── Role + identity ──────────────────────────────────────────────────────
    final session = ref.watch(authControllerProvider).session;
    final role = AppRole.fromString(session?.role);
    final myEmployeeId = session?.employeeId ?? '';
    final canVerify = role.canVerifyFinance;
    final isScopedToOwn = role.isScopedToOwnEntries;
    final asyncBookings = ref.watch(bookingProvider);

    // Filter bookings for this artist if scoped
    final myBookings = (asyncBookings.value ?? []).where((b) {
      if (!isScopedToOwn) return true;
      return b.assignedStaff.any((s) => s.employeeId == myEmployeeId);
    }).toList();

    // ── Data providers (scoped or global) ───────────────────────────────────
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncCollections = isScopedToOwn && myEmployeeId.isNotEmpty
        ? ref.watch(artistCollectionsProvider(myEmployeeId))
        : ref.watch(collectionsProvider);
    final asyncExpenses = isScopedToOwn && myEmployeeId.isNotEmpty
        ? ref.watch(artistExpensesProvider(myEmployeeId))
        : ref.watch(expensesProvider);
    // ── Filter States ────────────────────────────────────────────────────────
    final filterStatuses = useState<Set<String>>({'pending', 'verified'});
    final filterPaymentModes = useState<Set<String>>({'cash', 'bank_transfer', 'upi', 'other'});
    final filterFromDate = useState<DateTime?>(null);
    final filterToDate = useState<DateTime?>(null);
    final filterMinAmount = useState<double?>(null);
    final filterMaxAmount = useState<double?>(null);

    final collectionItems =
        asyncCollections.value ?? const <ArtistCollection>[];
    final expenseItems = asyncExpenses.value ?? const <ArtistExpense>[];

    // Filtered lists
    final filteredCollections = collectionItems.where((c) {
      if (!filterStatuses.value.contains(c.status)) return false;
      if (!filterPaymentModes.value.contains(c.paymentMode)) return false;
      if (filterFromDate.value != null && c.date.isBefore(filterFromDate.value!)) return false;
      if (filterToDate.value != null && c.date.isAfter(filterToDate.value!.add(const Duration(days: 1)))) return false;
      if (filterMinAmount.value != null && c.amount < filterMinAmount.value!) return false;
      if (filterMaxAmount.value != null && c.amount > filterMaxAmount.value!) return false;
      return true;
    }).toList();

    final filteredExpenses = expenseItems.where((e) {
      if (!filterStatuses.value.contains(e.status)) return false;
      if (filterFromDate.value != null && e.date.isBefore(filterFromDate.value!)) return false;
      if (filterToDate.value != null && e.date.isAfter(filterToDate.value!.add(const Duration(days: 1)))) return false;
      if (filterMinAmount.value != null && e.amount < filterMinAmount.value!) return false;
      if (filterMaxAmount.value != null && e.amount > filterMaxAmount.value!) return false;
      return true;
    }).toList();

    final totalCollected = filteredCollections.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final totalExpenses = filteredExpenses.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );

    Future<void> addCollectionDialog() async {
      final amountCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      // Artist accounts auto-fill their own employeeId
      var selEmployee = isScopedToOwn ? myEmployeeId : '';
      var selBooking = '';
      var payMode = 'cash';
      var selDate = DateTime.now();
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
                .where((e) => e.artistRole != 'driver')
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
                            'Select the booking and enter the amount received from the client.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          24.h,
                          // Artist picker — hidden for artist-role (auto-scoped)
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
                              initialValue: selEmployee.isEmpty
                                  ? null
                                  : selEmployee,
                              items: artists
                                  .map(
                                    (e) => DropdownMenuItem(
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
                          // Booking Selector
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            itemHeight: 64,
                            decoration: InputDecoration(
                              labelText: 'Select Booking / Client *',
                              prefixIcon: const Icon(
                                Icons.book_online_outlined,
                              ),
                              helperText:
                                  'Only your assigned works are shown here',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            initialValue: selBooking.isEmpty
                                ? null
                                : selBooking,
                            items: myBookings.map((b) {
                              final balance =
                                  b.totalPrice -
                                  b.advanceAmount -
                                  b.discountAmount;
                              return DropdownMenuItem(
                                value: b.id,
                                child: SizedBox(
                                  height: 64,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        b.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${b.service} • ₹${balance.toStringAsFixed(0)} Bal.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Select a booking'
                                : null,
                            onChanged: (v) =>
                                setState(() => selBooking = v ?? ''),
                          ),
                          16.h,
                          TextFormField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount Collected (₹) *',
                              prefixIcon: const Icon(
                                Icons.currency_rupee,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: crm.success.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: crm.success.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            onChanged: (v) => setState(() {}),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter amount'
                                : null,
                          ),
                          16.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Payment Mode',
                              prefixIcon: const Icon(
                                Icons.payments_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            initialValue: payMode,
                            items: _paymentModes
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.$1,
                                    child: Text(m.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => payMode = v ?? 'cash'),
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
                              labelText: 'Internal Notes',
                              prefixIcon: const Icon(Icons.note_alt_outlined),
                              hintText: 'e.g. Received via GPay from husband',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          16.h,
                          // Attachment section
                          if (payMode == 'upi') ...[
                            const Text(
                              'UPI Payment Screenshot *',
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
                                        : crm.success,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade50,
                                ),
                                child: attachmentFile == null
                                    ? const Column(
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
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: kIsWeb
                                            ? Image.network(
                                                attachmentFile!.path,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(attachmentFile!.path),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                              ),
                            ),
                            16.h,
                          ],
                          32.h,
                          SizedBox(
                            width: double.infinity,
                            child: isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: crm.success,
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
                                      if (!formKey.currentState!.validate())
                                        return;

                                      if (payMode == 'upi' &&
                                          attachmentFile == null) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please upload the UPI payment screenshot',
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

                                        await ref
                                            .read(collectionServiceProvider)
                                            .createCollection(
                                              bookingId: selBooking.isNotEmpty
                                                  ? selBooking
                                                  : '000000000000000000000000',
                                              employeeId: selEmployee.isNotEmpty
                                                  ? selEmployee
                                                  : myEmployeeId,
                                              amount:
                                                  double.tryParse(
                                                    amountCtrl.text.trim(),
                                                  ) ??
                                                  0,
                                              date: selDate,
                                              paymentMode: payMode,
                                              notes: notesCtrl.text.trim(),
                                              attachmentUrl: uploadedUrl,
                                            );
                                        ref.invalidate(collectionsProvider);
                                        ref.invalidate(
                                          artistCollectionsProvider,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } catch (e) {
                                        setState(() => isUploading = false);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
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

    Future<void> addExpenseDialog() async {
      final amountCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      var selEmployee = isScopedToOwn ? myEmployeeId : '';
      var selCategory = 'food';
      var selDate = DateTime.now();
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
                .where((e) => e.artistRole != 'driver')
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
                                'Log Artist Expense',
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
                                  .map(
                                    (e) => DropdownMenuItem(
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
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.$1,
                                    child: Text(c.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selCategory = v ?? 'other'),
                          ),
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
                                      'Expense Bill / Receipt *',
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
                                        );
                                        if (picked != null) {
                                          setState(
                                            () => attachmentFile = picked,
                                          );
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                    'Tap to upload bill',
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
                          32.h,
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
                                      if (!formKey.currentState!.validate())
                                        return;

                                      final amt =
                                          double.tryParse(
                                            amountCtrl.text.trim(),
                                          ) ??
                                          0;
                                      if (amt > 100 && attachmentFile == null) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please upload the bill for expenses over ₹100',
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

                                        await ref
                                            .read(expenseServiceProvider)
                                            .createExpense(
                                              employeeId: selEmployee.isNotEmpty
                                                  ? selEmployee
                                                  : myEmployeeId,
                                              category: selCategory,
                                              amount: amt,
                                              date: selDate,
                                              notes: notesCtrl.text.trim(),
                                              receiptImage: uploadedUrl ?? '',
                                            );
                                        ref.invalidate(expensesProvider);
                                        ref.invalidate(artistExpensesProvider);
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } catch (e) {
                                        setState(() => isUploading = false);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'LOG EXPENSE',
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
    }) async {
      try {
        final verifiedBy = session?.userId ?? '';
        if (isCollection) {
          await ref
              .read(collectionServiceProvider)
              .verifyCollection(id: id, status: action, verifiedBy: verifiedBy);
          ref.invalidate(collectionsProvider);
          ref.invalidate(artistCollectionsProvider);
        } else {
          await ref
              .read(expenseServiceProvider)
              .verifyExpense(id: id, status: action, verifiedBy: verifiedBy);
          ref.invalidate(expensesProvider);
          ref.invalidate(artistExpensesProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
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
          ref.invalidate(collectionsProvider);
          ref.invalidate(artistCollectionsProvider);
        } else {
          await ref.read(expenseServiceProvider).deleteExpense(id);
          ref.invalidate(expensesProvider);
          ref.invalidate(artistExpensesProvider);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }


    void showImageDialog(String url) {
      showDialog(
        context: context,
        builder: (ctx) => Stack(
          children: [
            // Frosted glass background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    16.h,
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget collectionsTab(List<ArtistCollection> items) {
      if (items.isEmpty) {
        return Builder(
          builder: (context) {
            return CustomScrollView(
              key: const PageStorageKey<String>('collections'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  sliver: SliverToBoxAdapter(
                    child: _FinanceEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No collections logged yet',
                      subtitle: 'Start by recording the first amount collected from a client.',
                    ),
                  ),
                ),
              ],
            );
          }
        );
      }

      final sortedItems = [...items]..sort((a, b) => b.date.compareTo(a.date));
      return Builder(
        builder: (context) {
          return CustomScrollView(
            key: const PageStorageKey<String>('collections'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0, vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = sortedItems[i];
                      final metadataStr = [
                        _fmt(c.date),
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

                      return _FinanceEntryCard(
                        title: c.booking?.customerName ?? 'Unknown Client',
                        amount: _currency(c.amount),
                        status: c.status,
                        metadata: metadataStr,
                        note: c.notes.isNotEmpty ? c.notes : null,
                        creatorName: c.employee?.name ?? 'Unknown',
                        date: c.date,
                        actions: actionsList,
                        onAttachmentTap: (c.attachmentUrl != null && c.attachmentUrl!.isNotEmpty)
                            ? () => showImageDialog(c.attachmentUrl!)
                            : null,
                      );
                    },
                    childCount: sortedItems.length,
                  ),
                ),
              ),
            ],
          );
        }
      );
    }

    Widget expensesTab(List<ArtistExpense> items) {
      if (items.isEmpty) {
        return Builder(
          builder: (context) {
            return CustomScrollView(
              key: const PageStorageKey<String>('expenses'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  sliver: SliverToBoxAdapter(
                    child: _FinanceEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses logged yet',
                      subtitle: 'Receipts and travel costs logged here will appear for review.',
                    ),
                  ),
                ),
              ],
            );
          }
        );
      }

      final sortedItems = [...items]..sort((a, b) => b.date.compareTo(a.date));
      return Builder(
        builder: (context) {
          return CustomScrollView(
            key: const PageStorageKey<String>('expenses'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
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
                        catLabel,
                        _fmt(e.date),
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
                        actions: actionsList,
                        onAttachmentTap: e.receiptImage.isNotEmpty
                            ? () => showImageDialog(e.receiptImage)
                            : null,
                      );
                    },
                    childCount: sortedItems.length,
                  ),
                ),
              ),
            ],
          );
        }
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

    void openFilterBottomSheet() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final tempStatuses = Set<String>.from(filterStatuses.value);
            final tempPaymentModes = Set<String>.from(filterPaymentModes.value);
            var tempFromDate = filterFromDate.value;
            var tempToDate = filterToDate.value;
            final minAmountCtrl = TextEditingController(
              text: filterMinAmount.value != null ? filterMinAmount.value!.toStringAsFixed(0) : '',
            );
            final maxAmountCtrl = TextEditingController(
              text: filterMaxAmount.value != null ? filterMaxAmount.value!.toStringAsFixed(0) : '',
            );

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Transactions',
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
                          'STATUS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        ...[
                          ('pending', 'Pending Verification'),
                          ('verified', 'Approved'),
                          ('rejected', 'Rejected'),
                        ].map((item) {
                          final isChecked = tempStatuses.contains(item.$1);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.$2, style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                            value: isChecked,
                            activeColor: crm.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  tempStatuses.add(item.$1);
                                } else {
                                  tempStatuses.remove(item.$1);
                                }
                              });
                            },
                          );
                        }),
                        16.h,
                        Text(
                          'DATE RANGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: tempFromDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => tempFromDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'From Date',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    tempFromDate != null ? _fmt(tempFromDate!) : 'Select',
                                    style: TextStyle(fontSize: 12, color: crm.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                            12.w,
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: tempToDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => tempToDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'To Date',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    tempToDate != null ? _fmt(tempToDate!) : 'Select',
                                    style: TextStyle(fontSize: 12, color: crm.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        16.h,
                        Text(
                          'AMOUNT RANGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: minAmountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Min Amount',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                style: TextStyle(fontSize: 12, color: crm.textPrimary),
                              ),
                            ),
                            12.w,
                            Expanded(
                              child: TextFormField(
                                controller: maxAmountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Max Amount',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                style: TextStyle(fontSize: 12, color: crm.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        16.h,
                        Text(
                          'PAYMENT METHOD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: crm.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        8.h,
                        ...[
                          ('cash', 'Cash'),
                          ('bank_transfer', 'Bank Transfer'),
                          ('upi', 'UPI'),
                          ('other', 'Other'),
                        ].map((item) {
                          final isChecked = tempPaymentModes.contains(item.$1);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.$2, style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                            value: isChecked,
                            activeColor: crm.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  tempPaymentModes.add(item.$1);
                                } else {
                                  tempPaymentModes.remove(item.$1);
                                }
                              });
                            },
                          );
                        }),
                        24.h,
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  filterStatuses.value = {'pending', 'verified'};
                                  filterPaymentModes.value = {'cash', 'bank_transfer', 'upi', 'other'};
                                  filterFromDate.value = null;
                                  filterToDate.value = null;
                                  filterMinAmount.value = null;
                                  filterMaxAmount.value = null;
                                  Navigator.pop(ctx);
                                  showToast('✓ Filters Reset');
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('RESET'),
                              ),
                            ),
                            12.w,
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  filterStatuses.value = tempStatuses;
                                  filterPaymentModes.value = tempPaymentModes;
                                  filterFromDate.value = tempFromDate;
                                  filterToDate.value = tempToDate;
                                  filterMinAmount.value = double.tryParse(minAmountCtrl.text);
                                  filterMaxAmount.value = double.tryParse(maxAmountCtrl.text);
                                  Navigator.pop(ctx);
                                  showToast('✓ Filters Applied Successfully');
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: crm.primary,
                                ),
                                child: const Text('APPLY FILTERS'),
                              ),
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
                                value: selectedMonth,
                                items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
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
                                value: selectedYear,
                                items: [DateTime.now().year - 1, DateTime.now().year]
                                    .map((y) => DropdownMenuItem(
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
                            value: selectedArtist,
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All Artists', style: TextStyle(fontSize: 12)),
                              ),
                              ...(asyncEmployees.value ?? []).map(
                                (e) => DropdownMenuItem(
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
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('PDF', style: TextStyle(fontSize: 12)),
                                value: 'pdf',
                                groupValue: selectedFormat,
                                activeColor: crm.primary,
                                onChanged: (v) => dialogSetState(() => selectedFormat = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('CSV', style: TextStyle(fontSize: 12)),
                                value: 'csv',
                                groupValue: selectedFormat,
                                activeColor: crm.primary,
                                onChanged: (v) => dialogSetState(() => selectedFormat = v!),
                              ),
                            ),
                          ],
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
                                    employeeId: selectedType == 'artist' ? selectedArtist : 'all',
                                    format: selectedFormat,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    showToast('✓ Report Generated (${selectedFormat.toUpperCase()})');
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error generating report: $e')),
                                    );
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

    final pendingCount = filteredCollections.where((c) => c.status == 'pending').length +
        filteredExpenses.where((e) => e.status == 'pending').length;

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
                                    Text(
                                      'TOTAL COLLECTED',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: crm.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
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
                                    Icon(Icons.arrow_upward, size: 10, color: crm.success),
                                    4.w,
                                    Text(
                                      '+12% this month',
                                      style: TextStyle(
                                        color: crm.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                                    Text(
                                      'PENDING',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: crm.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
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
                                    Text(
                                      'Awaiting verification',
                                      style: TextStyle(
                                        color: crm.warning,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                    border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            controller: tabCtrl,
                            isScrollable: true,
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
                            tabs: const [
                              Tab(text: 'COLLECTIONS'),
                              Tab(text: 'EXPENSES'),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.tune_outlined, color: crm.textSecondary, size: 20),
                            onPressed: openFilterBottomSheet,
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: crm.border),
                              ),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                            tooltip: 'Filter Transactions',
                          ),
                          8.w,
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
        body: TabBarView(
          controller: tabCtrl,
          children: [
            asyncCollections.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e', style: TextStyle(color: crm.destructive)),
              ),
              data: (_) => collectionsTab(filteredCollections),
            ),
            asyncExpenses.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e', style: TextStyle(color: crm.destructive)),
              ),
              data: (_) => expensesTab(filteredExpenses),
            ),
          ],
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

class _FinanceEntryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String status;
  final String metadata;
  final String? note;
  final String creatorName;
  final DateTime date;
  final List<Widget> actions;
  final VoidCallback? onAttachmentTap;

  const _FinanceEntryCard({
    required this.title,
    required this.amount,
    required this.status,
    required this.metadata,
    this.note,
    required this.creatorName,
    required this.date,
    required this.actions,
    this.onAttachmentTap,
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
                        Text(
                          metadata,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: crm.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
              12.h,
              Divider(height: 1, color: crm.border.withValues(alpha: 0.5)),
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
