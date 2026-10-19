import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/help/presentation/help_assistant.dart';

void main() {
  for (final size in [const Size(1900, 1000), const Size(390, 800)]) {
    testWidgets('help panel layout at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, _) => const HelpAssistantOverlay(
                child: Scaffold(body: Center(child: Text('page'))))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [authSessionProvider.overrideWithValue(null)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byTooltip("Ask Team N"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      final panel = find.byType(HelpChatPanel);
      expect(panel, findsOneWidget);
      // ignore: avoid_print
      print('panel size at $size: ${tester.getSize(panel)} topLeft ${tester.getTopLeft(panel)}');
      expect(tester.takeException(), isNull);
    });
  }
}
