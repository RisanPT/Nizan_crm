// Layout checks for the Marketing EOD screen (all eight tabs) and the Sales
// EOD dialog at phone (390px) and desktop (1440px) widths, with long names
// and big numbers. A RenderFlex overflow shows up as an exception, so each
// step asserts `tester.takeException()` is null.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/marketing_eod_models.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/marketing_eod_screen.dart';
import 'package:nizan_crm/features/marketing/services/marketing_eod_service.dart';
import 'package:nizan_crm/features/sales/data/sales_eod_report.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/sales_eod_dialog.dart';
import 'package:nizan_crm/features/sales/services/sales_eod_service.dart';
import 'package:nizan_crm/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _desktop = Size(1440, 1400);
const _phone = Size(390, 1400);

// Run with --dart-define=LOCATE=true to let overflows print their culprit
// ("Row:file:///...dart:LINE") instead of failing on the first one.
const _locate = bool.fromEnvironment('LOCATE');

void _check(WidgetTester tester, String reason) {
  if (_locate) return;
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Drags every visible vertical list to its end so lazily built rows below
/// the fold are laid out too.
Future<void> _scrollThrough(WidgetTester tester, String reason) async {
  final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  final hits = lists.hitTestable();
  if (hits.evaluate().isEmpty) return;
  for (var i = 0; i < 12; i++) {
    await tester.drag(hits.first, const Offset(0, -500), warnIfMissed: false);
    await tester.pumpAndSettle();
    _check(tester, '$reason (scrolled)');
  }
}

// ── Marketing EOD fixtures ──────────────────────────────────────────────────

const _longMetric = 'Meta & LinkedIn Ad Campaign – Bridal Season Kochi';

final _members = [
  for (final (i, name) in [
    'Anjali Krishnakumar Menon Pillai',
    'Mohammed Risan Abdul Rahman',
    'FATHIMA LIYA MUHAMMED KUTTY',
  ].indexed)
    {
      '_id': 'm$i',
      'name': name,
      'shortName': name,
      'role': 'Senior Performance Marketing & Social Media Executive',
      'isActive': true,
    },
];

final _metricsJson = [
  for (var i = 0; i < 6; i++)
    {
      '_id': 'k$i',
      'groupId': 'g${i % 2}',
      'groupName': i.isEven ? 'Paid Campaigns & Performance Marketing (Kerala)' : 'Organic Content',
      'code': 100 + i,
      'name': i == 0 ? _longMetric : 'Instagram Reels Published for Team N Makeovers Page #$i',
      'unitType': i == 5 ? 'currency' : 'count',
      'inTotalOutput': true,
      'maxPerDay': 25,
    },
];

MarketingSetupData _setup() => MarketingSetupData.fromJson({
      'groups': [
        {'_id': 'g0', 'name': 'Paid Campaigns & Performance Marketing (Kerala)'},
        {'_id': 'g1', 'name': 'Organic Content'},
      ],
      'metrics': _metricsJson,
      'roles': [
        {'_id': 'r0', 'name': 'Senior Performance Marketing & Social Media Executive'},
      ],
      'roleMetrics': [
        for (final m in _metricsJson) {'roleId': 'r0', 'metricId': m['_id']},
      ],
      'members': _members,
      'calendarSettings': {'standardHours': 8, 'workingDays': 'Mon-Sat'},
      'thresholds': {'green': 100, 'amber': 70},
      'memberRoles': [
        for (final m in _members) {'memberId': m['_id'], 'roleId': 'r0', 'month': '2026-11'},
      ],
    });

MarketingEodEntryPayload _entry() => MarketingEodEntryPayload.fromJson({
      'member': _members.first,
      'entryDate': '2026-11-11',
      'canEdit': true,
      'editNotice': 'You are editing another member\'s EOD after the cut-off – a reason will be asked and logged.',
      'isManager': true,
      'entry': {'hoursWorked': 8, 'notes': 'Shot reels', 'checkStatus': 'Over usual max', 'checkMessage': ''},
      'totalOutput': 1234567,
      'values': {for (final m in _metricsJson) m['_id'] as String: 1234},
      'groupedMetrics': [
        for (final g in ['g0', 'g1'])
          {
            'groupId': g,
            'groupName': g == 'g0' ? 'Paid Campaigns & Performance Marketing (Kerala)' : 'Organic Content',
            'metrics': _metricsJson.where((m) => m['groupId'] == g).toList(),
          },
      ],
    });

MarketingIndividualDashboardData _dash() => MarketingIndividualDashboardData.fromJson({
      'member': _members.first,
      'month': '2026-11',
      'period': '1 Nov 2026 – 30 Nov 2026',
      'summaryTiles': {
        'daysReported': 22,
        'totalOutput': 1234567,
        'targetAchievedPct': 87,
        'mtdPacePct': 92,
        'workingDaysElapsed': 18,
        'workingDays': 26,
        'hoursWorked': 176.5,
      },
      'activityNumbers': [
        for (final m in _metricsJson)
          {
            'metricId': m['_id'],
            'code': m['code'],
            'name': m['name'],
            'groupName': m['groupName'],
            'target': 1234567,
            'achieved': 1034567,
            'achievedPct': 84,
            'dailyAvg': '45678.9',
            'bestDay': {'count': 99999, 'date': '2026-11-04'},
            'status': 'amber',
            'expectedToDate': 987654.3,
            'pacePct': 104,
            'paceStatus': 'green',
          },
      ],
      'weekWiseNumbers': {
        'rows': [
          for (final m in _metricsJson)
            {'metricId': m['_id'], 'name': m['name'], 'w1': 123456, 'w2': 234567, 'w3': 345678, 'w4': 456789, 'w5': 98765, 'monthTotal': 1259255},
        ],
        'totalOutputRow': {'name': 'TOTAL', 'w1': 1234567, 'w2': 1234567, 'w3': 1234567, 'w4': 1234567, 'w5': 1234567, 'monthTotal': 6172835},
      },
      'dailyGrid': [
        for (var d = 1; d <= 30; d++)
          {
            'day': d,
            'date': '2026-11-${d.toString().padLeft(2, '0')}',
            'dayOfWeek': d % 7,
            'hours': 8,
            'output': d * 1111,
            'color': d % 7 == 0 ? 'grey' : (d % 5 == 0 ? 'red' : 'green'),
            'hasEod': true,
          },
      ],
      'remarks': {
        'managerRemarks': 'Great month for the bridal season campaign; reels reach doubled.',
        'memberAckAt': null,
        'managerSignedAt': null,
        'monthStatus': 'open',
      },
    });

MarketingTeamSummaryData _team() => MarketingTeamSummaryData.fromJson({
      'month': '2026-11',
      'members': _members,
      'overviewRows': {
        for (final k in ['daysReported', 'hoursWorked', 'totalOutput', 'avgTargetAchieved', 'mtdPace', 'workingDaysElapsed'])
          k: {
            'memberValues': {for (final m in _members) m['_id']: 1234567},
            'teamTotal': 3703701,
          },
      },
      'metricRows': [
        for (final m in _metricsJson)
          {
            'metricId': m['_id'],
            'name': m['name'],
            'groupName': m['groupName'],
            'memberValues': {for (final mem in _members) mem['_id']: 123456},
            'teamTotal': 370368,
            'teamExpected': 345678.9,
            'teamPacePct': 107,
          },
      ],
    });

MarketingMissedEodsData _missed() => MarketingMissedEodsData.fromJson({
      'month': '2026-11',
      'totalMissedCount': 1234,
      'memberMissedCounts': {for (final m in _members) m['_id'] as String: 12},
      'missedList': [
        for (var i = 0; i < 8; i++)
          {
            'memberId': _members[i % 3]['_id'],
            'memberName': _members[i % 3]['name'],
            'shortName': _members[i % 3]['shortName'],
            'date': '2026-11-0${i + 1}',
          },
      ],
    });

class _FakeMarketingService extends MarketingEodService {
  _FakeMarketingService() : super(Dio());

  @override
  Future<List<MarketingMetricModel>> getMemberMetrics(String memberId, [String? month]) async =>
      _metricsJson.map(MarketingMetricModel.fromJson).toList();

  @override
  Future<List<Map<String, dynamic>>> getTargets([String? month]) async => [
        for (final m in _members)
          for (final k in _metricsJson) {'memberId': m['_id'], 'metricId': k['_id'], 'targetValue': 1234567},
      ];

  @override
  Future<List<Map<String, dynamic>>> getWeeklyPageStats({String? memberId, String? month}) async => [
        for (final page in ['makeovers', 'kerala'])
          for (final w in ['W1', 'W2', 'W3', 'W4', 'W5'])
            {'page': page, 'weekBlock': w, 'postsPublished': 123, 'reach': 1234567, 'engagement': 98765},
      ];
}

Future<void> _pumpMarketing(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await _setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketingEodServiceProvider.overrideWithValue(_FakeMarketingService()),
        marketingEodAccessProvider.overrideWith(
          (ref) async => const MarketingEodAccess(isManager: true, canViewTeam: true, memberId: 'm0'),
        ),
        marketingEodSetupProvider.overrideWith((ref) async => _setup()),
        marketingEodEntryProvider.overrideWith((ref, q) async => _entry()),
        marketingIndividualDashboardProvider.overrideWith((ref, q) async => _dash()),
        marketingTeamSummaryProvider.overrideWith((ref, m) async => _team()),
        marketingMissedEodsProvider.overrideWith((ref, m) async => _missed()),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const MarketingEodScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Sales EOD fixtures ──────────────────────────────────────────────────────

SalesEodReport _report() {
  Map<String, dynamic> cell(String label, num today, num mtd) => {'label': label, 'today': today, 'mtd': mtd};
  Map<String, dynamic> check() =>
      {'manualDays': 3, 'formDays': 2, 'source': 'mixed', 'manualCount': 1234, 'savedInCrm': 1100, 'notLogged': 134};
  return SalesEodReport.fromJson({
    'date': '2026-11-11',
    'reportDateFormatted': 'Wednesday, 11 November 2026',
    'monthName': 'November 2026',
    'leadCountTask': 'WhatsApp + Instagram (Main & Kerala pages)',
    'isTeam': false,
    'salesPerson': {
      'id': 'u1',
      'name': 'Anjali Krishnakumar Menon Pillai',
      'email': 'anjali@example.com',
      'phone': '9876543210',
      'role': 'sales_executive',
    },
    'todayTargetVsAchieved': {
      'bookings': {'achievableTarget': 12.5, 'achieved': 9, 'achievementPct': 72, 'shortExcess': 3.5},
      'bookingValue': {'achievableTarget': 1234567, 'achieved': 1034567, 'achievementPct': 83.8, 'shortExcess': -200000},
    },
    'mtdTargetVsAchieved': {
      'bookings': {'mtdTarget': 150, 'monthlyTarget': 300, 'mtdAchieved': 120, 'mtdAchievementPct': 80, 'balanceToTarget': 180},
      'bookingValue': {'mtdTarget': 12345678, 'monthlyTarget': 24691356, 'mtdAchieved': 11234567, 'mtdAchievementPct': 91, 'balanceToTarget': 13456789},
    },
    'bookingsBySource': {
      'organic': {'today': 5, 'mtd': 80, 'shareOfMtd': 66.7},
      'paidAds': {'today': 3, 'mtd': 30, 'shareOfMtd': 25},
      'trialBookings': {'today': 1, 'mtd': 10, 'shareOfMtd': 8.3},
      'totalBookings': {'today': 9, 'mtd': 120},
    },
    'leadsAndFollowUps': {
      'whatsappLeads': cell('WhatsApp', 123, 1234),
      'otherLeads': cell('Other', 12, 345),
      'trialCampaignLeads': cell('Trial', 4, 56),
    },
    'orderValueAndPayments': {
      'totalOrderValue': cell('Total', 1234567, 12345678),
      'advancePaid': cell('Adv', 234567, 2345678),
      'balanceDue': cell('Bal', 1000000, 10000000),
    },
    'leadCountCheck': {'today': check(), 'mtd': check()},
    'ledgerRows': [
      for (var i = 0; i < 6; i++)
        {
          'userId': 'u$i',
          'date': '2026-11-11',
          'salesPersonName': 'Anjali Krishnakumar Menon Pillai',
          'whatsappLeads': 123,
          'totalOrderValue': 1234567,
          'advancePaid': 234567,
          'comment': 'Follow up on Meta & LinkedIn Ad Campaign – Bridal Season Kochi leads',
        },
    ],
    'ledgerTotals': {'whatsappLeads': 738, 'totalOrderValue': 7407402, 'advancePaid': 1407402},
    'summary': {
      'callsMade': 12345,
      'callsConnected': 9876,
      'bookingsCount': 1234,
      'leadsConverted': 1234,
      'totalRevenue': 123456789,
      'totalAdvance': 12345678,
      'followUpsCompleted': 1234,
      'pendingFollowUpsCount': 5678,
    },
    'bookings': [
      for (var i = 0; i < 6; i++)
        {
          'id': 'b$i',
          'bookingNumber': 'TN-2026-11-00$i',
          'customerName': 'Fathima Liya Muhammed Kutty Abdul Rahman',
          'phone': '+91 98765 43210',
          'service': 'Bridal Makeup – Premium HD Airbrush Package with Hairstyling',
          'totalPrice': 1234567,
          'advanceAmount': 234567,
          'time': '10:30 AM',
        },
    ],
    'activities': [
      for (var i = 0; i < 6; i++)
        {
          'id': 'a$i',
          'leadName': 'Anjali Krishnakumar Menon Pillai',
          'leadPhone': '+91 98765 43210',
          'type': 'call',
          'callResponse': i.isEven ? 'connected' : 'not answering / switched off',
          'remark': 'Asked for the bridal season package brochure and price list again.',
          'time': '11:45 AM',
        },
    ],
    'pendingFollowUps': [
      for (var i = 0; i < 6; i++)
        {
          'id': 'f$i',
          'customerName': 'Mohammed Risan Abdul Rahman Kunjumon',
          'phone': '+91 98765 43210',
          'followUpDate': '2026-11-12 10:30 AM',
          'notes': 'Call back after family discussion about the wedding date',
        },
    ],
  });
}

Future<void> _pumpSalesEod(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await _setSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => const AuthSession(token: 't', userId: 'u0', name: 'Admin', email: 'admin@example.com', role: 'admin'),
        ),
        crmUsersProvider.overrideWith(
          (ref) async => [
            CrmUser.fromJson(const {
              '_id': 'u1',
              'name': 'Anjali Krishnakumar Menon Pillai',
              'email': 'anjali@example.com',
              'role': 'sales_executive',
            }),
          ],
        ),
        salesEodReportProvider.overrideWith((ref, q) async => _report()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showSalesEodDialog(context, initialSalesPersonId: 'u1'),
                child: const Text('Open EOD'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open EOD'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [('desktop 1440', _desktop), ('phone 390', _phone)]) {
    group(label, () {
      testWidgets('marketing EOD: every tab lays out without overflow', (tester) async {
        await _pumpMarketing(tester, size);
        _check(tester, 'EOD Entry tab');
        await _scrollThrough(tester, 'EOD Entry tab');

        for (final tab in [
          'My Dashboard',
          'Team Dashboards',
          'Team Summary',
          'Missed EODs',
          'Weekly Stats',
          'Setup',
          'Month Close',
        ]) {
          await tester.ensureVisible(find.text(tab));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          _check(tester, '$tab tab');
          await _scrollThrough(tester, '$tab tab');
        }
      });

      testWidgets('sales EOD dialog: every tab lays out without overflow', (tester) async {
        await _pumpSalesEod(tester, size);
        _check(tester, 'EOD Sheet tab');
        await _scrollThrough(tester, 'EOD Sheet tab');

        for (final tab in ['Team Ledger', 'Bookings (6)', 'Activity Log (6)', 'Due Follow-ups (6)']) {
          await tester.ensureVisible(find.text(tab));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          _check(tester, '$tab tab');
          await _scrollThrough(tester, '$tab tab');
        }
      });
    });
  }
}
