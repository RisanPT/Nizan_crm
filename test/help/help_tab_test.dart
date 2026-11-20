import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/help/presentation/help_assistant.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The floating help button is a slim tab on the RIGHT EDGE (in the page's side margin), not a big round button over the bottom-right
// corner where pages keep their main buttons. It can be dragged along the edge and remembers where it was left; tapping it (or the
// "Need help?" nudge) opens the chat exactly as before.
//
// (No pumpAndSettle here: the tab's soft glow animates forever.)

const _desktop = Size(1280, 800);
const _phone = Size(390, 800);
const _tick = Duration(milliseconds: 50);

/// A page with a main button where pages usually put one: the bottom-right corner.
Future<void> _pump(
  WidgetTester t, {
  Size size = _desktop,
  Map<String, Object> stored = const {},
  void Function()? onSave,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HelpAssistantOverlay(
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                child: FilledButton(
                  key: const Key('pageSave'),
                  onPressed: onSave,
                  child: const Text('Save changes'),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [authSessionProvider.overrideWithValue(null)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await t.pump(_tick);
}

Finder get _tab => find.byKey(const Key('helpTab'));
Rect _rect(WidgetTester t, Finder f) => t.getRect(f);

void main() {
  // FIRST in the file on purpose: the nudge shows once per app run (a static flag), so an earlier test that lets 1.5 s pass would use it up.
  testWidgets(
    'the "Need help?" nudge still appears once, beside the tab, opens the chat when tapped',
    (t) async {
      await _pump(t);
      await t.pump(const Duration(milliseconds: 1600));
      await t.pump(const Duration(milliseconds: 500));
      final nudge = find.text('👋 Need help? Ask Team N');
      expect(nudge, findsOneWidget);
      expect(
        _rect(t, nudge).right,
        lessThanOrEqualTo(_rect(t, _tab).left + 44),
        reason: 'beside the tab, to its left',
      );
      await t.tap(nudge);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(HelpChatPanel), findsOneWidget);
      // once per app run: a later screen does not show it again
      await t.pumpWidget(const SizedBox());
      await _pump(t);
      await t.pump(const Duration(milliseconds: 2200));
      expect(find.text('👋 Need help? Ask Team N'), findsNothing);
    },
  );

  group('where the tab sits', () {
    testWidgets(
      'hugging the right edge, slim, clear of the bottom-right corner and of the top bar',
      (t) async {
        await _pump(t);
        final r = _rect(t, _tab);
        expect(r.right, _desktop.width, reason: 'flush with the edge');
        expect(
          r.width,
          lessThanOrEqualTo(44),
          reason:
              'slim: the tap area is a finger wide, the visible tab is narrower',
        );
        expect(r.height, lessThanOrEqualTo(64));
        expect(r.top, greaterThanOrEqualTo(72), reason: 'below the top bar');
        expect(
          r.bottom,
          lessThan(_desktop.height - 24),
          reason: 'not in the bottom-right corner where the main buttons are',
        );
        expect(
          Rect.fromLTWH(
            _desktop.width - 140,
            _desktop.height - 140,
            140,
            140,
          ).overlaps(r),
          isFalse,
        );
      },
    );

    testWidgets(
      'a button in the bottom-right corner is not covered: it is fully visible and a tap reaches it',
      (t) async {
        var saved = 0;
        await _pump(t, onSave: () => saved += 1);
        expect(
          _rect(t, find.byKey(const Key('pageSave'))).overlaps(_rect(t, _tab)),
          isFalse,
        );
        await t.tap(find.byKey(const Key('pageSave')));
        expect(saved, 1);
      },
    );

    testWidgets('on a phone it stays above the bottom navigation bar', (
      t,
    ) async {
      await _pump(t, size: _phone);
      final r = _rect(t, _tab);
      expect(r.right, _phone.width);
      expect(r.bottom, lessThanOrEqualTo(_phone.height - 100));
      expect(r.top, greaterThanOrEqualTo(72));
    });

    testWidgets(
      'the visible tab is only 26 wide — it sits in the page margin, not over the content',
      (t) async {
        await _pump(t);
        expect(
          t
              .getSize(
                find
                    .descendant(of: _tab, matching: find.byType(Container))
                    .first,
              )
              .width,
          26,
        );
      },
    );
  });

  group('moving it', () {
    testWidgets('dragging slides it along the edge and it stays on the edge', (
      t,
    ) async {
      await _pump(t);
      final before = _rect(t, _tab);
      await t.drag(_tab, const Offset(0, -150));
      await t.pump(_tick);
      final after = _rect(t, _tab);
      // (Flutter swallows the first ~18px of a drag as touch slop)
      expect(before.top - after.top, inInclusiveRange(125, 150));
      expect(after.right, _desktop.width, reason: 'still on the edge');
    });

    testWidgets(
      'it cannot be dragged off the screen — nor into the top bar or the bottom corner',
      (t) async {
        await _pump(t);
        await t.drag(_tab, const Offset(0, -2000));
        await t.pump(_tick);
        expect(_rect(t, _tab).top, 72);
        await t.drag(_tab, const Offset(0, 2000));
        await t.pump(_tick);
        expect(_rect(t, _tab).bottom, _desktop.height - 24);
      },
    );

    testWidgets(
      'where it was left is remembered; the next visit starts there',
      (t) async {
        await _pump(t);
        await t.drag(_tab, const Offset(0, -2000));
        await t.pump(_tick);
        await t.pump(_tick);
        expect(
          (await SharedPreferences.getInstance()).getDouble(
            'help.assistant.edge',
          ),
          0.0,
        );
        await t.pumpWidget(const SizedBox());
        await _pump(t, stored: {'help.assistant.edge': 0.0});
        await t.pump(_tick);
        expect(_rect(t, _tab).top, 72);
      },
    );

    testWidgets(
      'a stored place outside 0..1 is clamped; nothing stored means the usual place',
      (t) async {
        await _pump(t, stored: {'help.assistant.edge': 7.0});
        await t.pump(_tick);
        expect(_rect(t, _tab).bottom, _desktop.height - 24);
        await t.pumpWidget(const SizedBox());
        await _pump(t);
        await t.pump(_tick);
        final usual = _rect(t, _tab).top;
        expect(usual, greaterThan(300));
        expect(usual, lessThan(600));
      },
    );

    testWidgets('a tap is a tap, not a drag: it does not move the tab', (
      t,
    ) async {
      await _pump(t);
      final before = _rect(t, _tab);
      await t.tap(_tab);
      await t.pump(const Duration(milliseconds: 400));
      expect(_rect(t, _tab), before);
    });
  });

  group('what it does is unchanged', () {
    testWidgets(
      'tapping it opens the Team N chat; its tooltip still says Ask Team N',
      (t) async {
        await _pump(t);
        expect(find.byTooltip('Ask Team N'), findsOneWidget);
        await t.tap(_tab);
        await t.pump(const Duration(milliseconds: 500));
        expect(find.byType(HelpChatPanel), findsOneWidget);
      },
    );
  });
}
