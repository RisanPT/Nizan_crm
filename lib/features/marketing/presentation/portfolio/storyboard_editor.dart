import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_board.dart' show MoodboardTile, displayImageUrl, moodboardPickerProvider;
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/services/upload_service.dart';

/// Edit a shoot's storyboard: its frames in shooting order — shot no., what the shot is, shot type, duration, a PICTURE (a sketch or a
/// still uploaded from the phone or computer, or a picture from the shoot's moodboard), a reference link and notes. Frames can be added,
/// moved up or down and removed; the list is saved at once, each frame with its key — so a frame ticked "shot" keeps its tick.
Future<void> showStoryboardEditor(BuildContext context, WidgetRef ref, {required String shootId, required List<StoryFrame> frames, List<MoodboardItem> moodboard = const []}) {
  final form = _StoryboardForm(shootId: shootId, frames: frames, moodboard: moodboard);
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760), child: form)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form));
}

/// One frame's text boxes.
class _Frame {
  _Frame(StoryFrame f)
      : frameKey = f.key,
        imageUrl = f.imageUrl,
        shotNo = TextEditingController(text: f.shotNo),
        description = TextEditingController(text: f.description),
        shotType = TextEditingController(text: f.shotType),
        duration = TextEditingController(text: f.durationSec == 0 ? '' : '${f.durationSec}'),
        reference = TextEditingController(text: f.referenceUrl),
        notes = TextEditingController(text: f.notes);
  final TextEditingController shotNo, description, shotType, duration, reference, notes;

  /// The frame's key on the server ('' for a new frame) — sent back so its "shot" tick stays.
  final String frameKey;
  String imageUrl;
  bool uploading = false;
  // a stable key, so a frame keeps its boxes when it is moved
  final key = UniqueKey();

  List<TextEditingController> get all => [shotNo, description, shotType, duration, reference, notes];
  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
        if (frameKey.isNotEmpty) 'key': frameKey,
        'imageUrl': imageUrl,
        'shotNo': shotNo.text.trim(),
        'description': description.text.trim(),
        'shotType': shotType.text.trim(),
        'durationSec': duration.text.trim().isEmpty ? 0 : (int.tryParse(duration.text.trim()) ?? -1),
        'referenceUrl': reference.text.trim(),
        'notes': notes.text.trim(),
      };
}

class _StoryboardForm extends ConsumerStatefulWidget {
  const _StoryboardForm({required this.shootId, required this.frames, this.moodboard = const []});
  final String shootId;
  final List<StoryFrame> frames;
  final List<MoodboardItem> moodboard;

  @override
  ConsumerState<_StoryboardForm> createState() => _StoryboardFormState();
}

class _StoryboardFormState extends ConsumerState<_StoryboardForm> {
  late final List<_Frame> _frames = [for (final f in widget.frames) _Frame(f)];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final f in _frames) {
      f.dispose();
    }
    super.dispose();
  }

  void _add() => setState(() => _frames.add(_Frame(const StoryFrame())));

  void _move(int i, int by) => setState(() {
        final f = _frames.removeAt(i);
        _frames.insert(i + by, f);
      });

  void _remove(int i) => setState(() => _frames.removeAt(i).dispose());

  /// A picture for the frame from the phone or computer (uploaded like the moodboard's).
  Future<void> _upload(_Frame f) async {
    final files = await ref.read(moodboardPickerProvider)();
    if (files.isEmpty || !mounted) return;
    setState(() {
      f.uploading = true;
      _error = null;
    });
    try {
      final url = await ref.read(uploadServiceProvider).uploadImage(files.first);
      if (mounted) setState(() => f.imageUrl = url);
    } catch (_) {
      if (mounted) setState(() => _error = 'The picture could not be uploaded. Check the connection and try again.');
    } finally {
      if (mounted) setState(() => f.uploading = false);
    }
  }

  /// A picture from the shoot's moodboard.
  Future<void> _fromMoodboard(_Frame f) async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a moodboard picture'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (j, m) in widget.moodboard.indexed)
                SizedBox(key: Key('sb_mood_pick_$j'), width: 120, height: 120, child: MoodboardTile(item: m, size: 120, onTap: () => Navigator.pop(context, m.url))),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );
    if (url != null && mounted) setState(() => f.imageUrl = url);
  }

  Future<void> _save() async {
    if (_frames.any((f) => f.uploading)) {
      setState(() => _error = 'A picture is still uploading — wait a moment.');
      return;
    }
    final blank = _frames.indexWhere((f) => f.description.text.trim().isEmpty);
    if (blank >= 0) {
      setState(() => _error = 'Frame ${blank + 1} needs a description.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(marketingPortfolioServiceProvider).saveShoot({'storyboard': [for (final f in _frames) f.toJson()]}, id: widget.shootId);
      refreshPortfolio(ref);
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

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder(), suffixIcon: suffix);

  Widget _frame(int i, _Frame f) => Container(
        key: f.key,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: Mkt.primary, shape: BoxShape.circle), child: Text('${i + 1}', style: mktText(11, weight: FontWeight.w800, color: Colors.white))),
            const SizedBox(width: 8),
            Text('Frame ${i + 1}', style: mktText(12.5, weight: FontWeight.w800)),
            const Spacer(),
            IconButton(key: Key('sb_up_$i'), tooltip: 'Move up', visualDensity: VisualDensity.compact, onPressed: i == 0 ? null : () => _move(i, -1), icon: const Icon(Icons.arrow_upward_rounded, size: 18)),
            IconButton(key: Key('sb_down_$i'), tooltip: 'Move down', visualDensity: VisualDensity.compact, onPressed: i == _frames.length - 1 ? null : () => _move(i, 1), icon: const Icon(Icons.arrow_downward_rounded, size: 18)),
            IconButton(key: Key('sb_remove_$i'), tooltip: 'Remove', visualDensity: VisualDensity.compact, onPressed: () => _remove(i), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Mkt.bad)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 90, child: TextField(key: Key('sb_shot_$i'), controller: f.shotNo, decoration: _dec('Shot no.', hint: '${i + 1}'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(key: Key('sb_desc_$i'), controller: f.description, decoration: _dec('What the shot is'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                key: Key('sb_type_$i'),
                controller: f.shotType,
                decoration: _dec('Shot type', hint: 'Wide, Close-up…', suffix: PopupMenuButton<String>(tooltip: 'Pick a shot type', icon: const Icon(Icons.arrow_drop_down_rounded), onSelected: (v) => setState(() => f.shotType.text = v), itemBuilder: (_) => [for (final t in kShotTypes) PopupMenuItem(value: t, child: Text(t))])),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 120, child: TextField(key: Key('sb_dur_$i'), controller: f.duration, keyboardType: TextInputType.number, decoration: _dec('Duration (sec)'))),
          ]),
          const SizedBox(height: 8),
          // the frame's picture: a sketch or a still, or one from the moodboard
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 54,
                child: f.imageUrl.isEmpty
                    ? Container(color: Mkt.tint(Mkt.primary, 0.06), child: const Icon(Icons.image_outlined, color: Mkt.primaryLight))
                    : Image.network(displayImageUrl(f.imageUrl), key: Key('sb_pic_$i'), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Mkt.tint(Mkt.primary, 0.06), child: const Icon(Icons.broken_image_outlined, color: Mkt.primaryLight))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(
                  key: Key('sb_upload_$i'),
                  onPressed: f.uploading ? null : () => _upload(f),
                  icon: f.uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded, size: 16),
                  label: Text(f.uploading ? 'Uploading…' : (f.imageUrl.isEmpty ? 'Upload picture' : 'Change picture')),
                ),
                if (widget.moodboard.isNotEmpty) OutlinedButton.icon(key: Key('sb_mood_$i'), onPressed: f.uploading ? null : () => _fromMoodboard(f), icon: const Icon(Icons.photo_library_outlined, size: 16), label: const Text('From moodboard')),
                if (f.imageUrl.isNotEmpty && !f.uploading) TextButton(key: Key('sb_pic_remove_$i'), onPressed: () => setState(() => f.imageUrl = ''), child: const Text('Remove picture')),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(key: Key('sb_ref_$i'), controller: f.reference, decoration: _dec('Reference link (optional)', hint: 'https://…')),
          const SizedBox(height: 8),
          TextField(key: Key('sb_notes_$i'), controller: f.notes, minLines: 1, maxLines: 3, decoration: _dec('Notes (optional)')),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final total = _frames.fold<int>(0, (s, f) => s + (int.tryParse(f.duration.text.trim()) ?? 0));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Storyboard', style: mktText(19, weight: FontWeight.w800)),
            Text('The frames in shooting order. ${_frames.length} frame${_frames.length == 1 ? '' : 's'}${total > 0 ? ' · ${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')} in all' : ''}', style: mktText(11.5, color: Mkt.inkSoft)),
            const SizedBox(height: 12),
            if (_frames.isEmpty) const MktEmpty('No frames yet. Add the first shot.', icon: Icons.view_carousel_outlined, height: 110),
            for (final (i, f) in _frames.indexed) _frame(i, f),
            OutlinedButton.icon(key: const Key('sb_add'), onPressed: _add, icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add frame')),
          ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('sb_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(key: const Key('sb_cancel'), onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(key: const Key('sb_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save storyboard')),
          ]),
        ]),
      ),
    ]);
  }
}
