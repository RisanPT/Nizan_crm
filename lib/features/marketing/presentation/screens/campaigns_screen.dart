import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/marketing/data/campaign.dart';
import 'package:nizan_crm/features/marketing/services/campaign_service.dart';

/// Marketing → Campaigns: track each campaign's ad spend + production cost and
/// the revenue it generated, with computed ROI / ROAS.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  static const _statuses = ['all', 'active', 'planned', 'paused', 'completed'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final role = ref.watch(authSessionProvider)?.role ?? '';
    final canManage = role == 'admin' || role == 'manager' || role == 'marketing_admin';
    final filter = ref.watch(campaignStatusFilterProvider);
    final async = ref.watch(campaignsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New Campaign'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(campaignsProvider),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 90),
          children: [
            Text('Campaigns',
                style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
            Text('Ad spend · production cost · ROI',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            16.hg,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _statuses)
                  _chip(crm, _statusLabel(s), filter == s,
                      () => ref.read(campaignStatusFilterProvider.notifier).state = s),
              ],
            ),
            16.hg,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: Text(e.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
              data: (board) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _summary(crm, isMobile, 'Ad Spend', '₹${_money(board.totalAdSpend)}',
                          const Color(0xFFEA580C)),
                      _summary(crm, isMobile, 'Production', '₹${_money(board.totalProductionCost)}',
                          const Color(0xFFDB2777)),
                      _summary(crm, isMobile, 'Revenue', '₹${_money(board.totalRevenue)}',
                          const Color(0xFF16A34A)),
                      _summary(crm, isMobile, 'Blended ROI',
                          board.blendedRoiPct != null ? '${board.blendedRoiPct!.toStringAsFixed(0)}%' : '—',
                          _roiColor(board.blendedRoiPct)),
                    ],
                  ),
                  18.hg,
                  if (board.campaigns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('No campaigns yet.',
                            style: TextStyle(color: crm.textSecondary)),
                      ),
                    )
                  else
                    for (final c in board.campaigns)
                      _campaignCard(context, ref, crm, c, canManage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campaignCard(BuildContext context, WidgetRef ref, CrmTheme crm,
      Campaign c, bool canManage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: crm.textPrimary)),
                    2.hg,
                    Text(
                        [
                          if (c.channel.isNotEmpty) c.channel,
                          if (c.startDate != null)
                            DateFormat('d MMM').format(c.startDate!) +
                                (c.endDate != null
                                    ? ' – ${DateFormat('d MMM').format(c.endDate!)}'
                                    : ''),
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              _pill(_statusLabel(c.status), _statusColor(c.status)),
            ],
          ),
          10.hg,
          // ROI banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _roiColor(c.roiPct).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded, size: 18, color: _roiColor(c.roiPct)),
                8.wg,
                Text('ROI ',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                Text(c.roiPct != null ? '${c.roiPct!.toStringAsFixed(0)}%' : '—',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _roiColor(c.roiPct))),
                if (c.autoAttributed) ...[
                  6.wg,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100)),
                    child: Text('auto · ${c.autoConversions} bookings',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: crm.primary)),
                  ),
                ],
                const Spacer(),
                if (c.roas != null)
                  Text('${c.roas!.toStringAsFixed(1)}× ROAS',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
              ],
            ),
          ),
          10.hg,
          Row(
            children: [
              _mini(crm, 'Ad spend', '₹${_money(c.adSpend)}'),
              _mini(crm, 'Production', '₹${_money(c.productionCost)}'),
              _mini(crm, 'Total cost', '₹${_money(c.totalCost)}'),
              _mini(crm, 'Revenue', '₹${_money(c.revenue)}'),
            ],
          ),
          if (c.leads > 0 || c.conversions > 0) ...[
            8.hg,
            Row(
              children: [
                _mini(crm, 'Leads', '${c.leads}'),
                _mini(crm, 'Conversions', '${c.conversions}'),
                _mini(crm, 'Cost/lead',
                    c.costPerLead != null ? '₹${_money(c.costPerLead!)}' : '—'),
                _mini(crm, 'CAC',
                    c.costPerAcquisition != null ? '₹${_money(c.costPerAcquisition!)}' : '—'),
              ],
            ),
          ],
          if (canManage) ...[
            8.hg,
            Divider(height: 1, color: crm.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openEditor(context, ref, existing: c),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, c),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── editor ──
  void _openEditor(BuildContext context, WidgetRef ref, {Campaign? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final channelCtrl = TextEditingController(text: existing?.channel ?? '');
    final adCtrl = TextEditingController(
        text: (existing?.adSpend ?? 0) > 0 ? existing!.adSpend.toStringAsFixed(0) : '');
    final prodCtrl = TextEditingController(
        text: (existing?.productionCost ?? 0) > 0 ? existing!.productionCost.toStringAsFixed(0) : '');
    final revCtrl = TextEditingController(
        text: (existing?.revenue ?? 0) > 0 ? existing!.revenue.toStringAsFixed(0) : '');
    final leadsCtrl = TextEditingController(
        text: (existing?.leads ?? 0) > 0 ? '${existing!.leads}' : '');
    final convCtrl = TextEditingController(
        text: (existing?.conversions ?? 0) > 0 ? '${existing!.conversions}' : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var status = existing?.status ?? 'active';
    DateTime? start = existing?.startDate;
    DateTime? end = existing?.endDate;
    var saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text(existing == null ? 'New Campaign' : 'Edit Campaign'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Campaign title *', border: OutlineInputBorder()),
                  ),
                  12.hg,
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: channelCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Channel', hintText: 'Instagram, Meta…',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    10.wg,
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Status', border: OutlineInputBorder()),
                        items: [
                          for (final s in _statuses.where((s) => s != 'all'))
                            DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                        ],
                        onChanged: (v) => setLocal(() => status = v ?? status),
                      ),
                    ),
                  ]),
                  12.hg,
                  Row(children: [
                    Expanded(child: _numField(adCtrl, 'Ad spend (₹)')),
                    10.wg,
                    Expanded(child: _numField(prodCtrl, 'Production cost (₹)')),
                  ]),
                  12.hg,
                  _numField(revCtrl, 'Revenue (₹) — blank = auto from tagged leads'),
                  6.hg,
                  const Text(
                      'Leave revenue/leads/conversions blank to auto-attribute from leads tagged to this campaign. A manual value overrides the auto figure.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  12.hg,
                  Row(children: [
                    Expanded(child: _numField(leadsCtrl, 'Leads')),
                    10.wg,
                    Expanded(child: _numField(convCtrl, 'Conversions')),
                  ]),
                  12.hg,
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: ctx,
                              initialDate: start ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100));
                          if (d != null) setLocal(() => start = d);
                        },
                        child: Text(start == null
                            ? 'Start date'
                            : DateFormat('d MMM y').format(start!)),
                      ),
                    ),
                    10.wg,
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: ctx,
                              initialDate: end ?? start ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100));
                          if (d != null) setLocal(() => end = d);
                        },
                        child: Text(end == null
                            ? 'End date'
                            : DateFormat('d MMM y').format(end!)),
                      ),
                    ),
                  ]),
                  12.hg,
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter a campaign title')),
                        );
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        await ref.read(campaignServiceProvider).save(Campaign(
                              id: existing?.id ?? '',
                              title: titleCtrl.text.trim(),
                              channel: channelCtrl.text.trim(),
                              status: status,
                              startDate: start,
                              endDate: end,
                              adSpend: double.tryParse(adCtrl.text.trim()) ?? 0,
                              productionCost: double.tryParse(prodCtrl.text.trim()) ?? 0,
                              revenue: double.tryParse(revCtrl.text.trim()) ?? 0,
                              leads: int.tryParse(leadsCtrl.text.trim()) ?? 0,
                              conversions: int.tryParse(convCtrl.text.trim()) ?? 0,
                              notes: notesCtrl.text.trim(),
                            ));
                        ref.invalidate(campaignsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setLocal(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: const Color(0xFFDC2626),
                          ));
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Campaign c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete campaign?'),
        content: Text('Remove "${c.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(campaignServiceProvider).delete(c.id);
      ref.invalidate(campaignsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Widget _mini(CrmTheme crm, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        ),
      );

  Widget _summary(CrmTheme crm, bool isMobile, String label, String value, Color color) =>
      SizedBox(
        width: isMobile ? 150 : 170,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              2.hg,
              Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ),
      );

  Widget _chip(CrmTheme crm, String label, bool sel, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? crm.primary : crm.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: sel ? crm.primary : crm.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : crm.textSecondary)),
        ),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );

  static Color _statusColor(String s) => switch (s) {
        'active' => const Color(0xFF16A34A),
        'planned' => const Color(0xFF2563EB),
        'paused' => const Color(0xFFF59E0B),
        'completed' => const Color(0xFF6B7280),
        _ => const Color(0xFF6B7280),
      };
  static String _statusLabel(String s) => switch (s) {
        'all' => 'All',
        'active' => 'Active',
        'planned' => 'Planned',
        'paused' => 'Paused',
        'completed' => 'Completed',
        _ => s,
      };
  static Color _roiColor(double? roi) {
    if (roi == null) return const Color(0xFF6B7280);
    if (roi >= 100) return const Color(0xFF16A34A);
    if (roi >= 0) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  static String _money(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
