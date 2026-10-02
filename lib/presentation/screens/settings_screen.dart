import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/auth/access_control.dart';
import '../../services/role_service.dart';
import '../../core/models/crm_user.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/employee_service.dart';
import '../../core/models/employee.dart';
import '../../core/widgets/employee_picker.dart';
import '../../services/user_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/region_service.dart';
import '../../services/district_service.dart';
import '../../services/pincode_service.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'settings/roles_permissions_screen.dart';
import '../../features/org/presentation/screens/departments_screen.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final pageState = useState(1);
    const pageSize = 20;
    // Full list (small) so search, role filter and the summary counts work
    // client-side; paged locally below.
    final asyncUsers = ref.watch(crmUsersProvider);
    final searchState = useState('');
    final roleFilter = useState<String?>(null);
    final auth = ref.read(authControllerProvider);
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final isMobile = ResponsiveBuilder.isMobile(context);
    // ✅ Watched at build level — valid Riverpod usage
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncPincodes = ref.watch(pincodesProvider);

    Future<void> openUserDialog([CrmUser? user]) async {
      final nameCtrl = TextEditingController(text: user?.name ?? '');
      final emailCtrl = TextEditingController(text: user?.email ?? '');
      final passwordCtrl = TextEditingController();
      var role = user?.role ?? 'manager';
      var active = user?.active ?? true;
      var inventoryAccess = user?.inventoryAccess ?? false;
      var inventoryManage = user?.inventoryManage ?? false;
      var artistHead = user?.artistHead ?? false;
      var countInSales = user?.countInSalesTotals ?? true;
      var isDepartmentHead = user?.isDepartmentHead ?? false;
      var selEmployeeId = user?.employeeId ?? '';
      var selZoneId = user?.zoneId ?? '';
      var selStateId = user?.stateId ?? '';
      var selRegionId = user?.regionId ?? '';
      var selDistrictId = user?.districtId ?? '';
      var selPincodeId = user?.pincodeId ?? '';
      var saving = false;

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              // employees already fetched at build level — safe to use here
              final employees = (asyncEmployees.value ?? [])
                  .where((e) => e.isActive || e.id == selEmployeeId)
                  .toList();

              final zones = asyncZones.value ?? [];
              final allStates = asyncStates.value ?? [];
              final allRegions = asyncRegions.value ?? [];
              final allDistricts = asyncDistricts.value ?? [];
              final allPincodes = asyncPincodes.value ?? [];

              final filteredStates = selZoneId.isEmpty
                  ? allStates
                  : allStates.where((s) => s.zoneId == selZoneId).toList();
              final filteredRegions = selStateId.isEmpty
                  ? allRegions
                  : allRegions.where((r) => r.stateId == selStateId).toList();
              final filteredDistricts = selRegionId.isEmpty
                  ? allDistricts
                  : allDistricts
                        .where((d) => d.regionId == selRegionId)
                        .toList();
              final filteredPincodes = selDistrictId.isEmpty
                  ? allPincodes
                  : allPincodes
                        .where((p) => p.districtId == selDistrictId)
                        .toList();

              // Two fields side by side on wide dialogs, stacked on phones.
              Widget pair(Widget a, Widget b) => isMobile
                  ? Column(children: [a, 12.h, b])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: a),
                        12.w,
                        Expanded(child: b),
                      ],
                    );

              Widget geoDropdown<T>({
                required String label,
                required String value,
                required String anyLabel,
                required List<T> items,
                required String Function(T) idOf,
                required String Function(T) nameOf,
                required ValueChanged<String> onChanged,
              }) => SizedBox(
                width: isMobile ? double.infinity : 186,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(labelText: label, isDense: true),
                  initialValue: value.isEmpty ? '' : value,
                  items: [
                    DropdownMenuItem(value: '', child: Text(anyLabel)),
                    for (final it in items)
                      DropdownMenuItem(
                        value: idOf(it),
                        child: Text(
                          nameOf(it),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => onChanged(v ?? '')),
                ),
              );

              return AlertDialog(
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 40,
                  vertical: 24,
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: crmColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        user == null
                            ? Icons.person_add_alt_1
                            : Icons.manage_accounts_outlined,
                        size: 18,
                        color: crmColors.primary,
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: Text(
                        user == null ? 'Add user' : 'Edit user · ${user.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Account ─────────────────────────────────────────
                        const _FormSection('Account'),
                        pair(
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full name *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (login) *',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                        12.h,
                        TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: user == null
                                ? 'Password *'
                                : 'New password (leave blank to keep)',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),

                        // ── Role and team ───────────────────────────────────
                        // Roles come from Settings → Roles and permissions;
                        // department heads only see the roles they may create.
                        const _FormSection('Role and team'),
                        pair(
                          Consumer(
                            builder: (context, ref, _) {
                              final rolesAsync = ref.watch(rolesProvider);
                              final allRoles = rolesAsync.value ?? const [];
                              final creatableKeys = access.creatableRoles;
                              final roles = creatableKeys.isEmpty
                                  ? allRoles
                                  : allRoles
                                        .where(
                                          (r) => creatableKeys.contains(r.key),
                                        )
                                        .toList();
                              final values = roles.map((r) => r.key).toSet();
                              return DropdownButtonFormField<String>(
                                initialValue: values.contains(role)
                                    ? role
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Role *',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  helperText: rolesAsync.isLoading
                                      ? 'Loading roles…'
                                      : '${roles.length} roles available',
                                ),
                                items: [
                                  for (final r in roles)
                                    DropdownMenuItem(
                                      value: r.key,
                                      child: _RoleItem(
                                        label: r.label,
                                        sub: r.permissions.isEmpty
                                            ? 'No features yet'
                                            : '${r.permissions.length} features',
                                        color: _roleColor(r.key),
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => role = value);
                                  }
                                },
                              );
                            },
                          ),
                          asyncEmployees.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: LinearProgressIndicator(),
                                )
                              : asyncEmployees.hasError
                              ? Text(
                                  friendlyErrorMessage(
                                    asyncEmployees.error,
                                    fallback: 'Could not load employees.',
                                  ),
                                  style: TextStyle(
                                    color: crmColors.destructive,
                                  ),
                                )
                              // Searchable + filterable picker.
                              : EmployeePickerField(
                                  employees: employees,
                                  selectedId: selEmployeeId.isEmpty
                                      ? null
                                      : selEmployeeId,
                                  label: role == 'artist'
                                      ? 'Employee profile *'
                                      : 'Employee profile (optional)',
                                  icon: Icons.link_outlined,
                                  allowUnassign: true,
                                  onChanged: (e) => setState(
                                    () => selEmployeeId = e?.id ?? '',
                                  ),
                                ),
                        ),

                        // ── Extra access ────────────────────────────────────
                        const _FormSection(
                          'Extra access',
                          hint: 'hover an option for details',
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _AccessToggle(
                              icon: Icons.verified_user_outlined,
                              title: 'Active (can log in)',
                              help: 'Inactive users cannot log in.',
                              value: active,
                              onChanged: (v) => setState(() => active = v),
                            ),
                            _AccessToggle(
                              icon: Icons.point_of_sale_outlined,
                              title: 'Count in sales totals',
                              help:
                                  'Turn off to leave every booking this user enters out of sales totals '
                                  '(dashboards, sales reports, Sales & Invoices). Bookings, invoices, '
                                  'accounts and GST stay as they are.',
                              value: countInSales,
                              warnWhenOff: true,
                              onChanged: (v) =>
                                  setState(() => countInSales = v),
                            ),
                            if (role != 'artist')
                              _AccessToggle(
                                icon: Icons.manage_accounts_outlined,
                                title: 'Department head',
                                help:
                                    'Allows this user to add and manage staff in their own department.',
                                value: isDepartmentHead,
                                onChanged: (v) =>
                                    setState(() => isDepartmentHead = v),
                              ),
                            if (role == 'artist') ...[
                              _AccessToggle(
                                icon: Icons.inventory_2_outlined,
                                title: 'Inventory access',
                                help:
                                    'Let this artist manage and upload their own inventory.',
                                value: inventoryAccess,
                                onChanged: (v) =>
                                    setState(() => inventoryAccess = v),
                              ),
                              _AccessToggle(
                                icon: Icons.swap_horiz_rounded,
                                title: 'Also inventory manager',
                                help:
                                    'Adds the full studio inventory-manager workspace (stock, purchases, '
                                    'vendors, all kits) with a workspace switcher.',
                                value: inventoryManage,
                                onChanged: (v) => setState(() {
                                  inventoryManage = v;
                                  // Managing implies access — keep consistent.
                                  if (v) inventoryAccess = true;
                                }),
                              ),
                              _AccessToggle(
                                icon: Icons.insights_outlined,
                                title: 'Also artist head',
                                help:
                                    'Keeps their artist role and adds the org-wide Artist Head dashboard.',
                                value: artistHead,
                                onChanged: (v) =>
                                    setState(() => artistHead = v),
                              ),
                            ],
                          ],
                        ),

                        // ── Location limits ─────────────────────────────────
                        const _FormSection(
                          'Location limits',
                          hint: 'optional — leave as "Any" for no limit',
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 12,
                          children: [
                            geoDropdown(
                              label: 'Zone',
                              value: selZoneId,
                              anyLabel: 'Any zone',
                              items: zones,
                              idOf: (z) => z.id,
                              nameOf: (z) => z.name,
                              onChanged: (v) {
                                selZoneId = v;
                                selStateId = '';
                                selRegionId = '';
                                selDistrictId = '';
                                selPincodeId = '';
                              },
                            ),
                            geoDropdown(
                              label: 'State',
                              value: selStateId,
                              anyLabel: 'Any state',
                              items: filteredStates,
                              idOf: (s) => s.id,
                              nameOf: (s) => s.name,
                              onChanged: (v) {
                                selStateId = v;
                                selRegionId = '';
                                selDistrictId = '';
                                selPincodeId = '';
                              },
                            ),
                            geoDropdown(
                              label: 'Region',
                              value: selRegionId,
                              anyLabel: 'Any region',
                              items: filteredRegions,
                              idOf: (r) => r.id,
                              nameOf: (r) => r.name,
                              onChanged: (v) {
                                selRegionId = v;
                                selDistrictId = '';
                                selPincodeId = '';
                              },
                            ),
                            geoDropdown(
                              label: 'District',
                              value: selDistrictId,
                              anyLabel: 'Any district',
                              items: filteredDistricts,
                              idOf: (d) => d.id,
                              nameOf: (d) => d.name,
                              onChanged: (v) {
                                selDistrictId = v;
                                selPincodeId = '';
                              },
                            ),
                            geoDropdown(
                              label: 'Pincode',
                              value: selPincodeId,
                              anyLabel: 'Any pincode',
                              items: filteredPincodes,
                              idOf: (p) => p.id,
                              nameOf: (p) => p.code,
                              onChanged: (v) => selPincodeId = v,
                            ),
                          ],
                        ),
                        8.h,
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
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final email = emailCtrl.text.trim();
                            final password = passwordCtrl.text.trim();
                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );

                            if (name.isEmpty || email.isEmpty) {
                              _showMessage(
                                context,
                                'Name and email are required',
                              );
                              return;
                            }
                            if (!emailRegex.hasMatch(email)) {
                              _showMessage(
                                context,
                                'Enter a valid email address',
                              );
                              return;
                            }
                            if (user == null && password.isEmpty) {
                              _showMessage(
                                context,
                                'Password is required for new users',
                              );
                              return;
                            }
                            if (role == 'artist' && selEmployeeId.isEmpty) {
                              _showMessage(
                                context,
                                'Please link this user to an Employee profile',
                              );
                              return;
                            }

                            setState(() => saving = true);
                            try {
                              final service = ref.read(userServiceProvider);
                              if (user == null) {
                                await service.createUser(
                                  name: name,
                                  email: email,
                                  password: password,
                                  role: role,
                                  active: active,
                                  inventoryAccess: inventoryAccess,
                                  inventoryManage: inventoryManage,
                                  isDepartmentHead: isDepartmentHead,
                                  artistHead: artistHead,
                                  countInSalesTotals: countInSales,
                                  employeeId: selEmployeeId.isEmpty
                                      ? null
                                      : selEmployeeId,
                                  zoneId: selZoneId.isEmpty ? null : selZoneId,
                                  stateId: selStateId.isEmpty
                                      ? null
                                      : selStateId,
                                  regionId: selRegionId.isEmpty
                                      ? null
                                      : selRegionId,
                                  districtId: selDistrictId.isEmpty
                                      ? null
                                      : selDistrictId,
                                  pincodeId: selPincodeId.isEmpty
                                      ? null
                                      : selPincodeId,
                                );
                              } else {
                                await service.updateUser(
                                  id: user.id,
                                  name: name,
                                  email: email,
                                  role: role,
                                  active: active,
                                  inventoryAccess: inventoryAccess,
                                  inventoryManage: inventoryManage,
                                  isDepartmentHead: isDepartmentHead,
                                  artistHead: artistHead,
                                  countInSalesTotals: countInSales,
                                  password: password.isEmpty ? null : password,
                                  employeeId: selEmployeeId.isEmpty
                                      ? null
                                      : selEmployeeId,
                                  zoneId: selZoneId.isEmpty ? null : selZoneId,
                                  stateId: selStateId.isEmpty
                                      ? null
                                      : selStateId,
                                  regionId: selRegionId.isEmpty
                                      ? null
                                      : selRegionId,
                                  districtId: selDistrictId.isEmpty
                                      ? null
                                      : selDistrictId,
                                  pincodeId: selPincodeId.isEmpty
                                      ? null
                                      : selPincodeId,
                                );
                              }

                              ref.refreshData.crmUsers();
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              setState(() => saving = false);
                              showErrorSnackBar(dialogContext, error);
                            }
                          },
                    child: Text(user == null ? 'Create user' : 'Save changes'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Future<void> deleteUser(CrmUser user) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete User'),
          content: Text(
            'Are you sure you want to delete ${user.name}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: crmColors.destructive,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(userServiceProvider).deleteUser(user.id);
          ref.refreshData.crmUsers();
          if (context.mounted) {
            _showMessage(context, 'User deleted successfully');
          }
        } catch (e) {
          if (context.mounted) showErrorSnackBar(context, e);
        }
      }
    }

    // ── Users tab ──────────────────────────────────────────────────────────
    String accessSummary(CrmUser u) {
      String? nameOf<T>(
        List<T> items,
        String id,
        String Function(T) n,
        String Function(T) idOf,
      ) {
        if (id.isEmpty) return null;
        for (final it in items) {
          if (idOf(it) == id) return n(it);
        }
        return null;
      }

      final limit =
          nameOf(
            asyncPincodes.value ?? const [],
            u.pincodeId,
            (p) => 'PIN ${p.code}',
            (p) => p.id,
          ) ??
          nameOf(
            asyncDistricts.value ?? const [],
            u.districtId,
            (d) => d.name,
            (d) => d.id,
          ) ??
          nameOf(
            asyncRegions.value ?? const [],
            u.regionId,
            (r) => r.name,
            (r) => r.id,
          ) ??
          nameOf(
            asyncStates.value ?? const [],
            u.stateId,
            (s) => s.name,
            (s) => s.id,
          ) ??
          nameOf(
            asyncZones.value ?? const [],
            u.zoneId,
            (z) => z.name,
            (z) => z.id,
          );
      final extras = [
        if (u.isDepartmentHead) 'Dept head',
        if (u.inventoryManage)
          'Inventory manager'
        else if (u.inventoryAccess)
          'Inventory',
        if (u.artistHead) 'Artist head',
      ];
      return [?limit, ...extras].join(' · ');
    }

    Widget usersTab() {
      return asyncUsers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(crmUsersProvider),
        ),
        data: (all) {
          final q = searchState.value.trim().toLowerCase();
          final roles = <String>{for (final u in all) u.role}.toList()..sort();
          final filtered = all.where((u) {
            if (roleFilter.value != null && u.role != roleFilter.value) {
              return false;
            }
            return q.isEmpty ||
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q);
          }).toList();
          final totalPages = (filtered.length / pageSize).ceil().clamp(
            1,
            1 << 30,
          );
          final page = pageState.value.clamp(1, totalPages);
          final pageItems = filtered
              .skip((page - 1) * pageSize)
              .take(pageSize)
              .toList();

          final activeCount = all.where((u) => u.active).length;
          final excludedCount = all.where((u) => !u.countInSalesTotals).length;

          Widget stat(
            String label,
            int value,
            Color? color,
            IconData icon,
          ) => Container(
            constraints: const BoxConstraints(minWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crmColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (color ?? crmColors.primary).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: color ?? crmColors.primary,
                  ),
                ),
                12.w,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color ?? crmColors.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: crmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          Widget roleChip(String label, String? value) {
            final on = roleFilter.value == value;
            return InkWell(
              onTap: () {
                roleFilter.value = value;
                pageState.value = 1;
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: on
                      ? crmColors.primary.withValues(alpha: 0.10)
                      : crmColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: on ? crmColors.primary : crmColors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? crmColors.primary : crmColors.textPrimary,
                  ),
                ),
              ),
            );
          }

          final toolbar = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 280,
                child: TextField(
                  onChanged: (v) {
                    searchState.value = v;
                    pageState.value = 1;
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search name or email',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              roleChip('All roles', null),
              for (final r in roles) roleChip(_roleLabel(r), r),
            ],
          );

          final list = pageItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      all.isEmpty
                          ? 'No CRM users yet. Add the first one.'
                          : 'No users match your search.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        child: Row(
                          children: const [
                            Expanded(flex: 4, child: _HeaderText('User')),
                            Expanded(flex: 2, child: _HeaderText('Role')),
                            Expanded(flex: 3, child: _HeaderText('Access')),
                            Expanded(flex: 2, child: _HeaderText('Status')),
                            SizedBox(width: 48),
                          ],
                        ),
                      ),
                    for (final u in pageItems)
                      _UserRow(
                        user: u,
                        compact: isMobile,
                        isYou: u.id == session?.userId,
                        access: accessSummary(u),
                        showDelete:
                            session?.role == 'admin' && u.id != session?.userId,
                        onEdit: () => openUserDialog(u),
                        onDelete: () => deleteUser(u),
                      ),
                  ],
                );

          return ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  stat('Users', all.length, null, Icons.people_alt_outlined),
                  stat(
                    'Active',
                    activeCount,
                    crmColors.success,
                    Icons.verified_user_outlined,
                  ),
                  stat(
                    'Inactive',
                    all.length - activeCount,
                    crmColors.textSecondary,
                    Icons.person_off_outlined,
                  ),
                  stat(
                    'Not in sales totals',
                    excludedCount,
                    excludedCount > 0 ? crmColors.warning : null,
                    Icons.money_off_csred_outlined,
                  ),
                ],
              ),
              16.h,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: toolbar),
                  12.w,
                  ElevatedButton.icon(
                    onPressed: () => openUserDialog(),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add user'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: crmColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              12.h,
              Container(
                decoration: BoxDecoration(
                  color: crmColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: crmColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: list,
              ),
              12.h,
              PaginatedFooter(
                page: page,
                limit: pageSize,
                totalPages: totalPages,
                totalItems: filtered.length,
                currentItemCount: pageItems.length,
                onPrevious: page > 1 ? () => pageState.value = page - 1 : null,
                onNext: page < totalPages
                    ? () => pageState.value = page + 1
                    : null,
              ),
            ],
          );
        },
      );
    }

    // ── Page: header + tabs ────────────────────────────────────────────────
    final email = session?.email ?? '';
    final initials = _initials(session?.name ?? email);
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    4.h,
                    Text(
                      'Users, roles and access for Team N ERP',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: crmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 17,
                backgroundColor: crmColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: crmColors.primary,
                  ),
                ),
              ),
              if (!isMobile) ...[
                8.w,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: crmColors.textSecondary,
                    ),
                  ),
                ),
              ],
              8.w,
              OutlinedButton.icon(
                onPressed: () async => auth.logout(),
                icon: const Icon(Icons.logout, size: 16),
                label: Text(isMobile ? 'Log out' : 'Log out of this device'),
              ),
            ],
          ),
          12.h,
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: crmColors.border)),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: crmColors.primary,
              unselectedLabelColor: crmColors.textSecondary,
              indicatorColor: crmColors.primary,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.people_alt_outlined, size: 18),
                  text: 'Users',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.admin_panel_settings_outlined, size: 18),
                  text: 'Roles and permissions',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.apartment_outlined, size: 18),
                  text: 'Departments',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                usersTab(),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: RolesPermissionsScreen(),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: DepartmentsScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w700,
        color: context.crmColors.textSecondary,
      ),
    );
  }
}

/// One user: avatar, name/email, role badge, access summary, status and a ⋮
/// menu (Edit / Delete). `compact` stacks it as a card for phones.
class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.compact,
    required this.isYou,
    required this.access,
    required this.showDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final CrmUser user;
  final bool compact;
  final bool isYou;
  final String access;
  final bool showDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final roleColor = _roleColor(user.role);

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: roleColor.withValues(alpha: 0.14),
      child: Text(
        _initials(user.name),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: roleColor,
        ),
      ),
    );

    final identity = Row(
      children: [
        avatar,
        12.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary,
                      ),
                    ),
                  ),
                  if (user.employeeId.isNotEmpty) ...[
                    6.w,
                    Tooltip(
                      message: 'Linked to an employee profile',
                      child: Icon(
                        Icons.link_rounded,
                        size: 15,
                        color: crm.success,
                      ),
                    ),
                  ],
                  if (isYou) ...[
                    6.w,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'You',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: crm.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                user.email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );

    final accessWidget = !user.countInSalesTotals
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.money_off_csred_outlined,
                size: 15,
                color: crm.warning,
              ),
              4.w,
              Flexible(
                child: Text(
                  access.isEmpty
                      ? 'Not in sales totals'
                      : 'Not in sales totals · $access',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: crm.warning,
                  ),
                ),
              ),
            ],
          )
        : Text(
            access.isEmpty ? 'Full access' : access,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: access.isEmpty ? crm.textSecondary : crm.textPrimary,
            ),
          );

    final menu = PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_vert_rounded, color: crm.textSecondary),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined, size: 20),
            title: Text('Edit user'),
          ),
        ),
        if (showDelete)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                size: 20,
                color: crm.destructive,
              ),
              title: Text(
                'Delete user',
                style: TextStyle(color: crm.destructive),
              ),
            ),
          ),
      ],
    );

    final row = compact
        ? Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    menu,
                  ],
                ),
                8.h,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _RoleBadge(role: user.role),
                    _StatusChip(active: user.active),
                  ],
                ),
                6.h,
                accessWidget,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(flex: 4, child: identity),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RoleBadge(role: user.role),
                  ),
                ),
                Expanded(flex: 3, child: accessWidget),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(active: user.active),
                  ),
                ),
                SizedBox(width: 48, child: menu),
              ],
            ),
          );

    return InkWell(
      onTap: onEdit,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: crm.border)),
        ),
        child: row,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = active ? crm.success : crm.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.pause_circle_outline,
          size: 15,
          color: color,
        ),
        4.w,
        Text(
          active ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// One option in the "Extra access" grid of the user form.
class _AccessToggle extends StatelessWidget {
  const _AccessToggle({
    required this.icon,
    required this.title,
    required this.help,
    required this.value,
    required this.onChanged,
    this.warnWhenOff = false,
  });

  final IconData icon;
  final String title;
  final String help;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Highlight amber when OFF (e.g. "Count in sales totals" switched off).
  final bool warnWhenOff;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final warn = warnWhenOff && !value;
    final tint = warn ? crm.warning : (value ? crm.primary : crm.textSecondary);
    return Tooltip(
      message: help,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 268,
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            color: warn
                ? crm.warning.withValues(alpha: 0.08)
                : (value ? crm.primary.withValues(alpha: 0.05) : null),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: warn
                  ? crm.warning.withValues(alpha: 0.6)
                  : (value ? crm.primary.withValues(alpha: 0.35) : crm.border),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tint),
              10.w,
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: warn ? crm.warning : crm.textPrimary,
                  ),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small grey heading for a section of the user form.
class _FormSection extends StatelessWidget {
  const _FormSection(this.title, {this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: crm.textSecondary,
            ),
          ),
          if (hint != null) ...[
            6.w,
            Flexible(
              child: Text(
                '· $hint',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
              ),
            ),
          ],
          8.w,
          Expanded(child: Divider(color: crm.border, height: 1)),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .split(RegExp(r'[\s@._-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String _roleLabel(String key) {
  const known = {
    'admin': 'Admin',
    'manager': 'Manager',
    'crm': 'CRM',
    'sales': 'Sales',
    'sales_manager': 'Sales Manager',
    'artist': 'Artist',
    'accounts': 'Accounts',
    'fleet_manager': 'Fleet Manager',
    'inventory_manager': 'Inventory',
    'marketing_admin': 'Marketing',
    'driver': 'Driver',
  };
  return known[key] ??
      key
          .split('_')
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
}

/// Single-line dropdown entry used in the Role dropdown.
/// Must stay one line — DropdownMenuItem constrains height to 24 px.
class _RoleItem extends StatelessWidget {
  const _RoleItem({
    required this.label,
    required this.sub,
    required this.color,
  });

  final String label;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: '  $sub',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Compact role chip shown in the users table.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  static const _meta = {
    'admin': ('Admin', Colors.deepPurple),
    'manager': ('Manager', Colors.indigo),
    'crm': ('CRM', Colors.blue),
    'sales': ('Sales', Colors.teal),
    'artist': ('Artist', Colors.orange),
    'accounts': ('Accounts', Colors.green),
    'fleet_manager': ('Fleet Manager', Colors.blueGrey),
  };

  @override
  Widget build(BuildContext context) {
    final entry = _meta[role];
    final label = entry?.$1 ?? role;
    final color = entry?.$2 ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Stable dot colour per role — known keys keep their familiar colour and
/// custom roles get a deterministic one derived from the key.
Color _roleColor(String key) {
  const known = {
    'admin': Colors.deepPurple,
    'manager': Colors.indigo,
    'crm': Colors.blue,
    'sales': Colors.teal,
    'artist': Colors.orange,
    'accounts': Colors.green,
    'fleet_manager': Colors.blueGrey,
    'driver': Colors.brown,
    'inventory_manager': Colors.pink,
    'marketing_admin': Colors.indigo,
  };
  if (known.containsKey(key)) return known[key]!;
  const palette = [
    Colors.cyan,
    Colors.amber,
    Colors.purple,
    Colors.redAccent,
    Colors.lightGreen,
    Colors.deepOrange,
  ];
  return palette[key.hashCode.abs() % palette.length];
}
