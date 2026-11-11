import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/presentation/screens/monthly_objectives_screen.dart';
import 'package:nizan_crm/features/it/services/monthly_objective_service.dart';
import 'package:nizan_crm/presentation/common_widgets/sidebar.dart';

// A department's people must be able to REACH their monthly objectives. Company Projects can be switched off per role (a role with an
// explicit permission list gets only what is ticked), so the way in cannot depend on it: every team member has "Monthly Objectives"
// in the menu, and the server decides what each person sees.

Access _roleWith(AppRole role, Set<String> permissions) => Access(role, permissions, roleKey: role.name);

void main() {
  group('the way in is open to every team member', () {
    test('a role with an explicit permission list and no Company Projects can still open Monthly Objectives — and still not Company Projects', () {
      final it = _roleWith(AppRole.fromString('it'), {'it', 'it.projects', 'it.tickets'}); // what the IT login in the field has
      expect(isRouteAllowed('/projects', it), isFalse, reason: 'the situation we are in: no Company Projects for this role');
      expect(isRouteAllowed('/monthly-objectives', it), isTrue);
      expect(isRouteAllowed('/monthly-objectives/', it), isTrue);
    });

    test('whatever the role, however little it is allowed', () {
      for (final role in AppRole.values) {
        final a = _roleWith(role, {'notifications'});
        expect(isRouteAllowed('/monthly-objectives', a), isTrue, reason: role.name);
      }
    });

    test('and a custom role the app does not know by name', () {
      expect(isRouteAllowed('/monthly-objectives', _roleWith(AppRole.fromString('some_custom_role'), {'dashboard'})), isTrue);
    });

    test('the CEO may open it too (to look — the server refuses every change)', () {
      expect(isRouteAllowed('/monthly-objectives', _roleWith(AppRole.ceo, {'ceo', 'planning'})), isTrue);
    });

    test('for the CEO it is a screen like /projects: it opens that one door, not the ones next to it', () {
      final ceo = _roleWith(AppRole.ceo, {'ceo', 'planning'});
      expect(isRouteAllowed('/hr/compensation', ceo), isFalse);
      expect(isRouteAllowed('/staff', ceo), isFalse);
    });
  });

  test('the page is registered with the app\'s router (the real router needs a signed-in app to build, so this reads its source)', () {
    final src = File('lib/core/routing/app_router.dart').readAsStringSync();
    expect(RegExp(r"path:\s*'/monthly-objectives',\s*builder:\s*\(context, state\) => const MonthlyObjectivesScreen\(\)").hasMatch(src), isTrue);
    expect(src.contains("title = 'Monthly Objectives'"), isTrue);
  });

  group('the menu', () {
    Future<GoRouter> pumpSidebar(WidgetTester tester, {required AuthSession session}) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Row(children: [
              SizedBox(
                width: 250,
                child: Sidebar(
                  fleetExpanded: false, fleetUserCollapsed: false, onFleetExpandToggle: (_) {},
                  accountsExpanded: false, accountsUserCollapsed: false, onAccountsExpandToggle: (_) {},
                  operationsExpanded: false, operationsUserCollapsed: false, onOperationsExpandToggle: (_) {},
                  administrativeExpanded: false, administrativeUserCollapsed: false, onAdministrativeExpandToggle: (_) {},
                  inventoryExpanded: false, inventoryUserCollapsed: false, onInventoryExpandToggle: (_) {},
                  salesExpanded: false, salesUserCollapsed: false, onSalesExpandToggle: (_) {},
                  hrExpanded: false, hrUserCollapsed: false, onHrExpandToggle: (_) {},
                  financeExpanded: false, financeUserCollapsed: false, onFinanceExpandToggle: (_) {},
                  itExpanded: true, itUserCollapsed: false, onItExpandToggle: (_) {},
                  stylistExpanded: false, stylistUserCollapsed: false, onStylistExpandToggle: (_) {},
                  marketingExpanded: false, marketingUserCollapsed: false, onMarketingExpandToggle: (_) {},
                  contentExpanded: false, contentUserCollapsed: false, onContentExpandToggle: (_) {},
                ),
              ),
            ]),
          ),
        ),
        GoRoute(path: '/monthly-objectives', builder: (context, state) => const Scaffold(body: Text('THE MONTHLY PAGE'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[authSessionProvider.overrideWithValue(session)],
        child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return router;
    }

    AuthSession session(String role, List<String> permissions) =>
        AuthSession(token: 't', userId: 'u', name: 'Irfan', email: 'i@x', role: role, permissions: permissions);

    testWidgets('the IT login from the field: no Company Projects, but Monthly Objectives is there — and opens its page', (tester) async {
      final router = await pumpSidebar(tester, session: session('it', ['it', 'it.projects', 'it.roadmap', 'it.my_tasks', 'it.tickets']));
      expect(find.text('Company Projects'), findsNothing); // this is why they could not find it
      expect(find.text('Monthly Objectives'), findsOneWidget);
      await tester.tap(find.text('Monthly Objectives'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/monthly-objectives');
      expect(find.text('THE MONTHLY PAGE'), findsOneWidget);
    });

    testWidgets('an artist, whose menu is its own, has it too', (tester) async {
      await pumpSidebar(tester, session: session('artist', const []));
      expect(find.text('Monthly Objectives'), findsOneWidget);
    });

    testWidgets('and the CEO', (tester) async {
      await pumpSidebar(tester, session: session('ceo', ['ceo', 'planning']));
      expect(find.text('Monthly Objectives'), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('is the monthly view itself — the department\'s month, what is assigned to this person', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          monthlyObjectivesProvider.overrideWith(
            (ref, m) async => MonthlyObjectivesPage.fromJson({
              'year': m.year,
              'month': m.month,
              'isCurrent': true,
              'departments': [
                {
                  'departmentId': 'd1',
                  'name': 'IT',
                  'member': true,
                  'canManage': false,
                  'objectives': [
                    {'id': 'o1', 'departmentId': 'd1', 'departmentName': 'IT', 'year': m.year, 'month': m.month, 'objective': 'Ship the booking app', 'progress': 40, 'keyResults': <dynamic>[]},
                  ],
                  'summary': {'count': 1, 'avgProgress': 40, 'open': 1},
                  'lastMonth': <String, dynamic>{},
                },
              ],
              'totals': {'departments': 1, 'withObjectives': 1, 'objectives': 1, 'avgProgress': 40, 'closed': 0},
            }),
          ),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const MonthlyObjectivesScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ship the booking app'), findsOneWidget);
      expect(find.text('Your department'), findsOneWidget);
      expect(find.byKey(const Key('mo_summary')), findsOneWidget);
    });
  });
}
