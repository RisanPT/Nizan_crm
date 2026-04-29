import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/auth/app_role.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/crm_user.dart';
import '../../core/models/list_page_params.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/employee_service.dart';
import '../../services/user_service.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final pageState = useState(1);
    const pageSize = 20;
    final asyncUsers = ref.watch(
      paginatedCrmUsersProvider(
        ListPageParams(page: pageState.value, limit: pageSize),
      ),
    );
    final auth = ref.read(authControllerProvider);
    final isMobile = ResponsiveBuilder.isMobile(context);
    // ✅ Watched at build level — valid Riverpod usage
    final asyncEmployees = ref.watch(employeesProvider);

    Future<void> openUserDialog([CrmUser? user]) async {
      final nameCtrl = TextEditingController(text: user?.name ?? '');
      final emailCtrl = TextEditingController(text: user?.email ?? '');
      final passwordCtrl = TextEditingController();
      var role = user?.role ?? 'manager';
      var active = user?.active ?? true;
      var selEmployeeId = user?.employeeId ?? '';

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              // employees already fetched at build level — safe to use here
              final employees = asyncEmployees.value ?? [];
              final artists = employees
                  .where((e) => e.artistRole != 'driver')
                  .toList();

              return AlertDialog(
                title: Text(user == null ? 'Add System User' : 'Edit System User'),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Basic Info ──────────────────────────────────────
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        16.h,
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (login) *',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        16.h,
                        TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: user == null
                                ? 'Password *'
                                : 'New Password (leave blank to keep)',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        16.h,

                        // ── Role ────────────────────────────────────────────
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(
                            labelText: 'Role *',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: _RoleItem(
                                label: 'Admin',
                                sub: 'Full access to everything',
                                color: Colors.deepPurple,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'manager',
                              child: _RoleItem(
                                label: 'Manager',
                                sub: 'Full access (default)',
                                color: Colors.indigo,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'crm',
                              child: _RoleItem(
                                label: 'CRM Team',
                                sub: 'Clients, Calendar, Booking',
                                color: Colors.blue,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'sales',
                              child: _RoleItem(
                                label: 'Sales',
                                sub: 'Sales & Invoices only',
                                color: Colors.teal,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'artist',
                              child: _RoleItem(
                                label: 'Artist',
                                sub: 'Log own collections & expenses',
                                color: Colors.orange,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'accounts',
                              child: _RoleItem(
                                label: 'Accounts',
                                sub: 'Verify artist finance entries',
                                color: Colors.green,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                role = value;
                                // Clear employee link if switching away from artist
                                if (value != 'artist') selEmployeeId = '';
                              });
                            }
                          },
                        ),

                        // ── Employee link (only for artist role) ────────────
                        if (role == 'artist') ...[
                          16.h,
                          if (asyncEmployees.isLoading)
                            const LinearProgressIndicator()
                          else if (asyncEmployees.hasError)
                            const Text('Could not load artists')
                          else
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Link to Employee Profile *',
                                prefixIcon: Icon(Icons.link_outlined),
                                helperText:
                                    'Their data will be scoped to this employee',
                              ),
                              value: selEmployeeId.isEmpty ? null : selEmployeeId,
                              items: artists
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(e.name),
                                          Text(
                                            e.specialization.isNotEmpty
                                                ? e.specialization
                                                : e.artistRole,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selEmployeeId = v ?? ''),
                            ),
                        ],

                        16.h,
                        // ── Active toggle ───────────────────────────────────
                        SwitchListTile(
                          value: active,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active Access'),
                          subtitle: const Text(
                            'Inactive users cannot log in.',
                          ),
                          onChanged: (value) => setState(() => active = value),
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
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text.trim();
                      final emailRegex =
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                      if (name.isEmpty || email.isEmpty) {
                        _showMessage(context, 'Name and email are required');
                        return;
                      }
                      if (!emailRegex.hasMatch(email)) {
                        _showMessage(context, 'Enter a valid email address');
                        return;
                      }
                      if (user == null && password.isEmpty) {
                        _showMessage(
                            context, 'Password is required for new users');
                        return;
                      }
                      if (role == 'artist' && selEmployeeId.isEmpty) {
                        _showMessage(
                            context,
                            'Please link this user to an Employee profile');
                        return;
                      }

                      try {
                        final service = ref.read(userServiceProvider);
                        if (user == null) {
                          await service.createUser(
                            name: name,
                            email: email,
                            password: password,
                            role: role,
                            active: active,
                            employeeId:
                                role == 'artist' ? selEmployeeId : null,
                          );
                        } else {
                          await service.updateUser(
                            id: user.id,
                            name: name,
                            email: email,
                            role: role,
                            active: active,
                            password: password.isEmpty ? null : password,
                            employeeId:
                                role == 'artist' ? selEmployeeId : null,
                          );
                        }

                        ref.invalidate(crmUsersProvider);
                        ref.invalidate(paginatedCrmUsersProvider);
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        _showMessage(
                          dialogContext,
                          error
                              .toString()
                              .replaceFirst('Exception: ', ''),
                        );
                      }
                    },
                    child: Text(user == null ? 'Create User' : 'Save Changes'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings & Access',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          8.h,
          Text(
            'Manage who can log in to the CRM and sign out from this device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: crmColors.textSecondary,
            ),
          ),
          24.h,
          _SettingsCard(
            title: 'Session',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed in as ${auth.session?.email ?? ''}',
                  style: theme.textTheme.bodyMedium,
                ),
                16.h,
                ElevatedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout From This Device'),
                ),
              ],
            ),
          ),
          24.h,
          _SettingsCard(
            title: 'CRM Users',
            trailing: ElevatedButton.icon(
              onPressed: () => openUserDialog(),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add User'),
            ),
            child: asyncUsers.when(
              data: (response) {
                final users = response.items;
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No CRM users found yet.'),
                  );
                }

                if (isMobile) {
                  return Column(
                    children: [
                      ...users.map((user) => _MobileUserCard(
                            user: user,
                            currentUserId: auth.session?.userId ?? '',
                            onEdit: () => openUserDialog(user),
                          )),
                      16.h,
                      PaginatedFooter(
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
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _HeaderText('User'),
                        ),
                        Expanded(
                          flex: 2,
                          child: _HeaderText('Role'),
                        ),
                        Expanded(
                          flex: 2,
                          child: _HeaderText('Linked Employee'),
                        ),
                        Expanded(
                          flex: 2,
                          child: _HeaderText('Status'),
                        ),
                        Expanded(
                          flex: 2,
                          child: _HeaderText('Actions', alignEnd: true),
                        ),
                      ],
                    ),
                    12.h,
                    const Divider(height: 1),
                    ...users.map(
                      (user) => _DesktopUserRow(
                        user: user,
                        currentUserId: auth.session?.userId ?? '',
                        onEdit: () => openUserDialog(user),
                      ),
                    ),
                    16.h,
                    PaginatedFooter(
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
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Failed to load CRM users: $error',
                  style: TextStyle(color: crmColors.destructive),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) ...[trailing!],
            ],
          ),
          20.h,
          child,
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.alignEnd = false});

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.crmColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DesktopUserRow extends StatelessWidget {
  const _DesktopUserRow({
    required this.user,
    required this.currentUserId,
    required this.onEdit,
  });

  final CrmUser user;
  final String currentUserId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.crmColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: Theme.of(context).textTheme.titleSmall),
                4.h,
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.crmColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _RoleBadge(role: user.role)),
          Expanded(
            flex: 2,
            child: user.employeeId.isNotEmpty
                ? Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: Colors.green),
                      4.w,
                      Flexible(
                        child: Text(
                          'Linked',
                          style: TextStyle(
                              color: Colors.green.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  )
                : Text('—',
                    style: TextStyle(
                        color: context.crmColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: _StatusChip(active: user.active),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (user.id == currentUserId) const Chip(label: Text('You')),
                  OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileUserCard extends StatelessWidget {
  const _MobileUserCard({
    required this.user,
    required this.currentUserId,
    required this.onEdit,
  });

  final CrmUser user;
  final String currentUserId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.name, style: Theme.of(context).textTheme.titleMedium),
          6.h,
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: crmColors.textSecondary,
                ),
          ),
          12.h,
          Row(
            children: [
              Expanded(child: Text('Role: ${user.role}')),
              _StatusChip(active: user.active),
            ],
          ),
          12.h,
          Row(
            children: [
              if (user.id == currentUserId) const Chip(label: Text('You')),
              const Spacer(),
              OutlinedButton(
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final background = active
        ? crmColors.success.withValues(alpha: 0.12)
        : crmColors.destructive.withValues(alpha: 0.12);
    final foreground = active ? crmColors.success : crmColors.destructive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
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
