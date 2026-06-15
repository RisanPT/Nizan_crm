import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/fuel_expense.dart';
import '../../core/models/list_page_params.dart';
import '../../core/models/vehicle.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/fuel_expense_service.dart';
import '../../services/vehicle_service.dart';
import '../common_widgets/paginated_footer.dart';

class FuelExpensesScreen extends HookConsumerWidget {
  const FuelExpensesScreen({super.key});

  static const _expenseCategories = [
    ('fuel', 'Fuel'),
    ('food', 'Food'),
    ('toll', 'Toll'),
    ('parking', 'Parking'),
    ('service', 'Service'),
    ('other', 'Other'),
  ];

  String _formatDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
  }

  String _formatCurrency(double value) {
    return '₹ ${value.toStringAsFixed(0)}';
  }

  String _categoryLabel(String category) {
    return _expenseCategories
        .firstWhere(
          (entry) => entry.$1 == category,
          orElse: () => ('other', 'Other'),
        )
        .$2;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'toll':
        return Icons.toll_outlined;
      case 'parking':
        return Icons.local_parking_outlined;
      case 'service':
        return Icons.build_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Color _categoryColor(String category, CrmTheme colors) {
    switch (category) {
      case 'fuel':
        return colors.primary;
      case 'food':
        return colors.warning;
      case 'toll':
      case 'parking':
        return colors.accent;
      case 'service':
        return colors.success;
      default:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;

    final asyncExpenses = ref.watch(
      paginatedFuelExpensesProvider(
        ListPageParams(page: pageState.value, limit: pageSize),
      ),
    );
    final asyncVehicles = ref.watch(vehiclesProvider);
    final asyncEmployees = ref.watch(employeesProvider);

    Future<void> openExpenseDialog([FuelExpense? expense]) async {
      final odometerCtrl = TextEditingController(
        text: expense != null && expense.odometerKm > 0
            ? expense.odometerKm.toStringAsFixed(0)
            : '',
      );
      final litersCtrl = TextEditingController(
        text: expense != null && expense.liters > 0
            ? expense.liters.toStringAsFixed(2)
            : '',
      );
      final amountCtrl = TextEditingController(
        text: expense != null ? expense.totalAmount.toStringAsFixed(0) : '',
      );
      final stationCtrl = TextEditingController(text: expense?.station ?? '');
      final notesCtrl = TextEditingController(text: expense?.notes ?? '');
      var selectedVehicleId = expense?.vehicle?.id ?? '';
      var selectedDriverId = expense?.driver?.id ?? '';
      var selectedCategory = expense?.category ?? 'fuel';
      var paymentMode = expense?.paymentMode ?? 'cash';
      var selectedDate = expense?.date ?? DateTime.now();

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final vehicles = asyncVehicles.value ?? const <Vehicle>[];
          final drivers = (asyncEmployees.value ?? const <Employee>[])
              .where((employee) => employee.artistRole == 'driver')
              .toList();
          final vehicleOptions = vehicles
              .map(
                (vehicle) => DropdownMenuItem(
                  value: vehicle.id,
                  child: Text(
                    '${vehicle.name} • ${vehicle.registrationNumber}',
                  ),
                ),
              )
              .toList();
          final driverOptions = [
            const DropdownMenuItem(
              value: '',
              child: Text('Unassigned'),
            ),
            ...drivers.map(
              (driver) => DropdownMenuItem(
                value: driver.id,
                child: Text(driver.name),
              ),
            ),
          ];
          final hasSelectedVehicle = vehicleOptions.any(
            (item) => item.value == selectedVehicleId,
          );
          final hasSelectedDriver = driverOptions.any(
            (item) => item.value == selectedDriverId,
          );

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(
                expense == null ? 'Add Expense' : 'Edit Expense',
              ),
              content: SizedBox(
                width: isMobile ? double.maxFinite : 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        items: _expenseCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.$1,
                                child: Text(category.$2),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedCategory = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Expense Category',
                        ),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        initialValue:
                            hasSelectedVehicle ? selectedVehicleId : null,
                        items: vehicleOptions,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedVehicleId = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Vehicle',
                        ),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        initialValue: hasSelectedDriver ? selectedDriverId : '',
                        items: driverOptions,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedDriverId = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Driver'),
                      ),
                      16.h,
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expense Date',
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _formatDate(selectedDate),
                            ),
                          ),
                        ),
                      ),
                      16.h,
                      if (selectedCategory == 'fuel') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: odometerCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Odometer (KM)',
                                ),
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: TextField(
                                controller: litersCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Liters',
                                ),
                              ),
                            ),
                          ],
                        ),
                        16.h,
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Total Amount',
                              ),
                            ),
                          ),
                          16.w,
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: paymentMode,
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'upi',
                                  child: Text('UPI'),
                                ),
                                DropdownMenuItem(
                                  value: 'card',
                                  child: Text('Card'),
                                ),
                                DropdownMenuItem(
                                  value: 'credit',
                                  child: Text('Credit'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('Other'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => paymentMode = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Payment Mode',
                              ),
                            ),
                          ),
                        ],
                      ),
                      16.h,
                      TextField(
                        controller: stationCtrl,
                        decoration: InputDecoration(
                          labelText: selectedCategory == 'fuel'
                              ? 'Fuel Station'
                              : 'Vendor / Place',
                        ),
                      ),
                      16.h,
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(fuelExpenseServiceProvider).saveFuelExpense(
                          id: expense?.id,
                          vehicleId: selectedVehicleId,
                          driverId: selectedDriverId,
                          category: selectedCategory,
                          date: selectedDate,
                          odometerKm:
                              double.tryParse(odometerCtrl.text.trim()) ?? 0,
                          liters:
                              double.tryParse(litersCtrl.text.trim()) ?? 0,
                          totalAmount:
                              double.tryParse(amountCtrl.text.trim()) ?? 0,
                          paymentMode: paymentMode,
                          station: stationCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                    ref.invalidate(fuelExpensesProvider);
                    ref.invalidate(paginatedFuelExpensesProvider);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Desktop header ──────────────────────────────────────────────
        if (!isMobile) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet Expenses',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Track fuel, food, toll, parking, service, and other vehicle-related expenses.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => openExpenseDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Expense'),
              ),
            ],
          ),
          24.h,
        ],

        // ── Mobile header ───────────────────────────────────────────────
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                asyncExpenses.maybeWhen(
                  data: (r) {
                    final count = r.totalItems;
                    return Text(
                      '$count expense${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: crmColors.textSecondary,
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => openExpenseDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Expense',
                      style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  ),
                ),
              ],
            ),
          ),

        // ── List ────────────────────────────────────────────────────────
        Expanded(
          child: asyncExpenses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load fuel expenses: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (response) {
              final expenses = response.items;
              if (expenses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 56,
                        color: crmColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      16.h,
                      Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                        ),
                      ),
                      6.h,
                      Text(
                        'Tap "Add Expense" to log your first entry.',
                        style: TextStyle(
                          fontSize: 12,
                          color: crmColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (isMobile) {
                // ── Mobile: premium expense cards ──────────────────────
                return ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => 10.h,
                  itemBuilder: (context, index) {
                    final exp = expenses[index];
                    final catColor = _categoryColor(exp.category, crmColors);
                    final catIcon = _categoryIcon(exp.category);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: crmColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => openExpenseDialog(exp),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left accent
                              Container(width: 4, color: catColor),
                              // Content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 12, 8, 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Category icon badge
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          catIcon,
                                          color: catColor,
                                          size: 20,
                                        ),
                                      ),
                                      12.w,
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Amount + category
                                            Row(
                                              children: [
                                                Text(
                                                  _formatCurrency(
                                                      exp.totalAmount),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: catColor
                                                        .withValues(alpha: 0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Text(
                                                    _categoryLabel(exp.category)
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: catColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            4.h,
                                            // Date + vehicle
                                            Text(
                                              exp.vehicle != null
                                                  ? '${exp.vehicle!.name} • ${_formatDate(exp.date)}'
                                                  : _formatDate(exp.date),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: crmColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (exp.liters > 0 ||
                                                exp.station.isNotEmpty) ...[
                                              6.h,
                                              Row(
                                                children: [
                                                  if (exp.liters > 0) ...[
                                                    Icon(
                                                        Icons
                                                            .local_gas_station_outlined,
                                                        size: 11,
                                                        color: crmColors
                                                            .textSecondary),
                                                    3.w,
                                                    Text(
                                                      '${exp.liters.toStringAsFixed(1)} L',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: crmColors
                                                              .textSecondary),
                                                    ),
                                                    8.w,
                                                  ],
                                                  if (exp.station
                                                      .isNotEmpty) ...[
                                                    Icon(Icons.store_outlined,
                                                        size: 11,
                                                        color: crmColors
                                                            .textSecondary),
                                                    3.w,
                                                    Expanded(
                                                      child: Text(
                                                        exp.station,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: crmColors
                                                                .textSecondary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                            6.h,
                                            // Payment mode tag
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: crmColors.textSecondary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                exp.paymentMode.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      crmColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Menu
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert,
                                            size: 18,
                                            color: crmColors.textSecondary),
                                        onSelected: (val) async {
                                          if (val == 'edit') {
                                            openExpenseDialog(exp);
                                          } else if (val == 'delete') {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                    'Delete Expense'),
                                                content: const Text(
                                                    'Delete this expense?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    style:
                                                        TextButton.styleFrom(
                                                      foregroundColor:
                                                          crmColors.destructive,
                                                    ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await ref
                                                  .read(
                                                      fuelExpenseServiceProvider)
                                                  .deleteFuelExpense(exp.id);
                                              ref.invalidate(
                                                  fuelExpensesProvider);
                                              ref.invalidate(
                                                  paginatedFuelExpensesProvider);
                                            }
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [
                                              Icon(Icons.edit, size: 16),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(children: [
                                              Icon(Icons.delete,
                                                  size: 16,
                                                  color: crmColors.destructive),
                                              const SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: crmColors
                                                          .destructive)),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }

              // ── Desktop: Card with ListView ──────────────────────────
              return Card(
                child: ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: crmColors.border),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return ListTile(
                      title: Text(
                        expense.vehicle != null
                            ? '${expense.vehicle!.name} • ${_formatCurrency(expense.totalAmount)}'
                            : _formatCurrency(expense.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(() {
                        final details = <String>[
                          _categoryLabel(expense.category),
                          _formatDate(expense.date),
                          if (expense.liters > 0)
                            '${expense.liters.toStringAsFixed(2)} L',
                          if (expense.odometerKm > 0)
                            '${expense.odometerKm.toStringAsFixed(0)} KM',
                          if (expense.station.isNotEmpty) expense.station,
                        ];
                        return details.join(' • ');
                      }()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: crmColors.textSecondary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              expense.paymentMode.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: crmColors.textSecondary,
                              ),
                            ),
                          ),
                          8.w,
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                openExpenseDialog(expense);
                              } else if (val == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Expense'),
                                    content: const Text(
                                        'Are you sure you want to delete this expense?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                crmColors.destructive),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(fuelExpenseServiceProvider)
                                      .deleteFuelExpense(expense.id);
                                  ref.invalidate(fuelExpensesProvider);
                                  ref.invalidate(paginatedFuelExpensesProvider);
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        size: 16,
                                        color: crmColors.destructive),
                                    const SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(
                                            color: crmColors.destructive)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        20.h,
        asyncExpenses.maybeWhen(
          data: (response) => PaginatedFooter(
            page: response.page,
            limit: response.limit,
            totalPages: response.totalPages,
            totalItems: response.totalItems,
            currentItemCount: response.items.length,
            onPrevious: response.page > 1
                ? () => pageState.value -= 1
                : null,
            onNext: response.page < response.totalPages
                ? () => pageState.value += 1
                : null,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
