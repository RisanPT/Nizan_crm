import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';

class _Section {
  final String label;
  final IconData icon;
  final String route;
  const _Section(this.label, this.icon, this.route);
}

// Inventory screens without a bottom-nav slot (Dashboard / Stock / Kits are in
// the bottom bar).
const _sections = <_Section>[
  _Section('Purchases', Icons.add_shopping_cart_outlined, '/inventory/purchases'),
  _Section('Vendors', Icons.storefront_outlined, '/inventory/vendors'),
  _Section('Restock Alerts', Icons.warning_amber_rounded, '/inventory/alerts'),
  _Section('Expiry Tracker', Icons.hourglass_bottom_outlined, '/inventory/expiry'),
  _Section('Reports', Icons.bar_chart_outlined, '/inventory/reports'),
];

Future<void> showInventoryMenuSheet(BuildContext context, WidgetRef ref) {
  final crmColors = context.crmColors;
  final currentPath = GoRouterState.of(context).uri.path;

  void goTo(BuildContext sheetCtx, String route) {
    Navigator.of(sheetCtx).pop();
    context.go(route);
  }

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: crmColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: crmColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.inventory_2_outlined,
                        color: crmColors.primary, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventory',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: crmColors.textPrimary)),
                      Text('More sections',
                          style: TextStyle(
                              fontSize: 12.5, color: crmColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final s in _sections)
                _row(context, sheetCtx, crmColors, s.icon, s.label,
                    selected: currentPath == s.route,
                    onTap: () => goTo(sheetCtx, s.route)),
              Divider(color: crmColors.border, height: 24),
              _row(context, sheetCtx, crmColors, Icons.account_circle_outlined,
                  'My Profile',
                  selected: currentPath == '/profile',
                  onTap: () => goTo(sheetCtx, '/profile')),
              _row(context, sheetCtx, crmColors, Icons.logout_rounded, 'Log Out',
                  color: crmColors.destructive, onTap: () async {
                Navigator.of(sheetCtx).pop();
                await ref.read(authControllerProvider).logout();
              }),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _row(BuildContext context, BuildContext sheetCtx, CrmTheme crm,
    IconData icon, String label,
    {bool selected = false, Color? color, required VoidCallback onTap}) {
  final fg = color ?? (selected ? crm.primary : crm.textPrimary);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? crm.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: fg),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: fg)),
            const Spacer(),
            if (color == null)
              Icon(Icons.chevron_right, size: 20, color: crm.textSecondary),
          ],
        ),
      ),
    ),
  );
}
