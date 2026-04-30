import 'dart:io';
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
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}';
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

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final employees = asyncEmployees.value ?? [];
            final artists = employees
                .where((e) => e.artistRole != 'driver')
                .toList();
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: crm.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_chart_outlined, size: 20, color: crm.success),
                  ),
                  12.w,
                  const Text('Log Fund Collection'),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select the booking and enter the amount received from the client.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        20.h,
                        // Artist picker — hidden for artist-role (auto-scoped)
                        if (!isScopedToOwn) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Artist / Staff Member *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            initialValue: selEmployee.isEmpty ? null : selEmployee,
                            items: artists
                                .map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ))
                                .toList(),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Select artist' : null,
                            onChanged: (v) =>
                                setState(() => selEmployee = v ?? ''),
                          ),
                          16.h,
                        ],
                        // Booking Selector
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          itemHeight: 64,
                          decoration: const InputDecoration(
                            labelText: 'Select Booking / Client *',
                            prefixIcon: Icon(Icons.book_online_outlined),
                            helperText: 'Only your assigned works are shown here',
                          ),
                          initialValue: selBooking.isEmpty ? null : selBooking,
                          items: myBookings.map((b) {
                            final balance = b.totalPrice - b.advanceAmount - b.discountAmount;
                            return DropdownMenuItem(
                              value: b.id,
                              child: SizedBox(
                                height: 64,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Select a booking' : null,
                          onChanged: (v) => setState(() => selBooking = v ?? ''),
                        ),
                        16.h,
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
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => setState(() {}),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Enter amount' : null,
                        ),
                        16.h,
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Payment Mode',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                ),
                                initialValue: payMode,
                                items: _paymentModes
                                    .map((m) => DropdownMenuItem(
                                          value: m.$1,
                                          child: Text(m.$2),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => payMode = v ?? 'cash'),
                              ),
                            ),
                            12.w,
                            Expanded(
                              flex: 2,
                              child: InkWell(
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
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    prefixIcon: Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(_fmt(selDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        16.h,
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Internal Notes',
                            prefixIcon: Icon(Icons.note_alt_outlined),
                            hintText: 'e.g. Received via GPay from husband',
                          ),
                        ),
                        16.h,
                        // Attachment section
                        if (payMode == 'upi') ...[
                          const Text('UPI Payment Screenshot *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          8.h,
                          InkWell(
                            onTap: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery);
                              if (picked != null) {
                                setState(() => attachmentFile = picked);
                              }
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
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                                        Text('Tap to add screenshot', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: kIsWeb 
                                        ? Image.network(attachmentFile!.path, fit: BoxFit.cover)
                                        : Image.file(File(attachmentFile!.path), fit: BoxFit.cover),
                                    ),
                            ),
                          ),
                          16.h,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                if (isUploading) 
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: crm.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      
                      if (payMode == 'upi' && attachmentFile == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please upload the UPI payment screenshot')),
                        );
                        return;
                      }

                      setState(() => isUploading = true);
                      try {
                        String? uploadedUrl;
                        if (attachmentFile != null) {
                          uploadedUrl = await ref.read(uploadServiceProvider).uploadImage(attachmentFile!);
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
                              amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                              date: selDate,
                              paymentMode: payMode,
                              notes: notesCtrl.text.trim(),
                              attachmentUrl: uploadedUrl,
                            );
                        ref.invalidate(collectionsProvider);
                        ref.invalidate(artistCollectionsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => isUploading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    child: const Text('Log Collection'),
                  ),
                ],
              ],
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

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final employees = asyncEmployees.value ?? [];
            final artists = employees
                .where((e) => e.artistRole != 'driver')
                .toList();
            return AlertDialog(
              title: const Text('Log Artist Expense'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isScopedToOwn)
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Artist *'),
                            initialValue: selEmployee.isEmpty ? null : selEmployee,
                            items: artists
                                .map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ))
                                .toList(),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Select artist' : null,
                            onChanged: (v) =>
                                setState(() => selEmployee = v ?? ''),
                          ),
                        if (!isScopedToOwn) 16.h,
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Category'),
                          initialValue: selCategory,
                          items: _expenseCategories
                              .map((c) => DropdownMenuItem(
                                    value: c.$1,
                                    child: Text(c.$2),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => selCategory = v ?? 'other'),
                        ),
                        16.h,
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹) *',
                          ),
                          onChanged: (v) => setState(() {}),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Enter amount' : null,
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
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(_fmt(selDate)),
                          ),
                        ),
                        16.h,
                      16.h,
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      16.h,
                      // Expense Bill Attachment
                      Builder(builder: (context) {
                        final amt = double.tryParse(amountCtrl.text) ?? 0;
                        if (amt > 100) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expense Bill / Receipt *',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              8.h,
                              InkWell(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (picked != null) {
                                    setState(
                                        () => attachmentFile = picked);
                                  }
                                },
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: attachmentFile == null
                                            ? Colors.grey.shade300
                                            : crm.primary),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: attachmentFile == null
                                      ? const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.receipt_long_outlined,
                                                color: Colors.grey),
                                            Text('Tap to upload bill',
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                          ],
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          child: kIsWeb 
                                            ? Image.network(attachmentFile!.path, fit: BoxFit.cover)
                                            : Image.file(File(attachmentFile!.path), fit: BoxFit.cover),
                                        ),
                                ),
                              ),
                              16.h,
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (isUploading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator()))
              else ...[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amt > 100 && attachmentFile == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please upload the bill for expenses over ₹100')),
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

                      await ref.read(expenseServiceProvider).createExpense(
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
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ],
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
          await ref.read(collectionServiceProvider).verifyCollection(
                id: id, status: action, verifiedBy: verifiedBy);
          ref.invalidate(collectionsProvider);
          ref.invalidate(artistCollectionsProvider);
        } else {
          await ref.read(expenseServiceProvider).verifyExpense(
                id: id, status: action, verifiedBy: verifiedBy);
          ref.invalidate(expensesProvider);
          ref.invalidate(artistExpensesProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
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
          content: const Text('Are you sure you want to delete this entry? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
            const SnackBar(content: Text('Entry deleted successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
        }
      }
    }

    Widget statusBadge(String status) {
      final color = _statusColor(status, crm);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          status.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );
    }


    void showImageDialog(String url) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                  ),
                ),
              ),
              12.h,
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check),
                label: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    Widget collectionsTab(List<ArtistCollection> items) {
      // Summary row
      final total = items.fold(0.0, (sum, c) => sum + c.amount);
      final pending = items.where((c) => c.status == 'pending').length;
      final verified = items.where((c) => c.status == 'verified').length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _KpiCard(label: 'Total Collected', value: _currency(total), icon: Icons.account_balance_wallet_outlined, crm: crm, theme: theme),
                12.w,
                _KpiCard(label: 'Pending Verification', value: '$pending entries', icon: Icons.hourglass_top_outlined, crm: crm, theme: theme, isWarning: true),
                12.w,
                _KpiCard(label: 'Verified', value: '$verified entries', icon: Icons.verified_outlined, crm: crm, theme: theme, isSuccess: true),
              ],
            ),
          ),
          20.h,
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 48, color: crm.textSecondary),
                    12.h,
                    Text('No collections logged yet', style: TextStyle(color: crm.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: crm.border),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: crm.accent.withValues(alpha: 0.15),
                        child: Icon(Icons.account_balance_wallet_outlined, color: crm.accent, size: 18),
                      ),
                      title: Text(
                        '${c.booking?.customerName ?? 'Unknown Client'}  •  ${_currency(c.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${_fmt(c.date)}  •  ${c.paymentMode.toUpperCase()}'
                        '${c.booking != null ? "  •  ${c.booking!.service}" : ""}'
                        '${!isScopedToOwn ? "  •  By: ${c.employee?.name ?? 'Unknown'}" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (c.attachmentUrl != null && c.attachmentUrl!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.image_outlined, size: 20),
                              onPressed: () => showImageDialog(c.attachmentUrl!),
                              tooltip: 'View Screenshot',
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              statusBadge(c.status),
                            ],
                          ),
                          // Verify/Reject buttons only for accounts+admin
                          if (canVerify && c.status == 'pending') ...[
                            IconButton(
                              tooltip: 'Verify',
                              icon: Icon(Icons.check_circle_outline, color: crm.success),
                              onPressed: () => verifyItem(id: c.id, isCollection: true, action: 'verified'),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              icon: Icon(Icons.cancel_outlined, color: crm.destructive),
                              onPressed: () => verifyItem(id: c.id, isCollection: true, action: 'rejected'),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline, color: crm.destructive),
                              onPressed: () => deleteItem(id: c.id, isCollection: true),
                            ),
                          ],
                          if (canVerify && c.status != 'pending') 
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline, color: crm.destructive.withValues(alpha: 0.5)),
                              onPressed: () => deleteItem(id: c.id, isCollection: true),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      );
    }

    Widget expensesTab(List<ArtistExpense> items) {
      final total = items.fold(0.0, (sum, e) => sum + e.amount);
      final pending = items.where((e) => e.status == 'pending').length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _KpiCard(label: 'Total Expenses', value: _currency(total), icon: Icons.receipt_long_outlined, crm: crm, theme: theme),
                12.w,
                _KpiCard(label: 'Pending Approval', value: '$pending entries', icon: Icons.pending_actions_outlined, crm: crm, theme: theme, isWarning: true),
              ],
            ),
          ),
          20.h,
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: crm.textSecondary),
                    12.h,
                    Text('No expenses logged yet', style: TextStyle(color: crm.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: crm.border),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final catLabel = _expenseCategories
                        .firstWhere((c) => c.$1 == e.category, orElse: () => ('other', 'Other'))
                        .$2;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: crm.primary.withValues(alpha: 0.08),
                        child: Icon(Icons.receipt_outlined, color: crm.primary, size: 18),
                      ),
                      title: Text(
                        '${e.employee?.name ?? 'Unknown Artist'}  •  ${_currency(e.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$catLabel  •  ${_fmt(e.date)}'
                        '${e.notes.isNotEmpty ? "  •  ${e.notes}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (e.receiptImage.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.receipt_long_outlined, size: 20),
                              onPressed: () => showImageDialog(e.receiptImage),
                              tooltip: 'View Bill',
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              statusBadge(e.status),
                            ],
                          ),
                          if (canVerify && e.status == 'pending') ...[
                            IconButton(
                              tooltip: 'Approve',
                              icon: Icon(Icons.check_circle_outline, color: crm.success),
                              onPressed: () => verifyItem(id: e.id, isCollection: false, action: 'verified'),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              icon: Icon(Icons.cancel_outlined, color: crm.destructive),
                              onPressed: () => verifyItem(id: e.id, isCollection: false, action: 'rejected'),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline, color: crm.destructive),
                              onPressed: () => deleteItem(id: e.id, isCollection: false),
                            ),
                          ],
                          if (canVerify && e.status != 'pending') 
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline, color: crm.destructive.withValues(alpha: 0.5)),
                              onPressed: () => deleteItem(id: e.id, isCollection: false),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artist Finance',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Track fund collections & expense claims by artists. Accounts team can verify here.',
                    style: TextStyle(color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              OutlinedButton.icon(
                onPressed: addExpenseDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log Expense'),
              ),
              12.w,
              ElevatedButton.icon(
                onPressed: addCollectionDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log Collection'),
              ),
            ],
          ],
        ),
        if (isMobile) ...[
          12.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: addExpenseDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log Expense'),
                ),
              ),
              12.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: addCollectionDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log Collection'),
                ),
              ),
            ],
          ),
        ],
        20.h,
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: crm.input,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: tabCtrl,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: crm.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: crm.textSecondary,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Fund Collections'),
              Tab(text: 'Expense Claims'),
            ],
          ),
        ),
        16.h,
        Expanded(
          child: TabBarView(
            controller: tabCtrl,
            children: [
              // Collections tab
              asyncCollections.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
                data: (items) => collectionsTab(items),
              ),
              // Expenses tab
              asyncExpenses.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
                data: (items) => expensesTab(items),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final CrmTheme crm;
  final ThemeData theme;
  final bool isWarning;
  final bool isSuccess;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.crm,
    required this.theme,
    this.isWarning = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? crm.success : isWarning ? crm.warning : crm.primary;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
