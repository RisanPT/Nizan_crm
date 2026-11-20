import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/footage_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/footage/work_footage_card.dart' show footageLinkOpenerProvider;
import 'package:nizan_crm/features/marketing/presentation/media/dropbox_folder_view.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/footage_service.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';

/// Creative Portfolio → Footage: the raw footage the artists handed in from their works (a Dropbox link from the work card, or found in
/// the work's Dropbox folder), newest first — hand it to an editor (a task on their Team Dashboard), then mark it edited — and the works
/// still owing footage (they need content: the booking asks for it, or a shoot covers it; their day has come; nothing is in).
/// Each piece of footage is also a raw asset in the Gallery, under the shoot that covers the work.
class FootageTab extends ConsumerStatefulWidget {
  const FootageTab({super.key});
  @override
  ConsumerState<FootageTab> createState() => _FootageTabState();
}

class _FootageTabState extends ConsumerState<FootageTab> {
  String _status = 'all';

  static String statusLabel(String s) => switch (s) { 'new' => 'New', 'in_edit' => 'Being edited', 'edited' => 'Edited', _ => s };
  static Color statusColor(String s) => switch (s) { 'new' => Mkt.blue, 'in_edit' => Mkt.warn, 'edited' => Mkt.good, _ => Mkt.grey };

  Future<void> _set(FootageItem it, String status, {String? editor}) async {
    try {
      await ref.read(footageServiceProvider).setStatus(it.id, status, editorMemberId: editor);
      refreshFootage(ref);
      if (mounted && status == 'in_edit') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to the editor — it is on their Team Dashboard as a task.')));
    } on TeamRefusal catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _toEditor(FootageItem it) async {
    final setup = await ref.read(shootSetupProvider.future);
    if (!mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Who edits it?'),
        children: [
          if (setup.members.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('The team list is empty.')),
          for (final m in setup.members) SimpleDialogOption(key: Key('footage_editor_${m.id}'), onPressed: () => Navigator.pop(c, m.id), child: Text(m.role.isEmpty ? m.name : '${m.name} · ${m.role}')),
        ],
      ),
    );
    if (id != null) await _set(it, 'in_edit', editor: id);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(footageInboxProvider(_status));
    return RefreshIndicator(
      onRefresh: () async => refreshFootage(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshFootage(ref))]),
        data: (d) {
          final c = d.counts;
          return ListView(
            key: const Key('pf_footage_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 170, children: [
                MktKpiCard(key: const Key('ft_kpi_waiting'), icon: Icons.hourglass_top_rounded, value: '${c['waiting'] ?? 0}', label: 'Works owing footage', tint: (c['waiting'] ?? 0) > 0 ? Mkt.bad : Mkt.good),
                MktKpiCard(key: const Key('ft_kpi_new'), icon: Icons.move_to_inbox_outlined, value: '${c['new'] ?? 0}', label: 'New footage', tint: Mkt.blue),
                MktKpiCard(key: const Key('ft_kpi_edit'), icon: Icons.movie_edit, value: '${c['in_edit'] ?? 0}', label: 'Being edited', tint: Mkt.warn),
                MktKpiCard(key: const Key('ft_kpi_edited'), icon: Icons.check_circle_outline_rounded, value: '${c['edited'] ?? 0}', label: 'Edited', tint: Mkt.good),
              ]),
              const SizedBox(height: 12),
              if (!d.dropboxEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Artists upload to Dropbox themselves (in the folder named after the work) and paste the link on their work card. With a Dropbox app connected on the server, they could upload straight from the card.', key: const Key('ft_dropbox_note'), style: mktText(11.5, color: Mkt.inkSoft)),
                ),
              MktGrid(breakpoint: 980, rows: [
                [
                  (8, MktCard(
                    title: 'Footage in',
                    subtitle: 'Newest first',
                    icon: Icons.video_library_outlined,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final s in const [('all', 'All'), ('new', 'New'), ('in_edit', 'Being edited'), ('edited', 'Edited')])
                          MktFilterChip(key: Key('ft_status_${s.$1}'), label: s.$2, selected: _status == s.$1, onTap: () => setState(() => _status = s.$1)),
                      ]),
                      const SizedBox(height: 10),
                      if (d.items.isEmpty) MktEmpty(_status == 'all' ? 'No footage has come in yet. Artists add it from their work card once the work is done.' : 'Nothing here.', icon: Icons.video_library_outlined, height: 110),
                      for (final it in d.items) _item(it),
                    ]),
                  )),
                  (4, MktCard(
                    title: 'Owing footage',
                    subtitle: 'Last 14 days · works that need content',
                    icon: Icons.hourglass_top_rounded,
                    child: d.waiting.isEmpty
                        ? const MktEmpty('Every work that needs content has its footage in.', icon: Icons.check_circle_outline_rounded, height: 100)
                        : Column(children: [
                            for (final w in d.waiting)
                              Padding(
                                key: Key('ft_waiting_${w.bookingId}_${w.day}'),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  const Icon(Icons.circle, size: 8, color: Mkt.bad),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text([w.client, w.service].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                                      Text([_day(w.day), if (w.bookingNumber.isNotEmpty) w.bookingNumber, if (w.artists.isNotEmpty) w.artists.join(', ')].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                                    ]),
                                  ),
                                ]),
                              ),
                          ]),
                  )),
                ],
              ]),
            ],
          );
        },
      ),
    );
  }

  static String _day(String d) {
    final t = DateTime.tryParse(d);
    return t == null ? d : DateFormat('EEE d MMM').format(t);
  }

  Widget _item(FootageItem it) => Container(
        key: Key('ft_item_${it.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(it.folderName, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w800))),
            MktChip(statusLabel(it.status), color: statusColor(it.status)),
          ]),
          const SizedBox(height: 2),
          Text(
            [if (it.uploaders.isNotEmpty) 'from ${it.uploaders.join(', ')}', if (it.firstAt != null) DateFormat('d MMM, h:mm a').format(it.firstAt!), if (it.fileCount > 0) '${it.fileCount} file${it.fileCount == 1 ? '' : 's'}', if (it.size.isNotEmpty) it.size, if (it.editorName.isNotEmpty) 'editor: ${it.editorName}'].join(' · '),
            style: mktText(11, color: Mkt.inkSoft),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final l in it.links)
              ActionChip(
                key: Key('ft_link_${l.id}'),
                avatar: Icon(l.kind == 'folder' ? Icons.folder_open_rounded : Icons.movie_outlined, size: 16, color: Mkt.primary),
                label: Text(l.summary.isEmpty ? l.title : '${l.title} · ${l.summary}', style: mktText(11.5, weight: FontWeight.w600)),
                visualDensity: VisualDensity.compact,
                // a Dropbox folder opens here: what is inside, each video playing in the app
                onPressed: () => l.isDropboxFolder ? showDropboxFolder(context, url: l.url, title: it.folderName) : ref.read(footageLinkOpenerProvider)(Uri.parse(l.url)),
              ),
            if (it.status == 'new') FilledButton.tonalIcon(key: Key('ft_to_editor_${it.id}'), onPressed: () => _toEditor(it), icon: const Icon(Icons.movie_edit, size: 16), label: const Text('Send to an editor')),
            if (it.status == 'in_edit') FilledButton.tonalIcon(key: Key('ft_edited_${it.id}'), onPressed: () => _set(it, 'edited'), icon: const Icon(Icons.check_rounded, size: 16), label: const Text('Mark edited')),
            if (it.status != 'new') TextButton(key: Key('ft_reset_${it.id}'), onPressed: () => _set(it, 'new'), child: const Text('Back to new')),
          ]),
        ]),
      );
}
