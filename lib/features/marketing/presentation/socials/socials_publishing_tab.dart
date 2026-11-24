import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/post_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Socials → Publishing & Accounts: the accounts the team posts on (with followers) and the queue of what is waiting to go out.
/// No platform API is connected, so an account is "Manual": posts and figures are typed in.
class SocialsPublishingTab extends ConsumerWidget {
  const SocialsPublishingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(socialsPublishingProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshSocials(ref))]),
        data: (d) => ListView(
          key: const Key('socials_publishing_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            MktGrid(breakpoint: 900, rows: [
              [(5, _AccountsCard(accounts: d.accounts)), (7, _QueueCard(queue: d.queue))],
              [(12, _RecentCard(recent: d.recent))],
            ]),
          ],
        ),
      ),
    );
  }
}

class _AccountsCard extends ConsumerWidget {
  const _AccountsCard({required this.accounts});
  final List<SocialAccount> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MktCard(
      title: 'Connected Accounts',
      icon: Icons.link_rounded,
      trailing: TextButton(key: const Key('soc_account_add'), onPressed: () => _showAccountForm(context, ref), child: Text('+ Add account', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.violet))),
      child: accounts.isEmpty
          ? const MktEmpty('No account is listed yet. Add the pages the team posts on.', icon: Icons.link_off_rounded)
          : Column(children: [
              for (final a in accounts)
                InkWell(
                  key: Key('soc_account_${a.id}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showAccountForm(context, ref, account: a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: Mkt.tint(Mkt.violet), borderRadius: BorderRadius.circular(10)), child: Icon(platformIcon(a.platform), size: 18, color: Mkt.violet)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${platformName(a.platform)} (${a.brand == 'kerala' ? 'Kerala' : 'Main'})', style: mktText(12.5, weight: FontWeight.w700)),
                          Text(a.handle.isEmpty ? '—' : a.handle, style: mktText(11, color: Mkt.inkSoft)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(compactCount(a.followers), style: mktText(12.5, weight: FontWeight.w800)),
                        Text('followers', style: mktText(10, color: Mkt.inkSoft)),
                      ]),
                      const SizedBox(width: 10),
                      MktChip(switch (a.status) { 'connected' => 'Connected', 'disconnected' => 'Disconnected', _ => 'Manual' }, color: a.status == 'connected' ? Mkt.good : (a.status == 'disconnected' ? Mkt.bad : Mkt.grey)),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

Future<void> _showAccountForm(BuildContext context, WidgetRef ref, {SocialAccount? account}) => showDialog<void>(context: context, builder: (_) => Dialog(child: _AccountForm(account: account)));

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.account});
  final SocialAccount? account;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  late final _handle = TextEditingController(text: widget.account?.handle ?? '');
  late final _followers = TextEditingController(text: (widget.account?.followers ?? 0) == 0 ? '' : '${widget.account!.followers}');
  late String _platform = widget.account?.platform ?? 'instagram';
  late String _brand = widget.account?.brand ?? 'main';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _followers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(marketingSocialsServiceProvider).saveAccount({'platform': _platform, 'brand': _brand, 'handle': _handle.text.trim(), if (_followers.text.trim().isNotEmpty) 'followers': int.tryParse(_followers.text.trim()) ?? -1}, id: widget.account?.id);
      refreshSocials(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _remove() async {
    try {
      await ref.read(marketingSocialsServiceProvider).deleteAccount(widget.account!.id);
      refreshSocials(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() => _error = r.message);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, isDense: true, border: const OutlineInputBorder());
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.account == null ? 'Add account' : 'Edit account', style: mktText(19, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(key: const Key('acct_platform'), isExpanded: true, initialValue: _platform, decoration: dec('Platform'), items: [for (final p in kPlatforms) DropdownMenuItem(value: p.$1, child: Text(p.$2))], onChanged: widget.account == null ? (v) => setState(() => _platform = v ?? _platform) : null)),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(key: const Key('acct_brand'), isExpanded: true, initialValue: _brand, decoration: dec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
          ]),
          const SizedBox(height: 10),
          TextField(key: const Key('acct_handle'), controller: _handle, decoration: dec('Handle', hint: '@teamnbridal')),
          const SizedBox(height: 10),
          TextField(key: const Key('acct_followers'), controller: _followers, keyboardType: TextInputType.number, decoration: dec('Followers today', hint: 'from the platform')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('acct_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
          const SizedBox(height: 14),
          Row(children: [
            if (widget.account != null) TextButton(key: const Key('acct_remove'), onPressed: _saving ? null : _remove, child: const Text('Remove', style: TextStyle(color: Mkt.bad))),
            const Spacer(),
            OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(key: const Key('acct_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : _save, child: const Text('Save')),
          ]),
        ]),
      ),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.queue});
  final List<SocialPost> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MktCard(
      title: 'Publishing Queue (${queue.length})',
      icon: Icons.schedule_send_outlined,
      trailing: MktPrimaryButton(key: const Key('soc_schedule_post'), label: 'Schedule Post', onPressed: () => showPostEditor(context, ref, status: 'scheduled')),
      child: queue.isEmpty
          ? const MktEmpty('Nothing is waiting to go out. Schedule a post, or send one for review from the calendar.', icon: Icons.schedule_send_outlined)
          : Column(children: [
              for (final p in queue)
                InkWell(
                  key: Key('soc_queue_${p.id}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showPostEditor(context, ref, post: p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      PostThumb(url: p.thumbUrl, contentType: p.contentType, width: 44, height: 44, radius: 9),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                          Row(children: [Icon(platformIcon(p.platform), size: 12, color: Mkt.inkSoft), const SizedBox(width: 4), Text('${platformName(p.platform)} · ${postFormatLabel(p.contentType)} · ${p.brand == 'kerala' ? 'Kerala' : 'Main'}', style: mktText(10.5, color: Mkt.inkSoft))]),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(p.scheduledDate == null ? '' : DateFormat('d MMM, h:mm a').format(p.scheduledDate!), style: mktText(11, weight: FontWeight.w600)),
                        MktChip(p.status == 'in-review' ? 'In Review' : 'Scheduled', color: stageColor(stageKeyOf(p.status))),
                      ]),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.recent});
  final List<SocialPost> recent;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Recently Published',
      icon: Icons.check_circle_outline_rounded,
      child: recent.isEmpty
          ? const MktEmpty('Nothing has been published yet.', icon: Icons.check_circle_outline_rounded, height: 80)
          : Column(children: [
              for (final p in recent)
                Padding(
                  key: Key('soc_published_${p.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    PostThumb(url: p.thumbUrl, contentType: p.contentType, width: 34, height: 34, radius: 8),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
                    Text('${platformName(p.platform)} (${p.brand == 'kerala' ? 'Kerala' : 'Main'})', style: mktText(11, color: Mkt.inkSoft)),
                    const SizedBox(width: 12),
                    Text(p.publishedDate == null ? '' : DateFormat('d MMM').format(p.publishedDate!), style: mktText(11, weight: FontWeight.w600)),
                  ]),
                ),
            ]),
    );
  }
}
