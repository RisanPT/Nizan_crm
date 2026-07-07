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

// Accounts screens with no bottom-nav slot (Dashboard / Finance / Collection
// live in the bottom bar, so they are intentionally left out here).
const _sections = <_Section>[
  _Section('Invoice', Icons.receipt_long_outlined, '/accounts/invoices'),
  _Section('Budget', Icons.pie_chart_outline, '/accounts/budget'),
];

/// Mobile "More" menu for the accounts role — surfaces Invoice / Budget plus
/// Profile / Log out.
Future<void> showAccountsMenuSheet(BuildContext context, WidgetRef ref) {
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
    builder: (sheetCtx) {
      return Container(
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: crmColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.account_balance,
                          color: crmColors.primary, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accounts',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: crmColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'More sections',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: crmColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'SECTIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: crmColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < _sections.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _SectionTile(
                          section: _sections[i],
                          selected: currentPath == _sections[i].route,
                          onTap: () => goTo(sheetCtx, _sections[i].route),
                        ),
                      ),
                    ],
                  ],
                ),
                Divider(color: crmColors.border, height: 28),
                _MenuRow(
                  icon: Icons.account_circle_outlined,
                  label: 'My Profile',
                  selected: currentPath == '/profile',
                  onTap: () => goTo(sheetCtx, '/profile'),
                ),
                _MenuRow(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  color: crmColors.destructive,
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref.read(authControllerProvider).logout();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SectionTile extends StatelessWidget {
  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  const _SectionTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? crmColors.primary.withValues(alpha: 0.09)
                : crmColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? crmColors.primary.withValues(alpha: 0.40)
                  : crmColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (selected ? crmColors.primary : crmColors.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  section.icon,
                  size: 21,
                  color: selected ? crmColors.primary : crmColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? crmColors.primary : crmColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final fg = color ?? (selected ? crmColors.primary : crmColors.textPrimary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? crmColors.primary.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: fg),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const Spacer(),
              if (color == null)
                Icon(Icons.chevron_right,
                    size: 20, color: crmColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
