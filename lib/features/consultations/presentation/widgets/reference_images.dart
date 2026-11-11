import 'package:flutter/material.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../data/consultation.dart';

/// A wrap of square thumbnails. Tapping one opens [showReferenceImageViewer].
/// [onRemove] adds a small remove button on each thumbnail.
class ReferenceImageGrid extends StatelessWidget {
  const ReferenceImageGrid({
    super.key,
    required this.images,
    this.onRemove,
    this.size = 96,
  });

  final List<ConsultationImage> images;
  final void Function(ConsultationImage image)? onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < images.length; i++)
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    color: crm.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showReferenceImageViewer(context, images, initialIndex: i),
                      child: Tooltip(
                        message: images[i].caption.isEmpty ? 'Open image' : images[i].caption,
                        child: Image.network(
                          images[i].thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.broken_image_outlined, color: crm.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove!(images[i]),
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
    );
  }
}

/// Full-screen viewer: swipe between images, pinch or double-tap to zoom.
Future<void> showReferenceImageViewer(
  BuildContext context,
  List<ConsultationImage> images, {
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _ImageViewer(images: images, initialIndex: initialIndex),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initialIndex});

  final List<ConsultationImage> images;
  final int initialIndex;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.images.length) return;
    _pages.animateToPage(next, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];
    final many = widget.images.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(many ? '${_index + 1} of ${widget.images.length}' : 'Reference image',
            style: const TextStyle(fontSize: 16)),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ZoomableImage(url: widget.images[i].url),
          ),
          if (many && _index > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _NavButton(icon: Icons.chevron_left, tooltip: 'Previous', onTap: () => _go(-1)),
            ),
          if (many && _index < widget.images.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: _NavButton(icon: Icons.chevron_right, tooltip: 'Next', onTap: () => _go(1)),
            ),
          if (image.caption.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black54,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: SafeArea(
                  top: false,
                  child: Text(image.caption,
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton.filled(
          tooltip: tooltip,
          style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
          onPressed: onTap,
          icon: Icon(icon),
        ),
      );
}

/// Pinch to zoom; double-tap toggles 2.5× zoom.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _zoom = TransformationController();
  TapDownDetails? _tap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = _tap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _zoom,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, _, _) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
                SizedBox(height: 8),
                Text("Couldn't load this image", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
