import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/whatsapp_service.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

/// Client Re-engagement worklist — past brides whose last event was more than N
/// months ago and who haven't booked since. A "who to contact now" list with
/// one-tap WhatsApp (no automated sending; the CRM has no scheduler).
class MarketingReEngagementScreen extends ConsumerWidget {
  const MarketingReEngagementScreen({super.key});

  static const _windows = [3, 6, 12, 18, 24];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(reEngagementMonthsProvider);
    final async = ref.watch(reEngagementProvider);

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(reEngagementProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktHeader(
                icon: Icons.forum_outlined,
                title: 'Client Re-engagement',
                subtitle: 'Past brides due for a re-touch',
                actions: [
                  MktPill(
                    label: 'Back',
                    icon: Icons.arrow_back,
                    trailing: false,
                    onTap: () => context.canPop() ? context.pop() : context.go('/marketing/insights'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Window selector
              Text('No booking in the last', style: mktText(12.5, color: Mkt.inkSoft)),
              8.hg,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _windows)
                    MktFilterChip(
                      label: '${m}mo',
                      selected: months == m,
                      onTap: () {
                        ref.read(reEngagementMonthsProvider.notifier).state = m;
                      },
                    ),
                ],
              ),
              14.hg,

              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: AppErrorView(error: e, onRetry: () => ref.invalidate(reEngagementProvider)),
                ),
                data: (r) {
                  if (r.clients.isEmpty) {
                    return const MktCard(
                      title: 'Clients due',
                      icon: Icons.people_alt_outlined,
                      child: MktEmpty(
                        'No clients are due for re-engagement in this window.',
                        icon: Icons.favorite_border,
                        height: 130,
                      ),
                    );
                  }
                  return MktCard(
                    title: '${r.count} clients due',
                    icon: Icons.people_alt_outlined,
                    child: Column(
                      children: [
                        for (var i = 0; i < r.clients.length; i++)
                          _clientRow(context, r.clients[i], last: i == r.clients.length - 1),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientRow(BuildContext context, ReEngagementClient c, {required bool last}) {
    final name = c.customerName.isEmpty ? c.phone : c.customerName;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Mkt.border)),
      ),
      child: Row(
        children: [
          MktAvatar(name, size: 34),
          10.wg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13.5, weight: FontWeight.w800)),
                2.hg,
                Text(
                    [
                      if (c.phone.isNotEmpty) c.phone,
                      'last event ${c.monthsSince} mo ago',
                      if (c.bookings > 1) '${c.bookings} past bookings',
                    ].join('  •  '),
                    style: mktText(11.5, color: Mkt.inkSoft)),
              ],
            ),
          ),
          8.wg,
          FilledButton.icon(
            onPressed: c.phone.isEmpty ? null : () => _whatsapp(context, c),
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: const Text('WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: Mkt.good,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              textStyle: mktText(12.5, weight: FontWeight.w700),
            ),
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
        showErrorSnackBar(context, e);
      }
    }
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
