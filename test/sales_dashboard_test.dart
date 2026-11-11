// Redesigned Sales Dashboard — widget tests with the server data stubbed.
//   flutter test test/sales_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/sales/data/sales_overview.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_dashboard_screen.dart';
import 'package:nizan_crm/features/sales/services/sales_overview_service.dart';

final _now = DateTime(2026, 11, 10, 15);


SalesOverview _data({bool countEntered = true, bool empty = false}) {
  if (empty) {
    return const SalesOverview(from: '2026-11-01', to: '2026-11-10');
  }
  return SalesOverview.fromJson({
    'range': {'from': '2026-11-01', 'to': '2026-11-10'},
    'selfScoped': false,
    'kpis': {
      'enquiries': countEntered ? 27 : null,
      'enquiryDays': countEntered ? 1 : 0,
      'days': 10,
      'savedOnCountDays': 14,
      'notSaved': countEntered ? 13 : 0,
      'leads': 40,
      'converted': 6,
      'bookings': 3,
      'orderValue': 145000,
      'avgOrderValue': 48333.33,
      'advance': 9000,
      'collected': 20000,
      'outstanding': 101000,
      'conversion': 7.5,
      'conversionBasis': 'leads',
    },
    'previous': {'leads': 30, 'bookings': 2, 'orderValue': 90000},
    'alerts': {'notSaved': countEntered ? 13 : 0, 'overdueFollowUps': 5, 'todayCountEntered': countEntered},
    'target': {
      'month': 11,
      'year': 2026,
      'scope': 'team',
      'bookingsTarget': 40,
      'bookings': 18,
      'valueTarget': 2500000,
      'value': 820000,
      'workingDays': 25,
      'workingDaysElapsed': 8,
      'expectedBookings': 12.8,
      'expectedValue': 800000,
    },
    'funnel': {'leads': 40, 'contacted': 30, 'followUp': 15, 'qualified': 9, 'converted': 6, 'lost': 4},
    'sources': [
      {'channel': 'IG Leads — Main Page', 'enquiries': 18, 'saved': 9, 'notSaved': 9, 'leads': 25, 'converted': 4, 'bookings': 2, 'orderValue': 100000, 'conversion': 16},
      {'channel': 'WhatsApp (Organic)', 'enquiries': 9, 'saved': 5, 'notSaved': 4, 'leads': 15, 'converted': 2, 'bookings': 0, 'orderValue': 0, 'conversion': 13.33},
      {'channel': 'YouTube', 'enquiries': 0, 'saved': 0, 'notSaved': 0, 'leads': 0, 'converted': 0, 'bookings': 0, 'orderValue': 0, 'conversion': 0},
    ],
    'direct': {'bookings': 1, 'orderValue': 45000},
    'trend': [
      for (var d = 1; d <= 10; d++)
        {
          'day': '2026-11-${d.toString().padLeft(2, '0')}',
          'enquiries': d == 10 && countEntered ? 27 : null,
          'saved': d == 10 ? 14 : 0,
          'leads': 4,
          'bookings': d == 10 ? 3 : 0,
          'orderValue': d == 10 ? 145000 : 0,
        },
    ],
    'team': [
      {
        'id': 'u1', 'name': 'Safana', 'role': 'sales', 'leads': 22, 'converted': 4, 'calls': 30, 'followUps': 12,
        'overdueFollowUps': 3, 'bookings': 2, 'orderValue': 100000,
        'monthTarget': {'salesTarget': 1200000, 'salesValue': 500000, 'bookingsTarget': 20, 'bookings': 10},
      },
      {
        'id': 'u2', 'name': 'Malavika', 'role': 'sales', 'leads': 18, 'converted': 2, 'calls': 21, 'followUps': 8,
        'overdueFollowUps': 2, 'bookings': 0, 'orderValue': 0,
        'monthTarget': {'salesTarget': 0, 'salesValue': 0, 'bookingsTarget': 0, 'bookings': 0},
      },
    ],
    'othersCredited': {'bookings': 1, 'orderValue': 45000},
    'recentLeads': [
      {'id': 'l1', 'name': 'Bride A', 'phone': '9', 'source': 'IG Leads — Main Page', 'status': 'Follow-up', 'assignedTo': 'Safana', 'date': '2026-11-10'},
    ],
    'salespeople': [
      {'id': 'u1', 'name': 'Safana'},
      {'id': 'u2', 'name': 'Malavika'},
    ],
  });
}

Future<void> _pump(WidgetTester tester, Size size, SalesOverview data, {List<SalesOverviewQuery>? seen}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      salesOverviewProvider.overrideWith((ref, q) async {
        seen?.add(q);
        return data;
      }),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
      home: Scaffold(body: SalesDashboardScreen(now: _now)),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, int i) async {
  await tester.ensureVisible(find.byKey(ValueKey('tab-$i')));
  await tester.tap(find.byKey(ValueKey('tab-$i')));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(390, 2600), Size(1440, 2200)]) {
    final label = size.width < 600 ? 'phone' : 'desktop';

    testWidgets('$label: header, alerts, target, key numbers — no overflow', (tester) async {
      await _pump(tester, size, _data());
      expect(tester.takeException(), isNull);
      expect(find.text('Sales dashboard'), findsOneWidget);
      expect(find.text('13 enquiries not saved as leads'), findsOneWidget);
      expect(find.text('5 follow-ups overdue'), findsOneWidget);
      expect(find.text("Today's team count is in"), findsOneWidget);
      expect(find.text('Team target · November 2026'), findsOneWidget);
      expect(find.text('On pace'), findsNWidgets(2)); // 18 ≥ 12.8 and ₹8.2L ≥ ₹8L
      expect(find.text('27'), findsWidgets);
      expect(find.textContaining('14 saved · 13 not saved'), findsOneWidget);
      expect(find.textContaining('+1 vs previous period'), findsOneWidget);
      expect(find.text('₹1.45L'), findsWidgets);
    });

    testWidgets('$label: every tab renders without overflow', (tester) async {
      await _pump(tester, size, _data());
      for (var i = 0; i < 4; i++) {
        await _openTab(tester, i);
        expect(tester.takeException(), isNull, reason: 'tab $i');
      }
      await _openTab(tester, 1);
      expect(find.text('By channel'), findsOneWidget);
      expect(find.text('Direct / no lead'), findsOneWidget);
      expect(find.text('YouTube'), findsNothing); // empty channels are hidden
      await _openTab(tester, 2);
      expect(find.text('Team leaderboard'), findsOneWidget);
      expect(find.text('Not credited to a salesperson'), findsOneWidget);
      expect(find.text('No target'), findsOneWidget); // Malavika
      await _openTab(tester, 3);
      expect(find.text('Day-by-day report'), findsOneWidget);
    });

    testWidgets('$label: no data at all', (tester) async {
      await _pump(tester, size, _data(empty: true));
      expect(tester.takeException(), isNull);
      expect(find.text('No target set for this month.'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await _openTab(tester, i);
        expect(tester.takeException(), isNull, reason: 'tab $i');
      }
    });
  }

  testWidgets("today's count missing shows a call to enter it", (tester) async {
    await _pump(tester, const Size(1440, 2200), _data(countEntered: false));
    // This month ends today, so the reminder shows.
    expect(find.text("Today's team lead count isn't entered yet"), findsOneWidget);
    expect(find.text('—'), findsWidgets); // enquiries tile
    expect(find.text('not entered for this period'), findsOneWidget);
  });

  testWidgets('period chips and salesperson filter change the query', (tester) async {
    final seen = <SalesOverviewQuery>[];
    await _pump(tester, const Size(1440, 2200), _data(), seen: seen);
    expect(seen.last, (from: '2026-11-01', to: '2026-11-10', salesPersonId: null));

    await tester.tap(find.byKey(const ValueKey('period-today')));
    await tester.pumpAndSettle();
    expect(seen.last.from, '2026-11-10');
    expect(seen.last.to, '2026-11-10');

    await tester.tap(find.byKey(const ValueKey('period-week')));
    await tester.pumpAndSettle();
    expect(seen.last.from, '2026-11-09'); // Monday

    await tester.tap(find.byKey(const ValueKey('period-lastMonth')));
    await tester.pumpAndSettle();
    expect((seen.last.from, seen.last.to), ('2026-10-01', '2026-10-31'));

    await tester.tap(find.byKey(const ValueKey('salesperson-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malavika').last);
    await tester.pumpAndSettle();
    expect(seen.last.salesPersonId, 'u2');
  });

  test('period ranges', () {
    final n = DateTime(2026, 1, 3); // a Saturday
    expect(salesPeriodRange(SalesPeriod.week, n).from, DateTime(2025, 12, 29));
    expect(salesPeriodRange(SalesPeriod.lastMonth, n).from, DateTime(2025, 12, 1));
    expect(salesPeriodRange(SalesPeriod.lastMonth, n).to, DateTime(2025, 12, 31));
  });
}
