import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/asset.dart';
import 'package:nizan_crm/features/finance/controllers/asset_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);
String _pretty(String s) =>
    s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

/// Finance → Dashboard. Company finance overview, centred on the asset
/// portfolio (digital + physical) with value, breakdowns and renewals.
class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final statsAsync = ref.watch(assetStatsProvider);
    final assetsAsync = ref.watch(assetsProvider('all'));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assetStatsProvider);
          ref.invalidate(assetsProvider('all'));
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive))),
            ),
          ]),
          data: (stats) {
            final assets = assetsAsync.value ?? const <Asset>[];
            final renewals = assets
                .where((a) => a.isDigital && a.expiryDate != null && (a.daysToExpiry ?? 999) <= 60)
                .toList()
              ..sort((a, b) => (a.daysToExpiry ?? 0).compareTo(b.daysToExpiry ?? 0));

            final cats = stats.byCategory.entries.toList()
              ..sort((a, b) => b.value.value.compareTo(a.value.value));
            final maxCat = cats.isEmpty ? 1.0 : cats.first.value.value.clamp(1.0, double.infinity);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Finance Overview',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                          4.h,
                          Text('Company asset portfolio',
                              style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/company-finance/assets'),
                      icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
                      label: const Text('Manage assets'),
                    ),
                  ],
                ),
                16.h,
                // KPI tiles
                LayoutBuilder(builder: (ctx, c) {
                  final perRow = c.maxWidth >= 720 ? 4 : 2;
                  const gap = 10.0;
                  final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
                  final tiles = [
                    _kpi(crm, _money(stats.totalValue), 'Total asset value',
                        Icons.savings_outlined, crm.primary),
                    _kpi(crm, '${stats.digital.count} · ${_money(stats.digital.value)}',
                        'Digital assets', Icons.cloud_outlined, crm.accent),
                    _kpi(crm, '${stats.physical.count} · ${_money(stats.physical.value)}',
                        'Physical assets', Icons.chair_outlined, const Color(0xFF0D9488)),
                    _kpi(crm, '${stats.upcomingRenewals}', 'Renewals due (30d)',
                        Icons.event_repeat_outlined,
                        stats.upcomingRenewals > 0 ? crm.warning : crm.textSecondary),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [for (final t in tiles) SizedBox(width: w, child: t)],
                  );
                }),
                16.h,
                // Digital vs physical value split
                _card(crm, 'Portfolio split', [
                  _splitBar(crm, 'Digital', stats.digital.value, stats.totalValue, crm.accent),
                  10.h,
                  _splitBar(crm, 'Physical', stats.physical.value, stats.totalValue,
                      const Color(0xFF0D9488)),
                ]),
                14.h,
                if (cats.isNotEmpty)
                  _card(crm, 'By category', [
                    for (final e in cats.take(6)) ...[
                      _catBar(crm, _pretty(e.key), e.value.value, e.value.count, maxCat),
                      10.h,
                    ],
                  ]),
                14.h,
                _card(crm, 'Upcoming renewals & expiries', [
                  if (renewals.isEmpty)
                    Text('Nothing due in the next 60 days.',
                        style: TextStyle(fontSize: 12.5, color: crm.textSecondary))
                  else
                    for (final a in renewals.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _renewalRow(crm, a),
                      ),
                ]),
                if (stats.expired > 0) ...[
                  12.h,
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crm.destructive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: crm.destructive.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: crm.destructive, size: 18),
                      8.w,
                      Expanded(
                        child: Text(
                            '${stats.expired} digital asset${stats.expired == 1 ? '' : 's'} '
                            'past their renewal date.',
                            style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
                      ),
                    ]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kpi(CrmTheme crm, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          8.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: crm.textPrimary)),
          ),
          2.h,
          Text(label,
              style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card(CrmTheme crm, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          12.h,
          ...children,
        ],
      ),
    );
  }

  Widget _splitBar(CrmTheme crm, String label, double value, double total, Color color) {
    final frac = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          Text('${_money(value)} · ${(frac * 100).round()}%',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
        ]),
        6.h,
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: crm.border.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _catBar(CrmTheme crm, String label, double value, int count, double max) {
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text('$label · $count',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary))),
          Text(_money(value),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
        ]),
        6.h,
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 7,
            backgroundColor: crm.border.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation(crm.primary),
          ),
        ),
      ],
    );
  }

  Widget _renewalRow(CrmTheme crm, Asset a) {
    final days = a.daysToExpiry ?? 0;
    final color = days < 0 ? crm.destructive : (days <= 30 ? crm.warning : crm.textSecondary);
    return Row(
      children: [
        Icon(Icons.language, size: 16, color: crm.primary),
        10.w,
        Expanded(
          child: Text('${a.name}${a.provider.isNotEmpty ? ' · ${a.provider}' : ''}',
              style: TextStyle(fontSize: 13, color: crm.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        8.w,
        Text(
          days < 0 ? 'expired' : 'in $days d',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
        8.w,
        Text(_date(a.expiryDate!),
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ],
    );
  }
}
