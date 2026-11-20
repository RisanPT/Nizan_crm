import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/footage_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/services/footage_service.dart';

/// How a link is opened (a test puts its own here).
final footageLinkOpenerProvider = Provider<Future<bool> Function(Uri)>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// On an artist's work card: the work's FOOTAGE. Once the work is done the artist puts the videos in Dropbox — in the folder named after
/// the work (the name is shown, ready to copy) — and adds the link here; with Dropbox connected on the server, "Upload to Dropbox" opens
/// the work's own upload page (no Dropbox login needed) and "I've uploaded" finds the files. Marketing gets the footage at once.
/// Shown only to the people who worked the booking (and Marketing), and only for days that have come.
class WorkFootageCard extends ConsumerWidget {
  const WorkFootageCard({super.key, required this.bookingId, this.today});
  final String bookingId;

  /// "Today" (IST day key) — for tests.
  final String? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookingFootageProvider(bookingId));
    final f = async.value;
    if (f == null || !f.canAdd) return const SizedBox.shrink();
    final now = today ?? DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));
    final days = f.days.where((d) => d.day.compareTo(now) <= 0).toList().reversed.toList();
    if (days.isEmpty) return const SizedBox.shrink();
    final anything = days.any((d) => d.links.isNotEmpty || d.files.isNotEmpty);
    // a work that asks for no content shows only a small "add footage" line until something is added
    if (!f.needsContent && !anything) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          const Icon(Icons.video_library_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          const Expanded(child: Text('Footage from this work (optional)', style: TextStyle(fontSize: 12.5, color: Colors.grey))),
          TextButton(key: Key('footage_add_optional_$bookingId'), onPressed: () => _addLink(context, ref, f, days.first), child: const Text('Add a link')),
        ]),
      );
    }
    return Column(children: [for (final d in days) _DayCard(footage: f, day: d)]);
  }
}

Future<void> _addLink(BuildContext context, WidgetRef ref, BookingFootage f, FootageDay d) async {
  final r = await showDialog<({String url, String label})>(context: context, builder: (_) => _LinkDialog(folderName: d.folderName));
  if (r == null || !context.mounted) return;
  try {
    await ref.read(footageServiceProvider).addLink(f.bookingId, day: d.day, url: r.url, label: r.label);
    refreshFootage(ref);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Footage sent to Marketing. Thank you!')));
  } on TeamRefusal catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

class _DayCard extends ConsumerStatefulWidget {
  const _DayCard({required this.footage, required this.day});
  final BookingFootage footage;
  final FootageDay day;
  @override
  ConsumerState<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<_DayCard> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on TeamRefusal catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() => _guard(() async {
        final url = await ref.read(footageServiceProvider).uploadPage(widget.footage.bookingId, widget.day.day);
        if (url.isNotEmpty) await ref.read(footageLinkOpenerProvider)(Uri.parse(url));
      });

  Future<void> _check() => _guard(() async {
        final (_, found) = await ref.read(footageServiceProvider).checkUpload(widget.footage.bookingId, widget.day.day);
        refreshFootage(ref);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(found == 0 ? 'Nothing in the folder yet — finish the upload, then check again.' : 'Found $found file${found == 1 ? '' : 's'} — sent to Marketing.')));
      });

  Future<void> _remove(FootageLink l) => _guard(() async {
        await ref.read(footageServiceProvider).removeLink(widget.footage.bookingId, l.id);
        refreshFootage(ref);
      });

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final f = widget.footage;
    final waiting = d.state == 'waiting';
    final color = waiting ? (d.due ? const Color(0xFFA9781B) : Colors.grey) : const Color(0xFF2E7D4F);
    final when = DateTime.tryParse(d.day);
    return Container(
      key: Key('footage_day_${d.day}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.video_library_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('Footage${when == null ? '' : ' · ${DateFormat('d MMM').format(when)}'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(footageStateLabel(d.state), key: Key('footage_state_${d.day}'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        if (d.due) ...[
          const SizedBox(height: 6),
          Text('Marketing is waiting for this work\'s videos.', key: Key('footage_due_${d.day}'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
        ],
        const SizedBox(height: 8),
        // the folder name everyone uses for this work — copy it into Dropbox
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
          child: Row(children: [
            const Icon(Icons.folder_outlined, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Expanded(child: SelectableText(d.folderName, key: Key('footage_folder_${d.day}'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            IconButton(
              key: Key('footage_copy_${d.day}'),
              tooltip: 'Copy the folder name',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 17),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: d.folderName));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder name copied.')));
              },
            ),
          ]),
        ),
        if (waiting && !f.dropboxEnabled) ...[
          const SizedBox(height: 8),
          const Text('1. In Dropbox, make a folder with the name above.\n2. Upload this work\'s videos into it.\n3. Tap Share, then Copy link.\n4. Add the link here.', key: Key('footage_steps'), style: TextStyle(fontSize: 12, height: 1.45, color: Colors.black87)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (f.dropboxEnabled) ...[
            FilledButton.icon(key: Key('footage_upload_${d.day}'), onPressed: _busy ? null : _upload, icon: const Icon(Icons.cloud_upload_outlined, size: 18), label: const Text('Upload to Dropbox')),
            OutlinedButton.icon(key: Key('footage_check_${d.day}'), onPressed: _busy ? null : _check, icon: const Icon(Icons.fact_check_outlined, size: 18), label: const Text('I\'ve uploaded — check')),
          ],
          OutlinedButton.icon(key: Key('footage_add_${d.day}'), onPressed: _busy ? null : () => _addLink(context, ref, f, d), icon: const Icon(Icons.add_link_rounded, size: 18), label: Text(f.dropboxEnabled ? 'Or add a link' : 'Add the Dropbox link')),
        ]),
        if (d.files.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d.files.length} file${d.files.length == 1 ? '' : 's'} in the folder${d.size.isEmpty ? '' : ' · ${d.size}'}', key: Key('footage_files_${d.day}'), style: const TextStyle(fontSize: 12, color: Colors.black54))),
        for (final l in d.links)
          Padding(
            key: Key('footage_link_${l.id}'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(l.kind == 'folder' ? Icons.folder_open_rounded : Icons.movie_outlined, size: 17, color: const Color(0xFF601A29)),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => ref.read(footageLinkOpenerProvider)(Uri.parse(l.url)),
                  child: Text([l.title, if (l.summary.isNotEmpty) l.summary, if (l.addedByName.isNotEmpty) l.addedByName].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF601A29))),
                ),
              ),
              if (l.mine) IconButton(key: Key('footage_remove_${l.id}'), tooltip: 'Take this link off', visualDensity: VisualDensity.compact, onPressed: _busy ? null : () => _remove(l), icon: const Icon(Icons.close_rounded, size: 17)),
            ]),
          ),
        if (d.editorName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Editor: ${d.editorName}', style: const TextStyle(fontSize: 12, color: Colors.black54))),
      ]),
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.folderName});
  final String folderName;
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
    final u = Uri.tryParse(_url.text.trim());
    if (u == null || !u.isScheme('https') || u.host.isEmpty) return setState(() => _error = 'Paste the link that starts with https://www.dropbox.com/');
    Navigator.pop(context, (url: _url.text.trim(), label: _label.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add the Dropbox link'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('The link of the folder "${widget.folderName}" (or of one video).', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 10),
            TextField(key: const Key('footage_link_url'), controller: _url, autofocus: true, decoration: InputDecoration(labelText: 'Dropbox link', hintText: 'https://www.dropbox.com/scl/fo/…', errorText: _error, isDense: true, border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(key: const Key('footage_link_label'), controller: _label, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Reception clips', isDense: true, border: OutlineInputBorder())),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(key: const Key('footage_link_ok'), onPressed: _ok, child: const Text('Send'))],
      );
}
