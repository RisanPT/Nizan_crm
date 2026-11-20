import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// Clients to call again (/crm/re-engagement): past clients whose last event was months ago and who have not booked since. Tick them and
/// make call cases — the head gives them to someone, a member takes them. A client already being called is marked.
class CrmReEngagementScreen extends ConsumerStatefulWidget {
  const CrmReEngagementScreen({super.key});

  @override
  ConsumerState<CrmReEngagementScreen> createState() => _CrmReEngagementScreenState();
}

class _CrmReEngagementScreenState extends ConsumerState<CrmReEngagementScreen> {
  int _months = 6;
  final Set<String> _selected = {};
  bool _busy = false;
  static final _day = DateFormat('d MMM yyyy');

  Future<void> _make(CrmMe me, List<ReEngagementClient> chosen) async {
    String? owner;
    if (me.canAssign) {
      owner = await showCrmAssignDialog(context, count: chosen.length, title: 'Who calls them?');
      if (owner == null) return;
    }
    setState(() => _busy = true);
    try {
      final (made, skipped) = await ref.read(crmServiceProvider).createCallCases(chosen, ownerId: (owner == null || owner.isEmpty) ? null : owner);
      refreshCrm(ref);
      if (mounted) {
        setState(_selected.clear);
        showSuccessSnackBar(context, '$made call ${made == 1 ? 'case' : 'cases'} made${skipped > 0 ? ' · $skipped already being called' : ''}');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final me = ref.watch(crmMeProvider).value;
    final async = ref.watch(crmReEngagementProvider(_months));
    final clients = async.value ?? const <ReEngagementClient>[];
    final chosen = clients.where((c) => _selected.contains(c.phoneKey)).toList();
    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/crm/cases')),
        title: const Text('Clients to call again'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('No event for', style: TextStyle(color: crm.textSecondary)),
                for (final m in const [3, 6, 12, 24])
                  ChoiceChip(label: Text('$m months'), selected: _months == m, onSelected: (_) => setState(() {
                    _months = m;
                    _selected.clear();
                  })),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmReEngagementProvider(_months))),
              data: (list) => list.isEmpty
                  ? Center(child: Text('Nobody to call.', style: TextStyle(color: crm.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        final can = (me?.canWrite ?? false) && !c.hasOpenCase;
                        return CrmPanel(
                          key: Key('crmReClient_${c.phoneKey}'),
                          margin: const EdgeInsets.only(bottom: 8),
                          radius: 12,
                          child: CheckboxListTile(
                            value: _selected.contains(c.phoneKey),
                            onChanged: can ? (v) => setState(() => v == true ? _selected.add(c.phoneKey) : _selected.remove(c.phoneKey)) : null,
                            title: Text(c.customerName.isEmpty ? c.phone : c.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [
                                c.phone,
                                if (c.service.isNotEmpty) c.service,
                                if (c.lastEventDate != null) 'last event ${_day.format(c.lastEventDate!)} (${c.monthsSince} months)',
                                '${c.bookings} ${c.bookings == 1 ? 'booking' : 'bookings'}',
                                if (c.hasOpenCase) 'being called by ${c.openCaseOwner.isEmpty ? 'the team' : c.openCaseOwner}',
                                if (!c.hasOpenCase && c.lastOutcome.isNotEmpty) 'last call: ${crmOutcomeLabel(c.lastOutcome)}',
                              ].join(' · '),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (chosen.isNotEmpty && me != null)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
                child: Row(children: [
                  Expanded(child: Text('${chosen.length} ticked', style: const TextStyle(fontWeight: FontWeight.w700))),
                  FilledButton.icon(
                    key: const Key('crmMakeCalls'),
                    onPressed: _busy ? null : () => _make(me, chosen),
                    icon: const Icon(Icons.phone_forwarded_outlined, size: 18),
                    label: Text(me.canAssign ? 'Make call cases…' : 'I\'ll call them'),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
