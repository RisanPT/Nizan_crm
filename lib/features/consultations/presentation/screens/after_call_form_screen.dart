import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../services/consultation_service.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/reference_images.dart';

/// Matches the server's per-call limit (consultationRules MAX_REFERENCE_IMAGES).
const kMaxReferenceImages = 15;

/// After-call details: what the client wants, what we conveyed, the agreed look,
/// skin notes, next steps and the client's reference photos. With [complete]
/// set (from "Record outcome" / "Complete") saving also marks a scheduled call
/// completed; otherwise it just saves the details.
class AfterCallFormScreen extends ConsumerWidget {
  const AfterCallFormScreen({super.key, required this.consultationId, this.complete = false});

  final String consultationId;
  final bool complete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(consultationProvider(consultationId));
    return async.when(
      loading: () => Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(title: const Text('Call details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(title: const Text('Call details')),
        body: AppErrorView(error: e, onRetry: () => ref.invalidate(consultationProvider(consultationId))),
      ),
      // Keyed by id so a refreshed consultation doesn't wipe what's being typed.
      data: (c) => _Form(key: ValueKey(c.id), consultation: c, complete: complete && c.isScheduled),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.consultation, required this.complete});

  final Consultation consultation;
  final bool complete;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final Map<String, TextEditingController> _text = {
    for (final f in kAfterCallFields)
      f.key: TextEditingController(text: widget.consultation.afterCallText[f.key] ?? ''),
  };
  final _picker = ImagePicker();
  final List<PickedImage> _pending = [];
  bool _saving = false;
  bool _dirty = false;

  /// The latest server copy — image removals update it without a reload.
  late Consultation _current = widget.consultation;

  @override
  void initState() {
    super.initState();
    for (final c in _text.values) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  int get _room => kMaxReferenceImages - _current.referenceImages.length - _pending.length;

  /// Only the fields that actually changed, so the history stays accurate.
  Map<String, String> _changedText() {
    final before = _current.afterCallText;
    return {
      for (final e in _text.entries)
        if (e.value.text.trim() != (before[e.key] ?? '').trim()) e.key: e.value.text.trim(),
    };
  }

  // ── Images ──────────────────────────────────────────────────────────────
  Future<void> _pickImages(ImageSource source) async {
    final room = _room;
    if (room <= 0) {
      showWarningSnackBar(context, 'A call can have at most $kMaxReferenceImages images');
      return;
    }
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final x = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
        picked = x == null ? const [] : [x];
      } else {
        picked = await _picker.pickMultiImage(maxWidth: 2000, imageQuality: 85, limit: room > 1 ? room : null);
      }
      if (picked.isEmpty) return;
      var skipped = 0;
      final add = <PickedImage>[];
      for (final x in picked.take(room)) {
        final bytes = await x.readAsBytes();
        final mime = PickedImage.sniffMime(bytes);
        if (mime == null) {
          skipped++;
          continue;
        }
        add.add(PickedImage(name: x.name, bytes: bytes, mime: mime));
      }
      if (!mounted) return;
      setState(() {
        _pending.addAll(add);
        if (add.isNotEmpty) _dirty = true;
      });
      if (skipped > 0) {
        showWarningSnackBar(
            context, '$skipped ${skipped == 1 ? 'file was' : 'files were'} skipped — use JPEG, PNG or WebP photos');
      } else if (picked.length > room) {
        showWarningSnackBar(context, 'Only $room more ${room == 1 ? 'image fits' : 'images fit'} on this call');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: "Couldn't open those photos.");
    }
  }

  void _onAddImages() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      _pickImages(ImageSource.gallery);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSaved(ConsultationImage image) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this image?'),
        content: const Text('It will be deleted from this call.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final fresh = await ref.read(consultationServiceProvider).deleteImage(_current.id, image.id);
      if (!mounted) return;
      setState(() => _current = fresh);
      ref.refreshData.consultations();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    final service = ref.read(consultationServiceProvider);
    final changed = _changedText();
    try {
      if (widget.complete) {
        await service.complete(_current.id, details: changed);
      } else if (changed.isNotEmpty) {
        await service.update(_current.id, changed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
      return;
    }

    // The text is saved; images go up after. If they fail, the details are
    // still kept — the stylist can add the images again from the call page.
    var imagesFailed = false;
    if (_pending.isNotEmpty) {
      try {
        await service.addImages(_current.id, List.of(_pending));
      } catch (e) {
        imagesFailed = true;
        if (mounted) showErrorSnackBar(context, e);
      }
    }
    ref.refreshData.consultations();
    if (!mounted) return;
    if (imagesFailed) {
      setState(() {
        _saving = false;
        _dirty = false;
      });
      showWarningSnackBar(context, 'Details saved, but the images were not uploaded. Try adding them again.');
      return;
    }
    _dirty = false;
    showSuccessSnackBar(context, widget.complete ? 'Call completed' : 'Call details saved');
    _leave();
  }

  Future<void> _markNoShow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as no-show?'),
        content: Text('${_current.clientName} did not join the call. Anything typed here will not be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark no-show')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(consultationServiceProvider).markNoShow(_current.id);
      ref.refreshData.consultations();
      if (!mounted) return;
      _dirty = false;
      showSuccessSnackBar(context, 'Marked as no-show');
      _leave();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/consultations/${_current.id}');
    }
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("What you've typed and any new images will be lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = _current;
    final title = widget.complete ? 'Complete call' : 'Call details';

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          _leave();
        }
      },
      child: Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(title: Text(title)),
        body: !c.notesVisible
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text("You don't have access to this call's notes.",
                      textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
                ),
              )
            : c.status == 'Cancelled'
                ? Center(
                    child: Text('This call was cancelled, so it cannot be edited.',
                        style: TextStyle(color: crm.textSecondary)),
                  )
                : _body(crm, c),
        bottomNavigationBar: c.notesVisible && c.status != 'Cancelled' ? _actions(crm) : null,
      ),
    );
  }

  Widget _body(CrmTheme crm, Consultation c) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Who and when
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: crm.primary.withValues(alpha: 0.12),
                    foregroundColor: crm.primary,
                    child: Text(c.clientName.isEmpty ? '?' : c.clientName.trim()[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.clientName.isEmpty ? 'Client' : c.clientName,
                            style: TextStyle(fontWeight: FontWeight.bold, color: crm.textPrimary, fontSize: 16)),
                        Text(
                          [
                            '${fmtDay(c.scheduledAt)}, ${fmtTime(c.scheduledAt)}',
                            c.isVideo ? 'Video' : 'In-person',
                            if (c.lead.eventDate != null) 'Event ${fmtShortDay(c.lead.eventDate!)}',
                          ].join('  ·  '),
                          style: TextStyle(color: crm.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ConsultationStatusChip(c.status),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final f in kAfterCallFields) ...[
              _field(crm, f),
              const SizedBox(height: 14),
            ],
            _imagesSection(crm, c),
          ],
        ),
      ),
    );
  }

  Widget _field(CrmTheme crm, AfterCallField f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(f.icon, size: 18, color: crm.primary),
            const SizedBox(width: 8),
            Text(f.label, style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _text[f.key],
          enabled: !_saving,
          minLines: f.lines,
          maxLines: f.lines + 6,
          maxLength: f.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: f.hint,
            filled: true,
            fillColor: crm.surface,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _imagesSection(CrmTheme crm, Consultation c) {
    final total = c.referenceImages.length + _pending.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 18, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reference images',
                    style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
              ),
              Text('$total / $kMaxReferenceImages', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Photos the client shared, such as outfit, jewellery or looks they like.',
              style: TextStyle(color: crm.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (c.referenceImages.isNotEmpty) ...[
            ReferenceImageGrid(images: c.referenceImages, onRemove: _saving ? null : _removeSaved),
            const SizedBox(height: 8),
          ],
          if (_pending.isNotEmpty) ...[
            Text('New: uploads when you save', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _pending.length; i++)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_pending[i].bytes, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _saving ? null : () => setState(() => _pending.removeAt(i)),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 16, color: Colors.white, semanticLabel: 'Remove image'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _saving || _room <= 0 ? null : _onAddImages,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Add images'),
          ),
        ],
      ),
    );
  }

  Widget _actions(CrmTheme crm) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: crm.surface,
          border: Border(top: BorderSide(color: crm.border)),
        ),
        child: Row(
          children: [
            if (widget.complete)
              Flexible(
                child: TextButton(
                  onPressed: _saving ? null : _markNoShow,
                  child: const Text("Client didn't join"),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(widget.complete ? Icons.check_circle_outline : Icons.save_outlined, size: 18),
              label: Text(widget.complete ? 'Complete call' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
