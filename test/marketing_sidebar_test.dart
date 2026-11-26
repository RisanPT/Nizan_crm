import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart' show effectiveAccessProvider, effectiveRoleProvider;
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/data/marketing_eod_models.dart' show MarketingEodAccess;
import 'package:nizan_crm/features/marketing/presentation/shell/marketing_sidebar.dart';
import 'package:nizan_crm/features/marketing/services/marketing_eod_service.dart' show marketingEodAccessProvider;
import 'package:nizan_crm/presentation/common_widgets/main_layout.dart' show marketingDestinations, marketingTabIndex;

// The Marketing ERP sidebar and look. It must draw at every width (desktop, tablet where it collapses to icons, a phone's drawer); a tap on an
// item must go to that item's screen — once, and nowhere else; the phone's bottom bar must never claim a screen it does not own; and the whole
// Marketing UI wears the brand burgundy of the rest of the app, not a purple of its own.

const _marketing = Access(AppRole.marketingAdmin, {'marketing'});
const _admin = Access(AppRole.admin, {});

class _Rig {
  _Rig(this.router, this.seen);
  final GoRouter router;

  /// Every location the router reported, in order.
  final List<String> seen;
  String get path => router.routerDelegate.currentConfiguration.uri.path;
  String get uri => router.routerDelegate.currentConfiguration.uri.toString();
}

/// The sidebar beside a body that says where we are; every marketing path lands on the same page so the test can see the URL.
Future<_Rig> _pump(WidgetTester t, Size size, {String start = '/marketing/dashboard', Access access = _marketing, AppRole role = AppRole.marketingAdmin, bool manager = false}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/marketing/:page',
        builder: (_, state) => Scaffold(
          body: Row(children: [
            const MarketingSidebar(),
            Expanded(child: Center(child: Text('PAGE ${state.uri.path}${state.uri.query.isEmpty ? '' : '?${state.uri.query}'}', key: const Key('where')))),
          ]),
        ),
      ),
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/:any', builder: (_, state) => Scaffold(body: Text('OTHER ${state.uri.path}'))),
    ],
  );
  final seen = <String>[];
  await t.pumpWidget(ProviderScope(
    overrides: <Override>[
      effectiveAccessProvider.overrideWithValue(access),
      effectiveRoleProvider.overrideWithValue(role),
      // who the EOD screen says may change its Setup (the server's isManagerOrAdmin)
      marketingEodAccessProvider.overrideWith((ref) async => MarketingEodAccess(isManager: manager, canViewTeam: manager)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await t.pump(const Duration(milliseconds: 100));
  router.routerDelegate.addListener(() => seen.add(router.routerDelegate.currentConfiguration.uri.toString()));
  return _Rig(router, seen);
}

Finder _nav(String id) => find.byKey(Key('mkt_nav_$id'));
String _where(WidgetTester t) => t.widget<Text>(find.byKey(const Key('where'))).data!;
Color? _tileColor(WidgetTester t, String id) => t.widget<Material>(find.descendant(of: _nav(id), matching: find.byType(Material)).first).color;

void main() {
  group('it draws at every width', () {
    for (final size in const [Size(1440, 900), Size(1280, 800), Size(1024, 768), Size(840, 900), Size(839, 900), Size(768, 1024), Size(600, 900), Size(390, 844)]) {
      testWidgets('${size.width.toInt()} x ${size.height.toInt()}', (t) async {
        await _pump(t, size);
        expect(_nav('overview'), findsOneWidget);
        expect(find.byKey(const Key('where')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('a tap goes to that screen, once, and nowhere else', () {
    testWidgets('an item without sub-items', (t) async {
      final rig = await _pump(t, const Size(1280, 800));
      await t.tap(_nav('analytics'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_where(t), 'PAGE /marketing/analytics');
      expect(rig.seen.toSet(), {'/marketing/analytics'}, reason: 'it did not bounce through any other screen');
    });

    testWidgets('on a tablet, where the sidebar is icons only', (t) async {
      final rig = await _pump(t, const Size(768, 1024));
      await t.tap(_nav('weekly'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_where(t), 'PAGE /marketing/weekly');
      expect(rig.seen.toSet(), {'/marketing/weekly'});
      await t.tap(_nav('competitors'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_where(t), 'PAGE /marketing/competitors');
    });

    testWidgets('a group opens its sub-items and goes to its first screen; tapping it again only folds it', (t) async {
      final rig = await _pump(t, const Size(1280, 800));
      expect(_nav('portfolio.calendar'), findsNothing);
      await t.tap(_nav('portfolio'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_where(t), 'PAGE /marketing/portfolio');
      expect(_nav('portfolio.planner'), findsOneWidget);
      expect(_nav('portfolio.calendar'), findsOneWidget);
      final went = rig.seen.length;
      await t.tap(_nav('portfolio'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_nav('portfolio.calendar'), findsNothing, reason: 'folded');
      expect(rig.seen.length, went, reason: 'folding a group does not navigate');
      expect(_where(t), 'PAGE /marketing/portfolio');
    });

    testWidgets('a sub-item puts its tab in the address and is the one lit', (t) async {
      final rig = await _pump(t, const Size(1280, 800));
      await t.tap(_nav('portfolio'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(_nav('portfolio.calendar'));
      await t.pump(const Duration(milliseconds: 300));
      expect(_where(t), 'PAGE /marketing/portfolio?tab=calendar');
      expect(rig.seen.last, '/marketing/portfolio?tab=calendar');
      expect(_tileColor(t, 'portfolio.calendar'), isNot(Colors.transparent), reason: 'the open sub-item is highlighted');
      expect(_tileColor(t, 'portfolio.planner'), Colors.transparent, reason: 'and the others are not');
      expect(_tileColor(t, 'portfolio'), Colors.transparent, reason: 'the group stays plain while its sub-item carries the highlight');
    });

    testWidgets('quick taps one after another end on the last one tapped', (t) async {
      final rig = await _pump(t, const Size(1280, 800));
      await t.tap(_nav('socials'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(_nav('socials.assets'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(_nav('socials.performance'));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(_nav('socials.calendar'));
      await t.pump(const Duration(milliseconds: 400));
      expect(_where(t), 'PAGE /marketing/socials?tab=calendar');
      expect(rig.seen.last, '/marketing/socials?tab=calendar');
      expect(rig.seen, ['/marketing/socials', '/marketing/socials?tab=assets', '/marketing/socials?tab=performance', '/marketing/socials?tab=calendar'], reason: 'one move per tap, in order');
    });

    testWidgets('the account strip: Profile, Support and Backup go to their own screens', (t) async {
      final rig = await _pump(t, const Size(1280, 800));
      await t.tap(find.byTooltip('Profile'));
      await t.pump(const Duration(milliseconds: 300));
      expect(rig.path, '/profile');
      final rig2 = await _pump(t, const Size(1280, 800));
      await t.tap(find.byTooltip('Support'));
      await t.pump(const Duration(milliseconds: 300));
      expect(rig2.path, '/helpdesk');
      final rig3 = await _pump(t, const Size(1280, 800));
      await t.tap(find.byTooltip('Backup'));
      await t.pump(const Duration(milliseconds: 300));
      expect(rig3.path, '/backup');
    });

    testWidgets('on a tablet the account icons are there too, and work', (t) async {
      final rig = await _pump(t, const Size(768, 1024));
      await t.tap(find.byTooltip('Profile'));
      await t.pump(const Duration(milliseconds: 300));
      expect(rig.path, '/profile');
    });
  });

  group('who sees the way back', () {
    testWidgets('the Marketing login has no "Main menu"; anyone else inside /marketing gets one that goes home', (t) async {
      await _pump(t, const Size(1280, 800));
      expect(_nav('back'), findsNothing);
      final rig = await _pump(t, const Size(1280, 800), access: _admin, role: AppRole.admin);
      expect(_nav('back'), findsOneWidget);
      await t.tap(_nav('back'));
      await t.pump(const Duration(milliseconds: 300));
      expect(rig.path, '/');
    });
  });

  group('the phone bottom bar never claims a screen it does not own', () {
    test('Overview, Competitors and Score own their screens; every other marketing screen is More', () {
      expect(marketingTabIndex('/marketing/dashboard'), 0);
      expect(marketingTabIndex('/marketing/competitors'), 1);
      expect(marketingTabIndex('/marketing/scores'), 2);
      for (final p in ['/marketing/portfolio', '/marketing/socials', '/marketing/campaigns', '/marketing/leads-report', '/marketing/team', '/marketing/weekly', '/marketing/insights', '/marketing/analytics', '/marketing/strategies', '/marketing/coordinations', '/marketing/content/dashboard']) {
        expect(marketingTabIndex(p), 3, reason: p);
      }
    });

    test('four tabs, with More last (it opens the full menu)', () {
      final d = marketingDestinations();
      expect(d.map((e) => e.label), ['Overview', 'Competitors', 'Score', 'More']);
      expect(marketingDestinations().length, 4);
    });
  });

  group('the Marketing look is the brand burgundy of the rest of the app', () {
    final crm = AppTheme.crmThemeExtension;

    test('the palette is the app\'s own: primary, ground, hairline, sidebar', () {
      expect(Mkt.primary, crm.primary, reason: 'the accent colour is the brand maroon, not a purple');
      expect(Mkt.maroon, crm.primary, reason: 'filled buttons too');
      expect(Mkt.bg, crm.background);
      expect(Mkt.border, crm.border);
      expect(Mkt.maroonDeep, crm.sidebar, reason: 'the foot of the sidebar is the colour of the main menu');
    });

    test('the primary is a burgundy: red-dominant and dark, not blue-dominant', () {
      for (final c in [Mkt.primary, Mkt.primaryLight]) {
        expect(c.r, greaterThan(c.b), reason: '$c');
        expect(c.b, lessThan(0.4), reason: '$c');
        expect(c.r, lessThan(0.7), reason: '$c is dark enough to read as burgundy');
      }
    });

    testWidgets('a filled button is burgundy', (t) async {
      await t.pumpWidget(MaterialApp(home: Scaffold(body: MktPrimaryButton(label: 'Save', onPressed: () {}))));
      final style = t.widget<FilledButton>(find.byType(FilledButton)).style!;
      expect(style.backgroundColor!.resolve(<WidgetState>{}), crm.primary);
    });

    test('no stray purple is left in the Marketing screens', () {
      const purples = ['0xFF5B3FD9', '0xFF7C5CE8', '0xFFEDE8FB', '0xFF86315A', '0xFF5A1030', '0xFF3F0B22', '0xFFF7F4FA', '0xFFE9E3F1'];
      final hits = <String>[];
      for (final f in Directory('lib/features/marketing').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final text = f.readAsStringSync();
        for (final p in purples) {
          if (text.contains(p)) hits.add('${f.path}: $p');
        }
      }
      expect(hits, isEmpty);
    });
  });

  group('the Setup link (EOD → Setup) is for the Marketing Manager and admin only', () {
    testWidgets('a manager sees it, and it opens the EOD screen on its Setup tab', (t) async {
      final rig = await _pump(t, const Size(1280, 900), manager: true);
      await t.pumpAndSettle();
      expect(_nav('setup'), findsOneWidget);
      await t.tap(_nav('setup'));
      await t.pumpAndSettle();
      expect(rig.uri, '/marketing/eod?tab=setup');
    });

    testWidgets('a member does not see it', (t) async {
      await _pump(t, const Size(1280, 900));
      await t.pumpAndSettle();
      expect(_nav('setup'), findsNothing);
    });
  });
}

