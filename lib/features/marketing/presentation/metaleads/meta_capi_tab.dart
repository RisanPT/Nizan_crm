import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_capi_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/meta_capi_service.dart';

final _when = DateFormat('d MMM, h:mm a');

/// Marketing → Campaigns → Meta → Results to Meta. Each stage a Lead Ads lead reaches in the CRM (Lead, Contacted, Qualified, Converted,
/// Follow-up, Lost) is told to Meta once, so Meta learns which leads BOOK and shows the ads to people like them. Off until the Marketing
/// Manager / admin switches it on.
class MetaCapiTab extends ConsumerWidget {
  const MetaCapiTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(metaCapiStatusProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(metaCapiStatusProvider);
        await ref.read(metaCapiStatusProvider.future).catchError((_) => const MetaCapiStatus());
      },
      child: ListView(
        key: const Key('meta_capi_list'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          status.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MktCard(title: 'Results to Meta', child: MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline, key: const Key('meta_capi_error'))),
            data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MktKpiRow(
                key: const Key('meta_capi_counts'),
                children: [
                  MktKpiCard(icon: Icons.groups_outlined, value: '${s.followed}', label: 'Meta leads followed', note: 'last ${s.windowDays} days', tint: Mkt.blue),
                  MktKpiCard(icon: Icons.verified_outlined, value: '${s.sentByStage['Qualified'] ?? 0}', label: 'Qualified sent', note: 'last 30 days', tint: Mkt.primaryLight),
                  MktKpiCard(icon: Icons.event_available_outlined, value: '${s.sentByStage['Converted'] ?? 0}', label: 'Bookings sent', note: 'last 30 days', tint: Mkt.good),
                  MktKpiCard(icon: Icons.error_outline_rounded, value: '${(s.counts['failed'] ?? 0) + (s.counts['expired'] ?? 0)}', label: 'Not taken', note: 'last 30 days', tint: (s.counts['failed'] ?? 0) + (s.counts['expired'] ?? 0) > 0 ? Mkt.bad : Mkt.grey),
                ],
              ),
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(6, _SwitchCard(s: s)), (5, _SetupCard(s: s))],
              ]),
              const SizedBox(height: 12),
              _RecentCard(s: s),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── on / off, Send now ───────────────────────────────────────────────────────

class _SwitchCard extends ConsumerStatefulWidget {
  const _SwitchCard({required this.s});
  final MetaCapiStatus s;
  @override
  ConsumerState<_SwitchCard> createState() => _SwitchCardState();
}

class _SwitchCardState extends ConsumerState<_SwitchCard> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('meta_capi_confirm'),
          title: const Text('Send lead results to Meta?'),
          content: const Text(
            'From now on, each stage a Lead Ads lead reaches is sent to Meta with Meta\'s own lead id. Her phone and e-mail go only as an '
            'unreadable code (hashed). Switch it on only if your privacy notice says you share results with Meta.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(key: const Key('meta_capi_confirm_yes'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Switch on')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(metaCapiServiceProvider).setEnabled(on);
      ref.invalidate(metaCapiStatusProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(metaCapiServiceProvider).sendNow();
      ref.invalidate(metaCapiStatusProvider);
      if (!mounted) return;
      r.ok ? showSuccessSnackBar(context, r.summary) : showWarningSnackBar(context, r.summary);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final run = s.lastRun;
    return MktCard(
      title: 'Results to Meta',
      icon: Icons.ios_share_rounded,
      trailing: MktChip(s.enabled ? 'On' : 'Off', key: const Key('meta_capi_on_chip'), color: s.enabled ? Mkt.good : Mkt.grey),
      child: Column(key: const Key('meta_capi_switch_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Meta learns which of its leads book, and shows the ads to more people like them — not just to people who fill forms. Each stage a Lead Ads lead reaches is sent once:',
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final (i, st) in const ['Lead', 'Contacted', 'Qualified', 'Converted'].indexed) ...[
            if (i > 0) const Icon(Icons.chevron_right_rounded, size: 16, color: Mkt.inkSoft),
            MktChip(st, color: st == 'Converted' ? Mkt.good : Mkt.primary),
          ],
          const SizedBox(width: 6),
          Text('and Follow-up, Lost as they happen', style: mktText(11.5, color: Mkt.inkSoft)),
        ]),
        const SizedBox(height: 6),
        Text('A booked lead also sends Contacted and Qualified if it skipped them. A lead that was already a client before the form counts only as a Lead.', style: mktText(11.5, color: Mkt.inkSoft, height: 1.35)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              s.enabled
                  ? 'On${s.enabledAt == null ? '' : ' since ${_when.format(s.enabledAt!)}'}${s.updatedByName.isEmpty ? '' : ' · ${s.updatedByName}'} · sent every ${s.everyMinutes == 60 ? 'hour' : '${s.everyMinutes} minutes'}'
                  : 'Off: nothing is sent to Meta',
              key: const Key('meta_capi_state_text'),
              style: mktText(12.5, weight: FontWeight.w700),
            ),
          ),
          if (s.canManage) Switch(key: const Key('meta_capi_switch'), value: s.enabled, activeThumbColor: Mkt.primary, onChanged: _busy || (!s.ready && !s.enabled) ? null : _set),
        ]),
        if (!s.canManage) Text('Only the Marketing Manager or Admin can switch it.', style: mktText(11, color: Mkt.inkSoft)),
        if (run != null) ...[
          const SizedBox(height: 8),
          Text(run.summary, key: const Key('meta_capi_last_run'), style: mktText(12, weight: FontWeight.w700, color: run.ok ? Mkt.ink : Mkt.bad, height: 1.35)),
          if (run.at != null) Text('${_when.format(run.at!)} · ${run.trigger == 'auto' ? 'automatic' : 'by hand'}', style: mktText(11, color: Mkt.inkSoft)),
        ],
        if (s.lastSentAt != null) Text('Last sent: ${_when.format(s.lastSentAt!)}', style: mktText(11, color: Mkt.inkSoft)),
        const SizedBox(height: 10),
        MktPrimaryButton(key: const Key('meta_capi_send'), icon: Icons.send_rounded, label: _busy || s.running ? 'Sending…' : 'Send now', onPressed: _busy || s.running || !s.enabled || !s.ready ? null : _send),
      ]),
    );
  }
}

// ── set-up ───────────────────────────────────────────────────────────────────

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.s});
  final MetaCapiStatus s;

  Widget _has(String key, String label, bool ok, [String? value]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(key: Key('meta_capi_has_$key'), children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: ok ? Mkt.good : Mkt.bad),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: mktText(12.5))),
      Text(value ?? (ok ? 'Set' : 'Missing'), style: mktText(11.5, weight: FontWeight.w700, color: ok ? Mkt.good : Mkt.bad)),
    ]),
  );

  @override
  Widget build(BuildContext context) => MktCard(
    title: 'Connection',
    icon: Icons.link_rounded,
    trailing: s.testMode ? const MktChip('Test mode', key: Key('meta_capi_test_chip'), color: Mkt.warn) : MktChip(s.ready ? 'Connected' : 'Not set up', color: s.ready ? Mkt.good : Mkt.grey),
    child: Column(key: const Key('meta_capi_setup_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _has('dataset', 'Dataset in Events Manager (META_CAPI_DATASET_ID)', s.dataset),
      _has('token', s.ownToken ? 'Conversions API token (META_CAPI_TOKEN)' : 'Access token (META_ACCESS_TOKEN)', s.token),
      if (s.testMode)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Test mode: events go to Events Manager → Test events and count for nothing. Remove META_CAPI_TEST_CODE to send for real.', style: mktText(11.5, color: Mkt.warn, weight: FontWeight.w700, height: 1.35)),
        ),
      if (!s.ready) ...[
        const SizedBox(height: 10),
        Container(
          key: const Key('meta_capi_setup_steps'),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('To set it up', style: mktText(12, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            for (final (i, t) in const [
              'In Events Manager, set up the CRM integration for your Lead Ads and note the dataset id.',
              'Put the dataset id in META_CAPI_DATASET_ID on the server, and the token Events Manager makes in META_CAPI_TOKEN; restart it.',
              'Optional: put Events Manager\'s test code in META_CAPI_TEST_CODE to try it without counting.',
              'Then switch it on here.',
            ].indexed)
              Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Text('${i + 1}. $t', style: mktText(11.5, height: 1.35))),
          ]),
        ),
      ],
      const SizedBox(height: 8),
      Text('Sent as "${s.crmName}". Only the last ${s.maxAgeDays} days can be sent: Meta takes nothing older.', style: mktText(11.5, color: Mkt.inkSoft, height: 1.35)),
    ]),
  );
}

// ── what was sent ────────────────────────────────────────────────────────────

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.s});
  final MetaCapiStatus s;

  @override
  Widget build(BuildContext context) => MktCard(
    title: 'Latest events',
    icon: Icons.history_rounded,
    child: Column(key: const Key('meta_capi_recent'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (s.recent.isEmpty)
        MktEmpty(s.enabled ? 'Nothing sent yet. Events appear here after the next run.' : 'Nothing sent: it is switched off.', key: const Key('meta_capi_recent_empty'))
      else
        for (final e in s.recent)
          Container(
            key: Key('meta_capi_event_${e.id}'),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(e.leadName.isEmpty ? 'Lead ${e.leadgenId}' : e.leadName, style: mktText(12.5, weight: FontWeight.w700)),
                MktChip(e.stage, color: e.stage == 'Converted' ? Mkt.good : Mkt.primary),
                MktChip(e.statusLabel, color: switch (e.status) { 'sent' => Mkt.good, 'failed' => e.retry ? Mkt.warn : Mkt.bad, 'pending' => Mkt.blue, _ => Mkt.grey }),
              ]),
              Text(
                [if (e.eventAt != null) 'reached ${_when.format(e.eventAt!)}', if (e.sentAt != null) 'sent ${_when.format(e.sentAt!)}', if (e.retry && e.nextTryAt != null) 'next try ${_when.format(e.nextTryAt!)}'].join(' · '),
                style: mktText(11, color: Mkt.inkSoft),
              ),
              if (e.problem.isNotEmpty && e.status != 'sent') Text(e.problem, key: Key('meta_capi_problem_${e.id}'), style: mktText(11.5, color: e.status == 'failed' ? Mkt.bad : Mkt.inkSoft, height: 1.3)),
            ]),
          ),
    ]),
  );
}
