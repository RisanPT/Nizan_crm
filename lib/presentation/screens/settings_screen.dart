import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/crm_user.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/user_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final asyncUsers = ref.watch(crmUsersProvider);
    final auth = ref.read(authControllerProvider);
    final isMobile = ResponsiveBuilder.isMobile(context);

    Future<void> openUserDialog([CrmUser? user]) async {
      final nameCtrl = TextEditingController(text: user?.name ?? '');
      final emailCtrl = TextEditingController(text: user?.email ?? '');
      final passwordCtrl = TextEditingController();
      var role = user?.role ?? 'manager';
      var active = user?.active ?? true;

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(user == null ? 'Add CRM User' : 'Edit CRM User'),
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
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        16.h,
                        TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: user == null
                                ? 'Password'
                                : 'New Password (Optional)',
                          ),
                        ),
                        16.h,
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text('Manager'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => role = value);
                            }
                          },
                        ),
                        16.h,
                        SwitchListTile(
                          value: active,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active Access'),
                          subtitle: const Text(
                            'Inactive users cannot log in to the CRM.',
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
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                      if (name.isEmpty || email.isEmpty) {
                        _showMessage(context, 'Name and email are required');
                        return;
                      }
                      if (!emailRegex.hasMatch(email)) {
                        _showMessage(context, 'Enter a valid email address');
                        return;
                      }
                      if (user == null && password.isEmpty) {
                        _showMessage(context, 'Password is required for new users');
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
                          );
                        } else {
                          await service.updateUser(
                            id: user.id,
                            name: name,
                            email: email,
                            role: role,
                            active: active,
                            password: password.isEmpty ? null : password,
                          );
                        }

                        ref.invalidate(crmUsersProvider);
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        _showMessage(
                          dialogContext,
                          error.toString().replaceFirst('Exception: ', ''),
                        );
                      }
                    },
                    child: const Text('Save'),
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
              data: (users) {
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No CRM users found yet.'),
                  );
                }

                if (isMobile) {
                  return Column(
                    children: users
                        .map((user) => _MobileUserCard(
                              user: user,
                              currentUserId: auth.session?.userId ?? '',
                              onEdit: () => openUserDialog(user),
                            ))
                        .toList(),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                4.h,
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.crmColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(user.role)),
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
