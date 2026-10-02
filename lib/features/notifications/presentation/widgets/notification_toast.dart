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
  // Always auto-closes within 5s. [_hardLimit] can't be paused — a resting
  // mouse cursor over the toast used to pause it forever (hover-pause only
  // resumed on mouse exit).
  static const _lifetime = Duration(seconds: 5);
  static const _hardLimit = Duration(seconds: 5);
  // Each toast's dismiss callback, so a toast dropped by the stack cap also
  // cancels its timers.
  static final Map<OverlayEntry, VoidCallback> _dismissers = {};

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
    Timer? hardTimer;

    void dismiss() {
      timer?.cancel();
      hardTimer?.cancel();
      _dismissers.remove(entry);
      if (!_active.remove(entry)) return;
      if (entry.mounted) entry.remove();
      onDismissed?.call();
      // Re-slot the remaining toasts so they move up into the freed space.
      for (final e in _active) {
        if (e.mounted) e.markNeedsBuild();
      }
    }

    // Cap the stack — drop the oldest if we're overflowing.
    bool overflowed = false;
    while (_active.length >= _maxVisible) {
      final oldest = _active.first;
      final close = _dismissers[oldest];
      if (close != null) {
        close(); // cancels its timers + closes its native twin
      } else {
        _active.removeAt(0);
        if (oldest.mounted) oldest.remove();
      }
      overflowed = true;
    }
    // Re-slot the remaining toasts so they slide up to make room.
    if (overflowed) {
      for (final e in _active) {
        if (e.mounted) e.markNeedsBuild();
      }
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
            // Already closed (e.g. ✕ closes on pointer-down, and the same
            // click's release then reaches this card) → don't open the link.
            if (!_active.contains(entry)) return;
            dismiss();
            onTap?.call();
          },
          // The ✕ and a sideways swipe only close it.
          onClose: dismiss,
          // Hovering (desktop) pauses the 5s auto-close so it can be read;
          // leaving restarts a short countdown. The hard limit still applies.
          onHover: (hovering) {
            timer?.cancel();
            if (!hovering) timer = Timer(const Duration(seconds: 2), dismiss);
          },
        );
      },
    );

    _active.add(entry);
    _dismissers[entry] = dismiss;
    overlay.insert(entry);
    timer = Timer(_lifetime, dismiss);
    hardTimer = Timer(_hardLimit, dismiss);
  }

  /// Close every toast currently on screen.
  static void dismissAll() {
    for (final close in _dismissers.values.toList()) {
      close();
    }
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.color, required this.onClose});
  final Color color;
  final VoidCallback onClose;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;
  bool _closed = false;

  void _close() {
    if (_closed) return; // pointer-down + any later tap must not double-fire
    _closed = true;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _close(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: Icon(Icons.close_rounded, size: 18, color: widget.color),
          ),
        ),
      ),
    );
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
                          // Close button: closes WITHOUT following the link.
                          // A raw Listener fires on pointer-down, before the
                          // gesture arena — so the card's InkWell / the swipe
                          // detector can never swallow the click (which is why
                          // the old IconButton sometimes did nothing).
                          _CloseButton(
                            color: crm.textSecondary,
                            onClose: widget.onClose,
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
