import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/help/controllers/help_chat_controller.dart';
import 'package:nizan_crm/features/help/services/help_service.dart';

const _kWide = 700.0;
const _kBotName = 'Team N';

/// Floating help button shown on every signed-in screen; opens the Team N chat.
class HelpAssistantOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const HelpAssistantOverlay({super.key, required this.child});

  @override
  ConsumerState<HelpAssistantOverlay> createState() =>
      _HelpAssistantOverlayState();
}

class _HelpAssistantOverlayState extends ConsumerState<HelpAssistantOverlay>
    with SingleTickerProviderStateMixin {
  // The "Need help?" nudge shows once per app run, then stays out of the way.
  static bool _nudged = false;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();
  bool _showNudge = false;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (!_nudged) {
      _showTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _nudged = true;
        setState(() => _showNudge = true);
        _hideTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _showNudge = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < _kWide;
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          // Clear of the mobile bottom navigation bar.
          bottom: narrow ? 92 : 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.3, 0), end: Offset.zero)
                        .animate(a),
                    child: c,
                  ),
                ),
                child: _showNudge
                    ? GestureDetector(
                        key: const ValueKey('nudge'),
                        onTap: () {
                          setState(() => _showNudge = false);
                          _open(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 14,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👋 Need help? Ask Team N',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _showNudge = false),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.close,
                                      size: 14, color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              Tooltip(
                message: 'Ask $_kBotName',
                child: GestureDetector(
                  onTap: () => _open(context),
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) {
                        final t = _pulse.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Expanding ring that draws the eye to the button.
                            Container(
                              width: 54 + 20 * t,
                              height: 54 + 20 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary
                                    .withValues(alpha: 0.28 * (1 - t)),
                              ),
                            ),
                            child!,
                          ],
                        );
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _brandGradient(cs),
                          boxShadow: [
                            BoxShadow(
                                color: cs.primary.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: const Center(
                            child: _NMark(size: 26, onDark: true)),
                      ),
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

  void _open(BuildContext context) {
    final router = GoRouter.of(context);
    if (MediaQuery.sizeOf(context).width < _kWide) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: HelpChatPanel(router: router),
          ),
        ),
      );
    } else {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close chat',
        barrierColor: Colors.black12,
        transitionDuration: const Duration(milliseconds: 220),
        transitionBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              elevation: 24,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                  width: math.min(430, MediaQuery.sizeOf(context).width - 40),
                  height: math.min(640, MediaQuery.sizeOf(context).height - 40),
                  child: HelpChatPanel(router: router)),
            ),
          ),
        ),
      );
    }
  }
}

LinearGradient _brandGradient(ColorScheme cs) => LinearGradient(
      colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.6)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

/// The bot icon used on the button, header and message avatars.
class _NMark extends StatelessWidget {
  final double size;
  final bool onDark;
  const _NMark({required this.size, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(Icons.smart_toy_rounded,
        size: size * 1.1, color: onDark ? cs.onPrimary : cs.primary);
  }
}

class HelpChatPanel extends ConsumerStatefulWidget {
  final GoRouter router;
  const HelpChatPanel({super.key, required this.router});

  @override
  ConsumerState<HelpChatPanel> createState() => _HelpChatPanelState();
}

class _HelpChatPanelState extends ConsumerState<HelpChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  static const _suggestions = [
    (Icons.request_quote_outlined, 'Create a quote', 'How do I create a quote?'),
    (Icons.chat_outlined, 'Invoice on WhatsApp', 'How do I send an invoice on WhatsApp?'),
    (Icons.flag_outlined, 'Report & Goals', 'Where is Report & Goals?'),
    (Icons.event_available_outlined, 'Apply for leave', 'How do I apply for leave?'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollDown(jump: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _controller.text).trim();
    if (q.isEmpty) return;
    _controller.clear();
    final f = ref.read(helpChatProvider.notifier).send(q);
    _scrollDown();
    await f;
    if (mounted) _scrollDown();
  }

  void _scrollDown({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent + 300;
      if (jump) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(end,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _openLink(HelpLink l) {
    final route = l.route;
    if (route == null) return;
    Navigator.of(context).pop();
    widget.router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(helpChatProvider);
    final cs = Theme.of(context).colorScheme;
    ref.listen(helpChatProvider, (_, _) => _scrollDown());
    return Material(
      color: cs.surface,
      child: Column(
        children: [
          _header(cs, chat),
          Expanded(
            child: chat.messages.isEmpty
                ? _welcome(cs)
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    children: [
                      for (final m in chat.messages) _message(m, cs),
                      if (chat.busy) _typing(cs),
                    ],
                  ),
          ),
          _composer(cs, chat.busy),
        ],
      ),
    );
  }

  Widget _header(ColorScheme cs, HelpChatState chat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                shape: BoxShape.circle, gradient: _brandGradient(cs)),
            child: const Center(child: _NMark(size: 20, onDark: true)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(_kBotName,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('AI Assistant · always here',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: chat.busy
                  ? null
                  : () => ref.read(helpChatProvider.notifier).clear(),
            ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _welcome(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      children: [
        Text('Hi, I\'m $_kBotName',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(
            'Ask me anything about Team N CRM or chat with me. I can guide you through features, explain how things work, and open the right screen for you.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, box) {
          final cardW = (box.maxWidth - 10) / 2;
          return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in _suggestions)
              SizedBox(
                width: cardW,
                child: Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _send(s.$3),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(s.$1, color: cs.primary),
                          const SizedBox(height: 10),
                          Text(s.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        }),
        const SizedBox(height: 18),
        Text('I can answer questions and guide you through the app. Client data privacy is always protected.',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _typing(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Text('Thinking…', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _message(HelpMsg m, ColorScheme cs) {
    if (m.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20)),
          child: Text(m.text,
              style: TextStyle(color: cs.onPrimaryContainer, height: 1.35)),
        ),
      );
    }
    final links = m.links.where((l) => l.route != null).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
                shape: BoxShape.circle, gradient: _brandGradient(cs)),
            child: const Center(child: _NMark(size: 15, onDark: true)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: m.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: cs.onSurface, height: 1.5),
                    listBullet: TextStyle(color: cs.onSurface),
                    strong: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final l in links) _linkCard(l, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkCard(HelpLink l, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openLink(l),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (l.menuPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(l.menuPath,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                    if (l.inPage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('💡 ${l.inPage}',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: cs.primary, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open',
                        style: TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 15, color: cs.onPrimary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(ColorScheme cs, bool busy) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 400,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask or chat with Team N…',
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: busy ? null : _send,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
