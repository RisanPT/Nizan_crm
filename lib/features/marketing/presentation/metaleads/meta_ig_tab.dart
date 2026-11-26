import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_ig_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/meta_ig_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

final _when = DateFormat('d MMM, h:mm a');
final _day = DateFormat('d MMM');
final _n = NumberFormat.decimalPattern('en_IN');

/// Marketing → Campaigns → Meta → Instagram. Followers and each recent post's reach, views, likes, comments, shares and saves come into
/// Socials on their own. A post is matched to its Socials post by its link or the one planned post of that day; the rest are listed
/// here to add, link or hide.
class MetaIgTab extends ConsumerWidget {
  const MetaIgTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(metaIgStatusProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(metaIgStatusProvider);
        await ref.read(metaIgStatusProvider.future).catchError((_) => const MetaIgStatus());
      },
      child: ListView(
        key: const Key('meta_ig_list'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          status.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MktCard(title: 'Instagram', child: MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline, key: const Key('meta_ig_error'))),
            data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MktGrid(rows: [
                [(5, _AccountsCard(s: s)), (6, _SyncCard(s: s))],
              ]),
              const SizedBox(height: 12),
              _UnmatchedCard(s: s),
            ]),
          ),
        ],
      ),
    );
  }
}

void _refreshAll(WidgetRef ref) {
  ref.invalidate(metaIgStatusProvider);
  refreshSocials(ref);
}

// ── accounts ─────────────────────────────────────────────────────────────────

class _AccountsCard extends ConsumerStatefulWidget {
  const _AccountsCard({required this.s});
  final MetaIgStatus s;
  @override
  ConsumerState<_AccountsCard> createState() => _AccountsCardState();
}

class _AccountsCardState extends ConsumerState<_AccountsCard> {
  bool _finding = false;
  List<MetaIgFound>? _found;

  Future<void> _find() async {
    setState(() => _finding = true);
    try {
      final f = await ref.read(metaIgServiceProvider).find();
      if (mounted) setState(() => _found = f);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Widget _has(String key, String label, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(key: Key('meta_ig_has_$key'), children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: ok ? Mkt.good : Mkt.bad),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: mktText(12.5))),
      Text(ok ? 'Set' : 'Missing', style: mktText(11.5, weight: FontWeight.w700, color: ok ? Mkt.good : Mkt.bad)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final found = _found;
    return MktCard(
      title: 'Accounts',
      icon: Icons.camera_alt_outlined,
      trailing: MktChip(s.ready ? 'Connected' : 'Not set up', key: const Key('meta_ig_ready_chip'), color: s.ready ? Mkt.good : Mkt.grey),
      child: Column(key: const Key('meta_ig_accounts_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        _has('appSecret', 'App secret (META_APP_SECRET)', s.appSecret),
        _has('token', 'Access token with Instagram rights (META_ACCESS_TOKEN)', s.token),
        _has('accounts', 'Instagram accounts (META_IG_ACCOUNTS)', s.accounts.isNotEmpty),
        for (final a in s.accounts)
          Padding(
            key: Key('meta_ig_account_${a.id}'),
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  a.username.isEmpty ? '${a.id} · ${a.brandLabel} · not synced yet' : '${a.username} · ${a.brandLabel}',
                  style: mktText(12, weight: FontWeight.w600),
                ),
              ),
              if (a.followers != null) Text('${_n.format(a.followers)} followers', style: mktText(11.5, color: Mkt.inkSoft)),
            ]),
          ),
        if (!s.ready)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              key: const Key('meta_ig_setup_steps'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('To set it up', style: mktText(12, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                for (final (i, t) in const [
                  'Each Instagram account must be a business (or creator) account linked to a Facebook Page.',
                  'Give the system user those Pages, and the app instagram_basic, instagram_manage_insights and pages_read_engagement (App Review).',
                  'Press "Find my Instagram accounts", then put the ids on the server as META_IG_ACCOUNTS, e.g. 1784…:main, 1784…:kerala, and restart it.',
                ].indexed)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Text('${i + 1}. $t', style: mktText(11.5, height: 1.35))),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('meta_ig_find'),
          onPressed: _finding || !s.canFind ? null : _find,
          icon: _finding ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded, size: 17),
          label: const Text('Find my Instagram accounts'),
        ),
        if (found != null) ...[
          const SizedBox(height: 6),
          if (found.isEmpty) Text('No Facebook Page is known yet (set META_PAGE_IDS on the server).', key: const Key('meta_ig_found_none'), style: mktText(11.5, color: Mkt.bad)),
          for (final f in found)
            Padding(
              key: Key('meta_ig_found_${f.pageId}'),
              padding: const EdgeInsets.only(top: 4),
              child: f.igId.isEmpty
                  ? Text('${f.pageName.isEmpty ? 'Page ${f.pageId}' : f.pageName}: ${f.problem}', style: mktText(11.5, color: Mkt.inkSoft))
                  : Row(children: [
                      Expanded(child: Text('${f.pageName} → @${f.username} · ${f.igId}', style: mktText(11.5, weight: FontWeight.w600))),
                      IconButton(
                        tooltip: 'Copy the id',
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: f.igId));
                          if (context.mounted) showSuccessSnackBar(context, 'Copied ${f.igId}');
                        },
                      ),
                    ]),
            ),
        ],
      ]),
    );
  }
}

// ── the sync ─────────────────────────────────────────────────────────────────

class _SyncCard extends ConsumerStatefulWidget {
  const _SyncCard({required this.s});
  final MetaIgStatus s;
  @override
  ConsumerState<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends ConsumerState<_SyncCard> {
  int _days = 30;
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(metaIgServiceProvider).syncNow(_days);
      _refreshAll(ref);
      if (!mounted) return;
      r.ok ? showSuccessSnackBar(context, r.summary) : showWarningSnackBar(context, r.summary);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAuto(bool on) async {
    setState(() => _busy = true);
    try {
      await ref.read(metaIgServiceProvider).setAutoSync(on);
      ref.invalidate(metaIgStatusProvider);
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
    final busy = _busy || s.running;
    return MktCard(
      title: 'Post figures',
      icon: Icons.sync_rounded,
      trailing: run == null ? null : MktChip(run.ok ? 'Last sync worked' : 'Last sync failed', key: const Key('meta_ig_last_chip'), color: run.ok ? Mkt.good : Mkt.bad),
      child: Column(key: const Key('meta_ig_sync_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Each post\'s reach, views, likes, comments, shares and saves go onto its Socials post, replacing what was there (Instagram no longer gives impressions: those stay as typed). Followers go onto each account. ${s.syncedPosts} post${s.syncedPosts == 1 ? '' : 's'} take their figures from Instagram.',
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 10),
        if (run == null)
          Text(s.ready ? 'Not synced yet.' : 'Nothing synced: the server is not set up.', key: const Key('meta_ig_never'), style: mktText(12.5, weight: FontWeight.w600))
        else ...[
          Text(run.summary, key: const Key('meta_ig_last_summary'), style: mktText(12.5, weight: FontWeight.w700, color: run.ok ? Mkt.ink : Mkt.bad, height: 1.35)),
          if (run.ok && run.gaps > 0)
            Text('${run.gaps} older post${run.gaps == 1 ? '' : 's'}: Instagram gave only some figures (likes and comments are still there).', key: const Key('meta_ig_gaps'), style: mktText(11.5, color: Mkt.inkSoft)),
          if (run.at != null) Text('${_when.format(run.at!)} · ${run.how}', style: mktText(11, color: Mkt.inkSoft)),
          if (!run.ok && s.lastOkAt != null) Text('Last good sync: ${_when.format(s.lastOkAt!)}', style: mktText(11, color: Mkt.inkSoft)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              s.autoSync ? 'Runs on its own every ${s.everyHours} hours (the last ${s.days} days)${s.nextAutoAt != null && s.ready ? ' · next ${_when.format(s.nextAutoAt!)}' : ''}' : 'Automatic sync is off',
              key: const Key('meta_ig_auto_text'),
              style: mktText(12, weight: FontWeight.w600),
            ),
          ),
          if (s.canManage) Switch(key: const Key('meta_ig_auto'), value: s.autoSync, activeThumbColor: Mkt.primary, onChanged: busy ? null : _setAuto),
        ]),
        if (!s.canManage) Text('Only the Marketing Manager or Admin can switch it.', style: mktText(11, color: Mkt.inkSoft)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<int>(
            key: const Key('meta_ig_days'),
            value: _days,
            underline: const SizedBox.shrink(),
            items: [for (final d in const [7, 30, 90]) DropdownMenuItem(value: d, child: Text('Last $d days', style: mktText(12.5)))],
            onChanged: busy ? null : (v) => setState(() => _days = v ?? 30),
          ),
          MktPrimaryButton(key: const Key('meta_ig_sync_button'), icon: Icons.sync_rounded, label: busy ? 'Syncing…' : 'Sync now', onPressed: busy || !s.ready ? null : _sync),
        ]),
      ]),
    );
  }
}

// ── posts no Socials post matched ────────────────────────────────────────────

class _UnmatchedCard extends ConsumerStatefulWidget {
  const _UnmatchedCard({required this.s});
  final MetaIgStatus s;
  @override
  ConsumerState<_UnmatchedCard> createState() => _UnmatchedCardState();
}

class _UnmatchedCardState extends ConsumerState<_UnmatchedCard> {
  String? _working;
  bool _showIgnored = false;

  Future<void> _do(String key, Future<Object?> Function() action, String done) async {
    setState(() => _working = key);
    try {
      await action();
      _refreshAll(ref);
      if (mounted) showSuccessSnackBar(context, done);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _pickAndLink(MetaIgUnmatched u) async {
    final same = widget.s.choices.where((c) => c.brand == u.brand).toList();
    final picked = await showDialog<MetaIgPostChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        key: const Key('meta_ig_link_dialog'),
        title: Text('Which post is "${u.firstLine.isEmpty ? 'this' : u.firstLine}"?', maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(15, weight: FontWeight.w800)),
        children: same.isEmpty
            ? [Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: Text('No ${u.brandLabel} Instagram post without a link was planned in the last 90 days. Add it as a new post instead.', style: mktText(12.5, color: Mkt.inkSoft)))]
            : [
                for (final c in same)
                  SimpleDialogOption(
                    key: Key('meta_ig_choice_${c.id}'),
                    onPressed: () => Navigator.of(ctx).pop(c),
                    child: Text('${c.title} · ${c.contentType}${c.scheduledDate == null ? '' : ' · ${_day.format(c.scheduledDate!)}'}', style: mktText(13)),
                  ),
              ],
      ),
    );
    if (picked == null || !mounted) return;
    await _do(u.mediaId, () => ref.read(metaIgServiceProvider).link(u.mediaId, picked.id), 'Linked: "${picked.title}" now takes its figures from Instagram.');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final svc = ref.read(metaIgServiceProvider);
    return MktCard(
      title: 'Instagram posts not in Socials',
      icon: Icons.link_off_rounded,
      trailing: s.unmatched.isEmpty ? const MktChip('All matched', color: Mkt.good) : MktChip('${s.unmatched.length} waiting', key: const Key('meta_ig_unmatched_count'), color: Mkt.warn),
      child: Column(key: const Key('meta_ig_unmatched_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          s.unmatched.isEmpty
              ? 'Every recent Instagram post is on its Socials post.'
              : 'These went out on Instagram but match no Socials post (no link typed, or two posts that day). Link each to its planned post, add it as a new published post, or hide it.',
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        for (final u in s.unmatched) _row(u, svc),
        if (s.unmatched.length > 1) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('meta_ig_add_all'),
            onPressed: _working != null ? null : () => _do('*', svc.addAll, 'Added as published posts.'),
            icon: const Icon(Icons.playlist_add_rounded, size: 17),
            label: Text('Add all ${s.unmatched.length} as published posts'),
          ),
        ],
        if (s.ignored.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            key: const Key('meta_ig_ignored_toggle'),
            onTap: () => setState(() => _showIgnored = !_showIgnored),
            child: Text('${s.ignored.length} hidden ${_showIgnored ? '▴' : '▾'}', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
          ),
          if (_showIgnored)
            for (final id in s.ignored)
              Row(children: [
                Expanded(child: Text('Instagram post $id', style: mktText(12))),
                TextButton(key: Key('meta_ig_restore_$id'), onPressed: _working != null ? null : () => _do(id, () => svc.restore(id), 'It shows again from the next sync.'), child: const Text('Show again')),
              ]),
        ],
      ]),
    );
  }

  Widget _row(MetaIgUnmatched u, MetaIgService svc) {
    final busy = _working != null;
    final m = u.metrics;
    return Container(
      key: Key('meta_ig_unmatched_${u.mediaId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(u.firstLine.isEmpty ? 'Untitled ${u.contentType}' : (u.firstLine.length > 60 ? '${u.firstLine.substring(0, 60)}…' : u.firstLine), style: mktText(13, weight: FontWeight.w700)),
          MktChip(u.contentType, color: Mkt.primary),
          MktChip(u.brandLabel, color: Mkt.blue),
        ]),
        Text(
          '${u.at == null ? '' : '${_when.format(u.at!)} · '}${u.username.isEmpty ? '' : '${u.username} · '}reach ${_n.format(m['reach'] ?? 0)} · views ${_n.format(m['views'] ?? 0)} · likes ${_n.format(m['likes'] ?? 0)}',
          style: mktText(11.5, color: Mkt.inkSoft),
        ),
        Wrap(spacing: 6, runSpacing: 4, children: [
          TextButton.icon(key: Key('meta_ig_link_${u.mediaId}'), onPressed: busy ? null : () => _pickAndLink(u), icon: const Icon(Icons.link_rounded, size: 16), label: const Text('Link to a post')),
          TextButton.icon(key: Key('meta_ig_add_${u.mediaId}'), onPressed: busy ? null : () => _do(u.mediaId, () => svc.add(u.mediaId), 'Added as a published post.'), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add as a new post')),
          TextButton(key: Key('meta_ig_ignore_${u.mediaId}'), onPressed: busy ? null : () => _do(u.mediaId, () => svc.ignore(u.mediaId), 'Hidden.'), child: const Text('Hide')),
        ]),
      ]),
    );
  }
}
