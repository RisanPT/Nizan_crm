import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../services/upload_service.dart';

/// Full-screen viewer for a reference look, with swipe between images.
class ReferenceImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ReferenceImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context,
    List<String> images,
    int index,
  ) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) =>
          ReferenceImageViewer(images: images, initialIndex: index),
    );
  }

  @override
  State<ReferenceImageViewer> createState() => _ReferenceImageViewerState();
}

class _ReferenceImageViewerState extends State<ReferenceImageViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_index + 1} of ${widget.images.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Flexible(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('Could not load image',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of bride / client reference looks.
///
/// Read-only for artists; when [onChanged] is supplied (CRM side) images can
/// be added from camera or gallery and removed.
class ReferenceImagesPanel extends ConsumerStatefulWidget {
  final List<String> images;
  final ValueChanged<List<String>>? onChanged;
  final String title;
  final String emptyHint;

  const ReferenceImagesPanel({
    super.key,
    required this.images,
    this.onChanged,
    this.title = 'Reference Looks',
    this.emptyHint = 'No reference images yet.',
  });

  bool get isEditable => onChanged != null;

  @override
  ConsumerState<ReferenceImagesPanel> createState() =>
      _ReferenceImagesPanelState();
}

class _ReferenceImagesPanelState extends ConsumerState<ReferenceImagesPanel> {
  bool _busy = false;

  Future<void> _add(ImageSource source, {bool multiple = false}) async {
    final picker = ImagePicker();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = multiple
          ? await picker.pickMultiImage(imageQuality: 85)
          : [
              if (await picker.pickImage(source: source, imageQuality: 85)
                  case final XFile f)
                f
            ];
      if (picked.isEmpty) return;

      setState(() => _busy = true);
      final uploader = ref.read(uploadServiceProvider);
      final urls = <String>[];
      for (final file in picked) {
        urls.add(await uploader.uploadImage(file));
      }
      widget.onChanged!([...widget.images, ...urls]);
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                '${urls.length} reference image${urls.length == 1 ? '' : 's'} added.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSource() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select several at once'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'gallery') {
      await _add(ImageSource.gallery, multiple: true);
    } else if (choice == 'camera') {
      await _add(ImageSource.camera);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final images = widget.images;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 17, color: crm.primary),
            8.w,
            Expanded(
              child: Text(
                '${widget.title}${images.isEmpty ? '' : ' (${images.length})'}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary),
              ),
            ),
            if (widget.isEditable)
              TextButton.icon(
                onPressed: _busy ? null : _pickSource,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_busy ? 'Uploading…' : 'Add images'),
              ),
          ],
        ),
        8.h,
        if (images.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            child: Text(widget.emptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < images.length; i++)
                Stack(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          ReferenceImageViewer.open(context, images, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          images[i],
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 96,
                            height: 96,
                            color: crm.border,
                            child: Icon(Icons.broken_image_outlined,
                                color: crm.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    if (widget.isEditable)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: _busy
                              ? null
                              : () {
                                  final next = [...images]..removeAt(i);
                                  widget.onChanged!(next);
                                },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        if (widget.isEditable) ...[
          6.h,
          Text(
            'Uploaded looks are visible to the assigned artists on their job screen.',
            style: TextStyle(fontSize: 11, color: crm.textSecondary),
          ),
        ],
      ],
    );
  }
}
