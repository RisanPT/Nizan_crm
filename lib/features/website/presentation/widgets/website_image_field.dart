import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/upload_check.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

/// Image picker + uploader for one website image field, with preview and alt text.
/// Value shape: { url, publicId, width, height, alt } or null.
class WebsiteImageField extends ConsumerStatefulWidget {
  final String label;
  final bool required;
  final UploadRule rule;
  final String section; // upload target, e.g. 'hero', 'gallery', 'package'
  final String field; // e.g. 'imageDesktop', 'image', 'coverImage'
  final dynamic value;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const WebsiteImageField({
    super.key,
    required this.label,
    required this.rule,
    required this.section,
    required this.field,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  @override
  ConsumerState<WebsiteImageField> createState() => _WebsiteImageFieldState();
}

class _WebsiteImageFieldState extends ConsumerState<WebsiteImageField> {
  bool _busy = false;
  String? _problem;

  WebsiteImage? get _image => WebsiteImage.tryParse(widget.value);

  Future<({int width, int height})?> _decodeSize(List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      final size = (width: frame.image.width, height: frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null; // unreadable here — the server makes the final call
    }
  }

  Future<void> _pickAndUpload() async {
    setState(() => _problem = null);
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.rule.pickerExtensions,
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          e,
          fallback: "Couldn't open the file picker.",
        );
      }
      return;
    }
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() => _busy = true);
    try {
      final size = await _decodeSize(bytes);
      final problem = checkPickedImage(
        widget.rule,
        filename: file.name,
        bytes: file.size,
        width: size?.width,
        height: size?.height,
      );
      if (problem != null) {
        setState(() => _problem = problem);
        return;
      }
      final uploaded = await ref
          .read(websiteServiceProvider)
          .uploadImage(
            section: widget.section,
            field: widget.field,
            bytes: bytes,
            filename: file.name,
            mime: imageMimeFor(file.name),
          );
      // Keep the alt text already typed when replacing a picture.
      widget.onChanged(uploaded.copyWith(alt: _image?.alt ?? '').toJson());
    } catch (e) {
      if (mounted) {
        setState(() => _problem = e is AppException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final img = _image;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border.all(color: crm.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.label}${widget.required ? ' *' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.rule.hint,
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
          if (img == null)
            Text(
              'Not changed — the website keeps its current photo.',
              style: TextStyle(
                fontSize: 12,
                color: crm.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 10),
          if (img != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: crm.input,
                height: 180,
                width: double.infinity,
                child: Image.network(
                  img.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: crm.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            if (img.width != null && img.height != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${img.width} × ${img.height} px',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              key: ValueKey('alt-${img.publicId}'),
              initialValue: img.alt,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Describe the photo (alt text) *',
                helperText:
                    'For Google and screen readers, e.g. "Bride in a red silk saree"',
                isDense: true,
              ),
              onChanged: (v) => widget.onChanged(img.copyWith(alt: v).toJson()),
            ),
          ],
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _problem!,
                style: TextStyle(color: crm.destructive, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickAndUpload,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: Text(
                  _busy
                      ? 'Checking & uploading…'
                      : (img == null ? 'Upload image' : 'Replace'),
                ),
              ),
              if (img != null)
                TextButton.icon(
                  onPressed: _busy ? null : () => widget.onChanged(null),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
