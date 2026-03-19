import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isTablet = ResponsiveBuilder.isTablet(context);

    // If on tablet, it's collapsed (icons only, 80 width). If desktop, expanded (250 width).
    // On mobile, this will be used inside a Drawer, so it can be 250 width.
    final width = (isTablet && !ResponsiveBuilder.isMobile(context))
        ? 80.0
        : 250.0;

    return Container(
      width: width,
      color: crmColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          24.h,
          _buildLogo(context, isCollapsed: width == 80.0),
          32.h,
          Expanded(
            child: ListView(
              padding: 16.p,
              children: [
                _buildSectionTitle(
                  'CRM',
                  isCollapsed: width == 80.0,
                  theme: theme,
                ),
                8.h,
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  isCollapsed: width == 80.0,
                  isSelected: GoRouterState.of(context).uri.path == '/',
                  onTap: () => context.go('/'),
                ),
                _SidebarItem(
                  icon: Icons.people_outline,
                  title: 'Clients',
                  isCollapsed: width == 80.0,
                  isSelected: GoRouterState.of(
                    context,
                  ).uri.path.startsWith('/client'),
                  onTap: () => context.go('/clients'),
                ),
                _SidebarItem(
                  icon: Icons.calendar_month_outlined,
                  title: 'Appointments',
                  isCollapsed: width == 80.0,
                  isSelected: GoRouterState.of(
                    context,
                  ).uri.path.startsWith('/calendar'),
                  onTap: () => context.go('/calendar'),
                ),
                32.h,
                _buildSectionTitle(
                  'ERP',
                  isCollapsed: width == 80.0,
                  theme: theme,
                ),
                8.h,
                _SidebarItem(
                  icon: Icons.design_services_outlined,
                  title: 'Services',
                  isCollapsed: width == 80.0,
                  isSelected: GoRouterState.of(
                    context,
                  ).uri.path.startsWith('/services'),
                  onTap: () => context.go('/services'),
                ),
                _SidebarItem(
                  icon: Icons.badge_outlined,
                  title: 'Staff Management',
                  isCollapsed: width == 80.0,
                  isSelected: GoRouterState.of(
                    context,
                  ).uri.path.startsWith('/staff'),
                  onTap: () => context.go('/staff'),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sales & Invoices',
                  isCollapsed: width == 80.0,
                ),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventory',
                  isCollapsed: width == 80.0,
                ),
                32.h,
                _buildSectionTitle(
                  'BUSINESS',
                  isCollapsed: width == 80.0,
                  theme: theme,
                ),
                8.h,
                _SidebarItem(
                  icon: Icons.campaign_outlined,
                  title: 'Marketing',
                  isCollapsed: width == 80.0,
                ),
                _SidebarItem(
                  icon: Icons.analytics_outlined,
                  title: 'Reports & Analytics',
                  isCollapsed: width == 80.0,
                ),
                _SidebarItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  isCollapsed: width == 80.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context, {required bool isCollapsed}) {
    final crmColors = context.crmColors;
    return Padding(
      padding: 16.px,
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: 8.p,
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/nizan_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          if (!isCollapsed) ...[
            12.w,
            Expanded(
              child: Text(
                'Nizan\nMakeovers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: crmColors.sidebarForeground,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    required bool isCollapsed,
    required ThemeData theme,
  }) {
    final crmColors = theme.extension<CrmTheme>()!;
    if (isCollapsed) {
      return Center(
        child: Divider(
          color: crmColors.sidebarForeground.withValues(alpha: 0.16),
        ),
      );
    }
    return Padding(
      padding: 8.px,
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: crmColors.sidebarForeground.withValues(alpha: 0.54),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isCollapsed;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isCollapsed,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: 4.py,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: 12.p,
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.70),
                size: 22,
              ),
              if (!isCollapsed) ...[
                12.w,
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.70),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
