import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/marketing/data/meta_leads_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/meta_leads_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The address Meta's webhook set-up asks for: this server's API + /meta/webhook.
String metaWebhookAddress([String base = apiBaseUrl]) => '${base.replaceAll(RegExp(r'/+$'), '')}/meta/webhook';

final _when = DateFormat('d MMM, h:mm a');

/// Marketing → Campaigns → Meta → Lead Ads. Forms filled on Facebook / Instagram ads arrive as CRM leads on their own: this tab says
/// whether the server is set up, who gets the new leads, what came in (and what could not be taken in, with the reason), and can ask
/// Meta for leads the webhook missed. (The page around it, with the Ad spend tab, is meta_screen.dart.)
class MetaLeadAdsTab extends ConsumerWidget {
  const MetaLeadAdsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(metaLeadsStatusProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(metaLeadsStatusProvider);
        ref.invalidate(metaEventsProvider);
        await ref.read(metaLeadsStatusProvider.future).catchError((_) => const MetaLeadsStatus());
      },
      child: ListView(
        key: const Key('meta_leads_list'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          status.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MktCard(title: 'Meta Lead Ads', child: MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline, key: const Key('meta_status_error'))),
            data: (s) => _Body(s: s),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.s});
  final MetaLeadsStatus s;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MktKpiRow(
        key: const Key('meta_counts'),
        children: [
          MktKpiCard(icon: Icons.person_add_alt_1_outlined, value: '${s.created}', label: 'New leads', note: 'last 30 days', tint: Mkt.good),
          MktKpiCard(icon: Icons.repeat_rounded, value: '${s.existing}', label: 'Already a lead', note: 'noted on her lead', tint: Mkt.blue),
          MktKpiCard(icon: Icons.error_outline_rounded, value: '${s.failed}', label: 'Not taken in', note: s.failed > 0 ? 'see the reasons below' : 'none', tint: s.failed > 0 ? Mkt.bad : Mkt.grey),
          MktKpiCard(icon: Icons.hourglass_empty_rounded, value: '${s.waiting}', label: 'Waiting', note: s.lastLeadAt == null ? 'no lead yet' : 'last lead ${_when.format(s.lastLeadAt!)}', tint: Mkt.warn),
        ],
      ),
      const SizedBox(height: 12),
      MktGrid(rows: [
        [(6, _ConnectionCard(s: s)), (5, _AssignCard(s: s))],
      ]),
      const SizedBox(height: 12),
      _CheckCard(s: s),
      const SizedBox(height: 12),
      const _EventsCard(),
    ],
  );
}

// ── connection ───────────────────────────────────────────────────────────────

class _ConnectionCard extends ConsumerStatefulWidget {
  const _ConnectionCard({required this.s});
  final MetaLeadsStatus s;
  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  bool _testing = false;
  MetaTestResult? _result;

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final r = await ref.read(metaLeadsServiceProvider).test();
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _has(String key, String label, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(key: Key('meta_has_$key'), children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: ok ? Mkt.good : Mkt.bad),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: mktText(12.5))),
      Text(ok ? 'Set' : 'Missing', style: mktText(11.5, weight: FontWeight.w700, color: ok ? Mkt.good : Mkt.bad)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.s.config;
    final address = metaWebhookAddress();
    final r = _result;
    return MktCard(
      title: 'Connection',
      icon: Icons.link_rounded,
      trailing: MktChip(c.ready ? 'Receiving leads' : 'Not set up', key: const Key('meta_ready_chip'), color: c.ready ? Mkt.good : Mkt.grey),
      child: Column(key: const Key('meta_connection_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('The keys live on the server, never in the app. The server only says whether each one is set.', style: mktText(12, color: Mkt.inkSoft, height: 1.35)),
        const SizedBox(height: 8),
        _has('appSecret', 'App secret (META_APP_SECRET)', c.appSecret),
        _has('token', 'Access token (META_ACCESS_TOKEN)', c.token),
        _has('verifyToken', 'Webhook verify token (META_WEBHOOK_VERIFY_TOKEN)', c.verifyToken),
        const SizedBox(height: 10),
        Text('Webhook address for Meta', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
        const SizedBox(height: 2),
        Row(children: [
          Expanded(child: SelectableText(address, key: const Key('meta_webhook_address'), style: mktText(12.5, weight: FontWeight.w600))),
          IconButton(
            key: const Key('meta_copy_address'),
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 17),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: address));
              if (context.mounted) showSuccessSnackBar(context, 'Webhook address copied');
            },
          ),
        ]),
        Text('Subscribe the Page to the "leadgen" field. Graph API ${c.version.isEmpty ? '' : c.version}', style: mktText(11.5, color: Mkt.inkSoft)),
        if (!c.ready) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('meta_setup_steps'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('To switch it on', style: mktText(12, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              for (final (i, t) in const [
                'In Meta Business Manager, make a business app and a system user with the Page.',
                'Give the app leads_retrieval, pages_manage_metadata, pages_show_list and pages_read_engagement (App Review).',
                'Put the app secret, the system user\'s token and a verify token of your choosing in the server\'s settings, then restart it.',
                'In the app\'s Webhooks, use the address above and the same verify token, and subscribe the Page to "leadgen".',
              ].indexed)
                Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Text('${i + 1}. $t', style: mktText(11.5, height: 1.35))),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('meta_test_button'),
          onPressed: _testing || !c.ready ? null : _test,
          icon: _testing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering_rounded, size: 17),
          label: const Text('Test connection'),
        ),
        if (r != null) ...[
          const SizedBox(height: 8),
          Text(
            r.ok ? 'Connected as ${r.name.isEmpty ? 'the system user' : r.name}' : r.problem,
            key: const Key('meta_test_result'),
            style: mktText(12, weight: FontWeight.w700, color: r.ok ? Mkt.good : Mkt.bad),
          ),
          for (final p in r.pages)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                p.ok ? 'Page ${p.name.isEmpty ? p.id : p.name}: can be read' : 'Page ${p.id}: ${p.problem}',
                style: mktText(11.5, color: p.ok ? Mkt.ink : Mkt.bad),
              ),
            ),
          if (r.ok && r.pages.isEmpty) Text('No Page known yet: the first lead Meta sends teaches it.', style: mktText(11.5, color: Mkt.inkSoft)),
        ],
      ]),
    );
  }
}

// ── who gets new leads ─────────────────────────────────────────────────────

class _AssignCard extends ConsumerStatefulWidget {
  const _AssignCard({required this.s});
  final MetaLeadsStatus s;
  @override
  ConsumerState<_AssignCard> createState() => _AssignCardState();
}

class _AssignCardState extends ConsumerState<_AssignCard> {
  late String _mode = widget.s.assignMode;
  late Set<String> _picked = widget.s.rotateUsers.where((u) => u.active).map((u) => u.id).toSet();
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _AssignCard old) {
    super.didUpdateWidget(old);
    if (old.s != widget.s) {
      _mode = widget.s.assignMode;
      _picked = widget.s.rotateUsers.where((u) => u.active).map((u) => u.id).toSet();
    }
  }

  bool get _changed {
    final was = widget.s.rotateUsers.where((u) => u.active).map((u) => u.id).toSet();
    return _mode != widget.s.assignMode || (_mode == 'rotate' && (_picked.length != was.length || !_picked.containsAll(was)));
  }

  Future<void> _save() async {
    if (_mode == 'rotate' && _picked.isEmpty) {
      showWarningSnackBar(context, 'Choose at least one Sales person to take turns.');
      return;
    }
    setState(() => _saving = true);
    try {
      final order = widget.s.assignees.map((a) => a.id).where(_picked.contains).toList();
      await ref.read(metaLeadsServiceProvider).saveAssignment(_mode, _mode == 'rotate' ? order : const []);
      ref.invalidate(metaLeadsStatusProvider);
      if (mounted) showSuccessSnackBar(context, 'Saved. New Meta leads follow it from now on.');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final now = s.rotates ? 'Sales take turns: ${s.rotateUsers.map((u) => u.active ? u.name : '${u.name} (no longer active)').join(', ')}.' : 'New Meta leads wait unassigned until a manager gives them out.';
    return MktCard(
      title: 'Who gets new leads',
      icon: Icons.groups_2_outlined,
      child: Column(key: const Key('meta_assign_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(now, key: const Key('meta_assign_now'), style: mktText(12.5, weight: FontWeight.w600, height: 1.35)),
        if (s.updatedByName.isNotEmpty) Text('Set by ${s.updatedByName}', style: mktText(11, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        Text('A lead whose number is already in the CRM is never added again: it is noted on her lead and its owner is told.', style: mktText(11.5, color: Mkt.inkSoft, height: 1.35)),
        if (!s.canManage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Only the Marketing Manager or Admin can change this.', key: const Key('meta_assign_readonly'), style: mktText(11.5, color: Mkt.inkSoft)),
          )
        else ...[
          const SizedBox(height: 10),
          RadioGroup<String>(
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v ?? 'none'),
            child: Column(children: [
              RadioListTile<String>(key: const Key('meta_mode_none'), dense: true, contentPadding: EdgeInsets.zero, value: 'none', title: Text('Nobody yet: a manager assigns them', style: mktText(12.5))),
              RadioListTile<String>(key: const Key('meta_mode_rotate'), dense: true, contentPadding: EdgeInsets.zero, value: 'rotate', title: Text('Sales take turns', style: mktText(12.5))),
            ]),
          ),
          if (_mode == 'rotate') ...[
            if (s.assignees.isEmpty)
              Text('There is no active Sales login to choose.', style: mktText(11.5, color: Mkt.bad))
            else
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in s.assignees)
                  FilterChip(
                    key: Key('meta_assignee_${a.id}'),
                    label: Text(a.name, style: mktText(12)),
                    selected: _picked.contains(a.id),
                    selectedColor: Mkt.primarySoft,
                    checkmarkColor: Mkt.primary,
                    side: BorderSide(color: _picked.contains(a.id) ? Mkt.primarySoft : Mkt.border),
                    onSelected: (on) => setState(() => on ? _picked.add(a.id) : _picked.remove(a.id)),
                  ),
              ]),
          ],
          const SizedBox(height: 10),
          MktPrimaryButton(key: const Key('meta_assign_save'), icon: Icons.check_rounded, label: _saving ? 'Saving…' : 'Save', onPressed: _saving || !_changed ? null : _save),
        ],
      ]),
    );
  }
}

// ── missed leads ─────────────────────────────────────────────────────────────

class _CheckCard extends ConsumerStatefulWidget {
  const _CheckCard({required this.s});
  final MetaLeadsStatus s;
  @override
  ConsumerState<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends ConsumerState<_CheckCard> {
  int _days = 7;
  bool _running = false;
  MetaCheckResult? _result;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final r = await ref.read(metaLeadsServiceProvider).checkMissed(_days);
      if (!mounted) return;
      setState(() => _result = r);
      ref.invalidate(metaLeadsStatusProvider);
      ref.invalidate(metaEventsProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _result ?? widget.s.lastCheck;
    final ready = widget.s.config.ready;
    return MktCard(
      title: 'Check for missed leads',
      icon: Icons.manage_search_rounded,
      child: Column(key: const Key('meta_check_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Reads every form\'s leads straight from Meta and takes in any that never arrived (for example while the server was down). Leads already here are left as they are.',
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<int>(
            key: const Key('meta_check_days'),
            value: _days,
            underline: const SizedBox.shrink(),
            items: [for (final d in const [1, 3, 7, 30, 90]) DropdownMenuItem(value: d, child: Text(d == 1 ? 'Last day' : 'Last $d days', style: mktText(12.5)))],
            onChanged: _running ? null : (v) => setState(() => _days = v ?? 7),
          ),
          MktPrimaryButton(
            key: const Key('meta_check_button'),
            icon: Icons.sync_rounded,
            label: _running ? 'Checking…' : 'Check now',
            onPressed: _running || !ready ? null : _run,
          ),
        ]),
        if (last != null) ...[
          const SizedBox(height: 8),
          Text(last.summary, key: const Key('meta_last_check'), style: mktText(12, weight: FontWeight.w700, color: last.failed > 0 || (last.forms == 0 && last.problem.isNotEmpty) ? Mkt.bad : Mkt.ink)),
          if (last.problem.isNotEmpty && last.forms > 0) Text(last.problem, style: mktText(11.5, color: Mkt.bad)),
          if (last.at != null) Text('${_when.format(last.at!)}${last.byName.isEmpty ? '' : ' · ${last.byName}'}', style: mktText(11, color: Mkt.inkSoft)),
        ],
      ]),
    );
  }
}

// ── what came in ─────────────────────────────────────────────────────────────

const _filters = [('all', 'All'), ('created', 'New lead'), ('existing', 'Already a lead'), ('failed', 'Not taken in'), ('waiting', 'Waiting')];

class _EventsCard extends ConsumerWidget {
  const _EventsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(metaEventsFilterProvider);
    final page = ref.watch(metaEventsPageProvider);
    final events = ref.watch(metaEventsProvider);
    final canOpenLeads = Access.of(ref.watch(authSessionProvider)).canSeeSub('sales.leads');
    return MktCard(
      title: 'Leads from Meta',
      icon: Icons.inbox_outlined,
      child: Column(key: const Key('meta_events_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (key, label) in _filters)
            MktFilterChip(
              key: Key('meta_filter_$key'),
              label: label,
              selected: filter == key,
              onTap: () {
                ref.read(metaEventsFilterProvider.notifier).state = key;
                ref.read(metaEventsPageProvider.notifier).state = 1;
              },
            ),
        ]),
        const SizedBox(height: 8),
        events.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline),
          data: (p) => p.items.isEmpty
              ? MktEmpty(filter == 'all' ? 'No lead has come from Meta yet.' : 'Nothing here.', key: const Key('meta_events_empty'))
              : Column(children: [
                  for (final e in p.items) _EventRow(e: e, canOpenLead: canOpenLeads),
                  if (p.pages > 1)
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('Page ${p.page} of ${p.pages} · ${p.total} leads', style: mktText(11.5, color: Mkt.inkSoft)),
                      IconButton(key: const Key('meta_page_prev'), onPressed: page > 1 ? () => ref.read(metaEventsPageProvider.notifier).state = page - 1 : null, icon: const Icon(Icons.chevron_left_rounded)),
                      IconButton(key: const Key('meta_page_next'), onPressed: page < p.pages ? () => ref.read(metaEventsPageProvider.notifier).state = page + 1 : null, icon: const Icon(Icons.chevron_right_rounded)),
                    ]),
                ]),
        ),
      ]),
    );
  }
}

class _EventRow extends ConsumerStatefulWidget {
  const _EventRow({required this.e, required this.canOpenLead});
  final MetaLeadEvent e;
  final bool canOpenLead;
  @override
  ConsumerState<_EventRow> createState() => _EventRowState();
}

class _EventRowState extends ConsumerState<_EventRow> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      final after = await ref.read(metaLeadsServiceProvider).retry(widget.e.id);
      ref.invalidate(metaEventsProvider);
      ref.invalidate(metaLeadsStatusProvider);
      if (!mounted) return;
      if (after.failed) {
        showWarningSnackBar(context, after.problemText.isEmpty ? 'Still not taken in.' : after.problemText);
      } else {
        showSuccessSnackBar(context, after.status == 'existing' ? 'Taken in: the number was already a lead.' : 'Taken in as a new lead.');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final color = switch (e.status) { 'created' => Mkt.good, 'existing' => Mkt.blue, 'failed' => Mkt.bad, _ => Mkt.warn };
    final when = e.submittedAt ?? e.receivedAt;
    return Container(
      key: Key('meta_event_${e.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MktAvatar(e.leadName.isEmpty ? '?' : e.leadName, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(e.leadName.isEmpty ? 'No name given' : e.leadName, style: mktText(13, weight: FontWeight.w700)),
              MktChip(e.statusLabel, color: color),
              if (e.via == 'check') const MktChip('found by a check', color: Mkt.grey),
            ]),
            const SizedBox(height: 2),
            Text(e.origin, style: mktText(11.5, color: Mkt.inkSoft)),
            Text(
              [
                if (when != null) _when.format(when),
                if (e.assignedToName.isNotEmpty) 'given to ${e.assignedToName}',
                if (e.email.isNotEmpty) e.email,
              ].join(' · '),
              style: mktText(11, color: Mkt.inkSoft),
            ),
            if (e.failed) ...[
              const SizedBox(height: 3),
              Text(e.problemText, key: Key('meta_problem_${e.id}'), style: mktText(11.5, color: Mkt.bad, height: 1.3)),
              Text(
                e.retry && e.nextTryAt != null ? 'Tried ${e.attempts} time${e.attempts == 1 ? '' : 's'} · next try ${_when.format(e.nextTryAt!)}' : 'Will not be tried again on its own',
                style: mktText(11, color: Mkt.inkSoft),
              ),
            ],
          ]),
        ),
        if (e.failed)
          TextButton.icon(
            key: Key('meta_retry_${e.id}'),
            onPressed: _retrying ? null : _retry,
            icon: _retrying ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
          )
        else if (e.leadId != null && widget.canOpenLead)
          TextButton(
            key: Key('meta_open_${e.id}'),
            onPressed: () => GoRouter.maybeOf(context)?.go('/sales/leads/${e.leadId}'),
            child: const Text('Open lead'),
          ),
      ]),
    );
  }
}
