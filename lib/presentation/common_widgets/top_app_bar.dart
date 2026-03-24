import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class TopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;

  const TopAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final auth = ref.read(authControllerProvider);

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final userName = auth.session?.name ?? 'Jessica Davis';
        final userRole = auth.session?.role ?? 'Manager';
        final trimmedName = userName.trim();
        final userInitial = trimmedName.isEmpty ? 'J' : trimmedName.substring(0, 1);

        // If mobile, we use standard AppBar so `Scaffold` provides the drawer hamburger icon automatically
        if (isMobile) {
          return AppBar(
            title: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: crmColors.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              Padding(
                padding: 8.px,
                child: CircleAvatar(
                  radius: 16,
                  child: Text(userInitial.toUpperCase()),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await ref.read(authControllerProvider).logout();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
              ),
            ],
          );
        }

        // For Tablet/Desktop:
        return Container(
          height: 70,
          padding: 16.px,
          decoration: BoxDecoration(
            color: crmColors.surface,
            border: Border(bottom: BorderSide(color: crmColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: crmColors.input,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              16.w,
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: crmColors.destructive,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              8.w,
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () {},
              ),
              if (!ResponsiveBuilder.isMobile(context)) ...[
                16.w,
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
              16.w,
              PopupMenuButton<String>(
                tooltip: 'Account',
                onSelected: (value) async {
                  if (value == 'logout') {
                    await ref.read(authControllerProvider).logout();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: crmColors.secondary,
                      child: Text(
                        userInitial.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: crmColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    12.w,
                    if (ResponsiveBuilder.isDesktop(context))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            userName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            userRole,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: crmColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
