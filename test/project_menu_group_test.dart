import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/presentation/common_widgets/sidebar.dart';

// The menu keeps everything to do with running projects together, under one heading: the portfolio and My Tasks, the monthly
// objectives, the finance head's project budgets and HR's manpower requests — instead of three loose entries above the CRM.
// Each entry still shows only to those who can use it (the server decides what they may do inside).

Future<GoRouter> _pump(WidgetTester tester, AuthSession session) async {
  tester.view.physicalSize = const Size(1400, 6000); // tall, so every entry of the (lazy) list is built
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Row(
            children: [
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
                  itExpanded: false, itUserCollapsed: false, onItExpandToggle: (_) {},
                  marketingExpanded: false, marketingUserCollapsed: false, onMarketingExpandToggle: (_) {},
                  contentExpanded: false, contentUserCollapsed: false, onContentExpandToggle: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
      GoRoute(path: '/manpower', builder: (context, state) => const Scaffold(body: Text('THE MANPOWER PAGE'))),
      GoRoute(path: '/project-budgets', builder: (context, state) => const Scaffold(body: Text('THE BUDGETS PAGE'))),
      GoRoute(path: '/monthly-objectives', builder: (context, state) => const Scaffold(body: Text('THE MONTHLY PAGE'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[authSessionProvider.overrideWithValue(session)],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

AuthSession _session(String role, List<String> permissions, {bool head = false}) =>
    AuthSession(token: 't', userId: 'u', name: 'Test', email: 't@x', role: role, permissions: permissions, isDepartmentHead: head);

double _y(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  const heading = 'PROJECTS';

  testWidgets('management sees the whole group, in one place and in order, below the heading', (t) async {
    await _pump(t, _session('admin', const []));
    expect(find.text(heading), findsOneWidget);
    for (final n in ['Company Projects', 'My Tasks', 'Monthly Objectives', 'Project budgets', 'Manpower']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    final order = ['Company Projects', 'My Tasks', 'Monthly Objectives', 'Project budgets', 'Manpower'];
    expect(_y(t, heading), lessThan(_y(t, order.first)));
    for (var i = 1; i < order.length; i++) {
      expect(_y(t, order[i - 1]), lessThan(_y(t, order[i])), reason: '${order[i - 1]} comes before ${order[i]}');
    }
  });

  testWidgets('they are no longer loose at the top: Notifications stands alone above the CRM, the group is further down', (t) async {
    await _pump(t, _session('admin', const []));
    expect(_y(t, 'Notifications'), lessThan(_y(t, 'CRM')));
    for (final n in ['Monthly Objectives', 'Project budgets', 'Manpower']) {
      expect(_y(t, n), greaterThan(_y(t, 'CRM')), reason: '$n is not above the CRM heading any more');
    }
  });

  testWidgets('the finance head gets Project budgets — not Manpower', (t) async {
    await _pump(t, _session('finance_head', const ['company_finance']));
    expect(find.text('Project budgets'), findsOneWidget);
    expect(find.text('Monthly Objectives'), findsOneWidget);
    expect(find.text('Manpower'), findsNothing);
  });

  testWidgets('HR (staff access) gets Manpower — not Project budgets', (t) async {
    await _pump(t, _session('crm', const ['staff']));
    expect(find.text('Manpower'), findsOneWidget);
    expect(find.text('Monthly Objectives'), findsOneWidget);
    expect(find.text('Project budgets'), findsNothing);
  });

  testWidgets('a department head gets Manpower (to answer the people asked of them)', (t) async {
    await _pump(t, _session('crm', const ['dashboard'], head: true));
    expect(find.text('Manpower'), findsOneWidget);
  });

  testWidgets('an ordinary team member gets Monthly Objectives under the heading — nothing else of the group', (t) async {
    await _pump(t, _session('crm', const ['dashboard']));
    expect(find.text(heading), findsOneWidget);
    expect(find.text('Monthly Objectives'), findsOneWidget);
    for (final n in ['Company Projects', 'My Tasks', 'Project budgets', 'Manpower']) {
      expect(find.text(n), findsNothing, reason: n);
    }
  });

  testWidgets('Company Projects and My Tasks follow the Company Projects permission', (t) async {
    await _pump(t, _session('crm', const ['dashboard', 'planning']));
    expect(find.text('Company Projects'), findsOneWidget);
    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('Monthly Objectives'), findsOneWidget);
  });

  testWidgets('an artist, whose menu is its own, has the group too', (t) async {
    await _pump(t, _session('artist', const []));
    expect(find.text(heading), findsOneWidget);
    expect(find.text('Monthly Objectives'), findsOneWidget);
  });

  testWidgets('a driver has Monthly Objectives under the heading', (t) async {
    await _pump(t, _session('driver', const []));
    expect(find.text(heading), findsOneWidget);
    expect(find.text('Monthly Objectives'), findsOneWidget);
    expect(find.text('Manpower'), findsNothing);
  });

  testWidgets('the CEO looks at objectives only — budgets and manpower are not his screens, and no second heading', (t) async {
    await _pump(t, _session('ceo', const ['ceo', 'planning', 'staff']));
    expect(find.text('Monthly Objectives'), findsOneWidget);
    expect(find.text('Project budgets'), findsNothing);
    expect(find.text('Manpower'), findsNothing);
    expect(find.text(heading), findsNothing);
  });

  testWidgets('each entry opens its page', (t) async {
    final router = await _pump(t, _session('admin', const []));
    String path() => router.routeInformationProvider.value.uri.path;
    for (final (label, route, page) in [
      ('Manpower', '/manpower', 'THE MANPOWER PAGE'),
      ('Project budgets', '/project-budgets', 'THE BUDGETS PAGE'),
      ('Monthly Objectives', '/monthly-objectives', 'THE MONTHLY PAGE'),
    ]) {
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(path(), route, reason: label);
      expect(find.text(page), findsOneWidget, reason: label);
      router.go('/');
      await t.pumpAndSettle();
    }
  });
}
