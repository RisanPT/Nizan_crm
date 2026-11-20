import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/dropbox_folder_view.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_link.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_docs.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/storyboard_editor.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/services/upload_service.dart';

// The Shoot Planner's own tabs (marketing document, Creative Portfolio → Shoot Planner): the Moodboard (pictures from the phone or the
// computer, picture links, Pinterest / Instagram / Drive links — added, labelled, made the cover, removed right here), its preview on the
// Brief, Crew & Logistics (call time, map, a checklist the crew ticks off, notes), and the raw footage the artists handed in for the work.

/// A link a picture can be shown from: a Dropbox share link is asked for the file itself (raw=1).
String displayImageUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return url;
  final host = u.host.toLowerCase();
  if ((host == 'www.dropbox.com' || host == 'dropbox.com') && (u.path.startsWith('/s/') || u.path.startsWith('/scl/fi/'))) {
    final q = Map<String, String>.from(u.queryParameters)..remove('dl');
    q['raw'] = '1';
    return u.replace(queryParameters: q).toString();
  }
  return url;
}

/// How the moodboard picks pictures (a test puts its own here).
final moodboardPickerProvider = Provider<Future<List<XFile>> Function()>((ref) => () => ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2200));

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() job, {String? done}) async {
  try {
    await job();
    refreshPortfolio(ref);
    if (done != null && context.mounted) _say(context, done);
  } on TeamRefusal catch (r) {
    if (context.mounted) _say(context, r.message);
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

/// One moodboard picture (or the card of a link when it is not a picture, or a picture that will not load).
class MoodboardTile extends StatelessWidget {
  const MoodboardTile({super.key, required this.item, this.onTap, this.size});
  final MoodboardItem item;
  final VoidCallback? onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final card = _LinkCard(item: item);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: item.kind == 'image'
              ? Stack(fit: StackFit.expand, children: [
                  Image.network(displayImageUrl(item.url), fit: BoxFit.cover, errorBuilder: (_, _, _) => card, loadingBuilder: (_, child, p) => p == null ? child : Container(color: Mkt.bg)),
                  if (item.label.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
                        child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ])
              : card,
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.item});
  final MoodboardItem item;

  @override
  Widget build(BuildContext context) => Container(
        color: Mkt.primarySoft,
        child: LayoutBuilder(builder: (context, c) {
          final icon = Icon(item.kind == 'video' ? Icons.play_circle_outline_rounded : Icons.link_rounded, color: Mkt.primary, size: c.maxHeight < 100 ? 22 : 28);
          // a small tile (the Brief's preview on a phone): the icon and the site only
          if (c.maxHeight < 100) {
            return Tooltip(
              message: item.label.isNotEmpty ? item.label : item.site,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(height: 2), Text(item.site, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(9.5, color: Mkt.inkSoft))]),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              icon,
              const SizedBox(height: 6),
              Text(item.label.isNotEmpty ? item.label : item.site, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: mktText(11.5, weight: FontWeight.w700)),
              if (item.label.isNotEmpty) Text(item.site, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft)),
            ]),
          );
        }),
      );
}

/// The moodboard's first pictures on the Brief ("Reference / Moodboard Preview"), with "View All" to the Moodboard tab.
class MoodboardPreview extends StatelessWidget {
  const MoodboardPreview({super.key, required this.detail, required this.onViewAll});
  final ShootDetail detail;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final pics = detail.pictures;
    final shown = (pics.isNotEmpty ? pics : detail.references).take(4).toList();
    return Container(
      key: const Key('pf_moodboard_preview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.photo_library_outlined, size: 16, color: Mkt.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('Reference / Moodboard Preview', style: mktText(12.5, weight: FontWeight.w800))),
          TextButton(key: const Key('pf_moodboard_view_all'), onPressed: onViewAll, child: Text(detail.references.isEmpty ? 'Add →' : 'View All →', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary))),
        ]),
        if (shown.isEmpty)
          Text('No moodboard yet — add pictures and links in the Moodboard tab.', style: mktText(11.5, color: Mkt.inkSoft))
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 6.0;
            final w = (c.maxWidth - gap * 3) / 4;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (i, r) in shown.indexed)
                SizedBox(
                  width: w,
                  child: Stack(children: [
                    MoodboardTile(item: r, onTap: onViewAll),
                    if (i == 3 && detail.references.length > 4)
                      Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text('+${detail.references.length - 4}', style: mktText(16, weight: FontWeight.w800, color: Colors.white))))),
                  ]),
                ),
            ]);
          }),
      ]),
    );
  }
}

/// The Moodboard tab: every picture and link as a grid, and the buttons that add to it.
class ShootMoodboard extends ConsumerStatefulWidget {
  const ShootMoodboard({super.key, required this.detail});
  final ShootDetail detail;

  @override
  ConsumerState<ShootMoodboard> createState() => _ShootMoodboardState();
}

class _ShootMoodboardState extends ConsumerState<ShootMoodboard> {
  bool _busy = false;
  String _progress = '';

  String get _id => widget.detail.summary.id;

  Future<void> _addPictures() async {
    final files = await ref.read(moodboardPickerProvider)();
    if (files.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _progress = 'Uploading 1 of ${files.length}…';
    });
    final urls = <Map<String, dynamic>>[];
    var failed = 0;
    for (final (i, f) in files.indexed) {
      if (mounted) setState(() => _progress = 'Uploading ${i + 1} of ${files.length}…');
      try {
        urls.add({'url': await ref.read(uploadServiceProvider).uploadImage(f), 'label': ''});
      } catch (_) {
        failed += 1;
      }
    }
    if (!mounted) return;
    if (urls.isNotEmpty) await _run(context, ref, () => ref.read(marketingPortfolioServiceProvider).addMoodboard(_id, urls), done: '${urls.length} picture${urls.length == 1 ? '' : 's'} added${failed > 0 ? ' — $failed could not be uploaded' : ''}.');
    if (urls.isEmpty && mounted) _say(context, 'The pictures could not be uploaded. Check the connection and try again.');
    if (mounted) setState(() => (_busy = false, _progress = ''));
  }

  Future<void> _addLink() async {
    final r = await showDialog<({String url, String label})>(context: context, builder: (_) => const _LinkDialog());
    if (r == null || !mounted) return;
    await _run(context, ref, () => ref.read(marketingPortfolioServiceProvider).addMoodboard(_id, [{'url': r.url, 'label': r.label}]));
  }

  Future<void> _open(MoodboardItem r) async {
    if (r.kind == 'image') {
      await showDialog<void>(context: context, builder: (_) => _PictureViewer(item: r));
    } else {
      await launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _menu(MoodboardItem r, String action) async {
    final svc = ref.read(marketingPortfolioServiceProvider);
    switch (action) {
      case 'open':
        await launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
      case 'rename':
        final label = await showDialog<String>(context: context, builder: (_) => _LabelDialog(initial: r.label));
        if (label != null && mounted) await _run(context, ref, () => svc.renameMoodboardItem(_id, r.url, label));
      case 'cover':
        await _run(context, ref, () => svc.saveShoot({'coverUrl': r.url}, id: _id).then((_) {}), done: 'Now the shoot\'s cover.');
      case 'remove':
        await _run(context, ref, () => svc.removeMoodboardItem(_id, r.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final refs = widget.detail.references;
    final buttons = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      FilledButton.icon(key: const Key('pf_moodboard_add_pictures'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _busy ? null : _addPictures, icon: const Icon(Icons.add_photo_alternate_outlined, size: 18), label: const Text('Add pictures')),
      OutlinedButton.icon(key: const Key('pf_moodboard_add_link'), onPressed: _busy ? null : _addLink, icon: const Icon(Icons.add_link_rounded, size: 18), label: const Text('Add a link')),
      if (_busy) Text(_progress, key: const Key('pf_moodboard_progress'), style: mktText(11.5, color: Mkt.inkSoft)),
    ]);
    return Column(key: const Key('pf_moodboard'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      buttons,
      const SizedBox(height: 10),
      // PDFs read in the app: a lookbook, the client's brief
      ShootPdfs(detail: widget.detail, part: 'moodboard', hint: 'A lookbook or the client\'s brief as a PDF — read here, page by page.'),
      const SizedBox(height: 12),
      if (refs.isEmpty)
        const MktEmpty('No moodboard yet. Add reference pictures from the phone or computer, or links from Pinterest, Instagram or Drive.', icon: Icons.photo_library_outlined, height: 110)
      else ...[
        Text('${refs.length} item${refs.length == 1 ? '' : 's'} · ${widget.detail.pictures.length} picture${widget.detail.pictures.length == 1 ? '' : 's'}', style: mktText(11.5, color: Mkt.inkSoft)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          const gap = 8.0;
          final cols = (c.maxWidth / 150).floor().clamp(2, 6);
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final r in refs)
              SizedBox(
                key: Key('pf_mood_${refs.indexOf(r)}'),
                width: w,
                child: Stack(children: [
                  MoodboardTile(item: r, onTap: () => _open(r)),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        key: Key('pf_mood_menu_${refs.indexOf(r)}'),
                        tooltip: 'More',
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        onSelected: (v) => _menu(r, v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'open', child: Text('Open')),
                          const PopupMenuItem(value: 'rename', child: Text('Name it')),
                          if (r.kind == 'image') const PopupMenuItem(value: 'cover', child: Text('Use as the cover')),
                          const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: Mkt.bad))),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
          ]);
        }),
        if (refs.any((r) => r.addedByName.isNotEmpty)) ...[
          const SizedBox(height: 6),
          Text('Added by ${{for (final r in refs) if (r.addedByName.isNotEmpty) r.addedByName}.join(', ')}', style: mktText(10.5, color: Mkt.inkSoft)),
        ],
      ],
    ]);
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();
  final _label = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  void _ok() {
    final u = _url.text.trim();
    final parsed = Uri.tryParse(u);
    if (parsed == null || !(parsed.isScheme('https') || parsed.isScheme('http')) || parsed.host.isEmpty) return setState(() => _error = 'Paste a link starting with https://');
    Navigator.pop(context, (url: u, label: _label.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add a link'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(key: const Key('pf_mood_link_url'), controller: _url, autofocus: true, decoration: InputDecoration(labelText: 'Link', hintText: 'https://www.pinterest.com/pin/…', errorText: _error, isDense: true, border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(key: const Key('pf_mood_link_label'), controller: _label, decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'Hair idea', isDense: true, border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text('A link to a picture (.jpg, .png) shows on the board; any other link opens in its own app.', style: mktText(11, color: Mkt.inkSoft)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(key: const Key('pf_mood_link_ok'), onPressed: _ok, child: const Text('Add'))],
      );
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.initial});
  final String initial;
  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Name it'),
        content: TextField(key: const Key('pf_mood_label'), controller: _c, autofocus: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(key: const Key('pf_mood_label_ok'), onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('Save'))],
      );
}

class _PictureViewer extends StatelessWidget {
  const _PictureViewer({required this.item});
  final MoodboardItem item;
  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: [
          InteractiveViewer(child: Center(child: Image.network(displayImageUrl(item.url), fit: BoxFit.contain, errorBuilder: (_, _, _) => Padding(padding: const EdgeInsets.all(30), child: Text('This picture could not be loaded.', style: mktText(13, color: Colors.white)))))),
          Positioned(top: 4, right: 4, child: IconButton(key: const Key('pf_picture_close'), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white))),
          if (item.label.isNotEmpty) Positioned(left: 12, bottom: 12, right: 12, child: Text(item.label, style: mktText(13, weight: FontWeight.w700, color: Colors.white))),
        ]),
      );
}

/// Crew & Logistics: the crew, when they must be there, where (the map), what to bring or arrange (ticked off by whoever did it), notes.
class ShootLogisticsCard extends ConsumerWidget {
  const ShootLogisticsCard({super.key, required this.detail});
  final ShootDetail detail;

  // only this line is sent: two people ticking at once on the shoot day never undo each other
  Future<void> _tick(BuildContext context, WidgetRef ref, int i, bool done) =>
      _run(context, ref, () => ref.read(marketingPortfolioServiceProvider).tickChecklist(detail.summary.id, detail.logistics.checklist[i].text, done));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = detail.logistics;
    final s = detail.summary;
    Widget fact(IconData icon, String text, {Key? key, VoidCallback? onTap}) => InkWell(
          key: key,
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: onTap == null ? Mkt.inkSoft : Mkt.primary), const SizedBox(width: 5), Text(text, style: mktText(12.5, color: onTap == null ? Mkt.ink : Mkt.primary, weight: onTap == null ? FontWeight.w500 : FontWeight.w700))]),
        );
    final done = l.checklist.where((c) => c.done).length;
    // a Material (not a coloured box), so the checklist rows' ripple shows
    return Material(
      key: const Key('pf_logistics'),
      color: Mkt.bg,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Logistics', style: mktText(12.5, weight: FontWeight.w800))),
            TextButton.icon(key: const Key('pf_logistics_edit'), onPressed: () => showDialog<void>(context: context, builder: (_) => _LogisticsDialog(detail: detail)), icon: const Icon(Icons.edit_outlined, size: 15), label: Text(l.isEmpty ? 'Add' : 'Edit')),
          ]),
          Wrap(spacing: 16, runSpacing: 6, children: [
            fact(Icons.alarm_rounded, l.callTime.isEmpty ? 'No call time' : 'Crew call ${l.callTime}', key: const Key('pf_logistics_call')),
            fact(Icons.schedule_rounded, s.time.isEmpty ? 'No shoot time' : 'Shoot ${s.time}'),
            fact(Icons.place_outlined, s.location.isEmpty ? 'No location' : s.location),
            if (l.mapUrl.isNotEmpty) fact(Icons.map_outlined, 'Open the map', key: const Key('pf_logistics_map'), onTap: () => launchUrl(Uri.parse(l.mapUrl), mode: LaunchMode.externalApplication)),
          ]),
          if (l.checklist.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Checklist · $done of ${l.checklist.length} done', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
            for (final (i, c) in l.checklist.indexed)
              CheckboxListTile(
                key: Key('pf_check_$i'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: c.done,
                onChanged: (v) => _tick(context, ref, i, v ?? false),
                title: Text(c.text, style: mktText(12.5, weight: FontWeight.w600).copyWith(decoration: c.done ? TextDecoration.lineThrough : null)),
                subtitle: c.done && c.byName.isNotEmpty ? Text('by ${c.byName}', style: mktText(10.5, color: Mkt.inkSoft)) : null,
              ),
          ],
          if (l.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.notes, style: mktText(12, color: Mkt.inkSoft))),
        ]),
      ),
    );
  }
}

class _LogisticsDialog extends ConsumerStatefulWidget {
  const _LogisticsDialog({required this.detail});
  final ShootDetail detail;
  @override
  ConsumerState<_LogisticsDialog> createState() => _LogisticsDialogState();
}

class _LogisticsDialogState extends ConsumerState<_LogisticsDialog> {
  late final _call = TextEditingController(text: widget.detail.logistics.callTime);
  late final _map = TextEditingController(text: widget.detail.logistics.mapUrl);
  late final _notes = TextEditingController(text: widget.detail.logistics.notes);
  late final _items = TextEditingController(text: widget.detail.logistics.checklist.map((c) => c.text).join('\n'));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_call, _map, _notes, _items]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => (_saving = true, _error = null));
    final was = {for (final c in widget.detail.logistics.checklist) c.text: c.done};
    final lines = _items.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    try {
      await ref.read(marketingPortfolioServiceProvider).saveLogistics(widget.detail.summary.id, {'callTime': _call.text.trim(), 'mapUrl': _map.text.trim(), 'notes': _notes.text.trim(), 'checklist': [for (final t in lines) {'text': t, 'done': was[t] ?? false}]});
      refreshPortfolio(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() => (_error = r.message, _saving = false));
    } catch (e) {
      if (mounted) setState(() => (_error = friendlyErrorMessage(e), _saving = false));
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Logistics'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(key: const Key('pf_log_call'), controller: _call, keyboardType: TextInputType.datetime, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')), LengthLimitingTextInputFormatter(5)], decoration: _dec('Crew call time (HH:MM)', hint: '07:30')),
              const SizedBox(height: 10),
              TextField(key: const Key('pf_log_map'), controller: _map, decoration: _dec('Map link', hint: 'https://maps.app.goo.gl/…')),
              const SizedBox(height: 10),
              TextField(key: const Key('pf_log_items'), controller: _items, minLines: 3, maxLines: 8, decoration: _dec('Checklist — what to bring or arrange (one per line)', hint: 'Ring light\nBridal jewellery set\nSteamer')),
              const SizedBox(height: 10),
              TextField(key: const Key('pf_log_notes'), controller: _notes, minLines: 2, maxLines: 4, decoration: _dec('Notes', hint: 'Parking at gate 2; venue contact')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('pf_log_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(key: const Key('pf_log_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : _save, child: const Text('Save'))],
      );
}

/// The raw footage the artists handed in for the work this shoot covers (Content Plan).
class ShootFootageList extends StatelessWidget {
  const ShootFootageList({super.key, required this.detail});
  final ShootDetail detail;

  static String stateLabel(String s) => switch (s) { 'new' => 'New', 'in_edit' => 'In edit', 'edited' => 'Edited', _ => 'Waiting' };
  static Color stateColor(String s) => switch (s) { 'new' => Mkt.blue, 'in_edit' => Mkt.warn, 'edited' => Mkt.good, _ => Mkt.grey };

  @override
  Widget build(BuildContext context) {
    if (detail.booking == null) return const SizedBox.shrink();
    return Column(key: const Key('pf_footage'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text('Raw footage from the work', style: mktText(12.5, weight: FontWeight.w800)),
      if (detail.footage.isEmpty)
        Text('No footage yet — the artists add the Dropbox link from their work card once the work is done.', style: mktText(11.5, color: Mkt.inkSoft))
      else
        for (final f in detail.footage)
          Padding(
            key: Key('pf_footage_${f.day}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(f.folderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700))),
                if (f.size.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6), child: Text(f.size, style: mktText(11, color: Mkt.inkSoft))),
                MktChip(stateLabel(f.state), color: stateColor(f.state)),
              ]),
              for (final l in f.links)
                InkWell(
                  // a Dropbox folder opens here (what is inside, each video playing in the app); anything else in its own page
                  onTap: () => l.kind == 'folder' && MediaLink.parse(l.url).isFolder ? showDropboxFolder(context, url: l.url, title: f.folderName) : launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(l.kind == 'folder' ? Icons.folder_open_rounded : Icons.movie_outlined, size: 15, color: Mkt.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text([if (l.label.isNotEmpty) l.label else (l.kind == 'folder' ? 'Dropbox folder' : 'Video'), if (l.summary.isNotEmpty) l.summary, if (l.addedByName.isNotEmpty) 'from ${l.addedByName}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.primary, weight: FontWeight.w600))),
                    ]),
                  ),
                ),
            ]),
          ),
    ]);
  }
}

// ── the storyboard ───────────────────────────────────────────────────────────

/// The storyboard as the crew uses it: each frame's picture (a sketch, a still, a moodboard picture), what the shot is — and on the shoot
/// day a tick when it is filmed ("6 of 9 shot", who ticked it and when). A tick sends only that frame, so two people ticking at once never
/// undo each other; editing the frames keeps the ticks of the frames that stay.
class ShootStoryboard extends ConsumerStatefulWidget {
  const ShootStoryboard({super.key, required this.detail});
  final ShootDetail detail;

  @override
  ConsumerState<ShootStoryboard> createState() => _ShootStoryboardState();
}

class _ShootStoryboardState extends ConsumerState<ShootStoryboard> {
  String? _busy; // the frame being ticked

  Future<void> _shot(StoryFrame f, bool shot) async {
    if (f.key.isEmpty || _busy != null) return;
    setState(() => _busy = f.key);
    await _run(context, ref, () => ref.read(marketingPortfolioServiceProvider).markFrameShot(widget.detail.summary.id, f.key, shot));
    if (mounted) setState(() => _busy = null);
  }

  void _view(StoryFrame f, int i) => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Flexible(child: InteractiveViewer(child: Image.network(displayImageUrl(f.imageUrl), key: const Key('pf_frame_big'), fit: BoxFit.contain))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Text('${f.shotNo.isEmpty ? i + 1 : f.shotNo}. ${f.description}', style: mktText(12.5, weight: FontWeight.w700))),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ]),
            ),
          ]),
        ),
      );

  Widget _placeholder(StoryFrame f) => Container(
        color: Mkt.tint(Mkt.primary, 0.06),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.movie_creation_outlined, size: 26, color: Mkt.primaryLight),
          const SizedBox(height: 2),
          Text(f.shotType.isEmpty ? 'No picture yet' : f.shotType, style: mktText(11, color: Mkt.inkSoft)),
        ]),
      );

  Widget _card(int i, StoryFrame f) {
    final busy = _busy == f.key;
    return Container(
      key: Key('pf_frame_$i'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: f.shot ? Mkt.tint(Mkt.good, 0.6) : Mkt.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            if (f.imageUrl.isEmpty)
              _placeholder(f)
            else
              GestureDetector(
                onTap: () => _view(f, i),
                child: Image.network(displayImageUrl(f.imageUrl), key: Key('pf_frame_img_$i'), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(f)),
              ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Mkt.primary, borderRadius: BorderRadius.circular(12)),
                child: Text(f.shotNo.isEmpty ? '${i + 1}' : f.shotNo, style: mktText(11, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            if (f.shot)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Mkt.good, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_rounded, size: 13, color: Colors.white), const SizedBox(width: 3), Text('Shot', style: mktText(11, weight: FontWeight.w800, color: Colors.white))]),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
            if (f.shotType.isNotEmpty || f.durationSec > 0) Text([if (f.shotType.isNotEmpty) f.shotType, if (f.durationSec > 0) '${f.durationSec} s'].join(' · '), style: mktText(11, color: Mkt.inkSoft)),
            if (f.notes.isNotEmpty) Text(f.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
            const SizedBox(height: 4),
            Row(children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('pf_frame_shot_$i'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: busy || f.key.isEmpty ? null : () => _shot(f, !f.shot),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(f.shot ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20, color: f.shot ? Mkt.good : Mkt.inkSoft),
                      const SizedBox(width: 5),
                      Text(f.shot ? 'Shot' : 'Mark as shot', style: mktText(12, weight: FontWeight.w700, color: f.shot ? Mkt.good : Mkt.ink)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  f.shot ? [if (f.shotByName.isNotEmpty) 'by ${f.shotByName}', DateFormat('d MMM, h:mm a').format(f.shotAt!)].join(' · ') : '',
                  key: Key('pf_frame_by_$i'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mktText(10.5, color: Mkt.inkSoft),
                ),
              ),
              if (f.referenceUrl.isNotEmpty)
                IconButton(tooltip: 'Open the reference', visualDensity: VisualDensity.compact, onPressed: () => launchUrl(Uri.parse(f.referenceUrl), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Mkt.primary)),
            ]),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final frames = d.storyboard;
    final total = frames.fold<int>(0, (s, f) => s + f.durationSec);
    final shot = frames.where((f) => f.shot).length;
    final edit = OutlinedButton.icon(
      key: const Key('pf_storyboard_edit'),
      onPressed: () => showStoryboardEditor(context, ref, shootId: d.summary.id, frames: frames, moodboard: d.pictures),
      icon: Icon(frames.isEmpty ? Icons.add_rounded : Icons.edit_outlined, size: 16),
      label: Text(frames.isEmpty ? 'Build the storyboard' : 'Edit storyboard'),
    );
    // PDFs read in the app: a drawn storyboard, a shot list
    final pdfs = ShootPdfs(detail: d, part: 'storyboard', hint: 'A drawn storyboard or a shot list as a PDF — read here, page by page.');
    if (frames.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [pdfs, const SizedBox(height: 12), const MktEmpty('No storyboard frames yet — lay out the shots in the order they are filmed, each with a sketch or a moodboard picture.', icon: Icons.view_carousel_outlined, height: 100), edit]);
    }
    return Column(key: const Key('pf_storyboard'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      pdfs,
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text('${frames.length} frame${frames.length == 1 ? '' : 's'}${total > 0 ? ' · ${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')} in all' : ''}', style: mktText(11.5, color: Mkt.inkSoft))),
        Text('$shot of ${frames.length} shot', key: const Key('pf_storyboard_progress'), style: mktText(12, weight: FontWeight.w800, color: shot == frames.length ? Mkt.good : Mkt.ink)),
      ]),
      const SizedBox(height: 6),
      MktProgress(pct: (shot * 100 / frames.length).round(), color: shot == frames.length ? Mkt.good : Mkt.primaryLight, labelWidth: 0, showLabel: false),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 860 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
        final w = (c.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final (i, f) in frames.indexed) SizedBox(width: w, child: _card(i, f))]);
      }),
      const SizedBox(height: 10),
      edit,
    ]);
  }
}
