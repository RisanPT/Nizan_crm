import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/website/data/visitor_stats.dart';
import 'package:nizan_crm/features/website/presentation/widgets/visitors_card.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

// Same shape as GET /api/website/admin/visitors (backend utils/websiteVisits.js).
Map<String, dynamic> _json(int days, {int views = 125}) => {
      'range': {'from': '2026-11-17', 'to': '2026-11-19', 'days': days},
      'totals': {'visitors': 40, 'newVisitors': 30, 'visits': 50, 'pageViews': views, 'pagesPerVisit': 2.5},
      'today': {'visitors': 3, 'pageViews': 7},
      'enquiries': {'booking': 2, 'contact': 1, 'bookingRate': 5, 'enquiryRate': 7.5},
      'daily': [
        {'day': '2026-11-17', 'visitors': 0, 'pageViews': 0},
        {'day': '2026-11-18', 'visitors': 10, 'pageViews': 25},
        {'day': '2026-11-19', 'visitors': 3, 'pageViews': 7},
      ],
      'pages': [
        {'path': '/', 'views': 60, 'visitors': 35},
        {'path': '/book', 'views': 20, 'visitors': 12},
      ],
      'sources': [
        {'name': 'instagram', 'views': 70, 'visitors': 20},
        {'name': 'direct', 'views': 30, 'visitors': 15},
      ],
      'devices': [
        {'name': 'mobile', 'views': 100, 'visitors': 32},
      ],
      'retentionDays': 90,
    };

void main() {
  test('visitor stats json → model', () {
    final s = VisitorStats.fromJson(_json(30));
    expect(s.visitors, 40);
    expect(s.returningVisitors, 10);
    expect(s.bookingRate, 5);
    expect(s.daily.length, 3);
    expect(s.pages.first.label, '/');
    expect(s.sources.first.label, 'instagram');
    expect(visitorPageLabel('/book'), 'Book');
    expect(visitorSourceLabel('direct'), 'Direct / typed in');
    expect(visitorDeviceLabel('mobile'), 'Phone');
  });

  test('missing fields fall back to zero', () {
    final s = VisitorStats.fromJson(const {});
    expect(s.visitors, 0);
    expect(s.daily, isEmpty);
  });

  Future<List<int>> pump(WidgetTester tester, {int views = 125}) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <int>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        websiteVisitorsProvider.overrideWith((ref, days) async {
          asked.add(days);
          return VisitorStats.fromJson(_json(days, views: views));
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: SingleChildScrollView(child: VisitorsCard())),
      ),
    ));
    await tester.pumpAndSettle();
    return asked;
  }

  testWidgets('shows totals, breakdowns and switches range', (tester) async {
    final asked = await pump(tester);

    expect(find.text('Visitors'), findsWidgets);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Today 3'), findsOneWidget);
    expect(find.text('5% of visitors'), findsOneWidget);
    expect(find.text('10 came back'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(asked, [30]);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(asked, [30, 7]);
  });

  testWidgets('explains an empty period', (tester) async {
    await pump(tester, views: 0);
    expect(find.textContaining('No visits counted in this period yet'), findsOneWidget);
  });
}
