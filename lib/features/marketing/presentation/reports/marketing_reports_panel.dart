import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamBrand;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

final _dayFmt = DateFormat('d MMM yyyy');
final _whenFmt = DateFormat('d MMM, h:mm a');

String _period(MarketingSavedReport r) {
  final a = DateTime.tryParse(r.from);
  final b = DateTime.tryParse(r.to);
  if (a == null || b == null) return '${r.from} – ${r.to}';
  return a == b ? _dayFmt.format(a) : '${DateFormat('d MMM').format(a)} – ${_dayFmt.format(b)}';
}

/// Keeps a report someone just generated (downloaded) in the module's "Saved reports" — the same report made again is the same entry,
/// brought to the top. A failure to keep it never stops the download: it is only a list.
Future<void> keepGeneratedReport(WidgetRef ref, {required String module, required String kind, required String name, required String from, required String to, String brand = 'all'}) async {
  try {
    await ref.read(marketingReportsServiceProvider).save(module: module, kind: kind, name: name, from: from, to: to, brand: brand);
    ref.invalidate(marketingSavedReportsProvider(module));
  } catch (_) {
    // the report itself was made; the list just misses it
  }
}

/// Puts a saved report's period and brand on the shared Marketing date range and brand (every Marketing screen reads it).
void showSavedReportPeriod(WidgetRef ref, MarketingSavedReport r) {
  final from = DateTime.tryParse(r.from);
  final to = DateTime.tryParse(r.to);
  if (from == null || to == null) return;
  final f = ref.read(teamFilterProvider);
  ref.read(teamFilterProvider.notifier).state = f.copyWith(from: from, to: to, brand: r.brand == 'all' ? TeamBrand.all : TeamBrand.parse(r.brand));
}

/// The saved report a link names (`?report=<id>` — the "report ready" notification opens the Reports tab with it), if any.
String? _linkedReportId(BuildContext context) {
  try {
    final id = GoRouterState.of(context).uri.queryParameters['report'];
    return (id == null || id.isEmpty) ? null : id;
  } catch (_) {
    return null; // not under a route (a test, a dialog)
  }
}

/// "Saved reports" and "Scheduled reports" on a module's Reports tab (Team Dashboard, Campaigns, Lead Report — the spec draws both on
/// each). [module] is team | campaigns | leads. [onOpen] runs the module's own report for a saved one (its kind, period and brand). A
/// link that names a saved report ([openId], else the route's `?report=`) opens it once, when the list has loaded.
class MarketingReportsPanel extends ConsumerStatefulWidget {
  const MarketingReportsPanel({super.key, required this.module, required this.onOpen, this.openId});
  final String module;
  final void Function(MarketingSavedReport report) onOpen;
  final String? openId;

  @override
  ConsumerState<MarketingReportsPanel> createState() => _MarketingReportsPanelState();
}

class _MarketingReportsPanelState extends ConsumerState<MarketingReportsPanel> {
  bool _linkHandled = false;

  void _openLinked(List<MarketingSavedReport> list) {
    if (_linkHandled) return;
    final id = widget.openId ?? _linkedReportId(context);
    if (id == null) {
      _linkHandled = true;
      return;
    }
    final r = list.where((x) => x.id == id).firstOrNull;
    _linkHandled = true;
    if (r == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpen(r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(marketingSavedReportsProvider(widget.module)).value;
    if (list != null) _openLinked(list);
    return LayoutBuilder(builder: (context, c) {
      final saved = _SavedCard(module: widget.module, onOpen: widget.onOpen);
      final scheduled = _ScheduledCard(module: widget.module);
      if (c.maxWidth < 900) return Column(children: [saved, const SizedBox(height: 14), scheduled]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: saved), const SizedBox(width: 14), Expanded(flex: 2, child: scheduled)]);
    });
  }
}

class _SavedCard extends ConsumerWidget {
  const _SavedCard({required this.module, required this.onOpen});
  final String module;
  final void Function(MarketingSavedReport report) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketingSavedReportsProvider(module));
    return MktCard(
      key: Key('mktSavedReports_$module'),
      title: 'Saved reports',
      icon: Icons.folder_open_outlined,
      subtitle: 'Reports generated here or by a schedule — open one to run it again for its period',
      child: async.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline),
        data: (list) => list.isEmpty
            ? const MktEmpty('No saved reports yet. Generate one above and it is kept here.')
            : Column(children: [
                for (final r in list)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('mktSavedReport_${r.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onOpen(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(children: [
                          Icon(r.scheduled ? Icons.schedule : Icons.description_outlined, size: 18, color: Mkt.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w700)),
                              Text(
                                [_period(r), if (r.brand != 'all') (r.brand == 'kerala' ? 'Kerala' : 'Main'), r.createdByName, if (r.createdAt != null) _whenFmt.format(r.createdAt!)]
                                    .where((x) => x.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: mktText(11.5, color: Mkt.inkSoft),
                              ),
                            ]),
                          ),
                          IconButton(
                            key: Key('mktSavedReportOpen_${r.id}'),
                            tooltip: 'Open / download',
                            icon: const Icon(Icons.download_outlined, size: 18),
                            onPressed: () => onOpen(r),
                          ),
                          if (r.mine)
                            IconButton(
                              key: Key('mktSavedReportRemove_${r.id}'),
                              tooltip: 'Remove from the list',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                try {
                                  await ref.read(marketingReportsServiceProvider).remove(r.id);
                                  ref.invalidate(marketingSavedReportsProvider(module));
                                } catch (e) {
                                  if (context.mounted) showErrorSnackBar(context, e);
                                }
                              },
                            ),
                        ]),
                      ),
                    ),
                  ),
              ]),
      ),
    );
  }
}

class _ScheduledCard extends ConsumerWidget {
  const _ScheduledCard({required this.module});
  final String module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketingReportSchedulesProvider(module));
    return MktCard(
      key: Key('mktScheduledReports_$module'),
      title: 'Scheduled reports',
      icon: Icons.schedule,
      subtitle: 'Made for the period that has just ended; the marketing managers get a notification',
      child: async.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => MktEmpty(friendlyErrorMessage(e), icon: Icons.error_outline),
        data: (data) {
          final (canManage, list) = data;
          if (list.isEmpty) return const MktEmpty('No scheduled reports.');
          return Column(children: [
            for (final s in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.label, style: mktText(13, weight: FontWeight.w700)),
                      Text(
                        [s.when, if (s.enabled && s.nextRunAt != null) 'next ${_whenFmt.format(s.nextRunAt!)}'].join(' · '),
                        style: mktText(11.5, color: Mkt.inkSoft),
                      ),
                    ]),
                  ),
                  if (canManage)
                    IconButton(
                      key: Key('mktScheduleTime_${s.key}'),
                      tooltip: 'Change the time',
                      icon: const Icon(Icons.access_time, size: 18),
                      onPressed: () async {
                        final parts = s.time.split(':');
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 10, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
                        );
                        if (picked == null || !context.mounted) return;
                        final hhmm = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        await _change(context, ref, s.key, {'time': hhmm});
                      },
                    ),
                  Switch(
                    key: Key('mktScheduleSwitch_${s.key}'),
                    value: s.enabled,
                    activeThumbColor: Mkt.primary,
                    onChanged: canManage ? (v) => _change(context, ref, s.key, {'enabled': v}) : null,
                  ),
                ]),
              ),
            if (!canManage) Text('Only the Marketing Manager switches these.', style: mktText(11, color: Mkt.inkSoft)),
          ]);
        },
      ),
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref, String key, Map<String, dynamic> change) async {
    try {
      await ref.read(marketingReportsServiceProvider).updateSchedule(key, change);
      ref.invalidate(marketingReportSchedulesProvider(module));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }
}
