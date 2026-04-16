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
    final months = const [
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
                width: 460,
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
                        initialValue: hasSelectedVehicle
                            ? selectedVehicleId
                            : null,
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
            if (!isMobile)
              ElevatedButton.icon(
                onPressed: () => openExpenseDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Expense'),
              ),
          ],
        ),
        if (isMobile) ...[
          16.h,
          ElevatedButton.icon(
            onPressed: () => openExpenseDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Expense'),
          ),
        ],
        24.h,
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
                  child: Text(
                    'No expenses found.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                );
              }

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
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            expense.paymentMode.toUpperCase(),
                            style: TextStyle(
                              color: crmColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () => openExpenseDialog(expense),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(fuelExpenseServiceProvider)
                                  .deleteFuelExpense(expense.id);
                              ref.invalidate(fuelExpensesProvider);
                              ref.invalidate(paginatedFuelExpensesProvider);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: crmColors.destructive,
                            ),
                            child: const Text('Delete'),
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
