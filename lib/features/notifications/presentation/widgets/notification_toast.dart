import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/crm_theme.dart';

/// A lightweight, self-dismissing notification popup rendered in the root
/// overlay (top-right on wide screens, top full-width on phones). Multiple
/// toasts stack downward and close up the gap when one is dismissed.
class NotificationToast {
  NotificationToast._();

  /// Toasts currently on screen, oldest first. A toast's position in this list
  /// is its slot, so removing one lets the rest slide up.
  static final List<OverlayEntry> _active = [];
  static const _cardHeight = 92.0;
  static const _gap = 10.0;
  static const _maxVisible = 4;
  static const _lifetime = Duration(seconds: 6);

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_rounded,
    VoidCallback? onTap,
    VoidCallback? onDismissed,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    Timer? timer;

    void dismiss() {
      timer?.cancel();
      if (!_active.remove(entry)) return;
      if (entry.mounted) entry.remove();
      onDismissed?.call();
      // Re-slot the remaining toasts so they move up into the freed space.
      for (final e in _active) {
        if (e.mounted) e.markNeedsBuild();
      }
    }

    // Cap the stack — drop the oldest if we're overflowing.
    while (_active.length >= _maxVisible) {
      final oldest = _active.removeAt(0);
      if (oldest.mounted) oldest.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) {
        final slot = _active.indexOf(entry).clamp(0, _maxVisible);
        return _ToastCard(
          title: title,
          body: body,
          icon: icon,
          topOffset: _gap + slot * (_cardHeight + _gap),
          // Tapping the card opens the linked screen (if any) and closes it.
          onTap: () {
            dismiss();
            onTap?.call();
          },
          // The ✕ and a sideways swipe only close it.
          onClose: dismiss,
          // Hovering (desktop) pauses the auto-close so it can be read.
          onHover: (hovering) {
            timer?.cancel();
            if (!hovering) timer = Timer(_lifetime, dismiss);
          },
        );
      },
    );

    _active.add(entry);
    overlay.insert(entry);
    timer = Timer(_lifetime, dismiss);
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
    this.onHover,
  });

  final String title;
  final String body;
  final IconData icon;
  final double topOffset;
  final VoidCallback onClose;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  // Stable key so the Dismissible survives rebuilds of this card.
  final Key _dismissKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween(
      begin: const Offset(0.15, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
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

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      top: media.padding.top + widget.topOffset,
      right: isNarrow ? 12 : 16,
      left: isNarrow ? 12 : null,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          // Swipe sideways to dismiss — a guaranteed way to clear the toast
          // even if a tap is missed.
          child: MouseRegion(
            onEnter: (_) => widget.onHover?.call(true),
            onExit: (_) => widget.onHover?.call(false),
            child: Dismissible(
              key: _dismissKey,
              direction: DismissDirection.horizontal,
              onDismissed: (_) => widget.onClose(),
              child: Container(
                width: width,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    // Tapping the card closes it and opens the linked screen.
                    onTap: widget.onTap,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: crm.border),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: crm.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 20,
                              color: crm.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.body,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: crm.textSecondary,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Real close button: closes WITHOUT following the link.
                          // As the innermost tap target it wins the gesture arena
                          // over the card's InkWell.
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              tooltip: 'Close',
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              onPressed: widget.onClose,
                              icon: Icon(
                                Icons.close_rounded,
                                color: crm.textSecondary,
                              ),
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
        ),
      ),
    );
  }
}
