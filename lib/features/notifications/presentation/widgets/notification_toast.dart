import 'package:flutter/material.dart';

import '../../../../core/theme/crm_theme.dart';

/// A lightweight, self-dismissing notification popup rendered in the root
/// overlay (top-right on wide screens, top full-width on phones). Multiple
/// toasts stack downward.
class NotificationToast {
  NotificationToast._();

  /// How many toasts are currently on screen, so new ones stack below.
  static final List<OverlayEntry> _active = [];
  static const _cardHeight = 92.0;
  static const _gap = 10.0;
  static const _maxVisible = 4;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_rounded,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Cap the stack — drop the oldest if we're overflowing.
    if (_active.length >= _maxVisible) {
      final oldest = _active.first;
      if (oldest.mounted) oldest.remove();
      _active.remove(oldest);
    }

    final slot = _active.length;
    late OverlayEntry entry;

    void dismiss() {
      if (!_active.contains(entry)) return;
      _active.remove(entry);
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) => _ToastCard(
        title: title,
        body: body,
        icon: icon,
        topOffset: _gap + slot * (_cardHeight + _gap),
        onTap: onTap == null
            ? null
            : () {
                onTap();
                dismiss();
              },
        onClose: dismiss,
      ),
    );

    _active.add(entry);
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 6), dismiss);
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.topOffset,
    required this.onClose,
    this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final double topOffset;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _slide = Tween(begin: const Offset(0.15, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 520;
    final width = isNarrow ? media.size.width - 24 : 380.0;

    return Positioned(
      top: media.padding.top + widget.topOffset,
      right: isNarrow ? 12 : 16,
      left: isNarrow ? 12 : null,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, size: 20, color: crm.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.body,
                              style: TextStyle(fontSize: 12, color: crm.textSecondary, height: 1.25),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onClose,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded, size: 16, color: crm.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
