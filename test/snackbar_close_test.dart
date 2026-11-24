// Snackbars must always be closable: the app theme adds a close (✕) button,
// and snackbars with an action (Undo / Retry / Open PDF) close by themselves
// because they set `persist: false` (Flutter otherwise keeps them forever).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';

Widget _app(SnackBar bar) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(bar),
            child: const Text('show'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('every snackbar has a close button that closes it', (t) async {
    await t.pumpWidget(_app(const SnackBar(content: Text('Saved'))));
    await t.tap(find.text('show'));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a snackbar with an action closes itself after 5 s', (t) async {
    await t.pumpWidget(_app(SnackBar(
      content: const Text('Removed 23 Nov'),
      persist: false,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    )));
    await t.tap(find.text('show'));
    await t.pumpAndSettle();
    expect(find.text('Removed 23 Nov'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Removed 23 Nov'), findsNothing);
  });

  testWidgets('without persist: false it would stay (why the fix is needed)', (t) async {
    await t.pumpWidget(_app(SnackBar(
      content: const Text('Stuck'),
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    )));
    await t.tap(find.text('show'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(find.text('Stuck'), findsOneWidget);
  });
}
