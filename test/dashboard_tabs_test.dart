import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/tabs/finance_tab.dart';
import 'package:nizan_crm/features/dashboard/presentation/tabs/marketing_tab.dart';
import 'package:nizan_crm/features/dashboard/presentation/tabs/sales_analytics_tab.dart';

// Payloads shaped like GET /api/dashboard/* responses.
final _days = [for (var i = 1; i <= 8; i++) '2026-10-${i.toString().padLeft(2, '0')}'];

final _sales = {
  'unit': 'day',
  'kpis': {'revenue': 627500, 'orders': 16, 'avgOrder': 39219, 'received': 64000, 'outstanding': 563500, 'discount': 16000, 'enquiries': 58, 'conversion': 27.6, 'completed': 0, 'cancelled': 0},
  'previous': {'revenue': 512000, 'orders': 14, 'avgOrder': 36571, 'received': 71000, 'outstanding': 441000, 'discount': 9000, 'enquiries': 61, 'conversion': 23},
  'trend': [
    for (var i = 0; i < _days.length; i++)
      {'key': _days[i], 'amount': [178500, 119000, 205000, 0, 0, 42000, 119000, 0][i], 'count': [4, 4, 3, 0, 0, 2, 3, 0][i], 'prevAmount': [60000, 90000, 42000, 81000, 30000, 120000, 59000, 30000][i], 'prevCount': 2},
  ],
  'byStatus': [{'label': 'confirmed', 'count': 16, 'amount': 627500}],
  'byPackage': [{'label': 'Airbrush', 'count': 7, 'amount': 301000}, {'label': 'Platinum', 'count': 5, 'amount': 190000}, {'label': 'Team N Royal', 'count': 2, 'amount': 117000}, {'label': 'Custom Package', 'count': 2, 'amount': 19500}],
  'byDistrict': [{'label': 'Thrissur', 'count': 6, 'amount': 245000}, {'label': 'Ernakulam', 'count': 5, 'amount': 198000}, {'label': 'Kozhikode', 'count': 3, 'amount': 120000}, {'label': 'Unspecified', 'count': 2, 'amount': 64500}],
  'bySalesperson': [{'id': 'a', 'label': 'Safana', 'count': 9, 'amount': 402000}, {'id': 'b', 'label': 'Malavika', 'count': 5, 'amount': 179000}, {'id': 'c', 'label': 'Saranya', 'count': 1, 'amount': 20000}, {'id': '', 'label': 'Direct / Others', 'count': 1, 'amount': 26500}],
  'leadSources': [{'label': 'Instagram', 'count': 31, 'converted': 9}, {'label': 'Whatsapp', 'count': 12, 'converted': 4}, {'label': 'Reference', 'count': 8, 'converted': 3}, {'label': 'Website', 'count': 5, 'converted': 0}, {'label': 'Walk-in', 'count': 2, 'converted': 0}],
  'salespeople': [{'id': 'a', 'name': 'Safana'}, {'id': 'b', 'name': 'Malavika'}, {'id': 'c', 'name': 'Saranya'}],
};

final _marketing = {
  'unit': 'day',
  'kpis': {'enquiries': 58, 'prevEnquiries': 61, 'converted': 16, 'prevConverted': 14, 'conversion': 27.59, 'prevConversion': 22.95, 'open': 33, 'lost': 9, 'revenue': 627500, 'spend': 45000, 'prevSpend': 38000, 'costPerEnquiry': 775.86, 'returnOnSpend': 13.9, 'published': 11, 'reviews': 6, 'avgRating': 4.6},
  'trend': [for (var i = 0; i < _days.length; i++) {'key': _days[i], 'count': [9, 7, 11, 5, 4, 8, 10, 4][i], 'converted': [3, 2, 3, 0, 1, 2, 4, 1][i], 'prevCount': [6, 8, 7, 9, 5, 8, 9, 9][i]}],
  'sources': [{'label': 'Instagram', 'count': 31, 'converted': 9, 'revenue': 352000}, {'label': 'Whatsapp', 'count': 12, 'converted': 4, 'revenue': 151000}, {'label': 'Reference', 'count': 8, 'converted': 3, 'revenue': 124500}, {'label': 'Website', 'count': 5, 'converted': 0, 'revenue': 0}, {'label': 'Walk-in', 'count': 2, 'converted': 0, 'revenue': 0}],
  'pipeline': [for (final s in ['New', 'Contacted', 'Qualified', 'Follow-up', 'Pending Lost Approval', 'Lost', 'Converted']) {'label': s, 'count': {'New': 12, 'Contacted': 9, 'Qualified': 4, 'Follow-up': 8, 'Pending Lost Approval': 0, 'Lost': 9, 'Converted': 16}[s]}],
  'priority': [{'label': 'Hot', 'count': 14}, {'label': 'Warm', 'count': 33}, {'label': 'Cold', 'count': 11}],
  'districts': [{'label': 'Thrissur', 'count': 19}, {'label': 'Ernakulam', 'count': 15}, {'label': 'Kozhikode', 'count': 9}, {'label': 'Unspecified', 'count': 15}],
  'campaigns': [{'label': 'Diwali bridal reels', 'channel': 'Instagram', 'spend': 30000, 'leads': 22, 'converted': 6, 'revenue': 241000}, {'label': 'Google search — Thrissur', 'channel': 'Google', 'spend': 15000, 'leads': 5, 'converted': 1, 'revenue': 38000}],
  'content': [{'label': 'Instagram', 'published': 8, 'planned': 6}, {'label': 'Youtube', 'published': 2, 'planned': 1}, {'label': 'Facebook', 'published': 1, 'planned': 2}],
  'ratings': [{'label': '1 stars', 'count': 0}, {'label': '2 stars', 'count': 0}, {'label': '3 stars', 'count': 1}, {'label': '4 stars', 'count': 1}, {'label': '5 stars', 'count': 4}],
};

final _finance = {
  'kpis': {'billed': 627500, 'billedPrev': 512000, 'orders': 16, 'cashIn': 312000, 'cashInPrev': 286000, 'advances': 64000, 'collections': 248000, 'collectionsPending': 30000, 'collectionsPendingCount': 3, 'expenses': 198000, 'expensesPrev': 221000, 'net': 114000, 'netPrev': 65000, 'receivables': 9200000, 'collectionRate': 10.2},
  'expenses': [{'label': 'Artist payouts', 'amount': 82000, 'count': 14, 'prevAmount': 90000}, {'label': 'Admin expenses', 'amount': 54000, 'count': 10, 'prevAmount': 61000}, {'label': 'Fuel & vehicle', 'amount': 31000, 'count': 18, 'prevAmount': 28000}, {'label': 'Artist expenses', 'amount': 21000, 'count': 9, 'prevAmount': 30000}, {'label': 'Salaries', 'amount': 10000, 'count': 1, 'prevAmount': 12000}, {'label': 'Sales returns', 'amount': 0, 'count': 0, 'prevAmount': 0}],
  'paymentModes': [{'label': 'UPI', 'amount': 171000, 'count': 21}, {'label': 'Bank Transfer', 'amount': 52000, 'count': 4}, {'label': 'Cash', 'amount': 25000, 'count': 6}],
  'pendingApprovals': [{'label': 'Admin expenses', 'amount': 12500, 'count': 3}, {'label': 'Artist expenses', 'amount': 4200, 'count': 2}, {'label': 'Fuel bills', 'amount': 3100, 'count': 2}, {'label': 'Artist payouts', 'amount': 46000, 'count': 5}, {'label': 'Collections to verify', 'amount': 30000, 'count': 3}],
  'aging': {'upcoming': 6100000, 'd0_30': 1800000, 'd31_90': 900000, 'd90plus': 400000},
  'trend': [
    for (var m = 0; m < 12; m++)
      {
        'key': '${m < 3 ? 2025 : 2026}-${(((m + 9) % 12) + 1).toString().padLeft(2, '0')}',
        'billed': [2100000, 1800000, 2400000, 2600000, 900000, 1700000, 3600000, 2100000, 1400000, 4000000, 2800000, 627500][m],
        'income': [900000, 820000, 1100000, 1200000, 700000, 650000, 980000, 870000, 760000, 1050000, 910000, 312000][m],
        'expense': [610000, 590000, 720000, 740000, 760000, 640000, 700000, 690000, 820000, 760000, 700000, 198000][m],
        'net': 0,
      },
  ],
};

Future<void> _loadFonts() async {
  // Real glyphs (not test boxes) so the screenshots are readable. Inter is
  // stood in by Roboto, registered under google_fonts' family names.
  const dir = 'C:/src/flutter/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) l.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await l.load();
  }

  await load('Inter_regular', ['roboto-regular.ttf']);
  await load('Inter_500', ['roboto-medium.ttf']);
  await load('Inter_600', ['roboto-medium.ttf']);
  await load('Inter_700', ['roboto-bold.ttf']);
  await load('Inter_800', ['roboto-black.ttf']);
  await load('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

Future<void> _pump(WidgetTester t, Widget tab, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      salesDashboardProvider.overrideWith((ref, q) async => SalesDashboard.fromJson(_sales)),
      marketingDashboardProvider.overrideWith((ref, q) async => MarketingDashboard.fromJson(_marketing)),
      financeDashboardProvider.overrideWith((ref, q) async {
        final j = Map<String, dynamic>.from(_finance);
        j['trend'] = [
          for (final m in _finance['trend'] as List)
            {...m as Map<String, dynamic>, 'net': (m['income'] as int) - (m['expense'] as int)},
        ];
        return FinanceDashboard.fromJson(j);
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', scaffoldBackgroundColor: const Color(0xFFF7F5F2)),
      home: Scaffold(body: tab),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

/// Fails with the full layout diagnostics if anything overflowed.
void _noErrors(WidgetTester t) {
  final e = t.takeException();
  if (e != null) fail(e is FlutterError ? e.toStringDeep() : '$e');
}

Future<void> _scrollAll(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    await t.drag(find.byType(ListView).first, const Offset(0, -700));
    await t.pump();
  }
}

void main() {
  setUpAll(_loadFonts);

  test('a running month compares with the same days of last month', () {
    final q = DashboardQuery.month(DateTime.now());
    expect(q.from.day, 1);
    expect(q.prevFrom.month, DateTime(q.from.year, q.from.month - 1).month);
    expect(q.prevTo.day, lessThanOrEqualTo(q.to.day));
    expect(q.isMonth, isTrue);
    final r = DashboardQuery.range(DateTime(2026, 9, 10), DateTime(2026, 9, 23));
    expect(r.prevTo, DateTime(2026, 9, 9));
    expect(r.prevFrom, DateTime(2026, 8, 27));
    expect(r.isMonth, isFalse);
    expect(r.toParams()['prevFrom'], '2026-08-27');
  });

  final tabs = <String, Widget>{
    'sales': const SalesAnalyticsTab(),
    'marketing': const MarketingTab(),
    'finance': const FinanceTab(),
  };

  for (final size in const [Size(1440, 1000), Size(390, 844)]) {
    for (final e in tabs.entries) {
      testWidgets('${e.key} tab renders at ${size.width.toInt()} px', (t) async {
        await _pump(t, e.value, size);
        _noErrors(t);
        await _scrollAll(t);
        _noErrors(t);
      });
    }
  }
}
