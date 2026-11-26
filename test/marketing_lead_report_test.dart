import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/data/lead_speed_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_list_tab.dart' show leadAddFormOpenerProvider;
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

import 'fakes/marketing_reports_fake.dart';

// The Lead Report: Overview, All Leads, Lead Stages, Sources, Follow-ups, Conversion, Reports — read-only views of the CRM's leads.

Map<String, dynamic> _kpis() => {
      'total': 12, 'new': 2, 'inProgress': 5, 'notConverted': 1, 'converted': 4, 'qualified': 7, 'hot': 3, 'conversionRate': 25, 'bookings': 3, 'bookingValue': 14237.29, 'orderValue': 16800, 'unvalued': 1,
      'change': {'total': 140, 'new': 0, 'inProgress': 25, 'notConverted': -50, 'converted': 300, 'bookings': 200, 'bookingValue': 110, 'conversionRate': 5},
    };

Map<String, dynamic> _funnel() => {
      'total': 12,
      'steps': [
        {'key': 'leads', 'label': 'Total Leads', 'count': 12, 'pct': 100},
        {'key': 'qualified', 'label': 'Qualified', 'count': 7, 'pct': 58.3},
        {'key': 'hot', 'label': 'Hot', 'count': 3, 'pct': 25},
        {'key': 'bookings', 'label': 'Bookings', 'count': 3, 'pct': 25},
      ],
    };

List<Map<String, dynamic>> _groups() => [
      {'key': 'instagram', 'label': 'Instagram', 'count': 3, 'pct': 25, 'change': 100},
      {'key': 'meta_ads', 'label': 'Meta Ads', 'count': 2, 'pct': 16.7, 'change': null},
      {'key': 'whatsapp', 'label': 'WhatsApp', 'count': 3, 'pct': 25, 'change': -25},
      {'key': 'youtube', 'label': 'YouTube', 'count': 1, 'pct': 8.3, 'change': 0},
      {'key': 'website', 'label': 'Website', 'count': 0, 'pct': 0, 'change': null},
      {'key': 'others', 'label': 'Others', 'count': 3, 'pct': 25, 'change': null},
    ];

Map<String, dynamic> _followUpCounts() => {'due': 3, 'today': 2, 'overdue': 1, 'upcoming': 0, 'completed': 1, 'total': 4, 'overdueBefore': 2, 'change': {'completed': -50, 'total': 100}};

Map<String, dynamic> _trend({String granularity = 'day'}) => {
      'granularity': granularity,
      'rows': [
        for (var i = 0; i < 7; i++) {'from': '2026-11-0${2 + i}', 'to': '2026-11-0${2 + i}', 'leads': i % 3, 'new': i % 2, 'inProgress': 1, 'notConverted': 0, 'converted': i % 2, 'qualified': 1, 'bookings': i % 2},
      ],
    };

Map<String, dynamic> _campaign(String id, String title, {int leads = 3, double? spend = 1500, double? cpl = 500, double? cpb = 1500, String channel = 'Instagram'}) => {
      'id': id, 'title': title, 'channel': channel, 'brand': 'kerala', 'leads': leads, 'qualified': 2, 'bookings': 1, 'rate': 33.3, 'bookingValue': 10000, 'spend': spend, 'costPerLead': cpl, 'costPerBooking': cpb,
    };

Map<String, dynamic> _campaigns() => {
      'rows': [_campaign('c1', 'Bridal Campaign'), _campaign('c2', 'Festive Offers', leads: 2, spend: null, cpl: null, cpb: null, channel: 'Meta')],
      'untagged': 7,
      'costs': {'campaignsWithSpend': 1, 'campaignsTotal': 2, 'adSpend': 1500, 'leads': 5, 'bookings': 1, 'costPerLead': 300, 'costPerBooking': 1500},
    };

List<Map<String, dynamic>> _types() => [
      {'key': 'lead_gen', 'label': 'Lead gen (Meta form)', 'leads': 4, 'pct': 80},
      {'key': 'whatsapp', 'label': 'WhatsApp / messages', 'leads': 1, 'pct': 20},
    ];

Map<String, dynamic> _overview() => {
      'from': '2026-11-02', 'to': '2026-11-08', 'brand': 'all', 'capped': false,
      'kpis': _kpis(), 'funnel': _funnel(), 'sources': {'total': 12, 'groups': _groups()}, 'followUps': _followUpCounts(), 'trend': _trend(), 'campaigns': _campaigns(), 'campaignTypes': _types(),
    };

Map<String, dynamic> _lead(String id, String name, {String status = 'New', String stage = 'new', String phone = '9876543210', String source = 'ig_main', String sourceLabel = 'Instagram (Main)', String campaign = 'Bridal Campaign', String assignedTo = 'Asha', String priority = 'Warm'}) => {
      'id': id, 'shortId': '#${id.toUpperCase()}1', 'name': name, 'phone': phone, 'phoneMasked': '98••••••10', 'source': source, 'sourceLabel': sourceLabel, 'campaign': campaign, 'campaignId': campaign.isEmpty ? '' : 'c1',
      'assignedTo': assignedTo, 'assignedToId': 'u1', 'status': status, 'stage': stage, 'priority': priority, 'createdDay': '2026-11-05', 'createdAt': '2026-11-05T12:00:00.000Z',
    };

Map<String, dynamic> _leadList({bool canContact = true, int total = 12, int page = 1, List<Map<String, dynamic>>? items}) => {
      'canContact': canContact,
      'counts': {'all': 12, 'new': 2, 'in_progress': 5, 'not_converted': 1, 'converted': 4},
      'filters': {
        'assignees': [{'id': 'u1', 'name': 'Asha', 'count': 6}, {'id': 'u2', 'name': 'Ben', 'count': 5}],
        'unassigned': 1,
        'campaigns': [{'id': 'c1', 'title': 'Bridal Campaign', 'count': 3}, {'id': 'c2', 'title': 'Festive Offers', 'count': 2}],
        'untagged': 7,
      },
      'total': total, 'page': page, 'pageSize': 10,
      'items': items ?? [
        _lead('l1', 'Rehana P', status: 'Converted', stage: 'converted', priority: 'Hot', phone: canContact ? '9876543210' : ''),
        _lead('l2', 'Arjun K', status: 'Qualified', stage: 'in_progress', phone: canContact ? '9876543211' : '', assignedTo: ''),
        _lead('l3', 'Fathima S', status: 'Lost', stage: 'not_converted', source: 'meta_ads', sourceLabel: 'Meta Ads', campaign: '', phone: canContact ? '9876543212' : ''),
      ],
    };

Map<String, dynamic> _detail(String id, {bool canContact = true}) => {
      'id': id, 'shortId': '#${id.toUpperCase()}1', 'name': 'Rehana P', 'phone': canContact ? '9876543210' : '', 'phoneMasked': '98••••••10', 'canContact': canContact, 'source': 'ig_main', 'sourceLabel': 'Instagram (Main)', 'brand': 'main',
      'campaign': 'Bridal Campaign', 'assignedTo': 'Asha', 'status': 'Converted', 'stage': 'converted', 'priority': 'Hot', 'qualified': true, 'createdDay': '2026-11-05', 'createdAt': '2026-11-05T12:00:00.000Z',
      'eventType': 'Wedding', 'region': 'Calicut', 'district': 'Kozhikode', 'followUpDate': '2026-11-20T12:00:00.000Z', 'followUpState': 'upcoming', 'followUpCount': 3, 'followUpCompletedCount': 2,
      'reason': canContact ? 'Booked on the first call' : '', 'remarks': canContact ? 'Wants the gold set' : '',
      'booking': {'number': 'BK-1001', 'status': 'confirmed', 'counted': true, 'value': 10000},
      'activities': [
        {'id': 'a1', 'type': 'followup', 'channel': 'whatsapp', 'status': 'Completed', 'scheduledDate': '2026-11-03T12:00:00.000Z', 'callResponse': 'N/A', 'remark': canContact ? 'Confirmed the date' : '', 'by': 'Preethi'},
        {'id': 'a2', 'type': 'call', 'status': 'Completed', 'scheduledDate': '2026-11-02T12:00:00.000Z', 'callResponse': 'Connected', 'remark': '', 'by': 'Asha'},
      ],
    };

Map<String, dynamic> _stages() => {
      'kpis': _kpis(),
      'stages': [
        {'key': 'new', 'label': 'New', 'count': 2, 'pct': 16.7, 'change': 0},
        {'key': 'in_progress', 'label': 'In Progress', 'count': 5, 'pct': 41.7, 'change': 25},
        {'key': 'not_converted', 'label': 'Not Converted', 'count': 1, 'pct': 8.3, 'change': -50},
        {'key': 'converted', 'label': 'Converted', 'count': 4, 'pct': 33.3, 'change': 300},
      ],
      'statuses': [for (final (i, s) in ['New', 'Contacted', 'Qualified', 'Follow-up', 'Pending Lost Approval', 'Lost', 'Converted'].indexed) {'status': s, 'count': i + 1, 'pct': 10.5}],
      'quality': {'total': 12, 'rows': [{'key': 'Hot', 'label': 'Hot', 'count': 3, 'pct': 25}, {'key': 'Warm', 'label': 'Warm', 'count': 5, 'pct': 41.7}, {'key': 'Nurture', 'label': 'Nurture', 'count': 1, 'pct': 8.3}, {'key': 'Cold', 'label': 'Cold', 'count': 2, 'pct': 16.7}, {'key': 'Not rated', 'label': 'Not rated', 'count': 1, 'pct': 8.3}]},
      'trend': _trend(),
    };

Map<String, dynamic> _sources() => {
      'total': 12, 'groups': _groups(),
      'sources': [
        {'key': 'ig_main', 'label': 'Instagram (Main)', 'leads': 2, 'qualified': 2, 'hot': 1, 'bookings': 1, 'rate': 50, 'share': 16.7, 'bookingValue': 10000, 'unvalued': 0},
        {'key': 'whatsapp', 'label': 'WhatsApp', 'leads': 3, 'qualified': 1, 'hot': 0, 'bookings': 1, 'rate': 33.3, 'share': 25, 'bookingValue': 0, 'unvalued': 1},
      ],
      'campaigns': _campaigns(),
      'campaignTypes': _types(),
    };

Map<String, dynamic> _followUps({bool canContact = true, int total = 3}) => {
      'canContact': canContact, 'today': '2026-11-13', 'counts': _followUpCounts(), 'filter': 'all', 'total': total, 'page': 1, 'pageSize': 10,
      'items': [
        for (final (i, s) in ['overdue', 'today', 'completed'].indexed)
          {
            'id': 'f$i', 'leadId': 'l$i', 'shortId': '#L${i}1', 'name': ['Arjun K', 'Ria Ref', 'Rehana P'][i], 'phone': canContact ? '98765432${10 + i}' : '', 'phoneMasked': '98••••••1$i', 'campaign': i == 1 ? '' : 'Bridal Campaign',
            'assignedTo': i == 1 ? '' : 'Asha', 'assignedToId': 'u1', 'kind': 'activity', 'channel': i == 0 ? 'whatsapp' : '', 'channelLabel': i == 0 ? 'WhatsApp' : 'Follow-up', 'dueDay': '2026-11-1${i + 1}', 'due': '2026-11-1${i + 1}T12:00:00.000Z', 'state': s, 'remark': canContact && i == 0 ? 'Send the price list' : '',
          },
      ],
    };

Map<String, dynamic> _conversion() => {
      'kpis': _kpis(),
      'costs': {'campaignsWithSpend': 1, 'campaignsTotal': 2, 'adSpend': 1500, 'leads': 5, 'bookings': 1, 'costPerLead': 300, 'costPerBooking': 1500},
      'funnel': _funnel(),
      'trend': _trend(),
      'bySource': [
        {'key': 'ig_main', 'label': 'Instagram (Main)', 'leads': 2, 'bookings': 1, 'rate': 50},
        {'key': 'whatsapp', 'label': 'WhatsApp', 'leads': 3, 'bookings': 1, 'rate': 33.3},
      ],
      'campaignTypes': _types(),
    };

Map<String, dynamic> _report(String type, {bool canContact = true, bool truncated = false}) => {
      'type': type, 'title': {'summary': 'Lead Summary', 'sources': 'Source Report', 'campaigns': 'Campaign Report', 'team': 'Team Performance', 'conversion': 'Conversion Report', 'leads': 'All Leads', 'followups': 'Follow-ups'}[type],
      'from': '2026-11-02', 'to': '2026-11-08', 'brand': 'all', 'generatedAt': '2026-11-13T05:00:00.000Z', 'truncated': truncated, 'canContact': canContact,
      'columns': ['Measure', 'Value', 'Share %'],
      'rows': [
        for (var i = 0; i < 12; i++) [i == 0 ? '=HYPERLINK("x")' : 'Row $i', i * 10, i == 3 ? null : 12.5],
      ],
    };

class _Fake extends LeadReportService {
  _Fake() : super(Dio());
  final speedScopes = <String>[];
  final speedSaved = <Map<String, dynamic>>[];
  bool speedCanEdit = false;

  @override
  Future<LeadSpeed> speed(TeamFilter f, {String scope = 'auto'}) async {
    speedScopes.add(scope);
    return LeadSpeed.fromJson({
      'scope': scope,
      'canEdit': speedCanEdit,
      'settings': {'targetMinutes': 15, 'alertAfterMinutes': 30, 'dayStart': '09:00', 'dayEnd': '21:00', 'alertsOn': true},
      'kpis': {'leads': scope == 'all' ? 9 : 6, 'contacted': 4, 'medianMinutes': 12, 'withinPct': 75, 'waiting': 2, 'late': 1, 'unrecorded': 0},
      'previous': {'leads': 5, 'contacted': 5, 'medianMinutes': 95, 'withinPct': 20},
      'byPerson': [{'name': 'Arjun', 'leads': 4, 'contacted': 3, 'medianMinutes': 9, 'withinPct': 100, 'waiting': 1, 'late': 1}, {'name': 'Unassigned', 'leads': 2, 'contacted': 1, 'medianMinutes': 70, 'withinPct': 0, 'waiting': 1, 'late': 0}],
      'bySource': [{'name': 'Paid Ads', 'leads': 6, 'contacted': 4, 'medianMinutes': 12, 'withinPct': 75, 'waiting': 2, 'late': 1}],
      'waiting': [{'id': 'w1', 'name': 'Chitra', 'source': 'Paid Ads', 'assignee': 'Arjun', 'waitingMinutes': 75, 'late': true, 'alerted': true}, {'id': 'w2', 'name': 'Devi', 'source': 'Paid Ads', 'assignee': 'Unassigned', 'waitingMinutes': 5, 'late': false}],
      'slowest': [{'id': 's1', 'name': 'Elsa', 'source': 'Website', 'assignee': 'Arjun', 'minutes': 130, 'firstBy': 'Arjun', 'firstVia': 'call'}],
    });
  }

  @override
  Future<SpeedSettings> saveSpeedSettings(Map<String, dynamic> body) async {
    if (body['dayStart'] == '25:00') throw const TeamRefusal('Working hours are HH:MM, like 09:00.', field: 'dayStart', status: 400);
    speedSaved.add(body);
    return SpeedSettings.fromJson({...body, 'canEdit': true});
  }
  final filters = <TeamFilter>[];
  final leadQueries = <LeadListQuery>[];
  final followQueries = <FollowUpQuery>[];
  final opened = <String>[];
  final reportTypes = <String>[];
  bool fails = false;
  bool canContact = true;
  Map<String, dynamic>? overviewJson;
  Map<String, dynamic>? reportJson;
  Map<String, dynamic>? leadListJson;
  Map<String, dynamic>? followJson;
  Map<String, dynamic>? detailJson;

  void _maybeFail() {
    if (fails) throw Exception('boom');
  }

  @override
  Future<LeadOverview> overview(TeamFilter f) async {
    filters.add(f);
    _maybeFail();
    return LeadOverview.fromJson(overviewJson ?? _overview());
  }

  @override
  Future<LeadList> leads(TeamFilter f, LeadListQuery q) async {
    filters.add(f);
    leadQueries.add(q);
    _maybeFail();
    return LeadList.fromJson(leadListJson ?? _leadList(canContact: canContact, page: q.page, total: q.page > 1 ? 25 : 12));
  }

  @override
  Future<LeadDetail> lead(String id) async {
    opened.add(id);
    return LeadDetail.fromJson(detailJson ?? _detail(id, canContact: canContact));
  }

  @override
  Future<StagesData> stages(TeamFilter f) async {
    _maybeFail();
    return StagesData.fromJson(_stages());
  }

  @override
  Future<SourcesData> sources(TeamFilter f) async {
    _maybeFail();
    return SourcesData.fromJson(_sources());
  }

  @override
  Future<FollowUpList> followUps(TeamFilter f, FollowUpQuery q) async {
    followQueries.add(q);
    _maybeFail();
    return FollowUpList.fromJson(followJson ?? _followUps(canContact: canContact));
  }

  @override
  Future<ConversionData> conversion(TeamFilter f) async {
    _maybeFail();
    return ConversionData.fromJson(_conversion());
  }

  @override
  Future<LeadReportTable> report(String type, TeamFilter f) async {
    reportTypes.add(type);
    filters.add(f);
    _maybeFail();
    return LeadReportTable.fromJson(reportJson ?? _report(type, canContact: canContact));
  }
}

class _NoSpendFake extends _Fake {
  @override
  Future<ConversionData> conversion(TeamFilter f) async => ConversionData.fromJson({..._conversion(), 'costs': {'campaignsWithSpend': 0, 'campaignsTotal': 2, 'adSpend': null, 'leads': 5, 'bookings': 1, 'costPerLead': null, 'costPerBooking': null}});
}

class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}

class _Capture implements HttpClientAdapter {
  _Capture(this.seen, {this.status = 200, this.body = '{}'});
  final List<RequestOptions> seen;
  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString(body, status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

typedef _Saved = ({String name, List<List<Object?>> rows});

Future<({_Fake f, List<_Saved> saved})> _pump(WidgetTester tester, {String tab = 'overview', _Fake? fake, Size size = const Size(1280, 2200), FakeMarketingReports? reports}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _Fake();
  final saved = <_Saved>[];
  final overrides = <Override>[
    leadReportServiceProvider.overrideWithValue(f),
    marketingTeamServiceProvider.overrideWithValue(_NoTeam()),
    leadLinkOpenerProvider.overrideWithValue((uri) async {
      f.opened.add(uri.toString());
      return true;
    }),
    leadCsvSaverProvider.overrideWithValue((name, rows) async => saved.add((name: name, rows: rows))),
    leadAddFormOpenerProvider.overrideWithValue((context) async => f.opened.add('add-lead-form')),
    marketingReportsServiceProvider.overrideWithValue(reports ?? FakeMarketingReports()),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: LeadReportScreen(initialTab: tab)))));
  await tester.pumpAndSettle();
  return (f: f, saved: saved);
}

Finder _k(String key) => find.byKey(Key(key));
Finder _in(String key, String text) => find.descendant(of: _k(key), matching: find.text(text));
String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

/// Types into the search box and waits out its debounce (a timer schedules no frame, so pumpAndSettle alone would not advance the clock).
Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_k(key), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('how the payloads read', () {
    test('an empty payload reads as zeros and empty lists, never a crash', () {
      final o = LeadOverview.fromJson(const {});
      expect(o.kpis.total, 0);
      expect(o.kpis.conversionRate, isNull);
      expect(o.kpis.change, isEmpty);
      expect(o.funnel.steps, isEmpty);
      expect(o.sources.groups, isEmpty);
      expect(o.trend.granularity, 'day');
      expect(o.trend.hasLeads, isFalse);
      expect(o.campaigns.rows, isEmpty);
      expect(o.campaigns.costs.costPerBooking, isNull);
      expect(o.brand, 'all');
      expect(LeadList.fromJson(const {}).page, 1);
      expect(LeadList.fromJson(const {}).pageSize, 10);
      expect(LeadList.fromJson(const {}).canContact, isFalse);
      expect(FollowUpList.fromJson(const {}).filter, 'all');
      expect(StagesData.fromJson(const {}).stages, isEmpty);
      expect(SourcesData.fromJson(const {}).sources, isEmpty);
      expect(ConversionData.fromJson(const {}).bySource, isEmpty);
      expect(LeadReportTable.fromJson(const {'type': 'summary'}).rows, isEmpty);
      expect(LeadDetail.fromJson(const {'id': 'x'}).booking, isNull);
    });

    test('the KPI strip, the funnel, the sources and the follow-ups read their numbers', () {
      final o = LeadOverview.fromJson(_overview());
      expect([o.kpis.total, o.kpis.newLeads, o.kpis.inProgress, o.kpis.notConverted, o.kpis.converted], [12, 2, 5, 1, 4]);
      expect([o.kpis.converted, o.kpis.bookings], [4, 3], reason: 'the stage and the bookings are two different figures');
      expect(o.kpis.conversionRate, 25);
      expect(o.kpis.bookingValue, 14237.29);
      expect(o.kpis.change['conversionRate'], 5);
      expect(o.kpis.change['total'], 140);
      expect(o.funnel.steps.map((s) => s.count), [12, 7, 3, 3]);
      expect(o.sources.groups.map((g) => g.key), ['instagram', 'meta_ads', 'whatsapp', 'youtube', 'website', 'others']);
      expect(o.sources.groups[1].change, isNull);
      expect(o.followUps.overdueBefore, 2);
      expect(o.followUps.change['completed'], -50);
      expect([o.campaigns.rows.first.spend, o.campaigns.rows.first.costPerLead, o.campaigns.rows.first.bookings, o.campaigns.rows.first.brand], [1500, 500, 1, 'kerala']);
      expect(o.campaigns.rows.last.spend, isNull);
      expect([o.campaigns.costs.adSpend, o.campaigns.costs.leads, o.campaigns.costs.costPerLead], [1500, 5, 300]);
      expect(o.campaigns.untagged, 7);
      expect(o.campaignTypes.map((t) => [t.key, t.leads]), [['lead_gen', 4], ['whatsapp', 1]]);
      expect(o.trend.rows[1].bookings, 1);
    });

    test('a lead row shows the real number to a manager and the masked one to everyone else; a stage count is looked up by key', () {
      final open = LeadRow.fromJson(_lead('l1', 'Rehana P'));
      final closed = LeadRow.fromJson(_lead('l1', 'Rehana P', phone: ''));
      expect(open.contactFor(true), '9876543210');
      expect(closed.contactFor(true), '98••••••10');
      expect(open.contactFor(false), '98••••••10', reason: 'a number the server should not have sent is still not shown');
      expect(LeadRow.fromJson(const {'id': 'x'}).status, 'New');
      expect(LeadRow.fromJson(const {'id': 'x'}).priority, 'Not rated', reason: 'no priority is never guessed as Warm');
      expect(LeadRow.fromJson(_lead('l1', 'R')).campaignId, 'c1');
      final opts = LeadList.fromJson(_leadList()).filters;
      expect([opts.assignees.length, opts.campaigns.first.label, opts.unassigned, opts.untagged], [2, 'Bridal Campaign', 1, 7]);
      final c = LeadList.fromJson(_leadList()).counts;
      expect([c.of('all'), c.of('new'), c.of('in_progress'), c.of('not_converted'), c.of('converted'), c.of('nonsense')], [12, 2, 5, 1, 4, 12]);
      expect(leadStageLabel('in_progress'), 'In Progress');
      expect(leadStageLabel('odd'), 'odd');
    });

    test('a lead detail reads its booking, counters and history', () {
      final d = LeadDetail.fromJson(_detail('l1'));
      expect(d.booking!.counted, isTrue);
      expect(d.booking!.value, 10000);
      expect([d.followUpCount, d.followUpCompletedCount], [3, 2]);
      expect(d.activities.map((a) => a.typeLabel), ['Follow-up · WhatsApp', 'Call']);
      expect(LeadDetail.fromJson(const {'id': 'x'}).priority, 'Not rated');
      expect(FollowUpRow.fromJson(const {'id': 'f', 'channel': 'visit'}).channelLabel, 'Visit');
      expect(FollowUpRow.fromJson(const {'id': 'f'}).channelLabel, 'Follow-up');
      expect(d.contact, '9876543210');
      expect(LeadDetail.fromJson(_detail('l1', canContact: false)).contact, '98••••••10');
    });

    test('query objects are compared by their parts, and a new cut starts on page 1', () {
      expect(const LeadListQuery() == const LeadListQuery(), isTrue);
      expect(const LeadListQuery(stage: 'new') == const LeadListQuery(), isFalse);
      expect(const LeadListQuery(page: 2) == const LeadListQuery(), isFalse);
      expect(const LeadListQuery(page: 3).copyWith(q: 'a').page, 1);
      expect(const LeadListQuery(stage: 'new').copyWith(page: 2).stage, 'new');
      expect(const LeadListQuery(assignee: 'u1') == const LeadListQuery(), isFalse);
      expect(const LeadListQuery(campaign: 'none', page: 4).copyWith(assignee: 'u2'), const LeadListQuery(campaign: 'none', assignee: 'u2'));
      expect(const FollowUpQuery(filter: 'overdue').hashCode == const FollowUpQuery(filter: 'overdue').hashCode, isTrue);
      expect(const FollowUpQuery(page: 2) == const FollowUpQuery(), isFalse);
    });
  });

  group('the number and link helpers', () {
    test('numbers, percentages and rupees', () {
      expect(numText(33.3), '33.3');
      expect(numText(50.0), '50');
      expect(pctText(null), '—');
      expect(pctText(18.3), '18.3%');
      expect(rupees(14237.29), '₹14,237');
      expect(rupees(1234567, compact: false), '₹12,34,567');
      expect(rupees(3476000), '₹34.76L');
      expect(rupees(25000000), '₹2.50Cr');
      expect(costText(null), '—');
      expect(costText(84.9), '₹84.90');
      expect(costText(6666.67), '₹6,667');
      expect(dayLabel('2026-11-08'), '8 Nov');
      expect(dayLabel('nonsense'), 'nonsense');
    });

    test('the change text: direction, colour, points, and nothing to compare', () {
      expect(leadDelta(null), isNull);
      expect(leadDelta(0)!.text, 'No change');
      expect(leadDelta(12)!.text, '↑ +12% vs previous period');
      expect(leadDelta(12)!.good, isTrue);
      expect(leadDelta(-8)!.text, '↓ −8% vs previous period');
      expect(leadDelta(-8)!.good, isFalse);
      expect(leadDelta(-50, lowerIsBetter: true)!.good, isTrue, reason: 'fewer lost leads is good');
      expect(leadDelta(13.3, points: true)!.text, '↑ +13.3 pp vs previous period');
    });

    test('WhatsApp and call links: a 10-digit Indian number gets 91, a number with its country code is kept, nonsense is refused', () {
      expect(whatsappUri('98765 43210').toString(), 'https://wa.me/919876543210');
      expect(whatsappUri('09876543210').toString(), 'https://wa.me/919876543210');
      expect(whatsappUri('+91 98765-43210').toString(), 'https://wa.me/919876543210');
      expect(whatsappUri('+971 50 123 4567').toString(), 'https://wa.me/971501234567');
      expect(whatsappUri('12345'), isNull);
      expect(whatsappUri(''), isNull);
      expect(telUri('98765 43210').toString(), 'tel:9876543210');
      expect(telUri('+91 98765 43210').toString(), 'tel:+919876543210');
      expect(telUri('123'), isNull);
    });

    test('a CSV cell that starts like a formula is written as text; the file is named for the report, range and brand', () {
      expect(csvSafe('=HYPERLINK("x")'), '\'=HYPERLINK("x")');
      expect(csvSafe('+91 98765'), '\'+91 98765');
      expect(csvSafe('-5 leads'), '\'-5 leads');
      expect(csvSafe('@cmd'), '\'@cmd');
      expect(csvSafe('Rehana'), 'Rehana');
      expect(csvSafe(-5), -5, reason: 'numbers stay numbers');
      expect(csvSafe(null), isNull);
      final t = LeadReportTable.fromJson(_report('summary'));
      expect(csvFileName(t), 'lead-report-summary-2026-11-02-to-2026-11-08.csv');
      expect(csvFileName(LeadReportTable.fromJson({..._report('team'), 'brand': 'kerala'})), 'lead-report-team-2026-11-02-to-2026-11-08-kerala.csv');
      final rows = leadReportCsvRows(t);
      expect(rows[0], ['Lead Report — Lead Summary']);
      expect(rows[1], ['From', '2026-11-02', 'To', '2026-11-08', 'Brand', 'All brands']);
      expect(rows[2], isEmpty);
      expect(rows[3], ['Measure', 'Value', 'Share %']);
      expect(rows[4].first, '\'=HYPERLINK("x")');
      expect(rows[4][1], 0);
      expect(rows[7][2], isNull, reason: 'a gap stays a gap');
      expect(rows.length, 4 + 12);
      expect(leadReportCsvRows(LeadReportTable.fromJson(_report('summary', truncated: true)))[2].first, startsWith('Only the first 20,000 rows'));
    });
  });

  group('the Lead Report screen', () {
    testWidgets('has the eight tabs the sidebar links to and an Export button', (tester) async {
      await _pump(tester);
      expect(kLeadReportTabs.map((t) => t.$1).toList(), ['overview', 'leads', 'stages', 'sources', 'followups', 'speed', 'conversion', 'reports']);
      expect(kLeadReportTabs.map((t) => t.$2).toList(), ['Overview', 'All Leads', 'Lead Stages', 'Sources', 'Follow-ups', 'Speed to lead', 'Conversion', 'Reports']);
      for (final t in kLeadReportTabs) {
        expect(_k('lr_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect(_k('lr_export'), findsOneWidget);
      expect(find.text('Lead Report  ›  '), findsNothing, reason: 'the breadcrumb is part of one rich text');
      expect(find.textContaining('Lead Report', findRichText: true), findsWidgets);
    });

    testWidgets('every tab opens from a link (?tab=…) and the header follows the tab', (tester) async {
      final marker = {
        'overview': 'lr_overview_list',
        'leads': 'lr_leads_list',
        'stages': 'lr_stages_list',
        'sources': 'lr_sources_list',
        'followups': 'lr_followups_list',
        'speed': 'lr_speed_list',
        'conversion': 'lr_conversion_list',
        'reports': 'lr_reports_list',
      };
      for (final t in kLeadReportTabs) {
        await _pump(tester, tab: t.$1);
        expect(_k(marker[t.$1]!), findsOneWidget, reason: t.$1);
        final title = tester.widget<Text>(_k('mkt_title')).textSpan!.toPlainText();
        expect(title, 'Lead Report  ›  ${t.$2}', reason: t.$1);
      }
    });

    testWidgets('a tab pill opens its tab; an unknown tab opens the Overview', (tester) async {
      await _pump(tester, tab: 'nonsense');
      expect(_k('lr_overview_list'), findsOneWidget);
      await tester.tap(_k('lr_tab_followups'));
      await tester.pumpAndSettle();
      expect(_k('lr_followups_list'), findsOneWidget);
    });

    testWidgets('the date range and brand filters are the shared ones: a brand change asks every read for that brand', (tester) async {
      final f = await _pump(tester);
      expect(f.f.filters.last.brand, TeamBrand.all);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(f.f.filters.last.brand, TeamBrand.kerala);
      expect(_k('team_filter_range'), findsOneWidget);
    });

    testWidgets('Export downloads the current tab\'s report as a CSV; the Reports tab has no header Export', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('lr_export'));
      await tester.pumpAndSettle();
      expect(f.f.reportTypes, ['summary']);
      expect(f.saved.single.name, 'lead-report-summary-2026-11-02-to-2026-11-08.csv');
      expect(f.saved.single.rows[0], ['Lead Report — Lead Summary']);
      expect(f.saved.single.rows[4].first, '\'=HYPERLINK("x")', reason: 'a formula-looking cell is neutralised');
      await tester.tap(_k('lr_tab_leads'));
      await tester.pumpAndSettle();
      await tester.tap(_k('lr_export'));
      await tester.pumpAndSettle();
      expect(f.f.reportTypes.last, 'leads');
      await tester.tap(_k('lr_tab_reports'));
      await tester.pumpAndSettle();
      expect(_k('lr_export'), findsNothing);
      expect(kLeadExportOf.keys.toSet(), {'overview', 'leads', 'stages', 'sources', 'followups', 'conversion'});
    });

    testWidgets('a failed export shows a message instead of a download', (tester) async {
      final fake = _Fake();
      final f = await _pump(tester, fake: fake);
      fake.fails = true;
      await tester.tap(_k('lr_export'));
      await tester.pumpAndSettle();
      expect(f.saved, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Overview', () {
    testWidgets('the KPI strip: leads by stage, the conversion rate, and the change against the period before', (tester) async {
      await _pump(tester);
      expect(_in('lr_kpi_total', '12'), findsOneWidget);
      expect(_in('lr_kpi_new', '2'), findsOneWidget);
      expect(_in('lr_kpi_progress', '5'), findsOneWidget);
      expect(_in('lr_kpi_lost', '1'), findsOneWidget);
      expect(_in('lr_kpi_converted', '4'), findsOneWidget);
      expect(_in('lr_kpi_converted', 'Converted (stage)'), findsOneWidget);
      expect(_in('lr_kpi_bookings', '3'), findsOneWidget);
      expect(_in('lr_kpi_bookings', '↑ +200% vs previous period'), findsOneWidget);
      expect(_in('lr_kpi_rate', '25%'), findsOneWidget);
      expect(find.textContaining('1 Converted lead has no live booking'), findsOneWidget, reason: 'the stage and the bookings differ, and the screen says why');
      expect(_in('lr_kpi_total', '↑ +140% vs previous period'), findsOneWidget);
      expect(_in('lr_kpi_rate', '↑ +5 pp vs previous period'), findsOneWidget);
      expect(_in('lr_kpi_new', 'No change'), findsOneWidget);
      final lostChange = tester.widget<Text>(find.descendant(of: _k('lr_kpi_lost'), matching: find.text('↓ −50% vs previous period')));
      expect(lostChange.style!.color, Mkt.good, reason: 'fewer lost leads is good news');
    });

    testWidgets('the funnel, the sources donut, the follow-ups, the trend and the top campaigns', (tester) async {
      await _pump(tester);
      for (final k in ['leads', 'qualified', 'hot', 'bookings']) {
        expect(_k('lr_ov_funnel_$k'), findsOneWidget, reason: k);
      }
      expect(_in('lr_ov_funnel_qualified', '7'), findsOneWidget);
      expect(find.descendant(of: _k('lr_ov_funnel_bookings'), matching: find.textContaining('25%')), findsOneWidget);
      expect(_text(tester, _k('lr_ov_sources_total')), '12');
      expect(find.text('Instagram'), findsWidgets);
      expect(_in('lr_ov_fu_due', '3'), findsOneWidget);
      expect(_in('lr_ov_fu_today', '2'), findsOneWidget);
      expect(_in('lr_ov_fu_overdue', '1'), findsOneWidget);
      expect(_in('lr_ov_fu_completed', '1'), findsOneWidget);
      expect(find.textContaining('2 more follow-ups are still overdue from before this range'), findsOneWidget);
      expect(_k('lr_ov_trend'), findsOneWidget);
      expect(find.descendant(of: _k('lr_ov_campaigns'), matching: find.text('Bridal Campaign')), findsOneWidget);
      expect(find.descendant(of: _k('lr_ov_campaigns'), matching: find.text('₹500.00')), findsOneWidget, reason: 'cost per lead where ad spend is known');
      expect(find.textContaining('ad spend of these dates'), findsOneWidget);
      expect(find.descendant(of: _k('lr_ov_campaigns'), matching: find.text('—')), findsWidgets, reason: 'and a dash where it is not');
      expect(find.text('7 leads in this range have no campaign.'), findsOneWidget);
      expect(_text(tester, _k('lr_campaign_types_total')), '5', reason: 'Leads by Campaign Type, from the same server function as the Campaigns hub');
      expect(find.text('Lead gen (Meta form)'), findsOneWidget);
    });

    testWidgets('the cards\' links go to the tab that has the detail', (tester) async {
      await _pump(tester);
      await tester.ensureVisible(_k('lr_ov_followups_link'));
      await tester.tap(_k('lr_ov_followups_link'));
      await tester.pumpAndSettle();
      expect(_k('lr_followups_list'), findsOneWidget);
      await tester.tap(_k('lr_tab_overview'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k('lr_ov_sources_link'));
      await tester.tap(_k('lr_ov_sources_link'));
      await tester.pumpAndSettle();
      expect(_k('lr_sources_list'), findsOneWidget);
    });

    testWidgets('an empty range shows dashes and empty cards, not made-up numbers; no ad spend says so', (tester) async {
      final fake = _Fake()
        ..overviewJson = {
          'kpis': {'total': 0, 'new': 0, 'inProgress': 0, 'notConverted': 0, 'converted': 0, 'conversionRate': null, 'change': {'total': null}},
          'funnel': {'total': 0, 'steps': []},
          'sources': {'total': 0, 'groups': []},
          'followUps': {},
          'trend': {'granularity': 'day', 'rows': []},
          'campaigns': {'rows': [_campaign('c9', 'Studio', spend: null, cpl: null, cpb: null)], 'untagged': 0, 'costs': {'campaignsWithSpend': 0, 'campaignsTotal': 1}},
        };
      await _pump(tester, fake: fake);
      expect(_in('lr_kpi_rate', '—'), findsOneWidget);
      expect(find.text('No leads in this range.'), findsWidgets);
      expect(find.text('No leads arrived in this range.'), findsOneWidget);
      expect(find.textContaining('No ad spend is recorded for these dates'), findsOneWidget);
      expect(find.text('No lead in this range is tagged to a campaign.'), findsOneWidget);
    });

    testWidgets('a range with more leads than the server can load says the figures are partial', (tester) async {
      final fake = _Fake()..overviewJson = {..._overview(), 'capped': true};
      await _pump(tester, fake: fake);
      expect(find.textContaining('more leads in this range than the report can load'), findsOneWidget);
    });

    testWidgets('a failing read shows "Try again", and trying again reads it again', (tester) async {
      final fake = _Fake()..fails = true;
      await _pump(tester, fake: fake);
      expect(find.text('Try again'), findsOneWidget);
      final before = fake.filters.length;
      fake.fails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(fake.filters.length, greaterThan(before));
      expect(_in('lr_kpi_total', '12'), findsOneWidget);
    });
  });

  group('All Leads', () {
    testWidgets('the table: id, name, contact, source, campaign, assignee, status and date; chips with counts', (tester) async {
      await _pump(tester, tab: 'leads');
      expect(_k('lr_leads_table'), findsOneWidget);
      for (final id in ['l1', 'l2', 'l3']) {
        expect(_k('lr_lead_$id'), findsOneWidget, reason: id);
      }
      expect(find.text('Rehana P'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Instagram (Main)'), findsWidgets);
      expect(find.text('Bridal Campaign'), findsWidgets);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.descendant(of: _k('lr_lead_l1'), matching: find.text('Converted')), findsOneWidget);
      expect(find.descendant(of: _k('lr_lead_l3'), matching: find.text('Lost')), findsOneWidget);
      expect(_in('lr_stage_all', '12'), findsOneWidget);
      expect(_in('lr_stage_new', '2'), findsOneWidget);
      expect(_in('lr_stage_in_progress', '5'), findsOneWidget);
      expect(_in('lr_stage_converted', '4'), findsOneWidget);
      expect(_in('lr_stage_not_converted', '1'), findsOneWidget);
      expect(_text(tester, _k('lr_leads_showing')), 'Showing 1–10 of 12');
      expect(find.text('Contact numbers are hidden — only a Marketing Manager can see them.'), findsNothing);
    });

    testWidgets('even a number the server should not have sent is not shown to someone who may not see numbers', (tester) async {
      final fake = _Fake()..leadListJson = {..._leadList(canContact: true), 'canContact': false};
      await _pump(tester, tab: 'leads', fake: fake);
      expect(find.text('9876543210'), findsNothing);
      expect(find.text('98••••••10'), findsWidgets);
    });

    testWidgets('a new date range or brand starts the list again on page 1', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      await tester.tap(_k('lr_leads_next'));
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.page, 2);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(f.f.filters.last.brand, TeamBrand.kerala);
      expect(f.f.leadQueries.last.page, 1);
    });

    testWidgets('someone who may not see numbers gets them masked, with a lock and a note', (tester) async {
      final fake = _Fake()..canContact = false;
      await _pump(tester, tab: 'leads', fake: fake);
      expect(find.text('9876543210'), findsNothing);
      expect(find.text('98••••••10'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      expect(find.text('Contact numbers are hidden — only a Marketing Manager can see them.'), findsOneWidget);
    });

    testWidgets('the stage chips, the source filter, sorting and searching each ask the server for exactly that', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      expect(f.f.leadQueries.last, const LeadListQuery());
      await tester.tap(_k('lr_stage_converted'));
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.stage, 'converted');
      await tester.tap(_k('lr_source_filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meta Ads').last);
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.source, 'meta_ads');
      expect(f.f.leadQueries.last.stage, 'converted', reason: 'filters add up');
      await tester.tap(_k('lr_sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name A–Z').last);
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.sort, 'name');
      await _type(tester, 'lr_search', 'rehana');
      expect(f.f.leadQueries.last.q, 'rehana');
      expect(f.f.leadQueries.last.stage, 'converted', reason: 'the chip stays when you search');
      expect(f.f.leadQueries.last.sort, 'name');
    });

    testWidgets('Assigned to and Campaign filters list the people and campaigns of the range and ask the server for exactly that', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      await tester.tap(_k('lr_assignee_filter'));
      await tester.pumpAndSettle();
      expect(find.text('Unassigned (1)'), findsOneWidget);
      await tester.tap(find.text('Ben (5)').last);
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.assignee, 'u2');
      await tester.tap(_k('lr_campaign_filter'));
      await tester.pumpAndSettle();
      expect(find.text('No campaign (7)'), findsOneWidget);
      await tester.tap(find.text('Bridal Campaign (3)').last);
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.campaign, 'c1');
      expect(f.f.leadQueries.last.assignee, 'u2', reason: 'filters add up');
      expect(f.f.leadQueries.last.page, 1);
      await tester.tap(_k('lr_assignee_filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unassigned (1)').last);
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.assignee, 'unassigned');
    });

    testWidgets('a chosen filter whose person has no leads in the new range still shows (no crash), and Anyone clears it', (tester) async {
      final fake = _Fake()..leadListJson = {..._leadList(), 'filters': {'assignees': [], 'campaigns': [], 'unassigned': 0, 'untagged': 0}};
      final f = await _pump(tester, tab: 'leads', fake: fake);
      expect(find.text('Anyone'), findsOneWidget);
      await tester.tap(_k('lr_assignee_filter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unassigned ('), findsNothing, reason: 'nobody unassigned in this range: no such choice');
      await tester.tap(find.text('Anyone').last);
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.assignee, 'all');
    });

    testWidgets('Add Lead opens the CRM\'s own lead form, then the list is read again', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      final before = f.f.leadQueries.length;
      await tester.tap(_k('lr_add_lead'));
      await tester.pumpAndSettle();
      expect(f.f.opened, ['add-lead-form']);
      expect(f.f.leadQueries.length, greaterThan(before), reason: 'a lead saved there shows here at once');
    });

    testWidgets('typing waits for a pause: one request per burst, not one per key', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      final before = f.f.leadQueries.length;
      await tester.enterText(_k('lr_search'), 'r');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(_k('lr_search'), 're');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(_k('lr_search'), 'reh');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.length, before + 1);
      expect(f.f.leadQueries.last.q, 'reh');
    });

    testWidgets('paging: next goes to page 2, previous comes back; the first page cannot go back', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      expect(tester.widget<IconButton>(_k('lr_leads_prev')).onPressed, isNull);
      expect(tester.widget<IconButton>(_k('lr_leads_next')).onPressed, isNotNull);
      await tester.tap(_k('lr_leads_next'));
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.page, 2);
      expect(tester.widget<IconButton>(_k('lr_leads_prev')).onPressed, isNotNull);
      await tester.tap(_k('lr_leads_prev'));
      await tester.pumpAndSettle();
      expect(f.f.leadQueries.last.page, 1);
    });

    testWidgets('a row opens the lead read-only: facts, follow-up counters, booking value, notes and the follow-up history', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      await tester.tap(_k('lr_lead_l1'));
      await tester.pumpAndSettle();
      expect(f.f.opened, ['l1']);
      expect(_text(tester, _k('lr_detail_name')), 'Rehana P');
      expect(_text(tester, _k('lr_detail_contact')), '9876543210');
      expect(find.text('Counted by the CRM: 3 scheduled · 2 actioned'), findsOneWidget);
      expect(find.textContaining('Next: 20 Nov 2026'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(_text(tester, _k('lr_detail_booking_value')), 'Value ₹10,000 (after discount, excluding GST)');
      expect(find.text('BK-1001 · confirmed'), findsOneWidget);
      expect(find.textContaining('Wants the gold set'), findsOneWidget);
      expect(find.descendant(of: _k('lr_detail_history'), matching: find.text('Follow-up · WhatsApp')), findsOneWidget);
      expect(find.descendant(of: _k('lr_detail_history'), matching: find.text('Call')), findsOneWidget);
      expect(find.text('Confirmed the date'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(_k('lr_call_detail'), findsOneWidget);
      // nothing to edit: no form fields, no save
      expect(find.descendant(of: _k('lr_detail'), matching: find.byType(TextField)), findsNothing);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(_k('lr_detail'), findsNothing);
    });

    testWidgets('for someone who may not see contact details the detail hides the number, the notes and the call buttons', (tester) async {
      final fake = _Fake()..canContact = false;
      await _pump(tester, tab: 'leads', fake: fake);
      await tester.tap(_k('lr_lead_l1'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('lr_detail_contact')), '98••••••10');
      expect(find.text('Contact details and notes are shown only to a Marketing Manager.'), findsOneWidget);
      expect(find.textContaining('Wants the gold set'), findsNothing);
      expect(_k('lr_call_detail'), findsNothing);
    });

    testWidgets('a booking that is not counted says so, whatever value came with it; the number stays masked without access', (tester) async {
      final fake = _Fake()..detailJson = {..._detail('l1', canContact: false), 'phone': '9876543210', 'booking': {'number': 'BK-9', 'status': 'cancelled', 'counted': false, 'value': 5000}};
      await _pump(tester, tab: 'leads', fake: fake);
      await tester.tap(_k('lr_lead_l1'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('lr_detail_booking_value')), startsWith('Not counted: the booking is cancelled or still pending'));
      expect(_text(tester, _k('lr_detail_contact')), '98••••••10');
      expect(_k('lr_call_detail'), findsNothing);
    });

    testWidgets('call and WhatsApp in the detail open tel: and wa.me', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      await tester.tap(_k('lr_lead_l1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('lr_call_detail'));
      await tester.tap(_k('lr_wa_detail'));
      await tester.pumpAndSettle();
      expect(f.f.opened, ['l1', 'tel:9876543210', 'https://wa.me/919876543210']);
    });

    testWidgets('no matching leads is an empty state; a failing read shows "Try again"', (tester) async {
      final fake = _Fake();
      await _pump(tester, tab: 'leads', fake: fake);
      fake.fails = true;
      await tester.tap(_k('lr_stage_new'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(_k('lr_search'), findsOneWidget, reason: 'the controls stay, so typing is not lost');
    });
  });

  group('Lead Stages', () {
    testWidgets('the stage tiles with their share, the pipeline, the distribution, the CRM statuses and the quality bars', (tester) async {
      await _pump(tester, tab: 'stages');
      expect(_in('lr_st_total', '12'), findsOneWidget);
      expect(_in('lr_st_new', '2'), findsOneWidget);
      expect(_in('lr_st_progress', '5'), findsOneWidget);
      expect(_in('lr_st_lost', '1'), findsOneWidget);
      expect(_in('lr_st_converted', '4'), findsOneWidget);
      expect(find.text('Converted · 33.3%'), findsOneWidget);
      expect(_in('lr_st_converted', '↑ +300% vs previous period'), findsOneWidget);
      for (final k in ['leads', 'new', 'in_progress', 'not_converted', 'converted']) {
        expect(_k('lr_pipe_$k'), findsOneWidget, reason: k);
      }
      expect(find.descendant(of: _k('lr_pipe_leads'), matching: find.textContaining('100%')), findsOneWidget, reason: 'the total is all of the leads');
      expect(find.descendant(of: _k('lr_pipe_converted'), matching: find.textContaining('33.3%')), findsOneWidget);
      expect(_text(tester, _k('lr_st_donut_total')), '12');
      expect(_k('lr_st_trend'), findsOneWidget);
      expect(find.descendant(of: _k('lr_st_statuses'), matching: find.text('Pending Lost Approval')), findsOneWidget);
      expect(find.descendant(of: _k('lr_st_statuses'), matching: find.text('7')), findsOneWidget, reason: 'Converted: the 7th status');
      expect(find.descendant(of: _k('lr_st_quality'), matching: find.text('Hot')), findsOneWidget);
      expect(find.descendant(of: _k('lr_st_quality'), matching: find.text('3 · 25%')), findsOneWidget);
      expect(find.descendant(of: _k('lr_st_quality'), matching: find.text('Nurture')), findsOneWidget);
      expect(find.descendant(of: _k('lr_st_quality'), matching: find.text('Not rated')), findsOneWidget);
      expect(find.textContaining('Hot, Warm, Nurture, Cold'), findsOneWidget);
    });

    testWidgets('empty and failing states', (tester) async {
      final fake = _Fake()..fails = true;
      await _pump(tester, tab: 'stages', fake: fake);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Sources', () {
    testWidgets('a card for each source group with its change; the donut; campaigns with cost per lead; the source table', (tester) async {
      await _pump(tester, tab: 'sources');
      for (final g in ['instagram', 'meta_ads', 'whatsapp', 'youtube', 'website', 'others']) {
        expect(_k('lr_src_$g'), findsOneWidget, reason: g);
      }
      expect(_in('lr_src_website', '0'), findsOneWidget);
      expect(_in('lr_src_instagram', '3'), findsOneWidget);
      expect(_in('lr_src_instagram', '↑ +100% vs previous period'), findsOneWidget);
      expect(_in('lr_src_whatsapp', '↓ −25% vs previous period'), findsOneWidget);
      expect(_in('lr_src_youtube', 'No change'), findsOneWidget);
      expect(_text(tester, _k('lr_src_donut_total')), '12');
      expect(find.descendant(of: _k('lr_src_campaigns'), matching: find.text('₹1,500')), findsOneWidget, reason: 'the spend of these dates');
      expect(find.descendant(of: _k('lr_src_campaigns'), matching: find.text('₹500.00')), findsOneWidget, reason: 'cost per lead');
      expect(find.descendant(of: _k('lr_src_campaigns'), matching: find.text('BOOKINGS')), findsOneWidget);
      expect(find.descendant(of: _k('lr_src_campaigns'), matching: find.text('Festive Offers')), findsOneWidget);
      expect(find.descendant(of: _k('lr_src_table'), matching: find.text('Instagram (Main)')), findsOneWidget);
      expect(find.descendant(of: _k('lr_src_table'), matching: find.text('50%')), findsOneWidget);
      expect(find.descendant(of: _k('lr_src_table'), matching: find.text('BOOKINGS')), findsOneWidget);
      expect(find.textContaining('the Campaigns hub\'s figures'), findsOneWidget);
      expect(_text(tester, _k('lr_campaign_types_total')), '5');
    });

    testWidgets('empty and failing states', (tester) async {
      final fake = _Fake()..fails = true;
      await _pump(tester, tab: 'sources', fake: fake);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Follow-ups', () {
    testWidgets('the four cards, the chips with counts, and the table with each follow-up\'s state', (tester) async {
      await _pump(tester, tab: 'followups');
      expect(_in('lr_fu_kpi_due', '3'), findsOneWidget);
      expect(_in('lr_fu_kpi_today', '2'), findsOneWidget);
      expect(_in('lr_fu_kpi_overdue', '1'), findsOneWidget);
      expect(_in('lr_fu_kpi_completed', '1'), findsOneWidget);
      expect(_in('lr_fu_kpi_completed', '↓ −50% vs previous period'), findsOneWidget);
      expect(_in('lr_fu_all', '4'), findsOneWidget);
      expect(_in('lr_fu_today', '2'), findsOneWidget);
      expect(_in('lr_fu_overdue', '1'), findsOneWidget);
      expect(_in('lr_fu_upcoming', '0'), findsOneWidget);
      expect(_in('lr_fu_completed', '1'), findsOneWidget);
      expect(find.descendant(of: _k('lr_fu_f0'), matching: find.text('Overdue')), findsOneWidget);
      expect(find.descendant(of: _k('lr_fu_f1'), matching: find.text('Due Today')), findsOneWidget);
      expect(find.descendant(of: _k('lr_fu_f2'), matching: find.text('Completed')), findsOneWidget);
      expect(find.text('Send the price list'), findsOneWidget);
      expect(_in('lr_fu_type_f0', 'WhatsApp'), findsOneWidget, reason: 'the type chosen when it was logged in the CRM');
      expect(_in('lr_fu_type_f1', 'Follow-up'), findsOneWidget, reason: 'none chosen');
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.textContaining('2 older follow-ups are still overdue from before this date range'), findsOneWidget);
      expect(find.textContaining('The CRM\'s own "Completed" counter has no dates'), findsOneWidget);
      expect(_text(tester, _k('lr_fu_showing')), 'Showing 1–3 of 3');
    });

    testWidgets('each chip asks for that filter, and paging keeps it', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      expect(f.f.followQueries.last, const FollowUpQuery());
      for (final c in ['today', 'overdue', 'upcoming', 'completed']) {
        await tester.tap(_k('lr_fu_$c'));
        await tester.pumpAndSettle();
        expect(f.f.followQueries.last.filter, c, reason: c);
        expect(f.f.followQueries.last.page, 1);
      }
      await tester.tap(_k('lr_fu_all'));
      await tester.pumpAndSettle();
      expect(f.f.followQueries.last.filter, 'all');
    });

    testWidgets('call and WhatsApp buttons open tel: and wa.me for a manager', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await tester.tap(_k('lr_call_f0'));
      await tester.tap(_k('lr_wa_f1'));
      await tester.pumpAndSettle();
      expect(f.f.opened, ['tel:9876543210', 'https://wa.me/919876543211']);
    });

    testWidgets('for someone who may not see numbers there are no call buttons — and no notes', (tester) async {
      final fake = _Fake()..canContact = false;
      await _pump(tester, tab: 'followups', fake: fake);
      expect(find.byIcon(Icons.call_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_outlined), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      expect(find.text('Send the price list'), findsNothing);
      expect(find.textContaining('Call and WhatsApp are available to a Marketing Manager'), findsOneWidget);
    });

    testWidgets('no call buttons without access even if a number came with the row', (tester) async {
      final fake = _Fake()..followJson = {..._followUps(canContact: true), 'canContact': false};
      await _pump(tester, tab: 'followups', fake: fake);
      expect(find.byIcon(Icons.call_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_outlined), findsNothing);
    });

    testWidgets('a new date range or brand starts the follow-ups again on page 1', (tester) async {
      final fake = _Fake()..followJson = _followUps(total: 25);
      final f = await _pump(tester, tab: 'followups', fake: fake);
      await tester.tap(_k('lr_fu_next'));
      await tester.pumpAndSettle();
      expect(f.f.followQueries.last.page, 2);
      await tester.tap(_k('lr_fu_overdue'));
      await tester.pumpAndSettle();
      expect(f.f.followQueries.last, const FollowUpQuery(filter: 'overdue'), reason: 'a new chip is page 1');
      await tester.tap(_k('lr_fu_next'));
      await tester.pumpAndSettle();
      expect(f.f.followQueries.last, const FollowUpQuery(filter: 'overdue', page: 2));
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(f.f.followQueries.last, const FollowUpQuery(filter: 'overdue'), reason: 'the chip stays, the page starts again');
    });

    testWidgets('a row opens its lead', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await tester.tap(_k('lr_fu_f1'));
      await tester.pumpAndSettle();
      expect(f.f.opened, ['l1']);
      expect(_k('lr_detail'), findsOneWidget);
    });

    testWidgets('a failing read shows "Try again"', (tester) async {
      final fake = _Fake();
      await _pump(tester, tab: 'followups', fake: fake);
      fake.fails = true;
      await tester.tap(_k('lr_fu_overdue'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Conversion', () {
    testWidgets('the rate, bookings, booking value and cost per booking; the funnel; the trend; conversion by source', (tester) async {
      await _pump(tester, tab: 'conversion');
      expect(_in('lr_cv_rate', '25%'), findsOneWidget);
      expect(_in('lr_cv_rate', '↑ +5 pp vs previous period'), findsOneWidget);
      expect(_in('lr_cv_bookings', '3'), findsOneWidget);
      expect(_in('lr_cv_value', '₹14,237'), findsOneWidget);
      expect(_in('lr_cv_value', '↑ +110% vs previous period'), findsOneWidget);
      expect(_in('lr_cv_cpb', '₹1,500'), findsOneWidget);
      expect(_in('lr_cv_cpb', '₹1,500 spent ÷ 1 campaign booking'), findsOneWidget);
      expect(find.textContaining('1 booking was entered by a user left out of sales totals'), findsOneWidget);
      expect(find.textContaining('1 lead is in the Converted stage without a live booking'), findsOneWidget, reason: 'the stage (4) and the bookings (3) differ, and the screen says why');
      expect(find.textContaining('Customers pay ₹16,800 including GST'), findsOneWidget);
      for (final k in ['leads', 'qualified', 'hot', 'bookings']) {
        expect(_k('lr_cv_funnel_$k'), findsOneWidget, reason: k);
      }
      expect(_k('lr_cv_trend'), findsOneWidget);
      expect(_text(tester, _k('lr_cv_src_ig_main')), '1/2 · 50%', reason: 'bookings ÷ leads');
      expect(_text(tester, _k('lr_cv_src_whatsapp')), '1/3 · 33.3%');
    });

    testWidgets('with no ad spend recorded the cost per booking is a dash and says why', (tester) async {
      await _pump(tester, tab: 'conversion', fake: _NoSpendFake());
      expect(_in('lr_cv_cpb', '—'), findsOneWidget);
      expect(_in('lr_cv_cpb', 'No ad spend recorded for these dates'), findsOneWidget);
    });

    testWidgets('empty and failing states', (tester) async {
      final fake = _Fake()..fails = true;
      await _pump(tester, tab: 'conversion', fake: fake);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Reports', () {
    testWidgets('the five report cards, the first one previewed, and the honest note about scheduled reports', (tester) async {
      final f = await _pump(tester, tab: 'reports');
      expect(kLeadReportCards.map((c) => c.$1).toList(), ['summary', 'sources', 'campaigns', 'team', 'conversion']);
      for (final c in kLeadReportCards) {
        expect(_k('lr_report_${c.$1}'), findsOneWidget, reason: c.$1);
      }
      expect(find.text('Lead Summary'), findsWidgets);
      expect(f.f.reportTypes, ['summary']);
      expect(_k('lr_report_table'), findsOneWidget);
      expect(find.text('Showing the first 10 of 12 rows — the download has them all.'), findsOneWidget);
      expect(_k('mktSavedReports_leads'), findsOneWidget, reason: 'Saved reports');
      expect(_k('mktScheduledReports_leads'), findsOneWidget, reason: 'Scheduled reports');
    });

    testWidgets('a downloaded report is kept in Saved reports — its kind, name, period and brand', (tester) async {
      final reports = FakeMarketingReports();
      final w = await _pump(tester, tab: 'reports', reports: reports);
      await tester.tap(_k('lr_report_download'));
      await tester.pumpAndSettle();
      expect(w.saved, hasLength(1));
      expect(reports.kept, [
        {'module': 'leads', 'kind': 'summary', 'name': 'Lead Summary', 'from': '2026-11-02', 'to': '2026-11-08', 'brand': 'all'},
      ]);
    });

    testWidgets('a download that fails is not kept', (tester) async {
      final reports = FakeMarketingReports();
      final f = _Fake();
      final w = await _pump(tester, tab: 'reports', reports: reports, fake: f);
      f.fails = true;
      await tester.tap(_k('lr_report_download'));
      await tester.pumpAndSettle();
      expect(w.saved, isEmpty);
      expect(reports.kept, isEmpty);
    });

    testWidgets('opening a scheduled report puts its period and brand back, picks its report and downloads it — not kept twice', (tester) async {
      final reports = FakeMarketingReports(savedList: [MarketingSavedReport.fromJson(const {'id': 'r9', 'module': 'leads', 'kind': 'monthly-conversion', 'name': 'Scheduled one', 'from': '2026-10-01', 'to': '2026-10-31', 'brand': 'kerala', 'scheduled': true, 'createdByName': 'Scheduled'})]);
      final w = await _pump(tester, tab: 'reports', reports: reports);
      await tester.tap(_k('mktSavedReportOpen_r9'));
      await tester.pumpAndSettle();
      expect(w.f.reportTypes.last, 'conversion', reason: 'the monthly conversion report');
      expect([w.f.filters.last.fromDay, w.f.filters.last.toDay, w.f.filters.last.brand], ['2026-10-01', '2026-10-31', TeamBrand.kerala]);
      expect(w.saved, hasLength(1), reason: 'downloaded again');
      expect(reports.kept, isEmpty);
    });

    testWidgets('picking a card builds that report', (tester) async {
      final f = await _pump(tester, tab: 'reports');
      for (final c in ['campaigns', 'team', 'conversion', 'sources']) {
        await tester.tap(_k('lr_report_$c'));
        await tester.pumpAndSettle();
        expect(f.f.reportTypes.last, c);
      }
      expect(find.text('Source Report'), findsWidgets);
    });

    testWidgets('Download CSV saves the whole report for the range and brand; formulas are neutralised', (tester) async {
      final f = await _pump(tester, tab: 'reports');
      await tester.tap(_k('lr_report_download'));
      await tester.pumpAndSettle();
      expect(f.saved.single.name, 'lead-report-summary-2026-11-02-to-2026-11-08.csv');
      expect(f.saved.single.rows.length, 4 + 12, reason: 'every row, not just the 10 previewed');
      expect(f.saved.single.rows[4].first, '\'=HYPERLINK("x")');
    });

    testWidgets('notes: phone numbers are left out of the lists for non-managers; a cut-off export says so', (tester) async {
      final fake = _Fake()
        ..canContact = false
        ..reportJson = _report('leads', canContact: false, truncated: true);
      await _pump(tester, tab: 'reports', fake: fake);
      expect(find.text('Phone numbers are left out — only a Marketing Manager gets them.'), findsOneWidget);
      expect(find.text('Only the first 20,000 rows are included — narrow the date range.'), findsOneWidget);
    });

    testWidgets('an empty report and a failing one', (tester) async {
      final fake = _Fake()..reportJson = {..._report('summary'), 'rows': []};
      await _pump(tester, tab: 'reports', fake: fake);
      expect(find.text('Nothing to report in this date range.'), findsOneWidget);
      final broken = _Fake()..fails = true;
      await _pump(tester, tab: 'reports', fake: broken);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('what the service asks the server for', () {
    Future<List<RequestOptions>> capture(Future<void> Function(LeadReportService s) run, {int status = 200, String body = '{}'}) async {
      final seen = <RequestOptions>[];
      await run(LeadReportService(Dio()..httpClientAdapter = _Capture(seen, status: status, body: body)));
      return seen;
    }

    final f = TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30), brand: TeamBrand.kerala);

    test('every read carries the shared range and brand', () async {
      final reqs = await capture((s) async {
        await s.overview(f);
        await s.leads(f, const LeadListQuery());
        await s.stages(f);
        await s.sources(f);
        await s.followUps(f, const FollowUpQuery());
        await s.conversion(f);
        await s.report('team', f);
      });
      expect(reqs.map((r) => r.path), [
        '/marketing/lead-report/overview',
        '/marketing/lead-report/leads',
        '/marketing/lead-report/stages',
        '/marketing/lead-report/sources',
        '/marketing/lead-report/followups',
        '/marketing/lead-report/conversion',
        '/marketing/lead-report/reports/team',
      ]);
      for (final r in reqs) {
        expect(r.method, 'GET', reason: r.path);
        expect(r.queryParameters, containsPair('from', '2026-11-01'), reason: r.path);
        expect(r.queryParameters, containsPair('to', '2026-11-30'), reason: r.path);
        expect(r.queryParameters, containsPair('brand', 'kerala'), reason: r.path);
      }
    });

    test('the list sends only the cuts that are set; the search is trimmed; a lead is read by id', () async {
      final reqs = await capture((s) async {
        await s.leads(f, const LeadListQuery(stage: 'converted', source: 'instagram', q: ' asha ', sort: 'name', dir: 'asc', page: 3));
        await s.leads(f, const LeadListQuery());
        await s.followUps(f, const FollowUpQuery(filter: 'overdue', page: 2));
        await s.followUps(f, const FollowUpQuery());
        await s.lead('abc123');
      });
      expect(reqs[0].queryParameters, containsPair('stage', 'converted'));
      expect(reqs[0].queryParameters, containsPair('source', 'instagram'));
      expect(reqs[0].queryParameters, containsPair('q', 'asha'));
      expect(reqs[0].queryParameters, containsPair('sort', 'name'));
      expect(reqs[0].queryParameters, containsPair('dir', 'asc'));
      expect(reqs[0].queryParameters, containsPair('page', 3));
      for (final k in ['stage', 'source', 'q', 'sort', 'dir']) {
        expect(reqs[1].queryParameters.containsKey(k), isFalse, reason: '"$k" is not sent when it is the default');
      }
      expect(reqs[1].queryParameters, containsPair('page', 1));
      expect(reqs[2].queryParameters, containsPair('filter', 'overdue'));
      expect(reqs[2].queryParameters, containsPair('page', 2));
      expect(reqs[3].queryParameters.containsKey('filter'), isFalse);
      expect(reqs[4].path, '/marketing/lead-report/leads/abc123');
    });

    test('a refusal or failure comes back as an error the screen can show', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 400, body: '{"message":"Choose a range of a year or less."}');
      await expectLater(LeadReportService(dio).overview(f), throwsA(isA<AppException>()));
      final dio403 = Dio()..httpClientAdapter = _Capture([], status: 403, body: '{"message":"Only the Marketing team can open this."}');
      await expectLater(LeadReportService(dio403).report('summary', f), throwsA(isA<AppException>()));
    });

    test('the Lead Report never writes: there is no write method on the service', () {
      // a read-only module: its service only has reads (compile-time: overview, leads, lead, stages, sources, followUps, conversion, report)
      final s = LeadReportService(Dio());
      expect([s.overview, s.leads, s.lead, s.stages, s.sources, s.followUps, s.conversion, s.report].length, 8);
    });
  });

  group('a phone', () {
    testWidgets('every tab fits a 390-wide screen without overflow', (tester) async {
      await _pump(tester, size: const Size(390, 2400));
      expect(tester.takeException(), isNull);
      final marker = {'leads': 'lr_leads_list', 'stages': 'lr_stages_list', 'sources': 'lr_sources_list', 'followups': 'lr_followups_list', 'conversion': 'lr_conversion_list', 'reports': 'lr_reports_list'};
      for (final t in marker.keys) {
        await tester.ensureVisible(_k('lr_tab_$t')); // the pills scroll sideways on a phone
        await tester.tap(_k('lr_tab_$t'));
        await tester.pumpAndSettle();
        expect(_k(marker[t]!), findsOneWidget, reason: '$t opened');
        expect(tester.takeException(), isNull, reason: t);
      }
    });

    testWidgets('the lead detail opens as a bottom sheet on a phone without overflow', (tester) async {
      final f = await _pump(tester, tab: 'leads', size: const Size(390, 2000));
      await tester.tap(find.text('Rehana P')); // the table scrolls sideways on a phone; the name is on screen
      await tester.pumpAndSettle();
      expect(f.f.opened, ['l1']);
      expect(_k('lr_detail'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty and a failing Overview fit a phone', (tester) async {
      await _pump(tester, size: const Size(390, 2000), fake: _Fake()..fails = true);
      expect(tester.takeException(), isNull);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Speed to lead', () {
    testWidgets('the figures in working time, who is waiting (late in red, alert sent), by salesperson and source, the slowest', (tester) async {
      final r = await _pump(tester, tab: 'speed');
      expect(find.descendant(of: _k('lr_speed_median'), matching: find.text('12 min')), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_median'), matching: find.text('Before: 1 h 35 min')), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_within'), matching: find.text('75%')), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_contacted'), matching: find.text('4 of 6')), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_waiting'), matching: find.text('1 past the target')), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_wait_w1'), matching: find.text('1 h 15 min')), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_wait_w1'), matching: find.textContaining('alert sent')), findsOneWidget);
      expect(_k('lr_speed_person_Arjun'), findsOneWidget);
      expect(_k('lr_speed_source_Paid Ads'), findsOneWidget);
      expect(find.descendant(of: _k('lr_speed_slow_s1'), matching: find.text('2 h 10 min')), findsOneWidget);
      expect(find.textContaining('09:00–21:00 IST'), findsOneWidget);
      expect(_k('lr_speed_settings'), findsNothing, reason: 'only a manager changes the target');
      expect(_k('lr_export'), findsNothing, reason: 'no export for this tab');
      await tester.tap(_k('lr_speed_scope_all'));
      await tester.pumpAndSettle();
      expect(r.f.speedScopes.last, 'all');
      expect(find.descendant(of: _k('lr_speed_contacted'), matching: find.text('4 of 9')), findsOneWidget);
    });

    testWidgets('a manager sets the target, alert and hours; a refusal is said in the dialog', (tester) async {
      final f = _Fake()..speedCanEdit = true;
      await _pump(tester, tab: 'speed', fake: f);
      await tester.tap(_k('lr_speed_settings'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('lr_speed_set_target'), '10');
      await tester.enterText(_k('lr_speed_set_start'), '25:00');
      await tester.tap(_k('lr_speed_set_save'));
      await tester.pumpAndSettle();
      expect(find.text('Working hours are HH:MM, like 09:00.'), findsOneWidget);
      await tester.enterText(_k('lr_speed_set_start'), '08:30');
      await tester.tap(_k('lr_speed_set_on'));
      await tester.tap(_k('lr_speed_set_save'));
      await tester.pumpAndSettle();
      expect(f.speedSaved.single, {'targetMinutes': 10, 'alertAfterMinutes': 30, 'dayStart': '08:30', 'dayEnd': '21:00', 'alertsOn': false});
      expect(_k('lr_speed_set_save'), findsNothing, reason: 'closed after saving');
    });

    test('working time in words; a lead\'s first contact in words', () {
      expect([workingTime(null), workingTime(8), workingTime(65), workingTime(24 * 60 + 180)], ['—', '8 min', '1 h 05 min', '1 d 3 h']);
      expect(FirstContact.fromJson(const {'state': 'contacted', 'minutes': 12, 'by': 'Arjun', 'via': 'call'}).text, 'First contact after 12 min (working time) — call by Arjun');
      expect(FirstContact.fromJson(const {'state': 'waiting', 'waitingMinutes': 40}).text, 'Waiting 40 min (working time) for a first contact');
      expect(FirstContact.fromJson(const {'state': 'unrecorded'}).text, 'Moved on with no contact recorded');
    });
  });
}
