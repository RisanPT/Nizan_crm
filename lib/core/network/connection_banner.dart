import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity.dart';

/// Wraps the whole app and shows a strip at the top whenever the API can't be
/// reached ("You're offline"), then a brief "Back online" when it recovers.
/// Content is pushed down rather than covered, so nothing becomes untappable.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);
    final show = status != NetworkStatus.online;
    final offline = status == NetworkStatus.offline;

    final bg = offline ? const Color(0xFF7F1D1D) : const Color(0xFF166534);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: !show
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: bg,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Icon(
                            offline
                                ? Icons.wifi_off_rounded
                                : Icons.wifi_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              offline
                                  ? "You're offline — can't reach the server. "
                                      'Changes won’t be saved until the connection is back.'
                                  : 'Back online',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (offline)
                            TextButton(
                              onPressed: () =>
                                  ref.read(connectivityProvider.notifier).retry(),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white),
                              child: const Text('Retry'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          // Let screens below handle the top inset themselves only when the
          // banner isn't already covering it.
          child: show
              ? MediaQuery.removePadding(
                  context: context, removeTop: true, child: child)
              : child,
        ),
      ],
    );
  }
}
