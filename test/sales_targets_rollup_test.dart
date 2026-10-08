import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/sales/data/sales_target.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_targets_screen.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/combined_targets_section.dart';
import 'package:nizan_crm/features/sales/services/sales_target_service.dart';

// Shaped like GET /api/sales-targets (manager row first = team total).
final _team = TeamTargets.fromJson({
  'month': 10, 'year': 2026, 'daysInMonth': 31, 'daysLeft': 24,
  'rows': [
    {
      'user': {'id': 'm', 'name': 'Meera (Manager)', 'role': 'sales_manager', 'active': true},
      'target': {'salesTarget': 300000, 'bookingsTarget': 15, 'derived': true, 'teamSize': 2},
      'achieved': {'salesValue': 130000, 'bookings': 6},
      'own': {'salesValue': 10000, 'bookings': 1},
    },
    {
      'user': {'id': 's1', 'name': 'Asha', 'role': 'sales', 'active': true},
      'target': {'salesTarget': 200000, 'bookingsTarget': 10},
      'achieved': {'salesValue': 100000, 'bookings': 4},
    },
    {
      'user': {'id': 's2', 'name': 'Binu', 'role': 'sales_executive', 'active': true},
      'target': {'salesTarget': 100000, 'bookingsTarget': 5},
      'achieved': {'salesValue': 20000, 'bookings': 1},
    },
  ],
  'totals': {'salesTarget': 300000, 'bookingsTarget': 15, 'salesValue': 130000, 'bookings': 6},
});

CombinedTarget _combined({List<Map<String, dynamic>>? contributions}) => CombinedTarget.fromJson({
      'id': 'c1',
      'title': 'Diwali week push',
      'startDay': '2026-10-10',
      'endDay': '2026-10-25',
      'salesTarget': 500000,
      'bookingsTarget': 20,
      'service': 'Airbrush',
      'note': 'Team bonus if hit',
      'setByName': 'Meera',
      'achieved': {'salesValue': 250000, 'bookings': 8},
      'mine': {'salesValue': 100000, 'bookings': 3},
      'contributions': contributions ??
          [
            {'userId': 's1', 'name': 'Asha', 'salesValue': 150000, 'bookings': 5},
            {'userId': 's2', 'name': 'Binu', 'salesValue': 100000, 'bookings': 3},
          ],
      'contributors': 2,
      'totalDays': 16,
      'daysLeft': 6,
      'status': 'active',
    });

AuthSession _session(String role) =>
    AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role);

Future<void> _pump(WidgetTester t, Widget child, String role, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      authSessionProvider.overrideWithValue(_session(role)),
      teamTargetsProvider.overrideWith((ref, p) async => _team),
      combinedTargetsProvider.overrideWith((ref, p) async => [_combined()]),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
      home: Scaffold(body: child),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  test('derived manager target parses as a read-only team total', () {
    expect(_team.rows.first.isTeamTotal, isTrue);
    expect(_team.rows.first.target!.teamSize, 2);
    expect(_team.rows.first.own!.salesValue, 10000);
    expect(_team.rows[1].isTeamTotal, isFalse);
  });

  test('combined target progress uses the value goal first', () {
    final c = _combined();
    expect(c.pct, 0.5);
    expect(c.elapsed, closeTo(11 / 16, 1e-9));
    expect(c.start, DateTime(2026, 10, 10));
  });

  test('isSalesManagerRole mirrors the backend', () {
    expect(isSalesManagerRole('sales_manager'), isTrue);
    expect(isSalesManagerRole('manager'), isFalse);
    expect(isSalesManagerRole('sales'), isFalse);
  });

  for (final size in const [Size(1400, 1000), Size(390, 844)]) {
    final w = size.width.toInt();
    testWidgets('targets screen shows the manager as team total at $w px', (t) async {
      await _pump(t, const SalesTargetsScreen(), 'admin', size);
      expect(find.text('Meera (Manager)'), findsOneWidget);
      expect(find.textContaining('team total'), findsOneWidget);
      // Only the two salespeople get editable fields (₹ + bookings each).
      expect(find.byType(TextField), findsNWidgets(1 + 2 * 2)); // + search box
      _noErrors(t);
    });

    testWidgets('combined section (manager) lists contributions at $w px', (t) async {
      await _pump(
        t,
        const SingleChildScrollView(child: CombinedTargetsSection(period: (month: 10, year: 2026), editable: true)),
        'sales_manager',
        size,
      );
      expect(find.text('Diwali week push'), findsOneWidget);
      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('Add combined target'), findsOneWidget);
      _noErrors(t);
    });

    testWidgets('combined section (salesperson) shows own share at $w px', (t) async {
      await _pump(
        t,
        const SingleChildScrollView(child: CombinedTargetsSection(period: (month: 10, year: 2026))),
        'sales',
        size,
      );
      expect(find.textContaining('Your share'), findsOneWidget);
      expect(find.text('Add combined target'), findsNothing);
      _noErrors(t);
    });
  }

  testWidgets('add dialog validates before saving', (t) async {
    await _pump(
      t,
      const SingleChildScrollView(child: CombinedTargetsSection(period: (month: 10, year: 2026), editable: true)),
      'sales_manager',
      const Size(1400, 1000),
    );
    await t.tap(find.text('Add combined target'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add target'));
    await t.pump();
    expect(find.text('Give the target a name.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Festival');
    await t.tap(find.text('Add target'));
    await t.pump();
    expect(find.text('Set a sales value, a number of bookings, or both.'), findsOneWidget);
    _noErrors(t);
  });
}

/// Fails with the full layout diagnostics (which widget overflowed) if any.
void _noErrors(WidgetTester t) {
  final e = t.takeException();
  if (e != null) fail(e is FlutterError ? e.toStringDeep() : '$e');
}
