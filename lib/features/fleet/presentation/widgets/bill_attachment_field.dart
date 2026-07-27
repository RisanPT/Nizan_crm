import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/upload_service.dart';

/// Bill / receipt screenshot attachment for a fleet expense.
///
/// Shared by the driver's expense form and the fleet manager's expense dialog
/// so both capture proof the same way. When [required] is true the field shows
/// a "required" hint and turns red once the user has tried to submit without
/// attaching anything — use [isMissing] to drive that.
class BillAttachmentField extends ConsumerStatefulWidget {
  /// Currently attached image URL (null = nothing attached yet).
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Whether a bill must be attached before the expense can be saved.
  final bool required;

  /// Set true after a failed submit to highlight the field in red.
  final bool isMissing;

  const BillAttachmentField({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = true,
    this.isMissing = false,
  });

  @override
  ConsumerState<BillAttachmentField> createState() =>
      _BillAttachmentFieldState();
}

class _BillAttachmentFieldState extends ConsumerState<BillAttachmentField> {
  bool _uploading = false;

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Screenshot or saved bill'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final img = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (img == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ref.read(uploadServiceProvider).uploadImage(img);
      widget.onChanged(url);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Bill upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attached = widget.value != null && widget.value!.isNotEmpty;
    final showError = widget.isMissing && !attached;
    final borderColor = attached
        ? Colors.green
        : (showError ? Colors.red : Colors.grey.shade400);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _uploading ? null : _attach,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: borderColor, width: showError ? 1.6 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (_uploading)
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(
                      attached
                          ? Icons.check_circle
                          : Icons.receipt_long_outlined,
                      color: attached
                          ? Colors.green
                          : (showError ? Colors.red : Colors.grey)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _uploading
                        ? 'Uploading…'
                        : attached
                            ? 'Bill attached — tap to change'
                            : 'Attach bill / screenshot'
                                '${widget.required ? ' *' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (attached && !_uploading)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => widget.onChanged(null),
                  ),
              ],
            ),
          ),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'A bill / screenshot is required for this expense.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          )
        else if (widget.required && !attached)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Required — attach a photo or screenshot of the bill.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}
