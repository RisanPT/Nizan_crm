// DEV ONLY — shows the in-app notification popup in a real browser to check it
// closes by itself. No backend, nothing saved. Build + serve:
//   flutter build web -t dev/toast_preview.dart -o build/toast_preview
//   node dev/serve_static.mjs build/toast_preview 5192
import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/notifications/presentation/widgets/notification_toast.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _Page(),
    ));

class _Page extends StatefulWidget {
  const _Page();
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int _n = 0;
  final _log = <String>[];

  void _show() {
    final i = ++_n;
    final shownAt = DateTime.now();
    NotificationToast.show(
      context,
      title: 'Sample notification $i',
      body: 'This popup should close by itself after 5 seconds.',
      onDismissed: () => setState(() => _log.insert(0,
          '#$i closed after ${DateTime.now().difference(shownAt).inMilliseconds} ms')),
    );
    setState(() => _log.insert(0, '#$i shown'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Popup test')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, children: [
              FilledButton(key: const Key('show'), onPressed: _show, child: const Text('Show popup')),
              // Switch to another tab right after pressing: the popup then
              // arrives while this page isn't being drawn (the real bug case).
              OutlinedButton(
                onPressed: () => Future<void>.delayed(const Duration(seconds: 2), _show),
                child: const Text('Show popup in 2s'),
              ),
            ]),
            const SizedBox(height: 12),
            for (final l in _log) Text(l, key: ValueKey(l)),
          ]),
        ),
      );
}
