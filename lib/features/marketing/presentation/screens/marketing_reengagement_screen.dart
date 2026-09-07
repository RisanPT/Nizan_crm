import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/utils/whatsapp_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

/// Client Re-engagement worklist — past brides whose last event was more than N
/// months ago and who haven't booked since. A "who to contact now" list with
/// one-tap WhatsApp (no automated sending; the CRM has no scheduler).
class MarketingReEngagementScreen extends ConsumerWidget {
  const MarketingReEngagementScreen({super.key});

  static const _windows = [3, 6, 12, 18, 24];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final months = ref.watch(reEngagementMonthsProvider);
    final async = ref.watch(reEngagementProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reEngagementProvider),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/marketing/insights'),
                  icon: const Icon(Icons.arrow_back),
                ),
                8.wg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client Re-engagement',
                          style: TextStyle(
                              fontSize: isMobile ? 20 : 25,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text('Past brides due for a re-touch',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            14.hg,

            // Window selector
            Row(
              children: [
                Text('No booking in the last',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                10.wg,
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in _windows)
                      _chip(crm, '${m}mo', months == m, () {
                        ref.read(reEngagementMonthsProvider.notifier).state = m;
                      }),
                  ],
                ),
              ],
            ),
            18.hg,

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
              data: (r) {
                if (r.clients.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                          'No clients are due for re-engagement in this window.',
                          style: TextStyle(color: crm.textSecondary)),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.count} clients due',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary)),
                    12.hg,
                    for (final c in r.clients)
                      _clientCard(context, crm, c),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientCard(BuildContext context, CrmTheme crm, ReEngagementClient c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.customerName.isEmpty ? c.phone : c.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: crm.textPrimary)),
                2.hg,
                Text(
                    [
                      if (c.phone.isNotEmpty) c.phone,
                      'last event ${c.monthsSince} mo ago',
                      if (c.bookings > 1) '${c.bookings} past bookings',
                    ].join('  •  '),
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          8.wg,
          FilledButton.icon(
            onPressed: c.phone.isEmpty ? null : () => _whatsapp(context, c),
            icon: const Icon(Icons.chat_outlined, size: 17),
            label: const Text('WhatsApp'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _whatsapp(BuildContext context, ReEngagementClient c) async {
    final name = c.customerName.trim().isEmpty ? 'there' : c.customerName.trim();
    final message = 'Hi $name, greetings from *Team N Makeovers*! 🌸\n\n'
        "It's been a while since we last styled you. We'd love to be part of "
        'your next special occasion — trials, party makeup, or a referral for '
        'someone dear. Reply here and our team will take care of the rest! 💖';
    try {
      await WhatsAppService.openChat(c.phone, message);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  Widget _chip(CrmTheme crm, String label, bool sel, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
