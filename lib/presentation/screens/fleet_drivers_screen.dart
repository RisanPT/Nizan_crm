import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/service_region.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/region_service.dart';
import '../../services/user_service.dart';
import '../common_widgets/paginated_footer.dart';
import 'fleet/fleet_mobile_ui.dart';
import 'staff_details_screen.dart';

class FleetDriversScreen extends HookConsumerWidget {
  const FleetDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncRegions = ref.watch(regionsProvider);

    Future<void> openDriverDialog([Employee? driver]) async {
      final messenger = ScaffoldMessenger.of(context);
      final rootContext = context;
      final nameCtrl = TextEditingController(text: driver?.name ?? '');
      final emailCtrl = TextEditingController(text: driver?.email ?? '');
      final roleCtrl = TextEditingController(
        text: driver?.specialization.isNotEmpty == true
            ? driver!.specialization
            : 'Fleet Driver',
      );
      final phoneCtrl = TextEditingController(text: driver?.phone ?? '');
      final passwordCtrl = TextEditingController();
      // New drivers get a login by default; editing an existing one doesn't
      // create a second account unless explicitly turned on.
      var createLogin = driver == null;
      var savingDriver = false;
      var type = driver?.type ?? 'in-house';
      if (!['in-house', 'outsource'].contains(type)) {
        type = 'in-house';
      }
      var status = driver?.status ?? 'active';
      if (!['active', 'inactive'].contains(status)) {
        status = 'active';
      }
      var regionId = driver?.regionId ?? '';

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final regions = asyncRegions.value ?? const <ServiceRegion>[];
          final regionOptions = [
            const DropdownMenuItem(value: '', child: Text('Any / All')),
            ...regions.map(
              (region) => DropdownMenuItem(
                value: region.id,
                child: Text(region.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ];
          final hasSelectedRegion = regionOptions.any(
            (item) => item.value == regionId,
          );
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(driver == null ? 'Add Driver' : 'Edit Driver'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      16.h,
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: createLogin
                              ? 'Login email (required)'
                              : 'Email (Optional)',
                          prefixIcon: const Icon(Icons.email_outlined),
                          helperText: createLogin
                              ? 'The driver signs in with this email'
                              : null,
                        ),
                      ),
                      16.h,
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: type,
                              items: const [
                                DropdownMenuItem(
                                  value: 'in-house',
                                  child: Text('In-House'),
                                ),
                                DropdownMenuItem(
                                  value: 'outsource',
                                  child: Text('Outsource'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => type = value);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Type',
                              ),
                            ),
                          ),
                          16.w,
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: hasSelectedRegion ? regionId : '',
                              items: regionOptions,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => regionId = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Region',
                              ),
                            ),
                          ),
                        ],
                      ),
                      16.h,
                      TextField(
                        controller: roleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Role / Notes',
                        ),
                      ),
                      16.h,
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: status,
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => status = value);
                        },
                        decoration: const InputDecoration(labelText: 'Status'),
                      ),
                      16.h,
                      // ── App login access ─────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: crmColors.primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: crmColors.border),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: createLogin,
                              onChanged: savingDriver
                                  ? null
                                  : (v) => setState(() => createLogin = v),
                              title: const Text('Allow app login',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  'Creates a driver account so they can sign in',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: crmColors.textSecondary)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            if (createLogin)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: TextField(
                                  controller: passwordCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Login password (min 6 chars)',
                                    prefixIcon: Icon(Icons.lock_outline),
                                    helperText:
                                        'Driver signs in with the email above',
                                  ),
                                ),
                              ),
                          ],
                        ),
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
                  onPressed: savingDriver
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          final password = passwordCtrl.text.trim();
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text('Driver name is required.')),
                            );
                            return;
                          }
                          if (createLogin && email.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Add a login email — the driver signs in with it.')),
                            );
                            return;
                          }
                          if (createLogin && password.length < 6) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Enter a login password of at least 6 characters.')),
                            );
                            return;
                          }
                          setState(() => savingDriver = true);
                          try {
                            final emp = await ref
                                .read(employeeServiceProvider)
                                .saveEmployee(
                                  id: driver?.id,
                                  name: nameCtrl.text.trim(),
                                  email: email,
                                  type: type,
                                  artistRole: 'driver',
                                  specialization: roleCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  status: status,
                                  regionId: regionId,
                                  category: 'administrative',
                                );

                            String? loginError;
                            if (createLogin) {
                              try {
                                await ref
                                    .read(userServiceProvider)
                                    .grantDriverLogin(
                                      name: nameCtrl.text.trim(),
                                      email: email,
                                      password: password,
                                      employeeId: emp.id,
                                    );
                              } catch (e) {
                                loginError = '$e';
                              }
                            }

                            ref.invalidate(employeesProvider);
                            ref.invalidate(paginatedEmployeesProvider);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (loginError != null && rootContext.mounted) {
                              // Blocking dialog so the exact reason can't be missed.
                              showDialog(
                                context: rootContext,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Login not created'),
                                  content: Text(
                                      'The driver profile was saved, but the login could not be created.\n\nReason:\n$loginError'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK')),
                                  ],
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(createLogin
                                      ? 'Driver added with login access.'
                                      : 'Driver saved.'),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => savingDriver = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Failed to save: $e')),
                              );
                            }
                          }
                        },
                  child: savingDriver
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
      );
    }

    // ── Mobile: title header + KPI strip + card list ──────────────────────
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: asyncEmployees.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Failed to load drivers: $error',
              style: TextStyle(color: crmColors.textSecondary),
            ),
          ),
          data: (employees) {
            final drivers = employees
                .where((e) => e.artistRole == 'driver')
                .toList();
            final active = drivers.where((e) => e.status == 'active').length;
            final inHouse = drivers.where((e) => e.type == 'in-house').length;
            final outsource =
                drivers.where((e) => e.type == 'outsource').length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FleetMobileHeader(
                  title: 'Fleet Drivers',
                  actionLabel: 'Add',
                  onAction: () => openDriverDialog(),
                  stats: [
                    FleetStat(
                        value: '${drivers.length}',
                        label: 'Total',
                        color: crmColors.primary),
                    FleetStat(
                        value: '$active',
                        label: 'Active',
                        color: crmColors.success),
                    FleetStat(
                        value: '$inHouse',
                        label: 'In-House',
                        color: crmColors.accent),
                    FleetStat(
                        value: '$outsource',
                        label: 'Outsource',
                        color: crmColors.textSecondary),
                  ],
                ),
                16.h,
                Expanded(
                  child: drivers.isEmpty
                      ? const FleetEmptyState(
                          icon: Icons.drive_eta_outlined,
                          title: 'No drivers yet',
                          subtitle: 'Tap "Add" to register your first driver.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: drivers.length,
                          separatorBuilder: (_, _) => 12.h,
                          itemBuilder: (context, index) => _buildDriverCard(
                            context,
                            ref,
                            drivers[index],
                            onEdit: () => openDriverDialog(drivers[index]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet Drivers',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage driver records used across bookings and fleet vehicles.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // OutlinedButton(
                  //   onPressed: () => context.go('/staff'),
                  //   child: const Text('Open Staff Management'),
                  // ),
                  12.w,
                  ElevatedButton.icon(
                    onPressed: () => openDriverDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Driver'),
                  ),
                ],
              ),
            ],
          ),
          24.h,
        ],
        if (isMobile) ...[
          // Mobile inline header with count + action
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                asyncEmployees.maybeWhen(
                  data: (employees) {
                    final count = employees
                        .where((e) => e.artistRole == 'driver')
                        .length;
                    return Text(
                      '$count driver${count == 1 ? '' : 's'}',
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
                  onPressed: () => openDriverDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Driver',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: asyncEmployees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load drivers: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (employees) {
              final allDrivers = employees
                  .where((employee) => employee.artistRole == 'driver')
                  .toList();
              final totalPages = allDrivers.isEmpty
                  ? 1
                  : (allDrivers.length / pageSize).ceil();
              final currentPage = pageState.value.clamp(1, totalPages);
              if (currentPage != pageState.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  pageState.value = currentPage;
                });
              }
              final startIndex = (currentPage - 1) * pageSize;
              final endIndex = (startIndex + pageSize).clamp(
                0,
                allDrivers.length,
              );
              final drivers = allDrivers.sublist(startIndex, endIndex);

              if (drivers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.drive_eta_outlined,
                        size: 56,
                        color: crmColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      16.h,
                      Text(
                        'No drivers yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                        ),
                      ),
                      6.h,
                      Text(
                        'Tap "Add Driver" to get started.',
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
                return ListView.separated(
                  itemCount: drivers.length,
                  separatorBuilder: (_, _) => 10.h,
                  itemBuilder: (context, index) {
                    return _buildDriverCard(
                      context,
                      ref,
                      drivers[index],
                      onEdit: () => openDriverDialog(drivers[index]),
                    );
                  },
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 190,
                ),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  return _buildDriverCard(
                    context,
                    ref,
                    drivers[index],
                    onEdit: () => openDriverDialog(drivers[index]),
                  );
                },
              );
            },
          ),
        ),
        20.h,
        asyncEmployees.maybeWhen(
          data: (employees) {
            final totalDrivers = employees
                .where((employee) => employee.artistRole == 'driver')
                .length;
            final totalPages = totalDrivers == 0
                ? 1
                : (totalDrivers / pageSize).ceil();
            final currentPage = pageState.value.clamp(1, totalPages);
            final currentItemCount = totalDrivers == 0
                ? 0
                : ((currentPage - 1) * pageSize + pageSize > totalDrivers
                      ? totalDrivers - ((currentPage - 1) * pageSize)
                      : pageSize);

            return PaginatedFooter(
              page: currentPage,
              limit: pageSize,
              totalPages: totalPages,
              totalItems: totalDrivers,
              currentItemCount: currentItemCount,
              onPrevious: pageState.value > 1
                  ? () => pageState.value -= 1
                  : null,
              onNext: pageState.value < totalPages
                  ? () => pageState.value += 1
                  : null,
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDriverCard(
    BuildContext context,
    WidgetRef ref,
    Employee employee, {
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isActive = employee.status == 'active';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StaffDetailsScreen(employee: employee),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    backgroundImage: employee.profileImage.isNotEmpty
                        ? NetworkImage(employee.profileImage)
                        : null,
                    child: employee.profileImage.isEmpty
                        ? Text(
                            employee.name.isNotEmpty
                                ? employee.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        4.h,
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: crmColors.warning.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Driver',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: crmColors.warning,
                                ),
                              ),
                            ),
                            if (employee.type == 'in-house') ...[
                              8.w,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: crmColors.accent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'In-House',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: crmColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Driver'),
                            content: Text(
                              'Are you sure you want to delete ${employee.name}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: crmColors.destructive,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(employeeServiceProvider)
                              .deleteEmployee(employee.id);
                          ref.invalidate(employeesProvider);
                          ref.invalidate(paginatedEmployeesProvider);
                        }
                      }
                    },
                    itemBuilder: (context) => [
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
                            Icon(
                              Icons.delete,
                              size: 16,
                              color: crmColors.destructive,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: crmColors.destructive),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              12.h,
              if (employee.regionName.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: crmColors.textSecondary,
                    ),
                    6.w,
                    Expanded(
                      child: Text(
                        employee.regionName,
                        style: TextStyle(
                          color: crmColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                6.h,
              ],
              if (employee.phone.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: crmColors.textSecondary,
                    ),
                    6.w,
                    Text(
                      employee.phone,
                      style: TextStyle(
                        color: crmColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                6.h,
              ],
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: crmColors.textSecondary,
                  ),
                  6.w,
                  Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? crmColors.success
                          : crmColors.destructive,
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
}
