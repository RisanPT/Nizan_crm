import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_reports_tabs.dart';
import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

import 'fakes/marketing_reports_fake.dart';

// The Marketing team's attendance from Timebox: the screens say where attendance comes from (Timebox exactly, or the CRM's records with
// the reason), who is not linked, which rows are Timebox's, who is still in, the day's Timebox plan, the month as Timebox counts it, and
// the Timesheet's Timebox hours beside the hours logged.

const _live = {'mode': 'live', 'ok': true, 'problem': '', 'linked': 2, 'unlinked': ['Shahada']};
const _off = {'mode': 'off', 'ok': false, 'problem': 'Timebox is not connected on this server (TIMEBOX_API_URL is not set), so attendance comes from the CRM\'s own records and the work logs.', 'linked': 0, 'unlinked': []};
const _down = {'mode': 'live', 'ok': false, 'problem': 'Timebox refused the CRM\'s key (TIMEBOX_API_KEY). Attendance below comes from the CRM\'s own records.', 'linked': 2, 'unlinked': []};

Map<String, dynamic> _attendance(Map<String, dynamic> timebox) => {
  'date': '2026-11-18',
  'summary': {'present': 2, 'onShoot': 0, 'wfh': 0, 'onLeave': 0, 'absent': 1},
  'rate': 72,
  'linked': 3,
  'timebox': timebox,
  'rows': [
    {'memberId': 'a', 'name': 'Ashique', 'checkIn': '2026-11-18T03:42:00.000Z', 'checkOut': '2026-11-18T12:35:00.000Z', 'hours': 8.2, 'state': 'Active', 'status': 'Out', 'source': 'timebox', 'timeboxLink': 'login', 'monthRate': 81, 'daysAttended': 13, 'daysExpected': 16, 'monthSource': 'timebox', 'plan': {'total': 3, 'done': 2}},
    {'memberId': 'f', 'name': 'Faies', 'checkIn': '2026-11-18T04:30:00.000Z', 'state': 'Active', 'status': 'In', 'source': 'timebox', 'timeboxLink': 'name', 'stillIn': true, 'monthRate': 94, 'daysAttended': 15, 'daysExpected': 16, 'monthSource': 'timebox'},
    {'memberId': 's', 'name': 'Shahada', 'state': 'Active', 'status': 'Logged', 'source': 'logs', 'monthRate': null},
  ],
};

Map<String, dynamic> _sheet(Map<String, dynamic> timebox, {bool live = true}) => {
  'days': ['2026-11-17', '2026-11-18'],
  'totalMinutes': 600,
  'totalLabel': '10h',
  'timeboxTotalMinutes': live ? 1213 : null,
  'timeboxTotalLabel': live ? '20h 13m' : '',
  'timebox': timebox,
  'split': [],
  'rows': [
    {'memberId': 'a', 'name': 'Ashique', 'minutes': 360, 'label': '6h', 'logs': 3, 'daysLogged': 2, 'byDay': {'2026-11-18': 360}, 'status': 'Submitted', 'timeboxMinutes': live ? 913 : null, 'timeboxLabel': live ? '15h 13m' : ''},
    {'memberId': 's', 'name': 'Shahada', 'minutes': 240, 'label': '4h', 'logs': 1, 'daysLogged': 1, 'byDay': {'2026-11-18': 240}, 'status': 'Submitted', 'timeboxMinutes': null, 'timeboxLabel': ''},
  ],
  'workSummary': [],
  'activityReport': {'rows': [], 'groups': []},
};

class _Fake extends MarketingTeamService {
  _Fake(this.att, this.sheet) : super(Dio());
  final Map<String, dynamic> att;
  final Map<String, dynamic> sheet;
  @override
  Future<AttendanceData> attendance(String date, {TeamFilter? f}) async => AttendanceData.fromJson(att);
  @override
  Future<Timesheet> timesheet(TeamFilter f) async => Timesheet.fromJson(sheet);
  @override
  Future<DailyLogs> logs(TeamFilter f, {int page = 1, int limit = 50}) async => DailyLogs.fromJson(const {'items': [], 'total': 0, 'page': 1, 'pages': 1});
}

Future<void> _pump(WidgetTester t, Widget screen, _Fake fake) async {
  t.view.physicalSize = const Size(1400, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [marketingTeamServiceProvider.overrideWithValue(fake), marketingReportsServiceProvider.overrideWithValue(FakeMarketingReports())],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: screen)),
  ));
  await t.pumpAndSettle();
}

Finder _k(String key) => find.byKey(Key(key));

void main() {
  test('the Timebox fields are read, and where each row comes from is said in words', () {
    final a = AttendanceData.fromJson(_attendance(_live));
    expect(a.timebox.live, isTrue);
    expect(a.timebox.unlinked, ['Shahada']);
    expect(a.rows.first.fromTimebox, isTrue);
    expect([a.rows.first.planDone, a.rows.first.planTotal], [2, 3]);
    expect(a.rows[1].stillIn, isTrue);
    expect(AttendanceData.fromJson(_attendance(_off)).timebox.live, isFalse);
    expect(TimeboxInfo.fromJson(const {'mode': 'live', 'ok': true, 'linked': 0}).live, isFalse, reason: 'nobody linked: not live');
    expect([attendanceSourceLabel('timebox'), attendanceSourceLabel('crm'), attendanceSourceLabel('logs')], ['Timebox', 'CRM record', 'Work log only']);
    final csv = attendanceCsv(a);
    expect(csv.first, containsAll(['Source', 'Plan done', 'Plan items']));
    expect(csv[1].sublist(8, 11), ['Timebox', 2, 3]);
  });

  testWidgets('Timebox live: the banner says so and names who is not linked; Timebox rows are marked; still in; the plan; the month', (t) async {
    await _pump(t, const TeamAttendanceTab(), _Fake(_attendance(_live), _sheet(_live)));
    expect(find.text('Attendance from Timebox, exactly as Timebox records it.'), findsOneWidget);
    expect(find.textContaining('Not linked to Timebox: Shahada'), findsOneWidget);
    expect(_k('team_att_tb_a'), findsOneWidget);
    expect(_k('team_att_tb_f'), findsOneWidget);
    expect(_k('team_att_tb_s'), findsNothing, reason: 'a work log is not Timebox');
    expect(t.widget<Text>(_k('team_att_out_f')).data, 'still in');
    expect(t.widget<Text>(_k('team_att_plan_a')).data, '2/3 done');
    expect(t.widget<Text>(_k('team_att_plan_f')).data, '—');
    expect(t.widget<Text>(_k('team_att_month_a')).data, '81%');
    final tip = t.widget<Tooltip>(find.ancestor(of: _k('team_att_month_a'), matching: find.byType(Tooltip)).first);
    expect(tip.message, '13 of 16 working days (Timebox)');
    expect(find.text('as Timebox counts it'), findsOneWidget);
  });

  testWidgets('Timebox not connected: the banner says the attendance is the CRM\'s, not Timebox\'s', (t) async {
    await _pump(t, const TeamAttendanceTab(), _Fake(_attendance(_off), _sheet(_off, live: false)));
    expect(find.textContaining('Timebox is not connected on this server'), findsOneWidget);
    expect(find.text('Attendance from Timebox, exactly as Timebox records it.'), findsNothing);
    expect(_k('team_timebox_unlinked'), findsNothing);
  });

  testWidgets('Timebox not answering: the reason in words', (t) async {
    await _pump(t, const TeamAttendanceTab(), _Fake(_attendance(_down), _sheet(_down, live: false)));
    expect(find.textContaining('Timebox refused the CRM\'s key (TIMEBOX_API_KEY)'), findsOneWidget);
  });

  testWidgets('the Timesheet: Timebox hours beside the hours logged; "—" for someone not linked', (t) async {
    await _pump(t, const TeamTimesheetTab(), _Fake(_attendance(_live), _sheet(_live)));
    await t.tap(_k('team_logs_timesheet'));
    await t.pumpAndSettle();
    expect(find.text('Logged 10h · Timebox 20h 13m'), findsOneWidget);
    expect(t.widget<Text>(_k('team_timesheet_tb_a')).data, '15h 13m');
    expect(t.widget<Text>(_k('team_timesheet_tb_s')).data, '—');
    expect(_k('team_timebox_banner'), findsNothing, reason: 'the column says it: no banner');
  });

  testWidgets('the Timesheet without Timebox: no Timebox column, and the banner says why', (t) async {
    await _pump(t, const TeamTimesheetTab(), _Fake(_attendance(_off), _sheet(_off, live: false)));
    await t.tap(_k('team_logs_timesheet'));
    await t.pumpAndSettle();
    expect(_k('team_timesheet_tb_a'), findsNothing);
    expect(find.text('Total 10h'), findsOneWidget);
    expect(find.textContaining('Timebox is not connected on this server'), findsOneWidget);
  });
}
