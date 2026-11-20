import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_hub_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_campaigns_tab.dart' show defaultBrandFor;
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_reports_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/meta_import.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

import 'fakes/marketing_reports_fake.dart';

// The Campaigns hub: Overview, All Campaigns, Performance, Creatives & Ads, Budget & Spend, Leads & Conversions, Reports & Insights — the
// honest Meta card, the import from a Meta Ads Manager file, the forms (campaign, ad, a day's figures), and what the service asks the server.

// ── fixtures (the server's payloads: backend utils/marketingCampaignStats.js) ─────────────────────────────────────────────────

Map<String, dynamic> _totals({double spend = 2750, int reach = 14400, int impressions = 25500, int clicks = 535, int results = 24, int leads = 5, int qualified = 2, int hot = 1, int bookedLeads = 1, int bookings = 1, double revenue = 40000, double? ctr = 2.1, double? cpm = 107.84, double? cpl = 550, double? conversionRate = 20, double? roas = 14.55}) => {
      'spend': spend, 'reach': reach, 'impressions': impressions, 'clicks': clicks, 'results': results, 'leads': leads, 'qualified': qualified, 'hot': hot, 'bookedLeads': bookedLeads, 'bookings': bookings, 'revenue': revenue,
      'ctr': ctr, 'cpm': cpm, 'cpl': cpl, 'conversionRate': conversionRate, 'roas': roas,
    };

Map<String, dynamic> _kpis({Map<String, dynamic>? now, Map<String, dynamic>? change}) => {
      'now': now ?? _totals(),
      'before': _totals(spend: 800, reach: 7200, impressions: 4000, clicks: 80, results: 5, leads: 1, qualified: 0, hot: 0, bookedLeads: 0, bookings: 0, revenue: 0, ctr: 2, cpm: 200, cpl: 800, conversionRate: 0, roas: 0),
      'change': change ?? {'spend': 244, 'reach': 100, 'impressions': 538, 'clicks': 569, 'results': 380, 'leads': 400, 'qualified': null, 'bookings': null, 'revenue': null, 'ctr': 5, 'cpm': -46, 'cpl': -31, 'conversionRate': 20.0},
    };

List<Map<String, dynamic>> _trend({bool empty = false}) => [
      for (var i = 0; i < 7; i++)
        {
          'day': '2026-11-0${i + 1}',
          'days': 1,
          'spend': empty ? 0 : [0, 1000, 800, 700, 0, 0, 250][i],
          'reach': empty ? 0 : [0, 5000, 3000, 4000, 0, 0, 2400][i],
          'impressions': empty ? 0 : [0, 8000, 6000, 9000, 0, 0, 2500][i],
          'clicks': empty ? 0 : [0, 200, 160, 90, 0, 0, 85][i],
          'results': empty ? 0 : [0, 10, 8, 0, 0, 0, 6][i],
          'leads': empty ? 0 : [0, 1, 3, 1, 0, 0, 0][i],
          'qualified': empty ? 0 : [0, 1, 1, 0, 0, 0, 0][i],
          'bookings': empty ? 0 : [0, 1, 0, 0, 0, 0, 0][i],
          'cpl': empty ? null : [null, 1000, 266.67, 700, null, null, null][i],
        },
    ];

Map<String, dynamic> _row(String id, {String title = 'Bridal Campaign – Nov', String brand = 'kerala', String platform = 'meta', String objective = 'lead_generation', String status = 'active', double budget = 10000, double spend = 2000, int leads = 3, double? cpl = 666.67, double? ctr = 2.5, int bookings = 1, double revenue = 40000, int workMinutes = 180, String metaId = '1203001', String thumbUrl = ''}) => {
      'id': id, 'title': title, 'brand': brand, 'platform': platform, 'objective': objective, 'status': status, 'budget': budget, 'metaCampaignId': metaId,
      'spend': spend, 'reach': 10000, 'impressions': 16000, 'clicks': 400, 'results': 20, 'ctr': ctr, 'leads': leads, 'qualified': 2, 'hot': 1, 'warm': 1, 'nurture': 0, 'cold': 1, 'notRated': 0, 'bookedLeads': bookings, 'bookings': bookings, 'revenue': revenue,
      'cpl': cpl, 'conversionRate': 33.3, 'roas': 20, 'workMinutes': workMinutes, 'workEntries': 3, 'thumbUrl': thumbUrl,
    };

Map<String, dynamic> _ad(String id, {String name = 'Bridal Reel 1', String verdict = 'top', String campaign = 'Bridal Campaign – Nov', String format = 'reel', String thumbUrl = '', String creativeUrl = 'https://drive.test/reel1', int results = 10, double? costPerResult = 100, String figures = 'range', int? leads = 2, double? cpl = 500}) => {
      'id': id, 'campaignId': 'c1', 'campaign': campaign, 'name': name, 'adSetName': 'Brides 22–35', 'metaAdId': '', 'format': format, 'status': 'active', 'creativeUrl': creativeUrl, 'thumbUrl': thumbUrl, 'figures': figures,
      'impressions': 10000, 'reach': 0, 'clicks': 400, 'spend': 1000, 'results': results, 'ctr': 4, 'cpm': 100, 'costPerResult': costPerResult, 'leads': leads, 'cpl': cpl, 'verdict': verdict,
    };

Map<String, dynamic> _seg(String segment, {double spend = 600, int results = 6, double? cpr = 100, double? pct = 60}) => {'segment': segment, 'spend': spend, 'impressions': 6000, 'clicks': 60, 'results': results, 'ctr': 1, 'costPerResult': cpr, 'spendPct': pct};

Map<String, dynamic> _audiences({bool empty = false}) => empty
    ? {'hasData': false, 'age': {'dimension': '', 'rows': []}, 'gender': {'dimension': '', 'rows': []}, 'placement': {'dimension': '', 'rows': []}}
    : {
        'hasData': true,
        'age': {'dimension': 'age', 'rows': [_seg('25-34'), _seg('18-24', spend: 400, results: 0, cpr: null, pct: 40)]},
        'gender': {'dimension': 'age+gender', 'rows': [_seg('female', spend: 980, results: 9, cpr: 108.89, pct: 90.7), _seg('male', spend: 100, results: 1, pct: 9.3)]},
        'placement': {'dimension': 'placement', 'rows': [_seg('Instagram · Reels', spend: 700, results: 8, cpr: 87.5, pct: 70)]},
      };

Map<String, dynamic> _import({String id = 'i1', String source = 'csv', String fileName = 'meta-export.csv', int written = 5, int matched = 6, int unmatched = 1, List<String> names = const ['Trial Makeup'], String at = '2026-11-12T11:02:00.000Z'}) => {
      'id': id, 'at': at, 'source': source, 'byName': 'Preethi', 'fileName': fileName, 'rows': 7, 'matched': matched, 'unmatched': unmatched, 'unmatchedNames': names, 'created': 0, 'written': written, 'skipped': 0, 'from': '2026-11-02', 'to': '2026-11-04',
    };

Map<String, dynamic> _overview() => {
      'kpis': _kpis(),
      'trend': _trend(),
      'leadsByType': [{'key': 'lead_gen', 'label': 'Lead gen (Meta form)', 'leads': 3, 'pct': 60}, {'key': 'whatsapp', 'label': 'WhatsApp / messages', 'leads': 1, 'pct': 20}, {'key': 'others', 'label': 'Others', 'leads': 1, 'pct': 20}],
      'meta': {'connected': false, 'status': 'not_connected', 'lastImport': _import()},
      'counts': {'total': 5, 'planned': 0, 'active': 2, 'paused': 1, 'completed': 2},
      'campaigns': {
        'active': [_row('c1'), _row('c2', title: 'Makeup Courses', objective: 'reach', platform: 'google', budget: 0, spend: 350, leads: 1, cpl: 350, ctr: 1.5, bookings: 0, revenue: 0)],
        'paused': [_row('c3', title: 'Festive Offers', status: 'paused', objective: 'messages', platform: 'instagram', budget: 0, spend: 300, leads: 1, cpl: 300)],
        'completed': [_row('c4', title: 'Old Campaign', status: 'completed', spend: 0, leads: 0, cpl: null, ctr: null)],
      },
      'topAds': [_ad('a1', thumbUrl: 'https://drive.test/reel1.jpg'), _ad('a2', name: 'Bridal Static', verdict: 'ok', format: 'image', creativeUrl: '', results: 8, costPerResult: 137.5)],
      'audiences': _audiences(),
      'insights': [
        {'kind': 'good', 'text': 'Cost per lead is ₹550, 31% lower than the period before (₹800).'},
        {'kind': 'good', 'text': 'Bridal Campaign – Nov brought the most leads: 3 of 5 (60%).'},
        {'kind': 'info', 'text': '1 lead from Meta Ads is not tagged to a campaign, so its cost cannot be counted.'},
      ],
    };

Map<String, dynamic> _campaignsPage({int total = 12, int page = 1}) => {
      'counts': {'total': 12, 'planned': 1, 'active': 6, 'paused': 3, 'completed': 2},
      'total': total, 'page': page, 'pageSize': 4,
      'items': [_row('c1'), _row('c2', title: 'Makeup Courses', objective: 'reach', platform: 'google', budget: 0, spend: 350, leads: 1, cpl: 350, workMinutes: 0, metaId: ''), _row('c3', title: 'Festive Offers', status: 'paused', platform: '', objective: '', budget: 0, spend: 0, leads: 0, cpl: null, workMinutes: 45)],
    };

Map<String, dynamic> _campaign({String id = 'c1', double budget = 10000}) => {
      'id': id, 'title': 'Bridal Campaign – Nov', 'brand': 'kerala', 'platform': 'meta', 'channel': 'Meta', 'objective': 'lead_generation', 'status': 'active', 'startDate': '2026-10-10', 'endDate': null, 'budget': budget, 'dailyBudget': 800,
      'metaCampaignId': '1203001', 'audienceNote': 'Brides 22–35', 'notes': 'Festive push',
    };

Map<String, dynamic> _budgetRow(String id, {String title = 'Bridal Campaign – Nov', bool hasBudget = true, double budget = 10000, double spent = 2800, double? remaining = 7200, double overBy = 0, double? util = 28, double inPeriod = 2000, String status = 'active'}) => {
      'id': id, 'title': title, 'brand': 'kerala', 'status': status, 'hasBudget': hasBudget, 'budget': hasBudget ? budget : 0, 'spentToDate': spent, 'remaining': hasBudget ? remaining : null, 'overBy': overBy, 'utilisationPct': hasBudget ? util : null, 'spendInPeriod': inPeriod,
    };

Map<String, dynamic> _detail({String id = 'c1', bool noWork = false, bool noBudget = false}) => {
      'campaign': _campaign(id: id, budget: noBudget ? 0 : 10000),
      'row': _row(id),
      'kpis': _kpis(),
      'trend': _trend(),
      'days': [
        {'id': 'd1', 'day': '2026-11-02', 'spend': 1000, 'reach': 5000, 'impressions': 8000, 'clicks': 200, 'results': 10, 'source': 'csv'},
        {'id': 'd2', 'day': '2026-11-03', 'spend': 1000, 'reach': 5000, 'impressions': 8000, 'clicks': 200, 'results': 10, 'source': 'manual'},
      ],
      'budget': noBudget ? _budgetRow(id, hasBudget: false) : _budgetRow(id),
      'ads': [_ad('a1'), _ad('a2', name: 'Bridal Static', verdict: 'under', format: 'image', figures: 'lifetime', leads: null, cpl: null)],
      'work': noWork
          ? {'minutes': 0, 'entries': 0, 'members': [], 'recent': []}
          : {
              'minutes': 195,
              'entries': 3,
              'members': [{'memberId': 'm1', 'name': 'Preethi', 'minutes': 135, 'entries': 2}, {'memberId': 'm2', 'name': 'Ashique', 'minutes': 60, 'entries': 1}],
              'recent': [{'id': 'w1', 'member': 'Ashique', 'workedOn': 'Edited the reel', 'status': 'completed', 'minutes': 60, 'day': '2026-11-12'}],
            },
    };

Map<String, dynamic> _performance() => {
      'kpis': _kpis(),
      'trend': _trend(),
      'objectives': [
        {'key': 'lead_generation', 'label': 'Lead Generation', 'campaigns': 1, 'spend': 2000, 'leads': 3, 'cpl': 666.67, 'results': 20},
        {'key': 'reach', 'label': 'Reach', 'campaigns': 1, 'spend': 350, 'leads': 1, 'cpl': 350, 'results': 0},
        {'key': 'not_set', 'label': 'Not set', 'campaigns': 1, 'spend': 100, 'leads': 0, 'cpl': null, 'results': 1},
      ],
    };

Map<String, dynamic> _adsData({int total = 4, bool empty = false}) => {
      'kpis': {'total': empty ? 0 : total, 'top': 1, 'ctr': 2.37, 'cpm': 107.84, 'costPerResult': 144.74, 'spend': 2750, 'results': 19, 'leads': 3, 'cpl': 500, 'lifetimeAds': 1},
      'counts': {'all': empty ? 0 : total, 'top': 1, 'under': 1, 'needs_attention': 1},
      'total': empty ? 0 : total, 'page': 1, 'pageSize': 2,
      'items': empty
          ? []
          : [
              _ad('a1', thumbUrl: ''),
              _ad('a2', name: 'Bridal Static', verdict: 'under', format: 'image', creativeUrl: '', figures: 'lifetime', leads: null, cpl: null),
              _ad('a3', name: 'Festive Carousel', verdict: 'needs_attention', campaign: 'Festive Offers', format: 'carousel', results: 0, costPerResult: null, leads: 0, cpl: null),
            ],
    };

Map<String, dynamic> _budgetData({bool empty = false, bool over = false}) => {
      'summary': {
        'budgetedCampaigns': empty ? 0 : 2, 'unbudgetedCampaigns': 2, 'totalBudget': empty ? 0 : 15000, 'spentToDate': empty ? 0 : (over ? 16000 : 3150), 'remaining': over ? 0 : 11850, 'overBy': over ? 1000 : 0, 'utilisationPct': empty ? null : (over ? 106.7 : 21), 'remainingPct': empty ? null : (over ? 0 : 79), 'utilisationChangePts': empty ? null : 15.7,
        'spendInPeriod': 2750, 'unbudgetedSpendInPeriod': 400,
      },
      'daily': [for (var i = 0; i < 7; i++) {'day': '2026-11-0${i + 1}', 'spend': empty ? 0 : [0, 1550, 800, 700, 0, 0, 0][i]}],
      'split': empty ? {'total': 0, 'slices': []} : {'total': 2750, 'slices': [{'id': 'c1', 'label': 'Bridal Campaign – Nov', 'spend': 2000, 'pct': 72.7}, {'id': 'c2', 'label': 'Makeup Courses', 'spend': 350, 'pct': 12.7}, {'id': null, 'label': 'Others', 'spend': 400, 'pct': 14.6}]},
      'rows': empty
          ? []
          : [
              _budgetRow('c1', spent: over ? 12000 : 2800, remaining: over ? 0 : 7200, overBy: over ? 2000 : 0, util: over ? 120 : 28),
              _budgetRow('c2', title: 'Makeup Courses', budget: 5000, spent: 350, remaining: 4650, util: 7, inPeriod: 350),
              _budgetRow('c3', title: 'Festive Offers', hasBudget: false, spent: 300, inPeriod: 300, status: 'paused'),
            ],
      'hasSpend': !empty,
    };

Map<String, dynamic> _leadsData({bool empty = false}) => {
      'kpis': _kpis(now: _totals(leads: empty ? 0 : 5, qualified: empty ? 0 : 2, bookedLeads: empty ? 0 : 2, bookings: empty ? 0 : 2, conversionRate: empty ? null : 40, revenue: empty ? 0 : 40000), change: {'leads': 400, 'qualified': 100, 'bookings': null, 'revenue': null, 'conversionRate': 40.0}),
      'funnel': empty
          ? [{'key': 'leads', 'label': 'Total Leads', 'count': 0, 'pct': null}, {'key': 'qualified', 'label': 'Qualified', 'count': 0, 'pct': null}, {'key': 'booked', 'label': 'Booked', 'count': 0, 'pct': null}]
          : [{'key': 'leads', 'label': 'Total Leads', 'count': 5, 'pct': 100}, {'key': 'qualified', 'label': 'Qualified', 'count': 2, 'pct': 40}, {'key': 'booked', 'label': 'Booked', 'count': 2, 'pct': 40}],
      'quality': {'Hot': 1, 'Warm': 3, 'Nurture': 1, 'Cold': 1, 'Not rated': 1},
      'trend': _trend(empty: empty),
      'rows': empty ? [] : [_row('c1', bookings: 2), _row('c2', title: 'Makeup Courses', spend: 350, leads: 1, cpl: 350, bookings: 0, revenue: 0)],
    };

Map<String, dynamic> _reportsData({bool noImport = false}) => {
      'kpis': _kpis(),
      'cards': [
        {'type': 'campaign', 'title': 'Campaign Report', 'description': 'Performance by campaign', 'rows': 3},
        {'type': 'creative', 'title': 'Creative Report', 'description': 'Ad and creative performance (lifetime figures)', 'rows': 4},
        {'type': 'lead', 'title': 'Lead Report', 'description': 'Leads, cost per lead and lead quality', 'rows': 2},
        {'type': 'conversion', 'title': 'Conversion Report', 'description': 'Bookings and revenue by campaign', 'rows': 1},
        {'type': 'spend', 'title': 'Spend Report', 'description': 'Budget against spend', 'rows': 0},
      ],
      'insights': [{'kind': 'warn', 'text': 'Festive Offers is over its budget by ₹100.'}, {'kind': 'good', 'text': 'Cost per lead is ₹550, 31% lower than the period before (₹800).'}],
      'imports': noImport ? [] : [_import(), _import(id: 'i2', source: 'manual', fileName: '', written: 1, names: const [], unmatched: 0, at: '2026-11-11T08:00:00.000Z')],
      'meta': {'connected': false, 'status': 'not_connected', 'lastImport': noImport ? null : _import()},
      'scheduledReports': false,
    };

Map<String, dynamic> _report(String type) => {
      'type': type, 'title': '${type[0].toUpperCase()}${type.substring(1)} Report', 'columns': ['Campaign', 'Spend (INR)'], 'rows': [['Bridal Campaign – Nov', 2000], ['Makeup Courses', 350]], 'filename': 'campaign-$type-report-2026-11-01_2026-11-07.csv',
    };

Map<String, dynamic> _setup() => {'campaigns': [{'id': 'c1', 'title': 'Bridal Campaign – Nov', 'brand': 'kerala', 'status': 'active'}, {'id': 'c2', 'title': 'Makeup Courses', 'brand': 'main', 'status': 'active'}]};

Map<String, dynamic> _importGroup(String name, {String campaignId = '', String title = '', String reason = '', String metaId = ''}) => {'name': name, 'metaId': metaId, 'campaignId': campaignId, 'title': title, 'reason': reason, 'rows': 1, 'days': 1, 'spend': 100};

// ── the fake service ──────────────────────────────────────────────────────────────────────────────────────────────────────────

class _FakeHub extends MarketingCampaignHubService {
  _FakeHub() : super(Dio());
  final overviews = <TeamFilter>[];
  final campaignQueries = <HubCampaignQuery>[];
  final adQueries = <HubAdQuery>[];
  final details = <String>[];
  final reportTypes = <String>[];
  final reportFilters = <TeamFilter>[];
  final savedCampaigns = <({Map<String, dynamic> body, String? id})>[];
  final deletedCampaigns = <String>[];
  final savedAds = <({Map<String, dynamic> body, String? id})>[];
  final deletedAds = <String>[];
  final savedDays = <Map<String, dynamic>>[];
  final deletedDays = <String>[];
  final imports = <({List<Map<String, dynamic>> rows, String level, bool createMissing, String brand, bool dryRun, String fileName, String? importId})>[];
  TeamRefusal? refuse;
  Completer<void>? hold;
  bool failReads = false;
  Map<String, dynamic> overviewJson = _overview();
  Map<String, dynamic> campaignsJson = _campaignsPage();
  Map<String, dynamic> detailJson = _detail();
  Map<String, dynamic> performanceJson = _performance();
  Map<String, dynamic> adsJson = _adsData();
  Map<String, dynamic> budgetJson = _budgetData();
  Map<String, dynamic> leadsJson = _leadsData();
  Map<String, dynamic> reportsJson = _reportsData();
  Map<String, dynamic> audiencesJson = _audiences();
  Map<String, dynamic> dryRunJson = {'dryRun': true, 'rows': 2, 'skipped': 0, 'skippedRows': [], 'matched': [_importGroup('Bridal Campaign – Nov', campaignId: 'c1', title: 'Bridal Campaign – Nov')], 'unmatched': [_importGroup('Trial Makeup', reason: 'no_match')], 'created': 0, 'written': 0};
  Map<String, dynamic> importJson = {'dryRun': false, 'rows': 2, 'skipped': 0, 'skippedRows': [], 'matched': [], 'unmatched': [], 'created': 0, 'written': 2, 'importId': 'imp1', 'from': '2026-11-02', 'to': '2026-11-03'};

  Future<T> _read<T>(T Function() make) async {
    if (failReads) throw Exception('boom');
    return make();
  }

  @override
  Future<OverviewData> overview(TeamFilter f) => _read(() {
        overviews.add(f);
        return OverviewData.fromJson(overviewJson);
      });

  @override
  Future<HubCampaignPage> campaigns(TeamFilter f, HubCampaignQuery q) => _read(() {
        campaignQueries.add(q);
        return HubCampaignPage.fromJson(campaignsJson);
      });

  @override
  Future<HubCampaignDetail> campaign(TeamFilter f, String id) => _read(() {
        details.add(id);
        return HubCampaignDetail.fromJson(detailJson);
      });

  @override
  Future<HubPerformance> performance(TeamFilter f) => _read(() => HubPerformance.fromJson(performanceJson));

  @override
  Future<AdsData> ads(TeamFilter f, HubAdQuery q) => _read(() {
        adQueries.add(q);
        return AdsData.fromJson(adsJson);
      });

  @override
  Future<HubAudiences> audiences(TeamFilter f) => _read(() => HubAudiences.fromJson(audiencesJson));

  @override
  Future<BudgetData> budget(TeamFilter f) => _read(() => BudgetData.fromJson(budgetJson));
  @override
  Future<LeadsData> leads(TeamFilter f) => _read(() => LeadsData.fromJson(leadsJson));
  @override
  Future<ReportsData> reports(TeamFilter f) => _read(() => ReportsData.fromJson(reportsJson));

  @override
  Future<ReportTable> report(TeamFilter f, String type) async {
    reportTypes.add(type);
    reportFilters.add(f);
    return ReportTable.fromJson(_report(type));
  }

  @override
  Future<HubSetup> setup() async => HubSetup.fromJson(_setup());

  Future<void> _gate() async {
    if (hold != null) await hold!.future;
    if (refuse != null) throw refuse!;
  }

  @override
  Future<HubCampaign> saveCampaign(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    savedCampaigns.add((body: body, id: id));
    return HubCampaign.fromJson({..._campaign(), ...body, 'id': id ?? 'new'});
  }

  @override
  Future<void> deleteCampaign(String id) async {
    await _gate();
    deletedCampaigns.add(id);
  }

  @override
  Future<HubAdRow> saveAd(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    savedAds.add((body: body, id: id));
    return HubAdRow.fromJson(_ad(id ?? 'new'));
  }

  @override
  Future<void> deleteAd(String id) async {
    await _gate();
    deletedAds.add(id);
  }

  @override
  Future<DayRecord> saveDay(Map<String, dynamic> body) async {
    await _gate();
    savedDays.add(body);
    return DayRecord.fromJson({'id': 'dn', 'day': body['day'], ...body});
  }

  @override
  Future<void> deleteDay(String id) async {
    await _gate();
    deletedDays.add(id);
  }

  @override
  Future<HubImportReport> importRows(List<Map<String, dynamic>> rows, {String level = 'campaign', bool createMissing = false, String brand = 'kerala', bool dryRun = false, String fileName = '', String? importId}) async {
    if (dryRun && failReads) throw Exception('boom');
    imports.add((rows: rows, level: level, createMissing: createMissing, brand: brand, dryRun: dryRun, fileName: fileName, importId: importId));
    if (!dryRun) await _gate();
    return HubImportReport.fromJson(dryRun ? dryRunJson : importJson);
  }
}

/// A hub whose reports cannot be built (an export that fails).
class _FailingReport extends _FakeHub {
  @override
  Future<ReportTable> report(TeamFilter f, String type) async => throw Exception('boom');
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

typedef _Saved = List<({String name, List<List<Object?>> rows})>;

Future<({_FakeHub hub, _Saved saved})> _pump(WidgetTester tester, {String tab = 'overview', _FakeHub? fake, Size size = const Size(1280, 2200), String? csv, String csvName = 'meta.csv', FakeMarketingReports? reports}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final hub = fake ?? _FakeHub();
  final saved = <({String name, List<List<Object?>> rows})>[];
  final overrides = <Override>[
    marketingCampaignHubServiceProvider.overrideWithValue(hub),
    marketingTeamServiceProvider.overrideWithValue(_NoTeam()),
    hubCsvSaverProvider.overrideWithValue((name, rows) async => saved.add((name: name, rows: rows))),
    hubFilePickerProvider.overrideWithValue(() async => csv == null ? null : (name: csvName, bytes: Uint8List.fromList(utf8.encode(csv)))),
    marketingReportsServiceProvider.overrideWithValue(reports ?? FakeMarketingReports()),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: CampaignHubScreen(initialTab: tab)))));
  await tester.pumpAndSettle();
  return (hub: hub, saved: saved);
}

Finder _k(String key) => find.byKey(Key(key));
String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;
Finder _in(String key, String text) => find.descendant(of: _k(key), matching: find.text(text));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
}

/// Tap a wide table row near its left edge: on a phone the row's middle is scrolled out of view, as it would be for a thumb.
Future<void> _tapRow(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await tester.tapAt(tester.getTopLeft(_k(key)) + const Offset(24, 12));
  await tester.pumpAndSettle();
}

/// Open a dropdown pill by its key and pick an entry by its label.
Future<void> _pick(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(_k(key));
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

// a Meta Ads Manager export, day by day
const _csv = 'Day,Campaign name,Amount spent (INR),Reach,Impressions,Link clicks,Results\n'
    '2026-11-02,Bridal Campaign – Nov,"1,000.50",5000,8000,200,10\n'
    '2026-11-03,Bridal Campaign – Nov,500,2000,3000,60,4\n'
    '2026-11-03,Trial Makeup,100,500,1000,10,1\n';

void main() {
  group('how the payloads read', () {
    test('a KPI block reads the period, the one before and each change; a missing part is empty', () {
      final k = HubKpis.fromJson(_kpis());
      expect(k.now.spend, 2750);
      expect(k.now.cpl, 550);
      expect(k.before.spend, 800);
      expect(k.changeOf('spend'), 244);
      expect(k.changeOf('cpl'), -31);
      expect(k.changeOf('revenue'), isNull, reason: 'nothing before to compare with');
      expect(k.changeOf('nonsense'), isNull);
      final empty = HubKpis.fromJson(const {});
      expect(empty.now.leads, 0);
      expect(empty.now.cpl, isNull);
      expect(empty.change, isEmpty);
    });

    test('the overview reads campaigns by status, ads, insights and the honest Meta card', () {
      final o = OverviewData.fromJson(_overview());
      expect(o.counts.active, 2);
      expect(o.rowsFor('active').length, 2);
      expect(o.rowsFor('paused').single.title, 'Festive Offers');
      expect(o.rowsFor('completed').single.status, 'completed');
      expect(o.rowsFor('anything else'), o.active, reason: 'an unknown status falls back to Active');
      expect(o.topAds.first.verdict, 'top');
      expect(o.insights.first.kind, 'good');
      expect(o.leadsByType.first.pct, 60);
      expect(o.meta.connected, isFalse);
      expect(o.meta.lastImport!.source, 'csv');
      expect(o.meta.lastImport!.unmatchedNames, ['Trial Makeup']);
      final none = OverviewData.fromJson(const {});
      expect(none.meta.connected, isFalse);
      expect(none.meta.lastImport, isNull);
      expect(none.trend, isEmpty);
      expect(none.rowsFor('active'), isEmpty);
    });

    test('a campaign row reads its figures, "no budget" and optional parts', () {
      final r = HubCampaignRow.fromJson(_row('c1'));
      expect([r.spend, r.leads, r.cpl, r.bookings, r.revenue, r.workMinutes], [2000, 3, 666.67, 1, 40000, 180]);
      expect(r.hasBudget, isTrue);
      expect(HubCampaignRow.fromJson(_row('c2', budget: 0)).hasBudget, isFalse);
      final bare = HubCampaignRow.fromJson(const {'id': 'x', 'title': 'x'});
      expect(bare.brand, 'main');
      expect(bare.status, 'active');
      expect(bare.cpl, isNull);
      expect(bare.ctr, isNull);
      expect(bare.thumbUrl, '');
    });

    test('a campaign detail reads days, budget, ads and the work members logged', () {
      final d = HubCampaignDetail.fromJson(_detail());
      expect(d.campaign.startDate, '2026-10-10');
      expect(d.campaign.endDate, isNull);
      expect(d.campaign.budget, 10000);
      expect(d.days.map((x) => x.source), ['csv', 'manual']);
      expect(d.budget!.remaining, 7200);
      expect(d.ads.length, 2);
      expect(d.work.minutes, 195);
      expect(d.work.members.first.name, 'Preethi');
      expect(d.work.recent.single.workedOn, 'Edited the reel');
      expect(HubCampaignDetail.fromJson({'campaign': {'id': 'x', 'title': 'x'}}).work.entries, 0);
    });

    test('budget, ads, leads, reports and an import answer read their parts', () {
      final b = BudgetData.fromJson(_budgetData());
      expect(b.summary.totalBudget, 15000);
      expect(b.summary.utilisationChangePts, 15.7);
      expect(b.rows.firstWhere((r) => r.id == 'c3').hasBudget, isFalse);
      expect(b.rows.firstWhere((r) => r.id == 'c3').remaining, isNull);
      expect(b.split.last.id, isNull, reason: '"Others" is not a campaign');
      expect(b.splitTotal, 2750);
      final a = AdsData.fromJson(_adsData());
      expect(a.countOf('needs_attention'), 1);
      expect(a.countOf('weird'), 0);
      expect(a.items.last.costPerResult, isNull);
      final l = LeadsData.fromJson(_leadsData());
      expect(l.funnel.map((s) => s.count), [5, 2, 2]);
      expect(l.quality['Hot'], 1);
      final r = ReportsData.fromJson(_reportsData());
      expect(r.cards.length, 5);
      expect(r.scheduledReports, isFalse);
      final t = ReportTable.fromJson(_report('campaign'));
      expect(t.rows.first, ['Bridal Campaign – Nov', 2000]);
      expect(ReportTable.fromJson(const {'type': 'x'}).filename, 'report.csv');
      final imp = HubImportReport.fromJson({'dryRun': true, 'matched': [_importGroup('A', campaignId: 'c1', title: 'A')], 'unmatched': [_importGroup('B', reason: 'ambiguous')], 'skippedRows': [{'index': 3, 'reason': 'No campaign name.'}], 'skipped': 1});
      expect(imp.dryRun, isTrue);
      expect(imp.matched.single.campaignId, 'c1');
      expect(imp.unmatched.single.reason, 'ambiguous');
      expect(imp.skippedRows.single.index, 3);
      expect(HubSetup.fromJson(_setup()).campaigns.length, 2);
    });

    test('labels and lists: the keys are the server\'s, an unknown key reads as itself', () {
      expect(hubStatusLabel('paused'), 'Paused');
      expect(hubObjectiveLabel('lead_generation'), 'Lead Generation');
      expect(hubObjectiveLabel(''), 'Not set');
      expect(hubObjectiveLabel('not_set'), 'Not set');
      expect(hubPlatformLabel('youtube'), 'YouTube');
      expect(hubPlatformLabel(''), 'Not set');
      expect(adFormatLabel('carousel'), 'Carousel');
      expect(adVerdictLabel('needs_attention'), 'Needs attention');
      expect(adVerdictLabel('mystery'), 'mystery');
      expect(kHubObjectives.map((o) => o.$1), ['lead_generation', 'messages', 'engagement', 'reach', 'traffic', 'conversions', 'other']);
      expect(kHubStatuses.map((s) => s.$1), ['planned', 'active', 'paused', 'completed']);
    });

    test('query objects are compared by their parts', () {
      expect(const HubCampaignQuery(status: 'paused') == const HubCampaignQuery(status: 'paused'), isTrue);
      expect(const HubCampaignQuery(status: 'paused') == const HubCampaignQuery(), isFalse);
      expect(const HubCampaignQuery(page: 2) == const HubCampaignQuery(), isFalse);
      expect(const HubCampaignQuery(q: 'a').hashCode == const HubCampaignQuery(q: 'a').hashCode, isTrue);
      expect(const HubAdQuery(filter: 'top') == const HubAdQuery(), isFalse);
      expect(const HubAdQuery(campaignId: 'c1') == const HubAdQuery(), isFalse);
      expect(const HubAdQuery().copyWith(campaignId: 'c1').copyWith(clearCampaign: true).campaignId, isNull);
    });
  });

  group('how figures read', () {
    test('rupees: whole above a thousand with Indian grouping, two decimals below, compact for lakhs and crores, a dash for nothing', () {
      expect(hubInr(null), '—');
      expect(hubInr(0), '₹0');
      expect(hubInr(84.93), '₹84.93');
      expect(hubInr(550), '₹550');
      expect(hubInr(1234.5), '₹1,235');
      expect(hubInr(145000), '₹1,45,000');
      expect(hubInr(145000, compact: true), '₹1.45L');
      expect(hubInr(99999, compact: true), '₹99,999');
      expect(hubInr(25000000, compact: true), '₹2.5Cr');
      expect(hubInr(-1500), '-₹1,500');
    });

    test('counts, percentages, hours and days', () {
      expect(hubCount(468320), '4,68,320');
      expect(hubCount(null), '—');
      expect(hubCompact(94320), '94,320');
      expect(hubCompact(468320), '4.68L');
      expect(hubPct(3.62), '3.62%');
      expect(hubPct(20), '20%');
      expect(hubPct(33.3, digits: 1), '33.3%');
      expect(hubPct(null), '—');
      expect(hubHours(0), '0m');
      expect(hubHours(45), '45m');
      expect(hubHours(180), '3h');
      expect(hubHours(195), '3h 15m');
      expect(hubDay('2026-11-08'), '8 Nov 2026');
      expect(hubDay('nonsense'), 'nonsense');
    });

    test('change lines: up is green, down is red; for a cost, down is the good direction; points; nothing to compare with is nothing', () {
      expect(hubDelta(null), isNull);
      expect(hubDelta(0)!.text, 'No change');
      expect(hubDelta(0)!.good, isNull);
      expect(hubDelta(12.4)!.text, '↑ +12% vs last period');
      expect(hubDelta(12.4)!.good, isTrue);
      expect(hubDelta(-8)!.text, '↓ −8% vs last period');
      expect(hubDelta(-8)!.good, isFalse);
      expect(hubDelta(-29, lowerIsBetter: true)!.good, isTrue);
      expect(hubDelta(29, lowerIsBetter: true)!.good, isFalse);
      expect(hubDelta(15.7, points: true)!.text, '↑ +15.7 pts vs last period');
    });
  });

  group('the Campaigns screen', () {
    testWidgets('has the seven tabs the sidebar links to, in order, and the New Campaign button', (tester) async {
      await _pump(tester);
      expect(kHubTabs.map((t) => t.$1).toList(), ['overview', 'campaigns', 'performance', 'creatives', 'budget', 'leads', 'reports']);
      expect(kHubTabs.map((t) => t.$2).toList(), ['Overview', 'All Campaigns', 'Performance', 'Creatives & Ads', 'Budget & Spend', 'Leads & Conversions', 'Reports & Insights']);
      for (final t in kHubTabs) {
        expect(_k('hub_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect(_k('hub_new_campaign'), findsOneWidget);
      expect(tester.widget<Text>(_k('mkt_title')).textSpan!.toPlainText(), 'Campaigns  ›  Overview');
      expect(_k('team_filter_range'), findsOneWidget, reason: 'the shared date range');
      expect(_k('team_brand_pill'), findsOneWidget, reason: 'and brand filters');
    });

    testWidgets('a tab can be opened from a link (?tab=…); an unknown tab opens the Overview', (tester) async {
      await _pump(tester, tab: 'budget');
      expect(_k('hub_budget_list'), findsOneWidget);
      await _pump(tester, tab: 'nonsense');
      expect(_k('hub_overview_list'), findsOneWidget);
    });

    testWidgets('every tab opens from its pill', (tester) async {
      await _pump(tester);
      for (final e in {'campaigns': 'hub_campaigns_list', 'performance': 'hub_performance_list', 'creatives': 'hub_ads_list', 'budget': 'hub_budget_list', 'leads': 'hub_leads_list', 'reports': 'hub_reports_list', 'overview': 'hub_overview_list'}.entries) {
        await _tap(tester, 'hub_tab_${e.key}');
        expect(_k(e.value), findsOneWidget, reason: e.key);
      }
    });

    testWidgets('the shared filters reach every read: changing the brand reloads the open tab with it', (tester) async {
      final f = await _pump(tester);
      expect(f.hub.overviews.last.brand, TeamBrand.all);
      await _pick(tester, 'team_brand_pill', 'Kerala');
      expect(f.hub.overviews.last.brand, TeamBrand.kerala);
    });

    testWidgets('New Campaign opens the campaign form, in the brand being looked at', (tester) async {
      await _pump(tester);
      await _pick(tester, 'team_brand_pill', 'Kerala');
      await _tap(tester, 'hub_new_campaign');
      expect(_k('cmp_title'), findsOneWidget);
      expect(find.text('New campaign'), findsOneWidget);
      expect(tester.widget<DropdownButtonFormField<String>>(_k('cmp_brand')).initialValue, 'kerala');
    });
  });

  group('Overview', () {
    testWidgets('the six KPIs, each with its change on the period before (a cost going down is green)', (tester) async {
      await _pump(tester);
      expect(_in('ov_kpi_spend', '₹2,750'), findsOneWidget);
      expect(_in('ov_kpi_spend', '↑ +244% vs last period'), findsOneWidget);
      expect(_in('ov_kpi_reach', '14,400'), findsOneWidget);
      expect(_in('ov_kpi_impr', '25,500'), findsOneWidget);
      expect(_in('ov_kpi_impr', '↑ +538% vs last period'), findsOneWidget);
      expect(_in('ov_kpi_leads', '5'), findsOneWidget);
      expect(_in('ov_kpi_cpl', '₹550'), findsOneWidget);
      expect(_in('ov_kpi_cpl', '↓ −31% vs last period'), findsOneWidget);
      expect(_in('ov_kpi_ctr', '2.1%'), findsOneWidget);
      final up = tester.widget<Text>(find.descendant(of: _k('ov_kpi_impr'), matching: find.text('↑ +538% vs last period')));
      final down = tester.widget<Text>(find.descendant(of: _k('ov_kpi_cpl'), matching: find.text('↓ −31% vs last period')));
      final spend = tester.widget<Text>(find.descendant(of: _k('ov_kpi_spend'), matching: find.text('↑ +244% vs last period')));
      expect(up.style!.color, down.style!.color, reason: 'more impressions and a lower cost per lead are both good (green)');
      expect(spend.style!.color, isNot(up.style!.color), reason: 'more spend is neither good nor bad');
    });

    testWidgets('the Meta card is HONEST: "Not connected", when figures were last imported and how, and the import button — never "Connected"', (tester) async {
      await _pump(tester);
      expect(_in('hub_meta_status', 'Not connected'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      final at = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse('2026-11-12T11:02:00.000Z').toLocal());
      expect(_text(tester, _k('hub_meta_last_import')), 'Last import: $at (file import)');
      expect(_k('hub_import_button'), findsOneWidget);
      expect(find.textContaining('no live Meta sync', findRichText: true), findsOneWidget);
    });

    testWidgets('before any import it says "No import yet"; a day typed by hand is called that', (tester) async {
      final f = _FakeHub()..overviewJson = {..._overview(), 'meta': {'connected': false, 'lastImport': null}};
      await _pump(tester, fake: f);
      expect(_text(tester, _k('hub_meta_last_import')), 'No import yet');
      expect(find.text('Not connected'), findsOneWidget);
      final g = _FakeHub()..overviewJson = {..._overview(), 'meta': {'connected': false, 'lastImport': _import(source: 'manual')}};
      await _pump(tester, fake: g);
      expect(find.textContaining('(typed by hand)'), findsOneWidget);
    });

    testWidgets('the trend chart switches between Spend, Leads and CPL; a period with nothing says why', (tester) async {
      await _pump(tester);
      HubSeries drawn() => tester.widget<HubChart>(find.byType(HubChart)).series.single;
      expect(_k('ov_trend_chart_spend'), findsOneWidget);
      expect([drawn().label, drawn().bars, drawn().values], ['Spend (₹)', true, [0, 1000, 800, 700, 0, 0, 250]]);
      await _tap(tester, 'ov_trend_leads');
      expect(_k('ov_trend_chart_leads'), findsOneWidget);
      expect(_k('ov_trend_chart_spend'), findsNothing);
      expect([drawn().label, drawn().bars, drawn().values], ['Leads', true, [0, 1, 3, 1, 0, 0, 0]]);
      await _tap(tester, 'ov_trend_cpl');
      expect(_k('ov_trend_chart_cpl'), findsOneWidget);
      expect([drawn().label, drawn().bars, drawn().values], ['Cost per lead (₹)', false, [null, 1000, 266.67, 700, null, null, null]], reason: 'a day with no leads is a gap, not a ₹0 cost');
      final f = _FakeHub()..overviewJson = {..._overview(), 'trend': _trend(empty: true)};
      await _pump(tester, fake: f);
      expect(find.textContaining('No ad spend in this period'), findsOneWidget);
      await _tap(tester, 'ov_trend_leads');
      expect(find.textContaining('No leads are tagged to a campaign'), findsOneWidget);
      await _tap(tester, 'ov_trend_cpl');
      expect(find.textContaining('Cost per lead needs both spend and leads'), findsOneWidget);
    });

    testWidgets('leads by campaign type: the donut total and each slice with its share', (tester) async {
      await _pump(tester);
      expect(_text(tester, _k('ov_type_total')), '5');
      expect(find.descendant(of: find.byType(MktDonut), matching: find.text('Lead gen (Meta form)')), findsOneWidget, reason: 'the server\'s campaign types and labels');
      expect(find.text('60% (3)'), findsOneWidget);
      expect(find.text('20% (1)'), findsNWidgets(2));
      final f = _FakeHub()..overviewJson = {..._overview(), 'leadsByType': []};
      await _pump(tester, fake: f);
      expect(find.text('No campaign leads in this period.'), findsOneWidget);
    });

    testWidgets('Active Campaigns: the chips carry the counts and switch the table; a row opens the campaign', (tester) async {
      final f = await _pump(tester);
      expect(find.text('Active Campaigns (2)'), findsOneWidget);
      expect(_in('ov_status_active', '2'), findsOneWidget);
      expect(_in('ov_status_paused', '1'), findsOneWidget);
      expect(_in('ov_status_completed', '2'), findsOneWidget);
      expect(_k('ov_row_c1'), findsOneWidget);
      expect(_k('ov_row_c2'), findsOneWidget);
      expect(_k('ov_row_c3'), findsNothing);
      expect(find.descendant(of: _k('ov_row_c1'), matching: find.text('₹2,000')), findsOneWidget);
      expect(find.descendant(of: _k('ov_row_c1'), matching: find.text('₹666.67')), findsOneWidget);
      expect(find.descendant(of: _k('ov_row_c1'), matching: find.text('2.5%')), findsOneWidget);
      expect(find.descendant(of: _k('ov_row_c1'), matching: find.text('Lead Generation')), findsOneWidget);
      expect(find.descendant(of: _k('ov_row_c2'), matching: find.text('—')), findsNothing, reason: 'a campaign with figures shows them');
      await _tap(tester, 'ov_status_paused');
      expect(_k('ov_row_c3'), findsOneWidget);
      expect(_k('ov_row_c1'), findsNothing);
      await _tap(tester, 'ov_status_completed');
      expect(find.descendant(of: _k('ov_row_c4'), matching: find.text('—')), findsWidgets, reason: 'no cost per lead, no CTR: a dash, not a made-up number');
      await _tap(tester, 'ov_status_active');
      await _tap(tester, 'ov_row_c1');
      expect(f.hub.details, ['c1']);
      expect(_k('det_title'), findsOneWidget);
    });

    testWidgets('View All goes to All Campaigns and to Creatives & Ads', (tester) async {
      await _pump(tester);
      await _tap(tester, 'ov_view_all_campaigns');
      expect(_k('hub_campaigns_list'), findsOneWidget);
      await _tap(tester, 'hub_tab_overview');
      await _tap(tester, 'ov_view_all_ads');
      expect(_k('hub_ads_list'), findsOneWidget);
    });

    testWidgets('Creative Performance shows the best ads; no ads says how to add one', (tester) async {
      await _pump(tester);
      expect(find.text('Top Performing Creatives'), findsOneWidget);
      expect(_k('ov_ad_a1'), findsOneWidget);
      expect(find.descendant(of: _k('ov_ad_a1'), matching: find.text('Bridal Reel 1')), findsOneWidget);
      expect(find.descendant(of: _k('ov_ad_a1'), matching: find.text('10 results · CTR 4%')), findsOneWidget);
      expect(find.descendant(of: _k('ov_ad_a1'), matching: find.text('Cost/result ₹100')), findsOneWidget);
      final f = _FakeHub()..overviewJson = {..._overview(), 'topAds': []};
      await _pump(tester, fake: f);
      expect(find.textContaining('No ads yet'), findsOneWidget);
      await _tap(tester, 'ov_add_ad');
      expect(_k('ad_name'), findsOneWidget);
    });

    testWidgets('an ad without a creative link opens its form (the card never pretends)', (tester) async {
      await _pump(tester);
      await _tap(tester, 'ov_ad_a2');
      expect(_k('ad_name'), findsOneWidget);
      expect(find.text('Edit ad'), findsOneWidget);
    });

    testWidgets('insights: the plain-language lines the data supports; none says so', (tester) async {
      await _pump(tester);
      expect(find.text('Campaign Insights & Actions'), findsOneWidget);
      expect(find.text('Cost per lead is ₹550, 31% lower than the period before (₹800).'), findsOneWidget);
      expect(find.text('1 lead from Meta Ads is not tagged to a campaign, so its cost cannot be counted.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.info_outline_rounded), findsWidgets);
      final f = _FakeHub()..overviewJson = {..._overview(), 'insights': []};
      await _pump(tester, fake: f);
      expect(find.text('Nothing to point out for this period.'), findsOneWidget);
    });

    testWidgets('a failing read says so with Try again, and Try again reads again', (tester) async {
      final f = _FakeHub()..failReads = true;
      await _pump(tester, fake: f);
      expect(find.text('Try again'), findsOneWidget);
      f.failReads = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_k('ov_kpi_spend'), findsOneWidget);
    });
  });

  group('All Campaigns', () {
    testWidgets('the strip counts campaigns by status; the table shows every column, "No budget set" and logged hours', (tester) async {
      await _pump(tester, tab: 'campaigns');
      expect(_in('cp_kpi_total', '12'), findsOneWidget);
      expect(_in('cp_kpi_total', '1 planned'), findsOneWidget);
      expect(_in('cp_kpi_active', '6'), findsOneWidget);
      expect(_in('cp_kpi_paused', '3'), findsOneWidget);
      expect(_in('cp_kpi_completed', '2'), findsOneWidget);
      expect(_k('cp_row_c1'), findsOneWidget);
      expect(find.descendant(of: _k('cp_row_c1'), matching: find.text('Bridal Campaign – Nov')), findsOneWidget);
      expect(find.descendant(of: _k('cp_row_c1'), matching: find.text('Kerala · Meta 1203001')), findsOneWidget);
      expect(find.descendant(of: _k('cp_row_c1'), matching: find.text('Lead Generation')), findsOneWidget);
      expect(find.descendant(of: _k('cp_row_c1'), matching: find.text('₹10,000')), findsOneWidget);
      expect(find.descendant(of: _k('cp_row_c1'), matching: find.text('3h')), findsOneWidget);
      expect(_k('cp_no_budget_c2'), findsOneWidget);
      expect(_text(tester, _k('cp_no_budget_c2')), 'No budget set');
      expect(_k('cp_no_budget_c1'), findsNothing);
      expect(find.descendant(of: _k('cp_row_c3'), matching: find.text('Paused')), findsOneWidget);
      expect(find.descendant(of: _k('cp_row_c3'), matching: find.text('45m')), findsOneWidget);
      expect(find.text('Showing 1–3 of 12'), findsOneWidget);
    });

    testWidgets('search and each filter ask the server for exactly that, and go back to page 1', (tester) async {
      final f = await _pump(tester, tab: 'campaigns');
      await tester.enterText(_k('cp_search'), 'festive');
      await tester.pumpAndSettle();
      expect(f.hub.campaignQueries.last.q, 'festive');
      await _pick(tester, 'cp_status', 'Paused');
      expect(f.hub.campaignQueries.last.status, 'paused');
      expect(f.hub.campaignQueries.last.q, 'festive', reason: 'filters add up');
      await _pick(tester, 'cp_platform', 'Google');
      expect(f.hub.campaignQueries.last.platform, 'google');
      await _pick(tester, 'cp_objective', 'Messages');
      expect(f.hub.campaignQueries.last.objective, 'messages');
      expect(f.hub.campaignQueries.last.status, 'paused');
      await _pick(tester, 'cp_status', 'All Status');
      expect(f.hub.campaignQueries.last.status, 'all');
    });

    testWidgets('paging: next asks for page 2; a filter after that starts over at page 1', (tester) async {
      final f = await _pump(tester, tab: 'campaigns');
      expect(tester.widget<IconButton>(_k('cp_prev')).onPressed, isNull);
      expect(tester.widget<IconButton>(_k('cp_next')).onPressed, isNotNull);
      await _tap(tester, 'cp_next');
      expect(f.hub.campaignQueries.last.page, 2);
      await _pick(tester, 'cp_status', 'Active');
      expect(f.hub.campaignQueries.last.page, 1);
      expect(f.hub.campaignQueries.last.status, 'active');
    });

    testWidgets('a row opens the campaign\'s page; the inline + New Campaign opens the form', (tester) async {
      final f = await _pump(tester, tab: 'campaigns');
      await _tap(tester, 'cp_row_c3');
      expect(f.hub.details, ['c3']);
      await _tap(tester, 'det_close');
      await _tap(tester, 'cp_new_inline');
      expect(_k('cmp_title'), findsOneWidget);
    });

    testWidgets('no campaigns says how to start; no match says so; a failing read has Try again', (tester) async {
      final none = _FakeHub()..campaignsJson = {'counts': {}, 'total': 0, 'items': []};
      await _pump(tester, tab: 'campaigns', fake: none);
      expect(find.textContaining('No campaigns yet'), findsOneWidget);
      final some = _FakeHub()..campaignsJson = {..._campaignsPage(), 'total': 0, 'items': []};
      await _pump(tester, tab: 'campaigns', fake: some);
      expect(find.text('No campaign matches these filters.'), findsOneWidget);
      await _pump(tester, tab: 'campaigns', fake: _FakeHub()..failReads = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('a campaign\'s page', () {
    Future<_FakeHub> open(WidgetTester tester, {_FakeHub? fake}) async {
      final f = await _pump(tester, tab: 'campaigns', fake: fake);
      await _tap(tester, 'cp_row_c1');
      return f.hub;
    }

    testWidgets('its title, status, brand, Meta ID, budget, figures, daily records, ads and the work members logged', (tester) async {
      await open(tester);
      expect(_text(tester, _k('det_title')), 'Bridal Campaign – Nov');
      expect(_text(tester, _k('det_meta_line')), contains('Meta ID 1203001'));
      expect(_text(tester, _k('det_meta_line')), contains('Brides 22–35'));
      expect(_in('det_kpi_spend', '₹2,750'), findsOneWidget);
      expect(_in('det_kpi_reach', '14,400'), findsOneWidget);
      expect(_in('det_kpi_leads', '5'), findsOneWidget);
      expect(_in('det_kpi_cpl', '₹550'), findsOneWidget);
      expect(_in('det_kpi_revenue', '₹40,000'), findsOneWidget);
      expect(_text(tester, _k('det_budget_text')), '₹2,800 spent of ₹10,000 · ₹7,200 left');
      expect(_k('det_day_d1'), findsOneWidget);
      expect(find.descendant(of: _k('det_day_d1'), matching: find.text('Imported')), findsOneWidget);
      expect(find.descendant(of: _k('det_day_d2'), matching: find.text('Typed')), findsOneWidget);
      expect(_k('det_ad_a1'), findsOneWidget);
      expect(find.descendant(of: _k('det_ad_a2'), matching: find.text('Underperforming')), findsOneWidget);
      expect(_text(tester, _k('det_work_total')), '3h 15m over 3 entries');
      expect(_k('det_work_member_m1'), findsOneWidget);
      expect(find.descendant(of: _k('det_work_member_m1'), matching: find.text('Preethi · 2h 15m')), findsOneWidget);
      expect(find.descendant(of: _k('det_work_entry_w1'), matching: find.text('Ashique: Edited the reel')), findsOneWidget);
    });

    testWidgets('no budget says "No budget set"; no logged work says how it gets here', (tester) async {
      await open(tester, fake: _FakeHub()..detailJson = _detail(noWork: true, noBudget: true));
      expect(_text(tester, _k('det_budget_text')), 'No budget set');
      expect(find.textContaining('Nobody has logged work against this campaign'), findsOneWidget);
    });

    testWidgets('Edit opens the form with the campaign\'s own values', (tester) async {
      await open(tester);
      await _tap(tester, 'det_edit');
      expect(find.text('Edit campaign'), findsOneWidget);
      expect(tester.widget<TextField>(_k('cmp_title')).controller!.text, 'Bridal Campaign – Nov');
      expect(tester.widget<TextField>(_k('cmp_budget')).controller!.text, '10000');
      expect(tester.widget<TextField>(_k('cmp_meta_id')).controller!.text, '1203001');
    });

    testWidgets('Delete asks first and deletes only on confirm', (tester) async {
      final f = await open(tester);
      await _tap(tester, 'det_delete');
      expect(find.text('Delete this campaign?'), findsOneWidget);
      await _tap(tester, 'det_delete_no');
      expect(f.deletedCampaigns, isEmpty);
      await _tap(tester, 'det_delete');
      await _tap(tester, 'det_delete_yes');
      expect(f.deletedCampaigns, ['c1']);
      expect(_k('det_title'), findsNothing, reason: 'the page closes');
    });

    testWidgets('a refusal (it has leads or logged work) is explained in the page and the campaign stays', (tester) async {
      final f = _FakeHub()..refuse = const TeamRefusal('This campaign has 4 leads and 3 logged entries attached. Mark it Completed instead, so the record stays.', status: 409);
      await open(tester, fake: f);
      await _tap(tester, 'det_delete');
      await _tap(tester, 'det_delete_yes');
      expect(_text(tester, _k('det_error')), contains('Mark it Completed instead'));
      expect(_k('det_title'), findsOneWidget);
    });

    testWidgets('a day can be removed after asking; Type a day\'s figures opens the day form for this campaign', (tester) async {
      final f = await open(tester);
      await _tap(tester, 'det_day_remove_d1');
      expect(find.text('Remove this day?'), findsOneWidget);
      await _tap(tester, 'det_day_delete_no');
      expect(f.deletedDays, isEmpty);
      await _tap(tester, 'det_day_remove_d1');
      await _tap(tester, 'det_day_delete_yes');
      expect(f.deletedDays, ['d1']);
      await _tap(tester, 'det_add_day');
      expect(_k('day_spend'), findsOneWidget);
      expect(tester.widget<DropdownButtonFormField<String>>(_k('day_campaign')).initialValue, 'c1');
    });

    testWidgets('a day can be changed: the form opens with its figures', (tester) async {
      await open(tester);
      await _tap(tester, 'det_day_edit_d2');
      expect(find.text('Change this day'), findsOneWidget);
      expect(tester.widget<TextField>(_k('day_spend')).controller!.text, '1000');
      expect(tester.widget<TextField>(_k('day_impressions')).controller!.text, '8000');
    });

    testWidgets('Add ad opens the ad form for this campaign; an ad row opens it filled in', (tester) async {
      await open(tester);
      await _tap(tester, 'det_add_ad');
      expect(find.text('Add an ad'), findsOneWidget);
      expect(tester.widget<DropdownButtonFormField<String>>(_k('ad_campaign')).initialValue, 'c1');
      await _tap(tester, 'ad_cancel');
      await _tap(tester, 'det_ad_a2');
      expect(tester.widget<TextField>(_k('ad_name')).controller!.text, 'Bridal Static');
    });

    testWidgets('a failing read says so with Try again', (tester) async {
      final f = _FakeHub();
      await _pump(tester, tab: 'campaigns', fake: f);
      f.failReads = true;
      await _tap(tester, 'cp_row_c1');
      expect(find.text('Try again'), findsWidgets);
    });
  });

  group('the campaign form', () {
    Future<_FakeHub> openNew(WidgetTester tester) async {
      final f = await _pump(tester);
      await _tap(tester, 'hub_new_campaign');
      return f.hub;
    }

    testWidgets('a name is needed; a budget that is not an amount is refused before anything is sent', (tester) async {
      final f = await openNew(tester);
      await _tap(tester, 'cmp_save');
      expect(find.text('Give the campaign a name.'), findsOneWidget);
      expect(f.savedCampaigns, isEmpty);
      await tester.enterText(_k('cmp_title'), 'Studio Tour');
      await tester.enterText(_k('cmp_budget'), 'lots');
      await _tap(tester, 'cmp_save');
      expect(find.textContaining('A budget must be an amount'), findsOneWidget);
      expect(f.savedCampaigns, isEmpty);
    });

    testWidgets('a filled form sends everything the server needs: brand, platform, objective, budget as a number, the Meta ID', (tester) async {
      final f = await openNew(tester);
      await tester.enterText(_k('cmp_title'), '  Studio Tour ');
      await tester.enterText(_k('cmp_budget'), '25,000');
      await tester.enterText(_k('cmp_daily'), '800');
      await tester.enterText(_k('cmp_meta_id'), '1203009');
      await tester.enterText(_k('cmp_audience'), 'Brides 22–35');
      await _pick(tester, 'cmp_brand', 'Kerala');
      await _pick(tester, 'cmp_platform', 'Instagram');
      await _pick(tester, 'cmp_objective', 'Messages');
      await _pick(tester, 'cmp_status', 'Paused');
      await _tap(tester, 'cmp_save');
      expect(f.savedCampaigns.single.id, isNull);
      final b = f.savedCampaigns.single.body;
      expect(b['title'], 'Studio Tour');
      expect(b['brand'], 'kerala');
      expect(b['platform'], 'instagram');
      expect(b['objective'], 'messages');
      expect(b['status'], 'paused');
      expect(b['budget'], 25000.0);
      expect(b['dailyBudget'], 800.0);
      expect(b['metaCampaignId'], '1203009');
      expect(b['audienceNote'], 'Brides 22–35');
      expect(b.containsKey('startDate'), isFalse, reason: 'dates not chosen are not sent for a new campaign');
      expect(_k('cmp_title'), findsNothing, reason: 'the form closes');
    });

    testWidgets('a blank budget is "no budget" (0); platform and objective can stay "Not set"', (tester) async {
      final f = await openNew(tester);
      await tester.enterText(_k('cmp_title'), 'Quiet campaign');
      await _tap(tester, 'cmp_save');
      final b = f.savedCampaigns.single.body;
      expect(b['budget'], 0.0);
      expect(b['platform'], '');
      expect(b['objective'], '');
      expect(b['brand'], 'kerala', reason: 'All brands starts a campaign in Kerala: the ads run only on the Kerala account');
    });

    testWidgets('a refusal from the server (Meta ID already used) is shown inside the form and the form stays open', (tester) async {
      final f = await openNew(tester);
      f.refuse = const TeamRefusal('Another campaign already has that Meta campaign ID.', field: 'metaCampaignId', status: 409);
      await tester.enterText(_k('cmp_title'), 'Studio Tour');
      await tester.enterText(_k('cmp_meta_id'), '1203001');
      await _tap(tester, 'cmp_save');
      expect(_text(tester, _k('cmp_error')), 'Another campaign already has that Meta campaign ID.');
      f.refuse = null;
      await _tap(tester, 'cmp_save');
      expect(f.savedCampaigns.single.body['metaCampaignId'], '1203001');
    });

    testWidgets('Save is disabled while saving, so a double tap cannot create two campaigns', (tester) async {
      final f = await openNew(tester);
      f.hold = Completer<void>();
      await tester.enterText(_k('cmp_title'), 'Studio Tour');
      await tester.tap(_k('cmp_save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(_k('cmp_save')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(_k('cmp_cancel')).onPressed, isNull);
      f.hold!.complete();
      await tester.pumpAndSettle();
      expect(f.savedCampaigns.length, 1);
    });

    testWidgets('editing sends the change to that campaign, with the dates it has (and null for one cleared)', (tester) async {
      final f = await _pump(tester, tab: 'campaigns');
      await _tap(tester, 'cp_row_c1');
      await _tap(tester, 'det_edit');
      await tester.enterText(_k('cmp_budget'), '12000');
      await _tap(tester, 'cmp_start_clear');
      await _tap(tester, 'cmp_save');
      expect(f.hub.savedCampaigns.single.id, 'c1');
      final b = f.hub.savedCampaigns.single.body;
      expect(b['budget'], 12000.0);
      expect(b['startDate'], isNull);
      expect(b.containsKey('startDate'), isTrue, reason: 'a cleared date is sent as null so the server clears it');
      expect(b['endDate'], isNull);
      expect(b['platform'], 'meta');
    });

    testWidgets('on a phone the form is a bottom sheet', (tester) async {
      await _pump(tester, size: const Size(390, 1800));
      await _tap(tester, 'hub_new_campaign');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(_k('cmp_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Performance', () {
    testWidgets('reach, impressions, clicks, leads and cost per lead with their change', (tester) async {
      await _pump(tester, tab: 'performance');
      expect(_in('hp_kpi_reach', '14,400'), findsOneWidget);
      expect(_in('hp_kpi_reach', '↑ +100% vs last period'), findsOneWidget);
      expect(_in('hp_kpi_impr', '25,500'), findsOneWidget);
      expect(_in('hp_kpi_clicks', '535'), findsOneWidget);
      expect(_in('hp_kpi_leads', '5'), findsOneWidget);
      expect(_in('hp_kpi_cpl', '₹550'), findsOneWidget);
      expect(_in('hp_kpi_cpl', '↓ −31% vs last period'), findsOneWidget);
    });

    testWidgets('the trend switches series; reach says what it adds up; an empty series says so', (tester) async {
      await _pump(tester, tab: 'performance');
      HubSeries drawn() => tester.widget<HubChart>(find.byType(HubChart)).series.single;
      expect(_k('hp_trend_chart_reach'), findsOneWidget);
      expect(drawn().values, [0, 5000, 3000, 4000, 0, 0, 2400]);
      expect(find.textContaining('adds up each day'), findsOneWidget);
      const expected = {'impressions': [0, 8000, 6000, 9000, 0, 0, 2500], 'clicks': [0, 200, 160, 90, 0, 0, 85], 'leads': [0, 1, 3, 1, 0, 0, 0]};
      for (final m in ['impressions', 'clicks', 'leads']) {
        await _tap(tester, 'hp_trend_$m');
        expect(_k('hp_trend_chart_$m'), findsOneWidget, reason: m);
        expect(drawn().values, expected[m], reason: m);
        expect(drawn().label.toLowerCase(), m, reason: 'the chart draws what the chip says');
      }
      final f = _FakeHub()..performanceJson = {..._performance(), 'trend': _trend(empty: true)};
      await _pump(tester, tab: 'performance', fake: f);
      expect(find.text('No reach in this period.'), findsOneWidget);
    });

    testWidgets('objective-wise results: campaigns, spend, leads and cost per lead; "Not set" is its own row; no cost per lead is a dash', (tester) async {
      await _pump(tester, tab: 'performance');
      expect(find.descendant(of: _k('hp_objective_lead_generation'), matching: find.text('₹2,000')), findsOneWidget);
      expect(find.descendant(of: _k('hp_objective_lead_generation'), matching: find.text('₹666.67')), findsOneWidget);
      expect(find.descendant(of: _k('hp_objective_reach'), matching: find.text('₹350')), findsNWidgets(2), reason: 'spend and cost per lead');
      expect(find.descendant(of: _k('hp_objective_not_set'), matching: find.text('Not set')), findsOneWidget);
      expect(find.descendant(of: _k('hp_objective_not_set'), matching: find.text('—')), findsOneWidget);
    });

    testWidgets('no objective data and a failing read', (tester) async {
      await _pump(tester, tab: 'performance', fake: _FakeHub()..performanceJson = {'kpis': _kpis(), 'trend': [], 'objectives': []});
      expect(find.textContaining('No campaign had spend or leads'), findsOneWidget);
      await _pump(tester, tab: 'performance', fake: _FakeHub()..failReads = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Creatives & Ads', () {
    testWidgets('the KPI strip, the chips with their counts, and the table with the verdict of each ad', (tester) async {
      await _pump(tester, tab: 'creatives');
      expect(_in('ad_kpi_total', '4'), findsOneWidget);
      expect(_in('ad_kpi_top', '1'), findsOneWidget);
      expect(_in('ad_kpi_ctr', '2.37%'), findsOneWidget);
      expect(_in('ad_kpi_cpm', '₹107.84'), findsOneWidget);
      expect(_in('ad_kpi_cpr', '₹144.74'), findsOneWidget);
      expect(_in('ad_chip_all', '4'), findsOneWidget);
      expect(_in('ad_chip_top', '1'), findsOneWidget);
      expect(_in('ad_chip_under', '1'), findsOneWidget);
      expect(_in('ad_chip_needs_attention', '1'), findsOneWidget);
      expect(find.descendant(of: _k('ad_row_a1'), matching: find.text('Top performing')), findsOneWidget);
      expect(find.descendant(of: _k('ad_row_a2'), matching: find.text('Underperforming')), findsOneWidget);
      expect(find.descendant(of: _k('ad_row_a3'), matching: find.text('Needs attention')), findsOneWidget);
      expect(find.descendant(of: _k('ad_row_a1'), matching: find.text('4%')), findsOneWidget);
      expect(find.descendant(of: _k('ad_row_a1'), matching: find.text('₹100')), findsNWidgets(2), reason: 'CPM and cost per result');
      expect(find.descendant(of: _k('ad_row_a3'), matching: find.text('—')), findsNWidgets(2), reason: 'no results: no cost per result; no CRM lead: no cost per lead');
      expect(find.textContaining('ads typed by hand: lifetime figures'), findsOneWidget, reason: 'the page says which ads the dates narrow');
    });

    testWidgets('the chips, search and campaign filter ask the server for exactly that', (tester) async {
      final f = await _pump(tester, tab: 'creatives');
      await _tap(tester, 'ad_chip_needs_attention');
      expect(f.hub.adQueries.last.filter, 'needs_attention');
      await tester.enterText(_k('ad_search'), 'carousel');
      await tester.pumpAndSettle();
      expect(f.hub.adQueries.last.q, 'carousel');
      expect(f.hub.adQueries.last.filter, 'needs_attention');
      await _pick(tester, 'ad_campaign_filter', 'Makeup Courses');
      expect(f.hub.adQueries.last.campaignId, 'c2');
      await _pick(tester, 'ad_campaign_filter', 'All Campaigns');
      expect(f.hub.adQueries.last.campaignId, isNull);
      await _tap(tester, 'ad_chip_all');
      expect(f.hub.adQueries.last.filter, 'all');
    });

    testWidgets('paging asks for the next page', (tester) async {
      final f = await _pump(tester, tab: 'creatives');
      expect(find.text('Showing 1–3 of 4'), findsOneWidget);
      await _tap(tester, 'ad_next');
      expect(f.hub.adQueries.last.page, 2);
    });

    testWidgets('Add Ad: campaign and a name are needed; the creative and thumbnail are links; the figures go as numbers', (tester) async {
      final f = await _pump(tester, tab: 'creatives');
      await _tap(tester, 'ad_add');
      await _tap(tester, 'ad_save');
      expect(find.text('Choose the campaign this ad belongs to.'), findsOneWidget);
      await _pick(tester, 'ad_campaign', 'Bridal Campaign – Nov');
      await _tap(tester, 'ad_save');
      expect(find.text('Give the ad a name.'), findsOneWidget);
      expect(f.hub.savedAds, isEmpty);
      await tester.enterText(_k('ad_name'), 'Bridal Reel 2');
      await tester.enterText(_k('ad_set'), 'Brides 22–35');
      await tester.enterText(_k('ad_creative'), 'https://drive.test/r2');
      await tester.enterText(_k('ad_thumb'), 'https://drive.test/r2.jpg');
      await tester.enterText(_k('ad_impressions'), '12,000');
      await tester.enterText(_k('ad_clicks'), '360');
      await tester.enterText(_k('ad_spend'), '1500.5');
      await tester.enterText(_k('ad_results'), '18');
      await _pick(tester, 'ad_format', 'Reel');
      await _tap(tester, 'ad_save');
      final b = f.hub.savedAds.single.body;
      expect(f.hub.savedAds.single.id, isNull);
      expect(b['campaignId'], 'c1');
      expect(b['name'], 'Bridal Reel 2');
      expect(b['format'], 'reel');
      expect(b['creativeUrl'], 'https://drive.test/r2');
      expect(b['thumbUrl'], 'https://drive.test/r2.jpg');
      expect(b['impressions'], 12000.0);
      expect(b['clicks'], 360.0);
      expect(b['spend'], 1500.5);
      expect(b['results'], 18.0);
    });

    testWidgets('a refusal (clicks more than impressions) is shown in the form; numbers that are not numbers are refused first', (tester) async {
      final f = await _pump(tester, tab: 'creatives');
      await _tap(tester, 'ad_add');
      await _pick(tester, 'ad_campaign', 'Bridal Campaign – Nov');
      await tester.enterText(_k('ad_name'), 'Bad numbers');
      await tester.enterText(_k('ad_clicks'), 'many');
      await _tap(tester, 'ad_save');
      expect(find.textContaining('must be numbers'), findsOneWidget);
      expect(f.hub.savedAds, isEmpty);
      await tester.enterText(_k('ad_clicks'), '500');
      f.hub.refuse = const TeamRefusal('Clicks cannot be more than impressions.', field: 'clicks');
      await _tap(tester, 'ad_save');
      expect(_text(tester, _k('ad_error')), 'Clicks cannot be more than impressions.');
    });

    testWidgets('a row opens the ad to edit (sent with its id); Delete asks first', (tester) async {
      final f = await _pump(tester, tab: 'creatives');
      await _tap(tester, 'ad_row_a2');
      expect(find.text('Edit ad'), findsOneWidget);
      expect(tester.widget<TextField>(_k('ad_name')).controller!.text, 'Bridal Static');
      await tester.enterText(_k('ad_results'), '12');
      await _tap(tester, 'ad_save');
      expect(f.hub.savedAds.single.id, 'a2');
      await _tap(tester, 'ad_row_a2');
      await _tap(tester, 'ad_delete');
      expect(find.text('Delete this ad?'), findsOneWidget);
      await _tap(tester, 'ad_delete_no');
      expect(f.hub.deletedAds, isEmpty);
      await _tap(tester, 'ad_delete');
      await _tap(tester, 'ad_delete_yes');
      expect(f.hub.deletedAds, ['a2']);
    });

    testWidgets('no ads says how to start; a filter with no match says so; a failing read has Try again', (tester) async {
      await _pump(tester, tab: 'creatives', fake: _FakeHub()..adsJson = _adsData(empty: true));
      expect(find.textContaining('No ads yet'), findsOneWidget);
      await _pump(tester, tab: 'creatives', fake: _FakeHub()..adsJson = {..._adsData(), 'total': 0, 'items': []});
      expect(find.text('No ad matches these filters.'), findsOneWidget);
      await _pump(tester, tab: 'creatives', fake: _FakeHub()..failReads = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Budget & Spend', () {
    testWidgets('total budget, spend (and its share of the budget), remaining and utilisation', (tester) async {
      await _pump(tester, tab: 'budget');
      expect(_in('bd_kpi_budget', '₹15,000'), findsOneWidget);
      expect(_in('bd_kpi_budget', '2 campaigns'), findsOneWidget);
      expect(_in('bd_kpi_spent', '₹3,150'), findsOneWidget);
      expect(_in('bd_kpi_spent', 'Spent to Date'), findsOneWidget);
      expect(_in('bd_kpi_spent', 'Budgeted campaigns, to ${DateFormat('d MMM').format(TeamFilter.thisWeek().to)}'), findsOneWidget, reason: 'budgeted campaigns, everything up to the end of the dates');
      expect(_in('bd_kpi_period', '₹2,750'), findsOneWidget);
      expect(_in('bd_kpi_period', 'Spend in This Period'), findsOneWidget);
      expect(find.descendant(of: _k('bd_kpi_period'), matching: find.textContaining('All campaigns')), findsOneWidget);
      expect(find.text('Total Spend'), findsNothing, reason: 'two different spend figures never share one name');
      expect(_in('bd_kpi_remaining', '₹11,850'), findsOneWidget);
      expect(_in('bd_kpi_remaining', '79% left'), findsOneWidget);
      expect(_in('bd_kpi_util', '21%'), findsOneWidget);
      expect(_in('bd_kpi_util', '↑ +15.7 pts vs last period'), findsOneWidget);
    });

    testWidgets('spend on campaigns with no budget is reported on its own, not in the totals', (tester) async {
      await _pump(tester, tab: 'budget');
      expect(_k('bd_unbudgeted_note'), findsOneWidget);
      expect(find.textContaining('₹400 was spent in this period on campaigns with no budget set'), findsOneWidget);
    });

    testWidgets('the table: budget, spent, remaining, a bar of how much is used; "No budget set" and "Over by" are said, not invented', (tester) async {
      await _pump(tester, tab: 'budget');
      expect(find.descendant(of: _k('bd_row_c1'), matching: find.text('₹10,000')), findsOneWidget);
      expect(find.descendant(of: _k('bd_row_c1'), matching: find.text('₹7,200')), findsOneWidget);
      expect(find.descendant(of: _k('bd_row_c1'), matching: find.text('28%')), findsOneWidget);
      expect(_text(tester, _k('bd_no_budget_c3')), 'No budget set');
      expect(_k('bd_no_budget_c1'), findsNothing);
      expect(_k('bd_over_c1'), findsNothing);
      await _pump(tester, tab: 'budget', fake: _FakeHub()..budgetJson = _budgetData(over: true));
      expect(_text(tester, _k('bd_over_c1')), 'Over by ₹2,000');
      expect(_in('bd_kpi_remaining', 'Over by ₹1,000'), findsOneWidget);
    });

    testWidgets('daily spend bars and the spend donut with its total; a row opens the campaign', (tester) async {
      final f = await _pump(tester, tab: 'budget');
      expect(_k('bd_daily'), findsOneWidget);
      expect(_text(tester, _k('bd_donut_total')), '₹2,750');
      expect(find.text('Others'), findsOneWidget);
      expect(find.text('72.7%'), findsOneWidget);
      await _tap(tester, 'bd_row_c1');
      expect(f.hub.details, ['c1']);
    });

    testWidgets('nothing budgeted and nothing spent say so instead of showing zeros', (tester) async {
      await _pump(tester, tab: 'budget', fake: _FakeHub()..budgetJson = _budgetData(empty: true));
      expect(_in('bd_kpi_budget', 'No budget set'), findsOneWidget);
      expect(find.textContaining('No spend in this period'), findsOneWidget);
      expect(find.text('No spend to split in this period.'), findsOneWidget);
      expect(find.text('No campaign ran in this period.'), findsOneWidget);
      await _pump(tester, tab: 'budget', fake: _FakeHub()..failReads = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Leads & Conversions', () {
    testWidgets('total leads, qualified, bookings, conversion rate (in points) and booking value', (tester) async {
      await _pump(tester, tab: 'leads');
      expect(_in('ld_kpi_leads', '5'), findsOneWidget);
      expect(_in('ld_kpi_leads', '↑ +400% vs last period'), findsOneWidget);
      expect(_in('ld_kpi_qualified', '2'), findsOneWidget);
      expect(_in('ld_kpi_bookings', '2'), findsOneWidget);
      expect(_in('ld_kpi_conversion', '40%'), findsOneWidget);
      expect(_in('ld_kpi_conversion', '↑ +40 pts vs last period'), findsOneWidget);
      expect(_in('ld_kpi_value', '₹40,000'), findsOneWidget);
    });

    testWidgets('the funnel shows each step with its count and share; the lead quality', (tester) async {
      await _pump(tester, tab: 'leads');
      expect(_in('ld_funnel_leads', 'Total Leads  5'), findsOneWidget);
      expect(_in('ld_funnel_leads', '100%'), findsOneWidget);
      expect(_in('ld_funnel_qualified', 'Qualified  2'), findsOneWidget);
      expect(_in('ld_funnel_qualified', '40%'), findsOneWidget);
      expect(_in('ld_funnel_booked', 'Booked  2'), findsOneWidget);
      expect(_in('ld_quality_Hot', 'Hot 1'), findsOneWidget);
      expect(_in('ld_quality_Warm', 'Warm 3'), findsOneWidget);
      expect(_k('ld_trend'), findsOneWidget);
      expect(find.text('Leads'), findsWidgets);
      expect(find.text('Bookings'), findsWidgets);
    });

    testWidgets('the campaign-wise table runs from leads to bookings to booking value; a row opens the campaign', (tester) async {
      final f = await _pump(tester, tab: 'leads');
      expect(find.descendant(of: _k('ld_row_c1'), matching: find.text('Bridal Campaign – Nov')), findsOneWidget);
      expect(find.descendant(of: _k('ld_row_c1'), matching: find.text('₹40,000')), findsOneWidget);
      expect(find.descendant(of: _k('ld_row_c1'), matching: find.text('33.3%')), findsOneWidget);
      expect(find.descendant(of: _k('ld_row_c1'), matching: find.text('20x')), findsOneWidget);
      expect(find.descendant(of: _k('ld_row_c2'), matching: find.text('₹0')), findsOneWidget, reason: 'booking value of a campaign with no bookings');
      await _tap(tester, 'ld_row_c2');
      expect(f.hub.details, ['c2']);
    });

    testWidgets('no leads says so; a failing read has Try again', (tester) async {
      await _pump(tester, tab: 'leads', fake: _FakeHub()..leadsJson = _leadsData(empty: true));
      expect(find.text('No leads are tagged to a campaign in this period.'), findsOneWidget);
      expect(find.text('No leads in this period.'), findsOneWidget);
      expect(find.text('No campaign has leads or spend in this period.'), findsOneWidget);
      expect(_in('ld_kpi_conversion', '—'), findsOneWidget);
      await _pump(tester, tab: 'leads', fake: _FakeHub()..failReads = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Reports & Insights', () {
    testWidgets('five report cards with their row counts, the insights, the import history, and the saved / scheduled reports', (tester) async {
      await _pump(tester, tab: 'reports');
      for (final t in ['campaign', 'creative', 'lead', 'conversion', 'spend']) {
        expect(_k('rp_card_$t'), findsOneWidget, reason: t);
      }
      expect(find.text('Campaign Report'), findsOneWidget);
      expect(_text(tester, _k('rp_rows_creative')), '4 rows');
      expect(_text(tester, _k('rp_rows_conversion')), '1 row');
      expect(_text(tester, _k('rp_rows_spend')), '0 rows');
      expect(find.text('Festive Offers is over its budget by ₹100.'), findsOneWidget);
      expect(_k('mktSavedReports_campaigns'), findsOneWidget);
      expect(_k('mktScheduledReports_campaigns'), findsOneWidget);
      expect(_k('rp_import_i1'), findsOneWidget);
      expect(find.descendant(of: _k('rp_import_i1'), matching: find.text('meta-export.csv')), findsOneWidget);
      expect(find.descendant(of: _k('rp_import_i1'), matching: find.text('Not matched: Trial Makeup')), findsOneWidget);
      expect(find.descendant(of: _k('rp_import_i2'), matching: find.text('Typed by hand')), findsOneWidget);
      expect(_in('hub_meta_status', 'Not connected'), findsOneWidget);
    });

    testWidgets('a downloaded report is kept in Saved reports with the dates and brand it was made for', (tester) async {
      final reports = FakeMarketingReports();
      final w = await _pump(tester, tab: 'reports', reports: reports);
      await tester.tap(_k('rp_download_creative'));
      await tester.pumpAndSettle();
      final f = w.hub.reportFilters.last;
      expect(reports.kept, [
        {'module': 'campaigns', 'kind': 'creative', 'name': reports.kept.single['name']!, 'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire},
      ]);
      expect(reports.kept.single['name'], isNotEmpty);
    });

    testWidgets('opening a scheduled monthly report downloads the campaign report for its month and brand — not kept twice', (tester) async {
      final reports = FakeMarketingReports(savedList: [MarketingSavedReport.fromJson(const {'id': 'r9', 'module': 'campaigns', 'kind': 'monthly', 'name': 'Scheduled one', 'from': '2026-10-01', 'to': '2026-10-31', 'brand': 'kerala', 'scheduled': true, 'createdByName': 'Scheduled'})]);
      final w = await _pump(tester, tab: 'reports', reports: reports);
      await tester.tap(_k('mktSavedReportOpen_r9'));
      await tester.pumpAndSettle();
      expect(w.hub.reportTypes.last, 'campaign');
      final f = w.hub.reportFilters.last;
      expect([f.fromDay, f.toDay, f.brand], ['2026-10-01', '2026-10-31', TeamBrand.kerala]);
      expect(w.saved, isNotEmpty);
      expect(reports.kept, isEmpty);
    });

    testWidgets('each card downloads ITS report as a CSV: the columns, then the rows, with the server\'s file name', (tester) async {
      final f = await _pump(tester, tab: 'reports');
      await _tap(tester, 'rp_download_conversion');
      expect(f.hub.reportTypes, ['conversion']);
      expect(find.textContaining('saved as campaign-conversion-report'), findsOneWidget, reason: 'the page says what it saved');
      await tester.pump(const Duration(seconds: 6)); // the first note goes away, so the second can show
      await tester.pumpAndSettle();
      expect(f.saved.single.name, 'campaign-conversion-report-2026-11-01_2026-11-07.csv');
      expect(f.saved.single.rows, [['Campaign', 'Spend (INR)'], ['Bridal Campaign – Nov', 2000], ['Makeup Courses', 350]]);
      await tester.ensureVisible(_k('rp_download_spend'));
      await tester.tap(_k('rp_download_spend'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(f.hub.reportTypes, ['conversion', 'spend']);
      expect(f.saved.length, 2);
      expect(find.textContaining('saved as campaign-spend-report'), findsOneWidget);
    });

    testWidgets('the scope line says which dates and brand a report is for; no imports says so', (tester) async {
      await _pump(tester, tab: 'reports', fake: _FakeHub()..reportsJson = _reportsData(noImport: true));
      expect(_text(tester, _k('rp_scope')), contains('All brands'));
      expect(find.text('Nothing imported yet.'), findsOneWidget);
      expect(_text(tester, _k('hub_meta_last_import')), 'No import yet');
    });

    testWidgets('a failing read has Try again', (tester) async {
      await _pump(tester, tab: 'reports', fake: _FakeHub()..failReads = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('typing a day\'s figures', () {
    testWidgets('a campaign is needed; the figures must be numbers; a good form sends the campaign, the day and the figures', (tester) async {
      final f = await _pump(tester);
      await _tap(tester, 'hub_type_day_button');
      await _tap(tester, 'day_save');
      expect(find.text('Choose the campaign.'), findsOneWidget);
      await _pick(tester, 'day_campaign', 'Bridal Campaign – Nov');
      await tester.enterText(_k('day_spend'), 'a lot');
      await _tap(tester, 'day_save');
      expect(find.textContaining('must be a number'), findsOneWidget);
      expect(f.hub.savedDays, isEmpty);
      await tester.enterText(_k('day_spend'), '1,250.5');
      await tester.enterText(_k('day_reach'), '5000');
      await tester.enterText(_k('day_impressions'), '8000');
      await tester.enterText(_k('day_clicks'), '200');
      await tester.enterText(_k('day_results'), '10');
      await _tap(tester, 'day_save');
      final b = f.hub.savedDays.single;
      expect(b['campaignId'], 'c1');
      expect(b['day'], TeamFilter.day(DateTime.now().subtract(const Duration(days: 1))), reason: 'a day starts at yesterday: the Meta Ads Manager has no figures for today yet');
      expect([b['spend'], b['reach'], b['impressions'], b['clicks'], b['results']], [1250.5, 5000.0, 8000.0, 200.0, 10.0]);
    });

    testWidgets('a refusal (reach above impressions) is shown in the form; blank figures are zero', (tester) async {
      final f = await _pump(tester);
      await _tap(tester, 'hub_type_day_button');
      await _pick(tester, 'day_campaign', 'Makeup Courses');
      f.hub.refuse = const TeamRefusal('Reach cannot be more than impressions.', field: 'reach');
      await tester.enterText(_k('day_reach'), '900');
      await _tap(tester, 'day_save');
      expect(_text(tester, _k('day_error')), 'Reach cannot be more than impressions.');
      f.hub.refuse = null;
      await tester.enterText(_k('day_reach'), '');
      await _tap(tester, 'day_save');
      expect(f.hub.savedDays.single['reach'], 0.0);
      expect(f.hub.savedDays.single['campaignId'], 'c2');
    });
  });

  group('reading a Meta Ads Manager export', () {
    Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

    test('a day-by-day export becomes campaign-day rows with the usual column names', () {
      final e = parseMetaExport(bytes(_csv), 'export.csv');
      expect(e.warnings, isEmpty);
      expect(e.totalRows, 3);
      expect(e.rows.length, 3);
      expect(e.rows.first, {'campaign': 'Bridal Campaign – Nov', 'day': '2026-11-02', 'spend': 1000.5, 'reach': 5000, 'impressions': 8000, 'clicks': 200, 'results': 10});
      expect(e.campaigns, 2);
      expect(e.firstDay, '2026-11-02');
      expect(e.lastDay, '2026-11-03');
    });

    test('other spellings of the columns: Campaign ID, Reporting starts (one-day rows), Clicks (all), Leads, ₹ and INR in amounts, day-first dates', () {
      const csv = 'Reporting starts,Reporting ends,Campaign ID,Campaign name,Amount spent,Reach,Impressions,Clicks (all),Leads\n'
          '03/11/2026,03/11/2026,1203001,Bridal,₹1250,100,200,10,2\n'
          '04-11-2026,04-11-2026,1203001,Bridal,INR 300,50,100,5,1\n';
      final e = parseMetaExport(bytes(csv), 'x.csv');
      expect(e.warnings, isEmpty);
      expect(e.rows.length, 2);
      expect(e.rows.first['campaignId'], '1203001');
      expect(e.rows.first['day'], '2026-11-03');
      expect(e.rows.first['spend'], 1250);
      expect(e.rows.first['clicks'], 10);
      expect(e.rows.first['results'], 2);
      expect(e.rows.last['day'], '2026-11-04');
      expect(e.rows.last['spend'], 300);
    });

    test('Link clicks win over Clicks (all) when a file has both', () {
      const csv = 'Day,Campaign name,Amount spent (INR),Impressions,Clicks (all),Link clicks\n2026-11-02,A,10,1000,50,20\n';
      expect(parseMetaExport(bytes(csv), 'x.csv').rows.single['clicks'], 20);
    });

    test('rows of the same campaign and day are added, so each day goes once', () {
      const csv = 'Day,Campaign name,Amount spent (INR),Reach,Impressions,Link clicks,Results\n'
          '2026-11-02,Bridal,600.10,3000,5000,100,6\n'
          '2026-11-02,BRIDAL,400.20,2000,3000,100,4\n'
          '2026-11-03,Bridal,50,10,20,1,0\n';
      final e = parseMetaExport(bytes(csv), 'x.csv');
      expect(e.rows.length, 2, reason: 'the same name in another case is the same campaign');
      expect(e.rows.first, {'campaign': 'Bridal', 'day': '2026-11-02', 'spend': 1000.3, 'reach': 5000, 'impressions': 8000, 'clicks': 200, 'results': 10});
      expect(mergeMetaRows([]), isEmpty);
    });

    test('a file that covers a whole period (not day by day) is not imported: the rows are left out and the file is explained', () {
      const csv = 'Reporting starts,Reporting ends,Campaign name,Amount spent (INR),Impressions\n2026-11-01,2026-11-30,Bridal,9000,50000\n2026-11-05,2026-11-05,Studio,100,900\n';
      final e = parseMetaExport(bytes(csv), 'x.csv');
      expect(e.rows.length, 1);
      expect(e.rows.single['campaign'], 'Studio');
      expect(e.warnings.single, contains('cover a whole period'));
      expect(e.warnings.single, contains('Breakdown → Time → Day'));
    });

    test('a title above the header is skipped; rows that cannot be used are counted, the rest still go', () {
      const csv = 'Meta Ads export\n\nDay,Campaign name,Amount spent (INR),Reach,Impressions,Link clicks,Results\n'
          '2026-11-02,Bridal,100,10,20,1,0\n'
          ',Total,500,50,100,5,0\n' // no day
          '2026-11-03,,100,10,20,1,0\n' // no campaign
          '2026-02-30,Bridal,100,10,20,1,0\n' // not a day
          '2026-11-04,Bridal,abc,10,20,1,0\n' // not a number
          '2026-11-05,Bridal,-5,10,20,1,0\n' // negative
          '2026-11-06,Bridal,—,—,10,1,\n'; // dashes and blanks are zero
      final e = parseMetaExport(bytes(csv), 'x.csv');
      expect(e.rows.map((r) => r['day']), ['2026-11-02', '2026-11-06']);
      expect(e.skipped, 5);
      expect(e.warnings.single, '5 rows could not be used (no campaign name, no real day, or a figure that is not a number).');
      expect(e.rows.last['spend'], 0);
    });

    test('a file without the columns, an empty file and a file that is not a spreadsheet explain themselves instead of crashing', () {
      expect(parseMetaExport(bytes('a,b,c\n1,2,3\n'), 'x.csv').warnings.single, contains('Could not find the columns'));
      expect(parseMetaExport(bytes('Day,Campaign name\n2026-11-02,A\n'), 'x.csv').warnings.single, contains('no "Amount spent" or "Impressions"'));
      expect(parseMetaExport(bytes(''), 'x.csv').warnings.single, 'The file is empty.');
      expect(parseMetaExport(bytes('not an excel file'), 'x.xlsx').warnings.single, contains('Could not read the file'));
      expect(parseMetaExport(bytes('Day,Campaign name,Amount spent\n'), 'x.csv').rows, isEmpty);
      expect(parseMetaExport(bytes('Day,Campaign name,Amount spent\n'), 'x.csv').warnings, isNotEmpty);
    });

    test('dates in the other usual shapes', () {
      const csv = 'Day,Campaign name,Amount spent (INR),Impressions\n3 Nov 2026,A,1,10\n"Nov 4, 2026",A,1,10\n2026-11-05T00:00:00,A,1,10\n';
      expect(parseMetaExport(bytes(csv), 'x.csv').rows.map((r) => r['day']), ['2026-11-03', '2026-11-04', '2026-11-05']);
    });
  });

  group('importing from Meta Ads Manager', () {
    testWidgets('the Overview button asks for the file and opens the preview: matched and not-found campaigns', (tester) async {
      final f = await _pump(tester, csv: _csv);
      await _tap(tester, 'hub_import_button');
      expect(find.text('Import from Meta Ads Manager'), findsWidgets);
      expect(_text(tester, _k('imp_file_name')), 'meta.csv');
      expect(_text(tester, _k('imp_summary')), startsWith('3 campaign-days · 2 campaigns'));
      expect(_k('imp_matched_c1'), findsOneWidget);
      expect(_k('imp_unmatched_Trial Makeup'), findsOneWidget);
      // the check sends ONE row per campaign, as a dry run, and nothing is written
      expect(f.hub.imports.single.dryRun, isTrue);
      expect(f.hub.imports.single.rows.map((r) => r['campaign']).toSet(), {'Bridal Campaign – Nov', 'Trial Makeup'});
      expect(f.hub.imports.single.rows.length, 2);
    });

    testWidgets('a cancelled file picker does nothing', (tester) async {
      final f = await _pump(tester);
      await _tap(tester, 'hub_import_button');
      expect(_k('imp_file_name'), findsNothing);
      expect(f.hub.imports, isEmpty);
    });

    testWidgets('creating the campaigns that were not found is an explicit choice, off by default, with a brand', (tester) async {
      final f = await _pump(tester, csv: _csv);
      await _tap(tester, 'hub_import_button');
      expect(tester.widget<CheckboxListTile>(_k('imp_create_missing')).value, isFalse);
      expect(_k('imp_brand'), findsNothing);
      await _tap(tester, 'imp_save');
      expect(f.hub.imports.last.createMissing, isFalse, reason: 'unticked: nothing is created');
      expect(f.hub.imports.last.dryRun, isFalse);
    });

    testWidgets('ticking create shows the brand (Kerala unless a brand is chosen) and sends both', (tester) async {
      final f = await _pump(tester, csv: _csv);
      await _tap(tester, 'hub_import_button');
      await _tap(tester, 'imp_create_missing');
      expect(tester.widget<DropdownButtonFormField<String>>(_k('imp_brand')).initialValue, 'kerala');
      await _pick(tester, 'imp_brand', 'Main');
      await _tap(tester, 'imp_save');
      expect(f.hub.imports.last.createMissing, isTrue);
      expect(f.hub.imports.last.brand, 'main');
      expect(f.hub.imports.last.fileName, 'meta.csv');
      expect(f.hub.imports.last.rows.length, 3, reason: 'all three campaign-days go');
      expect(f.hub.imports.last.rows.first['day'], '2026-11-02');
    });

    testWidgets('the result says what was written, what was created and what was left out', (tester) async {
      final f = _FakeHub()
        ..importJson = {'dryRun': false, 'rows': 3, 'skipped': 1, 'skippedRows': [], 'matched': [], 'unmatched': [_importGroup('Trial Makeup', reason: 'no_match')], 'created': 0, 'written': 2, 'importId': 'imp1', 'from': '2026-11-02', 'to': '2026-11-03'};
      await _pump(tester, csv: _csv, fake: f);
      await _tap(tester, 'hub_import_button');
      await _tap(tester, 'imp_save');
      expect(_text(tester, _k('imp_done_title')), 'Imported 2 campaign-days.');
      expect(_text(tester, _k('imp_done_span')), '2 Nov 2026 – 3 Nov 2026');
      expect(_text(tester, _k('imp_done_unmatched')), contains('Trial Makeup'));
      expect(_text(tester, _k('imp_done_skipped')), '1 row skipped as not valid.');
      expect(_k('imp_done_created'), findsNothing);
      await _tap(tester, 'imp_save');
      expect(_k('imp_done_title'), findsNothing, reason: 'Done closes the form');
    });

    testWidgets('created campaigns are reported', (tester) async {
      final f = _FakeHub()..importJson = {'dryRun': false, 'rows': 3, 'skipped': 0, 'skippedRows': [], 'matched': [], 'unmatched': [], 'created': 1, 'written': 3, 'importId': 'imp1', 'from': '2026-11-02', 'to': '2026-11-03'};
      await _pump(tester, csv: _csv, fake: f);
      await _tap(tester, 'hub_import_button');
      await _tap(tester, 'imp_create_missing');
      await _tap(tester, 'imp_save');
      expect(_text(tester, _k('imp_done_created')), '1 new campaign created.');
    });

    testWidgets('a big file is sent in parts that share one history entry', (tester) async {
      final rows = StringBuffer('Day,Campaign name,Amount spent (INR),Impressions\n');
      for (var i = 0; i < 600; i++) {
        final d = DateTime(2025, 1, 1).add(Duration(days: i));
        rows.writeln('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')},Bridal Campaign – Nov,10,100');
      }
      final f = _FakeHub()
        ..importJson = {'dryRun': false, 'rows': 250, 'skipped': 0, 'skippedRows': [], 'matched': [], 'unmatched': [], 'created': 0, 'written': 250, 'importId': 'imp1', 'from': '2025-01-01', 'to': '2026-08-23'};
      await _pump(tester, csv: rows.toString(), fake: f);
      await _tap(tester, 'hub_import_button');
      await _tap(tester, 'imp_save');
      final sends = f.imports.where((i) => !i.dryRun).toList();
      expect(sends.map((s) => s.rows.length), [250, 250, 100], reason: 'at most $kImportChunk campaign-days a request');
      expect(sends.map((s) => s.importId), [null, 'imp1', 'imp1'], reason: 'the first part opens the history entry, the others add to it');
      expect(_text(tester, _k('imp_done_title')), 'Imported 750 campaign-days.');
    });

    testWidgets('nothing matched: Import stays off until a campaign is matched or "create" is ticked', (tester) async {
      final f = _FakeHub()..dryRunJson = {'dryRun': true, 'rows': 2, 'matched': [], 'unmatched': [_importGroup('Bridal Campaign – Nov', reason: 'no_match'), _importGroup('Trial Makeup', reason: 'no_match')]};
      await _pump(tester, csv: _csv, fake: f);
      await _tap(tester, 'hub_import_button');
      expect(_k('imp_none_matched'), findsOneWidget);
      expect(tester.widget<FilledButton>(_k('imp_save')).onPressed, isNull);
      await _tap(tester, 'imp_create_missing');
      expect(tester.widget<FilledButton>(_k('imp_save')).onPressed, isNotNull);
    });

    testWidgets('a name shared by two campaigns is flagged and cannot be created', (tester) async {
      final f = _FakeHub()..dryRunJson = {'dryRun': true, 'matched': [_importGroup('A', campaignId: 'c1', title: 'A')], 'unmatched': [_importGroup('Twin', reason: 'ambiguous')]};
      await _pump(tester, csv: _csv, fake: f);
      await _tap(tester, 'hub_import_button');
      expect(find.text('Twin — two campaigns share this name'), findsOneWidget);
      expect(_k('imp_create_missing'), findsNothing, reason: 'creating a third "Twin" would only make it worse');
    });

    testWidgets('a file that cannot be read shows why and offers no import', (tester) async {
      final f = await _pump(tester, csv: 'a,b\n1,2\n');
      await _tap(tester, 'hub_import_button');
      expect(find.textContaining('Could not find the columns'), findsOneWidget);
      expect(_k('imp_nothing'), findsOneWidget);
      expect(tester.widget<FilledButton>(_k('imp_save')).onPressed, isNull);
      expect(f.hub.imports, isEmpty, reason: 'nothing to ask the server about');
    });

    testWidgets('warnings about skipped rows are shown above the preview', (tester) async {
      await _pump(tester, csv: '$_csv,Bridal,nonsense\n'.replaceFirst('\n,Bridal,nonsense\n', '\n2026-11-09,,5,5,5,5,5\n'));
      await _tap(tester, 'hub_import_button');
      expect(_k('imp_warnings'), findsOneWidget);
      expect(find.textContaining('1 row could not be used'), findsOneWidget);
    });

    testWidgets('a failing check says so and Try again asks again', (tester) async {
      final f = _FakeHub();
      await _pump(tester, csv: _csv, fake: f);
      f.failReads = true; // the overview is already on screen; the check of the file fails
      await _tap(tester, 'hub_import_button');
      expect(_k('imp_check_error'), findsOneWidget);
      f.failReads = false;
      await _tap(tester, 'imp_retry');
      expect(_k('imp_matched_c1'), findsOneWidget);
    });

    testWidgets('a refusal while importing is shown in the form and the import can be tried again', (tester) async {
      final f = _FakeHub();
      await _pump(tester, csv: _csv, fake: f);
      await _tap(tester, 'hub_import_button');
      f.refuse = const TeamRefusal('Send at most 500 rows at a time.');
      await _tap(tester, 'imp_save');
      expect(_text(tester, _k('imp_error')), 'Send at most 500 rows at a time.');
      expect(tester.widget<FilledButton>(_k('imp_save')).onPressed, isNotNull);
    });

    testWidgets('while importing, the form cannot be submitted twice', (tester) async {
      final f = _FakeHub();
      await _pump(tester, csv: _csv, fake: f);
      await _tap(tester, 'hub_import_button');
      f.hold = Completer<void>();
      await tester.tap(_k('imp_save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(_k('imp_save')).onPressed, isNull);
      expect(_k('imp_progress'), findsOneWidget);
      f.hold!.complete();
      await tester.pumpAndSettle();
      expect(f.imports.where((i) => !i.dryRun).length, 1);
    });

    testWidgets('the Reports tab has the same import button', (tester) async {
      await _pump(tester, tab: 'reports', csv: _csv);
      await _tap(tester, 'hub_import_button');
      expect(_k('imp_file_name'), findsOneWidget);
    });
  });

  group('what the service asks the server for', () {
    Future<List<RequestOptions>> capture(Future<void> Function(MarketingCampaignHubService s) run, {String body = '{}'}) async {
      final seen = <RequestOptions>[];
      await run(MarketingCampaignHubService(Dio()..httpClientAdapter = _Capture(seen, body: body)));
      return seen;
    }

    final f = TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30), brand: TeamBrand.kerala);

    test('every read carries the shared range and brand', () async {
      final reqs = await capture((s) async {
        await s.overview(f);
        await s.campaigns(f, const HubCampaignQuery());
        await s.campaign(f, 'c1');
        await s.performance(f);
        await s.budget(f);
        await s.leads(f);
        await s.reports(f);
        await s.report(f, 'spend');
      });
      expect(reqs.map((r) => r.path), ['/marketing/campaign-hub/overview', '/marketing/campaign-hub/campaigns', '/marketing/campaign-hub/campaigns/c1', '/marketing/campaign-hub/performance', '/marketing/campaign-hub/budget', '/marketing/campaign-hub/leads', '/marketing/campaign-hub/reports', '/marketing/campaign-hub/reports/spend']);
      for (final r in reqs) {
        expect(r.method, 'GET');
        expect(r.queryParameters, containsPair('from', '2026-11-01'), reason: r.path);
        expect(r.queryParameters, containsPair('to', '2026-11-30'), reason: r.path);
        expect(r.queryParameters, containsPair('brand', 'kerala'), reason: r.path);
      }
    });

    test('the campaign table adds its cuts; "all" and blank are not sent', () async {
      final reqs = await capture((s) async {
        await s.campaigns(f, const HubCampaignQuery(q: ' festive ', status: 'paused', platform: 'google', objective: 'reach', page: 3));
        await s.campaigns(f, const HubCampaignQuery(q: '   '));
      });
      expect(reqs[0].queryParameters, containsPair('q', 'festive'));
      expect(reqs[0].queryParameters, containsPair('status', 'paused'));
      expect(reqs[0].queryParameters, containsPair('platform', 'google'));
      expect(reqs[0].queryParameters, containsPair('objective', 'reach'));
      expect(reqs[0].queryParameters, containsPair('page', 3));
      for (final k in ['q', 'status', 'platform', 'objective']) {
        expect(reqs[1].queryParameters.containsKey(k), isFalse, reason: k);
      }
    });

    test('ads are asked for with the shared range and brand (imported ads follow the dates), the chip, search and campaign', () async {
      final reqs = await capture((s) async {
        await s.ads(f, const HubAdQuery(filter: 'top', q: ' reel ', campaignId: 'c1', page: 2));
        await s.ads(f, const HubAdQuery());
      });
      expect(reqs[0].path, '/marketing/campaign-hub/ads');
      expect(reqs[0].queryParameters, containsPair('brand', 'kerala'));
      expect(reqs[0].queryParameters, containsPair('filter', 'top'));
      expect(reqs[0].queryParameters, containsPair('q', 'reel'));
      expect(reqs[0].queryParameters, containsPair('campaignId', 'c1'));
      expect(reqs[0].queryParameters, containsPair('page', 2));
      expect(reqs[0].queryParameters, containsPair('from', '2026-11-01'));
      expect(reqs[0].queryParameters, containsPair('to', '2026-11-30'));
      for (final k in ['filter', 'q', 'campaignId']) {
        expect(reqs[1].queryParameters.containsKey(k), isFalse, reason: k);
      }
    });

    test('writes use the right method and path: post to create, put to change, delete to remove', () async {
      final reqs = await capture((s) async {
        await s.saveCampaign({'title': 'x'});
        await s.saveCampaign({'title': 'y'}, id: 'c1');
        await s.deleteCampaign('c1');
        await s.saveAd({'name': 'x'});
        await s.saveAd({'name': 'y'}, id: 'a1');
        await s.deleteAd('a1');
        await s.saveDay({'campaignId': 'c1', 'day': '2026-11-02'});
        await s.deleteDay('d1');
      });
      expect(reqs.map((r) => '${r.method} ${r.path}'), [
        'POST /marketing/campaign-hub/campaigns',
        'PUT /marketing/campaign-hub/campaigns/c1',
        'DELETE /marketing/campaign-hub/campaigns/c1',
        'POST /marketing/campaign-hub/ads',
        'PUT /marketing/campaign-hub/ads/a1',
        'DELETE /marketing/campaign-hub/ads/a1',
        'POST /marketing/campaign-hub/metrics',
        'DELETE /marketing/campaign-hub/metrics/d1',
      ]);
      expect(reqs[0].data, {'title': 'x'});
    });

    test('an import posts its rows with the options; the import id is sent only when there is one', () async {
      final reqs = await capture((s) async {
        await s.importRows([{'campaign': 'A', 'day': '2026-11-02'}], dryRun: true, fileName: 'f.csv');
        await s.importRows([{'campaign': 'A', 'day': '2026-11-02'}], createMissing: true, brand: 'main', fileName: 'f.csv', importId: 'imp1');
      });
      expect(reqs.map((r) => '${r.method} ${r.path}'), ['POST /marketing/campaign-hub/import', 'POST /marketing/campaign-hub/import']);
      expect(reqs[0].data, {'level': 'campaign', 'rows': [{'campaign': 'A', 'day': '2026-11-02'}], 'createMissing': false, 'brand': 'kerala', 'dryRun': true, 'fileName': 'f.csv'});
      expect(reqs[1].data, containsPair('importId', 'imp1'));
      expect(reqs[1].data, containsPair('createMissing', true));
      expect(reqs[1].data, containsPair('brand', 'main'));
    });

    test('a server refusal comes back as its own words, with the field', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 409, body: '{"message":"Another campaign already has that Meta campaign ID.","field":"metaCampaignId"}');
      await expectLater(MarketingCampaignHubService(dio).saveCampaign({'title': 'x'}), throwsA(isA<TeamRefusal>().having((e) => e.message, 'message', 'Another campaign already has that Meta campaign ID.').having((e) => e.field, 'field', 'metaCampaignId').having((e) => e.status, 'status', 409)));
    });

    test('a failure that is not a refusal is an error, not a message to show raw', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 500, body: '{"message":"MongoServerError: boom"}');
      await expectLater(MarketingCampaignHubService(dio).deleteAd('a1'), throwsA(isNot(isA<TeamRefusal>())));
      await expectLater(MarketingCampaignHubService(dio).overview(f), throwsA(anything));
    });
  });

  group('the pieces', () {
    testWidgets('a thumbnail falls back to a tile with the format\'s icon when there is no link', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: HubThumb(url: '', format: 'reel'))));
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: HubThumb(url: '', format: 'carousel'))));
      expect(find.byIcon(Icons.view_carousel_outlined), findsOneWidget);
    });

    test('status, verdict and insight colours differ so the chips can be told apart', () {
      expect({for (final s in ['active', 'paused', 'completed', 'planned']) hubStatusColor(s)}.length, 4);
      expect(hubStatusColor('anything'), hubStatusColor('planned'), reason: 'planned and anything unknown are grey');
      expect({for (final v in ['top', 'under', 'needs_attention', 'early', 'ok']) adVerdictColor(v)}.length, 5);
      expect({for (final k in ['good', 'warn', 'info']) insightColor(k)}.length, 3);
    });

    testWidgets('the chart draws bars for one bar series and lines otherwise, and survives no days', (tester) async {
      Future<void> pump(Widget w) => tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SizedBox(width: 500, child: w))));
      await pump(const HubChart(days: ['2026-11-01', '2026-11-02'], series: [HubSeries('Spend', Colors.purple, [10, 20], bars: true)]));
      expect(tester.takeException(), isNull);
      await pump(const HubChart(days: ['2026-11-01', '2026-11-02'], series: [HubSeries('A', Colors.purple, [10, null]), HubSeries('B', Colors.green, [null, 5])]));
      expect(tester.takeException(), isNull);
      await pump(const HubChart(days: [], series: [HubSeries('A', Colors.purple, [])]));
      expect(tester.takeException(), isNull);
    });
  });

  group('a phone', () {
    testWidgets('every tab fits a 390-wide screen without overflow, and so do the forms and the page of a campaign', (tester) async {
      await _pump(tester, size: const Size(390, 2400), csv: _csv);
      expect(tester.takeException(), isNull);
      for (final t in ['campaigns', 'performance', 'creatives', 'budget', 'leads', 'reports', 'overview']) {
        await _tap(tester, 'hub_tab_$t'); // the pills scroll sideways on a phone
        expect(tester.takeException(), isNull, reason: t);
      }
      await _tap(tester, 'hub_tab_campaigns');
      await _tapRow(tester, 'cp_row_c1');
      expect(_k('det_title'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'a campaign\'s page');
      await _tap(tester, 'det_edit');
      expect(tester.takeException(), isNull, reason: 'the campaign form');
      await _tap(tester, 'cmp_cancel');
      await _tap(tester, 'det_add_ad');
      expect(tester.takeException(), isNull, reason: 'the ad form');
      await _tap(tester, 'ad_cancel');
      await _tap(tester, 'det_add_day');
      expect(tester.takeException(), isNull, reason: 'the day form');
    });

    testWidgets('the import preview fits a phone', (tester) async {
      await _pump(tester, size: const Size(390, 2400), csv: _csv);
      await _tap(tester, 'hub_import_button');
      expect(_k('imp_file_name'), findsOneWidget);
      await _tap(tester, 'imp_create_missing');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'imp_save');
      expect(_k('imp_done_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the audit\'s gaps: one source, distinct spend labels, exports, ad-level and breakdown imports, audiences, Kerala', () {
    test('the payloads read the new fields: nurture / not rated, ad figures and CRM leads, audiences, the import level and ads added', () {
      final r = HubCampaignRow.fromJson({..._row('c1'), 'nurture': 2, 'notRated': 1});
      expect([r.nurture, r.notRated, r.bookedLeads, r.bookings], [2, 1, 1, 1]);
      final a = HubAdRow.fromJson(_ad('a1', figures: 'range', leads: 3, cpl: 333.33));
      expect([a.figures, a.isLifetime, a.leads, a.cpl], ['range', false, 3, 333.33]);
      final typed = HubAdRow.fromJson(_ad('a2', figures: 'lifetime', leads: null, cpl: null));
      expect([typed.isLifetime, typed.leads, typed.cpl], [true, null, null]);
      expect(HubAdRow.fromJson(const {'id': 'x', 'name': 'y'}).isLifetime, isTrue, reason: 'an older answer without the field reads as lifetime');
      final k = AdKpis.fromJson(_adsData()['kpis'] as Map<String, dynamic>);
      expect([k.leads, k.cpl, k.lifetimeAds], [3, 500, 1]);
      final au = HubAudiences.fromJson(_audiences());
      expect([au.hasData, au.isEmpty, au.age.rows.first.segment, au.gender.dimension, au.of('placement').rows.single.costPerResult], [true, false, '25-34', 'age+gender', 87.5]);
      expect(HubAudiences.fromJson(const {}).isEmpty, isTrue);
      expect(OverviewData.fromJson(_overview()).audiences.age.rows.length, 2);
      final rep = HubImportReport.fromJson(const {'level': 'ad', 'written': 3, 'adsCreated': 2});
      expect([rep.level, rep.written, rep.adsCreated], ['ad', 3, 2]);
      expect(ImportInfo.fromJson(const {'id': 'i', 'level': 'breakdown', 'adsCreated': 0}).level, 'breakdown');
      expect(ImportGroup.fromJson(const {'name': 'A', 'ads': 2, 'segments': 5}).ads, 2);
      expect(kHubReportTypes, containsAll(['overview', 'campaign', 'performance', 'audience', 'creative', 'spend', 'lead']));
    });

    testWidgets('every tab has an Export (CSV) that downloads ITS report for the dates and brand', (tester) async {
      const tabs = {'overview': 'overview', 'campaigns': 'campaign', 'performance': 'performance', 'creatives': 'creative', 'budget': 'spend', 'leads': 'lead'};
      for (final e in tabs.entries) {
        final f = await _pump(tester, tab: e.key);
        expect(_k('hub_export_${e.value}'), findsOneWidget, reason: e.key);
        await _tap(tester, 'hub_export_${e.value}');
        expect(f.hub.reportTypes, [e.value], reason: e.key);
        expect(f.saved.single.name, 'campaign-${e.value}-report-2026-11-01_2026-11-07.csv');
        expect(f.saved.single.rows.first, ['Campaign', 'Spend (INR)'], reason: 'the columns, then the rows');
        expect(find.textContaining('saved as campaign-${e.value}-report'), findsOneWidget);
        await tester.pump(const Duration(seconds: 6)); // the note goes away, so the next tab's can show
        await tester.pumpAndSettle();
      }
      final p = await _pump(tester, tab: 'performance');
      await _tap(tester, 'hub_export_audience');
      expect(p.hub.reportTypes, ['audience'], reason: 'the Audiences section downloads the audience report');
    });

    testWidgets('a failing export says so and the button works again', (tester) async {
      final f = _FailingReport();
      final p = await _pump(tester, tab: 'budget', fake: f);
      await _tap(tester, 'hub_export_spend');
      expect(p.saved, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget, reason: 'the failure is said, in plain words');
      expect(tester.widget<OutlinedButton>(_k('hub_export_spend')).onPressed, isNotNull);
    });

    testWidgets('Budget & Spend: "Spent to Date" (budgeted, to the end of the dates) and "Spend in This Period" (all campaigns) — never two "Total Spend"s', (tester) async {
      await _pump(tester, tab: 'budget');
      expect(find.text('Total Spend'), findsNothing);
      expect(_in('bd_kpi_spent', 'Spent to Date'), findsOneWidget);
      expect(_in('bd_kpi_period', 'Spend in This Period'), findsOneWidget);
      expect(_in('bd_kpi_period', '₹2,750'), findsOneWidget, reason: 'the donut and the bars add up to it');
      expect(find.descendant(of: find.byType(MktDonut), matching: find.text('In this period')), findsOneWidget);
      expect(find.text('Spend in this period, all campaigns'), findsOneWidget);
      await _pump(tester, tab: 'budget', fake: _FakeHub()..budgetJson = _budgetData(empty: true));
      expect(_in('bd_kpi_spent', '—'), findsOneWidget, reason: 'no budgeted campaign: nothing to have spent against, not ₹0');
    });

    testWidgets('Creatives & Ads: CRM leads and cost per CRM lead beside Meta\'s results; a typed ad is marked Lifetime; the verdict legend', (tester) async {
      await _pump(tester, tab: 'creatives');
      expect(_in('ad_kpi_leads', '3'), findsOneWidget);
      expect(_in('ad_kpi_leads', 'CPL ₹500'), findsOneWidget);
      expect(_in('ad_kpi_total', '1 with lifetime figures'), findsOneWidget);
      expect(_text(tester, _k('ad_leads_a1')), '2');
      expect(_text(tester, _k('ad_cpl_a1')), '₹500');
      expect(_text(tester, _k('ad_leads_a2')), '—', reason: 'not counted: a dash, never 0');
      expect(_text(tester, _k('ad_cpl_a2')), '—');
      expect(_text(tester, _k('ad_leads_a3')), '0');
      expect(_text(tester, _k('ad_cpl_a3')), '—', reason: 'no CRM lead: no cost per lead');
      expect(_k('ad_lifetime_a2'), findsOneWidget);
      expect(_k('ad_lifetime_a1'), findsNothing, reason: 'an imported ad follows the dates');
      expect(find.descendant(of: _k('ad_row_a1'), matching: find.text('10')), findsOneWidget, reason: 'Meta\'s results stay');
      expect(_k('ad_verdict_legend'), findsOneWidget);
      for (final t in ['Top performing', 'Underperforming', 'Needs attention', 'Too early']) {
        expect(find.descendant(of: _k('ad_verdict_legend'), matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.descendant(of: _k('ad_verdict_legend'), matching: find.textContaining('110%')), findsOneWidget);
    });

    testWidgets('the campaign page lists its ads with CRM leads, and marks a typed ad Lifetime', (tester) async {
      await _pump(tester, tab: 'campaigns');
      await _tapRow(tester, 'cp_row_c1');
      expect(find.descendant(of: _k('det_ad_a1'), matching: find.textContaining('2 CRM leads · CPL ₹500')), findsOneWidget);
      expect(_k('det_ad_lifetime_a2'), findsOneWidget);
      expect(_k('det_ad_lifetime_a1'), findsNothing);
      expect(find.text('Booking value (ex-GST)'), findsOneWidget);
    });

    testWidgets('Overview: the top audiences & placements, from the imported breakdowns; none imported says how', (tester) async {
      await _pump(tester, fake: _FakeHub()..overviewJson = {..._overview(), 'audiences': _audiences(empty: true)});
      expect(find.textContaining('No audience breakdown imported yet'), findsOneWidget);
      expect(_k('ov_audiences_more'), findsNothing);
      await _pump(tester);
      expect(find.text('Top audiences & placements'), findsOneWidget);
      expect(_k('ov_audiences'), findsOneWidget);
      expect(find.descendant(of: _k('ov_audience_age'), matching: find.text('25-34')), findsOneWidget);
      expect(find.descendant(of: _k('ov_audience_gender'), matching: find.text('female')), findsOneWidget);
      expect(find.descendant(of: _k('ov_audience_placement'), matching: find.text('Instagram · Reels')), findsOneWidget);
      expect(find.descendant(of: _k('ov_audience_placement_Instagram · Reels'), matching: find.text('8 results · ₹87.5 per result')), findsOneWidget);
      expect(find.textContaining('the CRM does not record a lead\'s age or placement'), findsOneWidget);
      await _tap(tester, 'ov_audiences_more');
      expect(_k('hub_performance_list'), findsOneWidget, reason: 'View all opens Performance');
    });

    testWidgets('Performance: the audiences & placements table switches between age, gender and placement; none imported says how', (tester) async {
      await _pump(tester, tab: 'performance');
      expect(_k('hp_audience_table_age'), findsOneWidget);
      expect(find.descendant(of: _k('hp_audience_age_25-34'), matching: find.text('60%')), findsOneWidget, reason: 'its share of the spend');
      expect(find.descendant(of: _k('hp_audience_age_18-24'), matching: find.text('—')), findsOneWidget, reason: 'no results: no cost per result');
      await _tap(tester, 'hp_aud_gender');
      expect(_k('hp_audience_table_gender'), findsOneWidget);
      expect(find.text('Read from the age and gender file.'), findsOneWidget);
      await _tap(tester, 'hp_aud_placement');
      expect(_k('hp_audience_placement_Instagram · Reels'), findsOneWidget);
      await _pump(tester, tab: 'performance', fake: _FakeHub()..audiencesJson = _audiences(empty: true));
      expect(find.textContaining('No audience breakdown imported yet'), findsOneWidget);
    });

    testWidgets('Leads & Conversions: Hot, Warm, Nurture, Cold — and "Not rated" only when some lead has no priority; booking value is ex-GST', (tester) async {
      await _pump(tester, tab: 'leads');
      expect(_in('ld_quality_Nurture', 'Nurture 1'), findsOneWidget);
      expect(_in('ld_quality_Cold', 'Cold 1'), findsOneWidget);
      expect(_in('ld_quality_Not_rated', 'Not rated 1'), findsOneWidget);
      expect(_in('ld_kpi_value', 'Booking Value (ex-GST)'), findsOneWidget);
      expect(find.text('Booking value (ex-GST)'), findsOneWidget, reason: 'the table column says it too');
      await _pump(tester, tab: 'leads', fake: _FakeHub()..leadsJson = {..._leadsData(), 'quality': {'Hot': 1, 'Warm': 3, 'Nurture': 0, 'Cold': 1}});
      expect(_k('ld_quality_Not_rated'), findsNothing);
      expect(_in('ld_quality_Nurture', 'Nurture 0'), findsOneWidget, reason: 'Nurture is always a bucket');
    });

    testWidgets('a new campaign is Kerala for All brands and for Kerala; Main only when Main is being looked at', (tester) async {
      await _pump(tester);
      await _tap(tester, 'hub_new_campaign');
      expect(tester.widget<DropdownButtonFormField<String>>(_k('cmp_brand')).initialValue, 'kerala');
      await _tap(tester, 'cmp_cancel');
      await _pick(tester, 'team_brand_pill', 'Main');
      await _tap(tester, 'hub_new_campaign');
      expect(tester.widget<DropdownButtonFormField<String>>(_k('cmp_brand')).initialValue, 'main');
      expect(defaultBrandFor('all'), 'kerala');
      expect(defaultBrandFor('kerala'), 'kerala');
      expect(defaultBrandFor('main'), 'main');
    });
  });

  group('ad-level and breakdown exports from Ads Manager', () {
    Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));
    const adCsv = 'Day,Campaign name,Campaign ID,Ad set name,Ad set ID,Ad name,Ad ID,Amount spent (INR),Reach,Impressions,Link clicks,Results\n'
        '2026-11-02,Bridal Campaign – Nov,1203001,Brides 22–35,8001,Reel #17,9001,700,4000,6000,150,7\n'
        '2026-11-02,Bridal Campaign – Nov,1203001,Brides 22–35,8001,Static B,9002,300,1000,2000,50,3\n'
        '2026-11-02,Bridal Campaign – Nov,1203001,Brides 22–35,8001,Reel #17,9001,100,100,200,10,1\n'
        '2026-11-03,Bridal Campaign – Nov,1203001,,,,,1000,5000,8000,200,10\n';
    const ageCsv = 'Day,Campaign name,Ad name,Age,Gender,Amount spent (INR),Impressions,Results\n'
        '2026-11-02,Bridal,Reel 1,25-34,female,600,5000,6\n'
        '2026-11-02,Bridal,Static,25-34,female,100,1000,1\n'
        '2026-11-02,Bridal,Reel 1,18-24,female,300,2000,3\n'
        '2026-11-02,Bridal,,,,50,100,0\n';

    test('an ad-level export is read as one row per ad per day: ad and ad set with their IDs; the same ad\'s day is added; a total row is left out', () {
      final e = parseMetaExport(bytes(adCsv), 'ads.csv');
      expect(e.level, MetaLevel.ad);
      expect(e.rows.length, 2);
      expect(e.ads, 2);
      expect(e.campaigns, 1);
      final reel = e.rows.firstWhere((r) => r['adId'] == '9001');
      expect(reel, {'campaign': 'Bridal Campaign – Nov', 'campaignId': '1203001', 'day': '2026-11-02', 'spend': 800.0, 'reach': 4100, 'impressions': 6200, 'clicks': 160, 'results': 8, 'ad': 'Reel #17', 'adId': '9001', 'adSet': 'Brides 22–35', 'adSetId': '8001'});
      expect(e.skipped, 1);
      expect(e.warnings.single, contains('no ad name or ad ID'));
    });

    test('a breakdown export (age / gender, platform / placement) is one row per segment per day; its ads are added together; a row with no segment is left out', () {
      final e = parseMetaExport(bytes(ageCsv), 'age.csv');
      expect(e.level, MetaLevel.breakdown, reason: 'a breakdown column wins over the ad columns');
      expect(e.rows.length, 2);
      final top = e.rows.firstWhere((r) => r['age'] == '25-34');
      expect(top, {'campaign': 'Bridal', 'day': '2026-11-02', 'spend': 700.0, 'reach': 0, 'impressions': 6000, 'clicks': 0, 'results': 7, 'age': '25-34', 'gender': 'female'});
      expect(e.rows.any((r) => r.containsKey('ad')), isFalse);
      expect(e.warnings.single, contains('no age, gender or placement'));
      final p = parseMetaExport(bytes('Day,Campaign name,Platform,Placement,Amount spent (INR),Impressions\n2026-11-02,Bridal,Instagram,Reels,700,6000\n2026-11-02,Bridal,Facebook,Feed,300,2000\n'), 'p.csv');
      expect(p.level, MetaLevel.breakdown);
      expect(p.rows.map((r) => '${r['platform']} / ${r['position']}'), ['Instagram / Reels', 'Facebook / Feed']);
      expect(parseMetaExport(bytes(_csv), 'x.csv').level, MetaLevel.campaign, reason: 'the usual export is unchanged');
      expect(importUnit('breakdown', 2), 'audience segments');
      expect(importUnit('ad', 1), 'ad-day');
      expect(importUnit('campaign', 3), 'campaign-days');
    });

    test('a big file goes in parts of at most 250 rows AND under 90 KB each (express.json takes 100 KB); nothing is lost or reordered', () {
      final small = [for (var i = 0; i < 600; i++) {'campaign': 'A', 'day': '2026-11-02', 'spend': i}];
      expect(chunkImportRows(small).map((c) => c.length), [250, 250, 100]);
      final wide = [
        for (var i = 0; i < 600; i++)
          {'campaign': 'Bridal Campaign – Nov ${'x' * 150}', 'campaignId': '120211234567890123', 'day': '2026-11-02', 'spend': 1234.56, 'reach': 12345, 'impressions': 23456, 'clicks': 345, 'results': 12, 'ad': 'Reel ${'y' * 150} $i', 'adId': '120211234567890$i', 'adSet': 'Brides 22–35 ${'z' * 100}', 'adSetId': '120211234567890124'},
      ];
      final parts = chunkImportRows(wide, overhead: 600 + 'ads.csv'.length);
      expect(parts.length, greaterThan(3), reason: 'wide rows make smaller parts than 250');
      for (final part in parts) {
        expect(part.length, lessThanOrEqualTo(kImportChunk));
        final body = utf8.encode(jsonEncode({'level': 'ad', 'rows': part, 'createMissing': true, 'brand': 'kerala', 'dryRun': false, 'fileName': 'ads.csv', 'importId': '64b7f0c2a1b2c3d4e5f60718'}));
        expect(body.length, lessThan(100 * 1024));
        expect(body.length, lessThanOrEqualTo(kImportChunkBytes));
      }
      expect([for (final p in parts) ...p], wide, reason: 'every row, in order');
      expect(chunkImportRows([{'campaign': 'x' * 200000, 'day': 'd'}]).length, 1, reason: 'one huge row still goes (the server refuses it in words), never a loop');
      expect(chunkImportRows([]), isEmpty);
    });

    testWidgets('importing an ad-level file: the preview says what the file is; it is sent as level "ad"; the result counts ad-days and the ads added', (tester) async {
      final f = _FakeHub()..importJson = {'dryRun': false, 'level': 'ad', 'rows': 2, 'skipped': 0, 'skippedRows': [], 'matched': [], 'unmatched': [], 'created': 0, 'written': 2, 'adsCreated': 2, 'importId': 'imp1', 'from': '2026-11-02', 'to': '2026-11-02'};
      await _pump(tester, csv: adCsv, csvName: 'ads.csv', fake: f);
      await _tap(tester, 'hub_import_button');
      expect(_text(tester, _k('imp_summary')), startsWith('2 ad-days · 2 ads · 1 campaign'));
      expect(_text(tester, _k('imp_level')), 'One row per ad per day (an ad-level export)');
      await _tap(tester, 'imp_save');
      expect(f.imports.map((i) => i.level).toSet(), {'ad'}, reason: 'the check and the import both say what the rows are');
      expect(f.imports.last.rows.first.containsKey('adId'), isTrue);
      expect(_text(tester, _k('imp_done_title')), 'Imported 2 ad-days.');
      expect(_text(tester, _k('imp_done_ads_created')), '2 ads added to their campaigns (they were not in the CRM yet).');
      expect(find.textContaining('Creatives & Ads'), findsWidgets);
    });

    testWidgets('importing a breakdown file: sent as level "breakdown", the result counts audience segments', (tester) async {
      final f = _FakeHub()..importJson = {'dryRun': false, 'level': 'breakdown', 'rows': 2, 'skipped': 0, 'skippedRows': [], 'matched': [], 'unmatched': [], 'created': 0, 'written': 2, 'importId': 'imp1', 'from': '2026-11-02', 'to': '2026-11-02'};
      await _pump(tester, csv: ageCsv, csvName: 'age.csv', fake: f);
      await _tap(tester, 'hub_import_button');
      expect(_text(tester, _k('imp_summary')), startsWith('2 audience segments · 1 campaign'));
      expect(_k('imp_warnings'), findsOneWidget, reason: 'the total row with no segment is explained');
      await _tap(tester, 'imp_save');
      expect(f.imports.map((i) => i.level).toSet(), {'breakdown'});
      expect(_text(tester, _k('imp_done_title')), 'Imported 2 audience segments.');
      expect(_k('imp_done_ads_created'), findsNothing);
    });
  });
}
