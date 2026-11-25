import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_ads_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_ads_service.dart';

final _when = DateFormat('d MMM, h:mm a');

/// Marketing → Campaigns → Meta → Ad spend. Spend, reach, impressions, clicks, ads and audiences come from Meta on their own (every few
/// hours, and on "Sync now"). Meta campaigns that match no CRM campaign are listed here — their spend is not counted until someone links
/// one to a campaign, adds it as a new one, or hides it.
class MetaAdSpendTab extends ConsumerWidget {
  const MetaAdSpendTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(metaAdsStatusProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(metaAdsStatusProvider);
        await ref.read(metaAdsStatusProvider.future).catchError((_) => const MetaAdsStatus());
      },
      child: ListView(
        key: const Key('meta_ads_list'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          status.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MktCard(title: 'Ad spend', child: MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline, key: const Key('meta_ads_error'))),
            data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MktGrid(rows: [
                [(5, _SetupCard(s: s)), (6, _SyncCard(s: s))],
              ]),
              const SizedBox(height: 12),
              _UnlinkedCard(s: s),
              if (s.history.isNotEmpty) ...[const SizedBox(height: 12), _HistoryCard(s: s)],
            ]),
          ),
        ],
      ),
    );
  }
}

/// After a sync, a link or an add: the hub's figures and this screen are read again.
void _refreshAfterSync(WidgetRef ref) {
  ref.invalidate(metaAdsStatusProvider);
  refreshCampaignHub(ref);
}

// ── set-up ───────────────────────────────────────────────────────────────────

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.s});
  final MetaAdsStatus s;

  Widget _has(String key, String label, bool ok, {String? value}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(key: Key('meta_ads_has_$key'), crossAxisAlignment: CrossAxisAlignment.start, children: [
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
    trailing: MktChip(s.ready ? 'Connected' : 'Not set up', key: const Key('meta_ads_ready_chip'), color: s.ready ? Mkt.good : Mkt.grey),
    child: Column(key: const Key('meta_ads_setup_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('The keys live on the server, never in the app. It only says whether each one is set.', style: mktText(12, color: Mkt.inkSoft, height: 1.35)),
      const SizedBox(height: 8),
      _has('appSecret', 'App secret (META_APP_SECRET)', s.appSecret),
      _has('token', 'Access token with ads_read (META_ACCESS_TOKEN)', s.token),
      _has('accounts', 'Ad accounts (META_AD_ACCOUNTS)', s.accounts.isNotEmpty, value: s.accounts.isEmpty ? 'Missing' : '${s.accounts.length}'),
      for (final a in s.accounts)
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 2),
          child: Text('${a.id} · new campaigns go to ${a.brandLabel}', key: Key('meta_ads_account_${a.id}'), style: mktText(11.5, color: Mkt.inkSoft)),
        ),
      if (!s.ready) ...[
        const SizedBox(height: 10),
        Container(
          key: const Key('meta_ads_setup_steps'),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('To switch it on', style: mktText(12, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            for (final (i, t) in const [
              'In Meta Business Manager, give the system user the ad accounts (the same user as Lead Ads).',
              'Give the app the ads_read permission (App Review).',
              'On the server, set META_AD_ACCOUNTS to the account ids with their brand, e.g. act_123:kerala, act_456:main, then restart it.',
              'Set each ad account\'s time zone to India, so Meta\'s days are the CRM\'s days.',
            ].indexed)
              Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Text('${i + 1}. $t', style: mktText(11.5, height: 1.35))),
          ]),
        ),
      ],
    ]),
  );
}

// ── the sync ─────────────────────────────────────────────────────────────────

class _SyncCard extends ConsumerStatefulWidget {
  const _SyncCard({required this.s});
  final MetaAdsStatus s;
  @override
  ConsumerState<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends ConsumerState<_SyncCard> {
  int _days = 3;
  bool _running = false;
  bool _switching = false;

  Future<void> _sync() async {
    setState(() => _running = true);
    try {
      final run = await ref.read(metaAdsServiceProvider).syncNow(_days);
      _refreshAfterSync(ref);
      if (!mounted) return;
      if (run.ok) {
        showSuccessSnackBar(context, 'Synced: ${run.summary}');
      } else {
        showWarningSnackBar(context, run.summary);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _setAuto(bool on) async {
    setState(() => _switching = true);
    try {
      await ref.read(metaAdsServiceProvider).setAutoSync(on);
      ref.invalidate(metaAdsStatusProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final run = s.lastRun;
    final busy = _running || s.running;
    return MktCard(
      title: 'Sync',
      icon: Icons.sync_rounded,
      trailing: run == null ? null : MktChip(run.ok ? 'Last sync worked' : 'Last sync failed', key: const Key('meta_ads_last_chip'), color: run.ok ? Mkt.good : Mkt.bad),
      child: Column(key: const Key('meta_ads_sync_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Brings in each day\'s spend, reach, impressions, clicks and results per campaign, per ad and per audience (age, gender, placement). A day brought in again replaces itself, so nothing is counted twice.',
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 10),
        if (run == null)
          Text(s.ready ? 'Not synced yet.' : 'Nothing synced: the server is not set up.', key: const Key('meta_ads_never'), style: mktText(12.5, weight: FontWeight.w600))
        else ...[
          Text(run.summary, key: const Key('meta_ads_last_summary'), style: mktText(12.5, weight: FontWeight.w700, color: run.ok ? Mkt.ink : Mkt.bad, height: 1.35)),
          if (run.ok) Text(run.details, style: mktText(11.5, color: Mkt.inkSoft)),
          if (run.ok && run.unlinkedSpend > 0)
            Text('${metaInr(run.unlinkedSpend)} more was spent on Meta campaigns not linked yet (below).', key: const Key('meta_ads_unlinked_note'), style: mktText(11.5, color: Mkt.warn, weight: FontWeight.w700)),
          if (run.at != null) Text('${_when.format(run.at!)} · ${run.how}', style: mktText(11, color: Mkt.inkSoft)),
          if (!run.ok && s.lastOkAt != null) Text('Last good sync: ${_when.format(s.lastOkAt!)}', style: mktText(11, color: Mkt.inkSoft)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              s.autoSync ? 'Runs on its own ${s.cadence} (the last ${s.daysBack} days)${s.nextAutoAt != null && s.ready ? ' · next ${_when.format(s.nextAutoAt!)}' : ''}' : 'Automatic sync is off',
              key: const Key('meta_ads_auto_text'),
              style: mktText(12, weight: FontWeight.w600),
            ),
          ),
          if (s.canManage)
            Switch(key: const Key('meta_ads_auto'), value: s.autoSync, activeThumbColor: Mkt.primary, onChanged: _switching ? null : _setAuto),
        ]),
        if (!s.canManage) Text('Only the Marketing Manager or Admin can switch it.', style: mktText(11, color: Mkt.inkSoft)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<int>(
            key: const Key('meta_ads_days'),
            value: _days,
            underline: const SizedBox.shrink(),
            items: [for (final d in const [1, 3, 7, 30, 90]) DropdownMenuItem(value: d, child: Text(d == 1 ? 'Today' : 'Last $d days', style: mktText(12.5)))],
            onChanged: busy ? null : (v) => setState(() => _days = v ?? 3),
          ),
          MktPrimaryButton(key: const Key('meta_ads_sync_button'), icon: Icons.sync_rounded, label: busy ? 'Syncing…' : 'Sync now', onPressed: busy || !s.ready ? null : _sync),
        ]),
      ]),
    );
  }
}

// ── Meta campaigns not linked yet ────────────────────────────────────────────

class _UnlinkedCard extends ConsumerStatefulWidget {
  const _UnlinkedCard({required this.s});
  final MetaAdsStatus s;
  @override
  ConsumerState<_UnlinkedCard> createState() => _UnlinkedCardState();
}

class _UnlinkedCardState extends ConsumerState<_UnlinkedCard> {
  String? _working; // the Meta id being linked / added ('*' = all)
  bool _showIgnored = false;

  Future<void> _do(String key, Future<Object> Function() action, {String? done}) async {
    setState(() => _working = key);
    try {
      final r = await action();
      _refreshAfterSync(ref);
      if (!mounted) return;
      final msg = r is MetaLinkResult ? r.message : done;
      if (msg != null) showSuccessSnackBar(context, msg);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _pickAndLink(MetaUnlinked u) async {
    final choices = widget.s.choices;
    final picked = await showDialog<MetaCampaignChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        key: const Key('meta_link_dialog'),
        title: Text('Which campaign is "${u.name.isEmpty ? u.metaId : u.name}"?', style: mktText(15, weight: FontWeight.w800)),
        children: choices.isEmpty
            ? [Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: Text('Every campaign already has a Meta campaign. Add it as a new campaign instead.', style: mktText(12.5, color: Mkt.inkSoft)))]
            : [
                for (final c in choices)
                  SimpleDialogOption(
                    key: Key('meta_link_choice_${c.id}'),
                    onPressed: () => Navigator.of(ctx).pop(c),
                    child: Text('${c.title}${c.brand.isEmpty ? '' : ' · ${c.brand == 'main' ? 'Main' : 'Kerala'}'}', style: mktText(13)),
                  ),
              ],
      ),
    );
    if (picked == null || !mounted) return;
    await _do(u.metaId, () => ref.read(metaAdsServiceProvider).link(u.metaId, picked.id));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final svc = ref.read(metaAdsServiceProvider);
    return MktCard(
      title: 'Meta campaigns not linked',
      icon: Icons.link_off_rounded,
      trailing: s.unlinked.isEmpty ? const MktChip('All linked', color: Mkt.good) : MktChip('${s.unlinked.length} waiting', key: const Key('meta_unlinked_count'), color: Mkt.warn),
      child: Column(key: const Key('meta_unlinked_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          s.unlinked.isEmpty
              ? 'Every Meta campaign that spent money is linked to a campaign here.'
              : 'These spent money on Meta but match no campaign here, so their spend is not counted yet. Link each to its campaign, add it as a new one, or hide a test campaign.',
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        if (s.unlinked.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final u in s.unlinked) _row(u, svc),
          const SizedBox(height: 8),
          if (s.unlinked.length > 1)
            OutlinedButton.icon(
              key: const Key('meta_add_all'),
              onPressed: _working != null ? null : () => _do('*', svc.addAll),
              icon: _working == '*' ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.playlist_add_rounded, size: 17),
              label: Text('Add all ${s.unlinked.length} as new campaigns'),
            ),
        ],
        if (s.ignored.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            key: const Key('meta_ignored_toggle'),
            onTap: () => setState(() => _showIgnored = !_showIgnored),
            child: Text('${s.ignored.length} hidden ${_showIgnored ? '▴' : '▾'}', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
          ),
          if (_showIgnored)
            for (final id in s.ignored)
              Row(children: [
                Expanded(child: Text('Meta campaign $id', style: mktText(12))),
                TextButton(key: Key('meta_restore_$id'), onPressed: _working != null ? null : () => _do(id, () => svc.restore(id), done: 'It shows again from the next sync.'), child: const Text('Show again')),
              ]),
        ],
      ]),
    );
  }

  Widget _row(MetaUnlinked u, MetaAdsService svc) {
    final busy = _working == u.metaId || _working == '*';
    return Container(
      key: Key('meta_unlinked_${u.metaId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(u.name.isEmpty ? 'Meta campaign ${u.metaId}' : u.name, style: mktText(13, weight: FontWeight.w700)),
          MktChip(u.brandLabel, color: Mkt.blue),
          if (u.reasonText.isNotEmpty) MktChip(u.reasonText, key: Key('ads_unlinked_reason_${u.metaId}'), color: Mkt.warn),
        ]),
        const SizedBox(height: 2),
        Text(
          '${metaInr(u.spend)} spent ${metaDays(u.runFrom, u.runTo)} (last sync) · first seen ${metaDays(u.firstDay, u.firstDay)} · ${u.accountId}',
          style: mktText(11.5, color: Mkt.inkSoft),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          TextButton.icon(
            key: Key('meta_link_${u.metaId}'),
            onPressed: busy || _working != null ? null : () => _pickAndLink(u),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Link to a campaign'),
          ),
          TextButton.icon(
            key: Key('meta_add_${u.metaId}'),
            onPressed: busy || _working != null ? null : () => _do(u.metaId, () => svc.add(u.metaId)),
            icon: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add as a new campaign'),
          ),
          TextButton(
            key: Key('meta_ignore_${u.metaId}'),
            onPressed: busy || _working != null ? null : () => _do(u.metaId, () => svc.ignore(u.metaId), done: 'Hidden. Its spend stays out.'),
            child: const Text('Hide'),
          ),
        ]),
      ]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.s});
  final MetaAdsStatus s;

  @override
  Widget build(BuildContext context) => MktCard(
    title: 'Recent syncs',
    icon: Icons.history_rounded,
    child: Column(key: const Key('meta_ads_history'), children: [
      for (final h in s.history)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text('${h.at == null ? '' : _when.format(h.at!)} · ${h.byName.isEmpty ? 'by hand' : h.byName}', style: mktText(12))),
            Text('${metaDays(h.from, h.to)} · ${h.written} records', style: mktText(11.5, color: Mkt.inkSoft)),
          ]),
        ),
    ]),
  );
}
