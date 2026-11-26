// The Lead Report's payloads (backend controllers/marketingLeadReportController.js). The leads are the CRM's own; every number is
// defined once on the server (utils/marketingLeadReportStats.js; bookings, booking value, qualified, spend and cost per lead in
// utils/marketingOutcomes.js — the same as the Campaigns hub). A missing part parses to an empty value, never a crash.
//
//  • A BOOKING is a lead linked to a live booking (one per lead). The stage "Converted" is the CRM status — a Converted lead whose booking
//    was cancelled is in the Converted stage but is not a booking. Conversion rate = bookings ÷ leads.
//  • Spend and cost per lead are the ad spend of the days IN the range (the Campaigns hub's daily records), never a lifetime figure.

import 'package:nizan_crm/features/marketing/data/lead_speed_models.dart';

export 'package:nizan_crm/features/marketing/data/lead_speed_models.dart' show FirstContact;

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
Map<String, double?> _changes(dynamic v) => _m(v).map((k, val) => MapEntry(k, _dn(val)));

/// The four stages the pipeline groups the CRM's statuses into.
const kLeadStages = [
  ('new', 'New'),
  ('in_progress', 'In Progress'),
  ('not_converted', 'Not Converted'),
  ('converted', 'Converted'),
];
String leadStageLabel(String key) => kLeadStages.firstWhere((s) => s.$1 == key, orElse: () => (key, key)).$2;

/// The headline figures of a range. [converted] is the CRM stage; [bookings] are the leads linked to a live booking (conversion rate =
/// bookings ÷ leads). [change]: counts in percent, conversionRate in percentage points; null = nothing to compare.
class LeadKpis {
  const LeadKpis({
    this.total = 0, this.newLeads = 0, this.inProgress = 0, this.notConverted = 0, this.converted = 0, this.qualified = 0, this.hot = 0, this.conversionRate,
    this.bookings = 0, this.bookingValue = 0, this.orderValue = 0, this.unvalued = 0, this.change = const {},
  });
  final int total, newLeads, inProgress, notConverted, converted, qualified, hot, bookings, unvalued;
  final double? conversionRate;
  final double bookingValue, orderValue;
  final Map<String, double?> change;
  factory LeadKpis.fromJson(Map<String, dynamic> j) => LeadKpis(
        total: _i(j['total']),
        newLeads: _i(j['new']),
        inProgress: _i(j['inProgress']),
        notConverted: _i(j['notConverted']),
        converted: _i(j['converted']),
        qualified: _i(j['qualified']),
        hot: _i(j['hot']),
        conversionRate: _dn(j['conversionRate']),
        bookings: _i(j['bookings']),
        bookingValue: _d(j['bookingValue']),
        orderValue: _d(j['orderValue']),
        unvalued: _i(j['unvalued']),
        change: _changes(j['change']),
      );
}

class FunnelStep {
  const FunnelStep({required this.key, required this.label, this.count = 0, this.pct});
  final String key, label;
  final int count;
  final double? pct;
  factory FunnelStep.fromJson(Map<String, dynamic> j) => FunnelStep(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _dn(j['pct']));
}

class Funnel {
  const Funnel({this.total = 0, this.steps = const []});
  final int total;
  final List<FunnelStep> steps;
  factory Funnel.fromJson(Map<String, dynamic> j) => Funnel(total: _i(j['total']), steps: _l(j['steps']).map(FunnelStep.fromJson).toList());
}

class SourceGroup {
  const SourceGroup({required this.key, required this.label, this.count = 0, this.pct, this.change});
  final String key, label;
  final int count;
  final double? pct;
  final int? change;
  factory SourceGroup.fromJson(Map<String, dynamic> j) => SourceGroup(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _dn(j['pct']), change: _in(j['change']));
}

class SourceBlock {
  const SourceBlock({this.total = 0, this.groups = const []});
  final int total;
  final List<SourceGroup> groups;
  factory SourceBlock.fromJson(Map<String, dynamic> j) => SourceBlock(total: _i(j['total']), groups: _l(j['groups']).map(SourceGroup.fromJson).toList());
}

/// One source with its leads, qualified, hot, bookings and conversion rate.
class SourceRow {
  const SourceRow({required this.key, required this.label, this.leads = 0, this.qualified = 0, this.hot = 0, this.bookings = 0, this.rate, this.share, this.bookingValue = 0, this.unvalued = 0});
  final String key, label;
  final int leads, qualified, hot, bookings, unvalued;
  final double? rate, share;
  final double bookingValue;
  factory SourceRow.fromJson(Map<String, dynamic> j) => SourceRow(
        key: _s(j['key']),
        label: _s(j['label']),
        leads: _i(j['leads']),
        qualified: _i(j['qualified']),
        hot: _i(j['hot']),
        bookings: _i(j['bookings']),
        rate: _dn(j['rate']),
        share: _dn(j['share']),
        bookingValue: _d(j['bookingValue']),
        unvalued: _i(j['unvalued']),
      );
}

class SourceConversion {
  const SourceConversion({required this.key, required this.label, this.leads = 0, this.bookings = 0, this.rate});
  final String key, label;
  final int leads, bookings;
  final double? rate;
  factory SourceConversion.fromJson(Map<String, dynamic> j) => SourceConversion(key: _s(j['key']), label: _s(j['label']), leads: _i(j['leads']), bookings: _i(j['bookings']), rate: _dn(j['rate']));
}

/// Leads by Campaign Type (lead gen / WhatsApp / website form / calls / others) — the campaign leads of the range, from the campaign's
/// objective and the lead's source: the same split as the Campaigns hub's Overview.
class CampaignTypeRow {
  const CampaignTypeRow({required this.key, required this.label, this.leads = 0, this.pct = 0});
  final String key, label;
  final int leads;
  final int pct;
  factory CampaignTypeRow.fromJson(Map<String, dynamic> j) => CampaignTypeRow(key: _s(j['key']), label: _s(j['label']), leads: _i(j['leads']), pct: _i(j['pct']));
}
List<CampaignTypeRow> _types(dynamic v) => _l(v).map(CampaignTypeRow.fromJson).toList();

/// The follow-up cards: due = overdue + today + upcoming (pending in the range); total = due + completed; overdueBefore = still-overdue ones from before the range.
class FollowUpCounts {
  const FollowUpCounts({this.due = 0, this.today = 0, this.overdue = 0, this.upcoming = 0, this.completed = 0, this.total = 0, this.overdueBefore = 0, this.change = const {}});
  final int due, today, overdue, upcoming, completed, total, overdueBefore;
  final Map<String, double?> change;
  factory FollowUpCounts.fromJson(Map<String, dynamic> j) => FollowUpCounts(
        due: _i(j['due']),
        today: _i(j['today']),
        overdue: _i(j['overdue']),
        upcoming: _i(j['upcoming']),
        completed: _i(j['completed']),
        total: _i(j['total']),
        overdueBefore: _i(j['overdueBefore']),
        change: _changes(j['change']),
      );
}

/// Leads that arrived in one bucket (a day, or a week for long ranges), by the stage they are in now, and how many are booked.
class TrendRow {
  const TrendRow({required this.from, required this.to, this.leads = 0, this.newLeads = 0, this.inProgress = 0, this.notConverted = 0, this.converted = 0, this.qualified = 0, this.bookings = 0});
  final String from, to;
  final int leads, newLeads, inProgress, notConverted, converted, qualified, bookings;
  factory TrendRow.fromJson(Map<String, dynamic> j) => TrendRow(
        from: _s(j['from']),
        to: _s(j['to']),
        leads: _i(j['leads']),
        newLeads: _i(j['new']),
        inProgress: _i(j['inProgress']),
        notConverted: _i(j['notConverted']),
        converted: _i(j['converted']),
        qualified: _i(j['qualified']),
        bookings: _i(j['bookings']),
      );
}

class LeadTrend {
  const LeadTrend({this.granularity = 'day', this.rows = const []});
  final String granularity;
  final List<TrendRow> rows;
  factory LeadTrend.fromJson(Map<String, dynamic> j) => LeadTrend(granularity: _s(j['granularity']).isEmpty ? 'day' : _s(j['granularity']), rows: _l(j['rows']).map(TrendRow.fromJson).toList());
  bool get hasLeads => rows.any((r) => r.leads > 0);
}

/// A campaign's leads of the range with their bookings and value, and its cost IN THE RANGE: [spend] is the ad spend of the days in the
/// range (null = none recorded, or hidden from a territory-scoped viewer); cost per lead / booking divide it by the range's leads / bookings.
class CampaignRow {
  const CampaignRow({
    required this.id, required this.title, this.channel = '', this.brand = '', this.leads = 0, this.qualified = 0, this.bookings = 0, this.rate, this.bookingValue = 0, this.spend,
    this.costPerLead, this.costPerBooking,
  });
  final String id, title, channel, brand;
  final int leads, qualified, bookings;
  final double? rate, spend, costPerLead, costPerBooking;
  final double bookingValue;
  factory CampaignRow.fromJson(Map<String, dynamic> j) => CampaignRow(
        id: _s(j['id']),
        title: _s(j['title']),
        channel: _s(j['channel']),
        brand: _s(j['brand']),
        leads: _i(j['leads']),
        qualified: _i(j['qualified']),
        bookings: _i(j['bookings']),
        rate: _dn(j['rate']),
        bookingValue: _d(j['bookingValue']),
        spend: _dn(j['spend']),
        costPerLead: _dn(j['costPerLead']),
        costPerBooking: _dn(j['costPerBooking']),
      );
}

/// The overall cost of the range: ALL the brand's ad spend in the range ÷ the campaign leads (and bookings) of the range — exactly the
/// Campaigns hub's cost per lead. null where nothing is known.
class CampaignCosts {
  const CampaignCosts({this.campaignsWithSpend = 0, this.campaignsTotal = 0, this.adSpend, this.leads = 0, this.bookings = 0, this.costPerLead, this.costPerBooking});
  final int campaignsWithSpend, campaignsTotal, leads, bookings;
  final double? adSpend, costPerLead, costPerBooking;
  factory CampaignCosts.fromJson(Map<String, dynamic> j) => CampaignCosts(
        campaignsWithSpend: _i(j['campaignsWithSpend']),
        campaignsTotal: _i(j['campaignsTotal']),
        adSpend: _dn(j['adSpend']),
        leads: _i(j['leads']),
        bookings: _i(j['bookings']),
        costPerLead: _dn(j['costPerLead']),
        costPerBooking: _dn(j['costPerBooking']),
      );
}

class CampaignBlock {
  const CampaignBlock({this.rows = const [], this.untagged = 0, this.costs = const CampaignCosts()});
  final List<CampaignRow> rows;
  final int untagged;
  final CampaignCosts costs;
  factory CampaignBlock.fromJson(Map<String, dynamic> j) => CampaignBlock(rows: _l(j['rows']).map(CampaignRow.fromJson).toList(), untagged: _i(j['untagged']), costs: CampaignCosts.fromJson(_m(j['costs'])));
}

class LeadOverview {
  const LeadOverview({this.from = '', this.to = '', this.brand = 'all', this.capped = false, this.kpis = const LeadKpis(), this.funnel = const Funnel(), this.sources = const SourceBlock(), this.followUps = const FollowUpCounts(), this.trend = const LeadTrend(), this.campaigns = const CampaignBlock(), this.campaignTypes = const []});
  final String from, to, brand;
  final bool capped;
  final LeadKpis kpis;
  final Funnel funnel;
  final SourceBlock sources;
  final FollowUpCounts followUps;
  final LeadTrend trend;
  final CampaignBlock campaigns;
  final List<CampaignTypeRow> campaignTypes;
  factory LeadOverview.fromJson(Map<String, dynamic> j) => LeadOverview(
        from: _s(j['from']),
        to: _s(j['to']),
        brand: _s(j['brand']).isEmpty ? 'all' : _s(j['brand']),
        capped: j['capped'] == true,
        kpis: LeadKpis.fromJson(_m(j['kpis'])),
        funnel: Funnel.fromJson(_m(j['funnel'])),
        sources: SourceBlock.fromJson(_m(j['sources'])),
        followUps: FollowUpCounts.fromJson(_m(j['followUps'])),
        trend: LeadTrend.fromJson(_m(j['trend'])),
        campaigns: CampaignBlock.fromJson(_m(j['campaigns'])),
        campaignTypes: _types(j['campaignTypes']),
      );
}

// ── All Leads ────────────────────────────────────────────────────────────────────────────────────────────────────────────

class LeadRow {
  const LeadRow({
    required this.id, this.shortId = '', this.name = '', this.phone = '', this.phoneMasked = '', this.source = '', this.sourceLabel = '', this.campaign = '', this.campaignId = '', this.assignedTo = '', this.assignedToId = '',
    this.status = 'New', this.stage = 'new', this.priority = kNotRated, this.createdDay = '', this.createdAt,
  });
  final String id, shortId, name, phone, phoneMasked, source, sourceLabel, campaign, campaignId, assignedTo, assignedToId, status, stage, priority, createdDay;
  final DateTime? createdAt;
  factory LeadRow.fromJson(Map<String, dynamic> j) => LeadRow(
        id: _s(j['id']),
        shortId: _s(j['shortId']),
        name: _s(j['name']),
        phone: _s(j['phone']),
        phoneMasked: _s(j['phoneMasked']),
        source: _s(j['source']),
        sourceLabel: _s(j['sourceLabel']),
        campaign: _s(j['campaign']),
        campaignId: _s(j['campaignId']),
        assignedTo: _s(j['assignedTo']),
        assignedToId: _s(j['assignedToId']),
        status: _s(j['status']).isEmpty ? 'New' : _s(j['status']),
        stage: _s(j['stage']).isEmpty ? 'new' : _s(j['stage']),
        priority: _s(j['priority']).isEmpty ? kNotRated : _s(j['priority']),
        createdDay: _s(j['createdDay']),
        createdAt: _dt(j['createdAt']),
      );

  /// The number to show: the real one for a manager, the masked one for everyone else (whatever the server sent).
  String contactFor(bool canContact) => canContact && phone.isNotEmpty ? phone : phoneMasked;
}

class StageCounts {
  const StageCounts({this.all = 0, this.newLeads = 0, this.inProgress = 0, this.notConverted = 0, this.converted = 0});
  final int all, newLeads, inProgress, notConverted, converted;
  factory StageCounts.fromJson(Map<String, dynamic> j) => StageCounts(all: _i(j['all']), newLeads: _i(j['new']), inProgress: _i(j['in_progress']), notConverted: _i(j['not_converted']), converted: _i(j['converted']));
  int of(String stage) => switch (stage) {
        'new' => newLeads,
        'in_progress' => inProgress,
        'not_converted' => notConverted,
        'converted' => converted,
        _ => all,
      };
}

/// One choice of the All Leads "Assigned to" / "Campaign" filters, with how many of the range's leads it has.
class LeadFilterOption {
  const LeadFilterOption({required this.id, required this.label, this.count = 0});
  final String id, label;
  final int count;
}

/// The choices of the All Leads filters: the people and campaigns of the range's leads (the server lists them).
class LeadFilterOptions {
  const LeadFilterOptions({this.assignees = const [], this.campaigns = const [], this.unassigned = 0, this.untagged = 0});
  final List<LeadFilterOption> assignees, campaigns;
  final int unassigned, untagged;
  factory LeadFilterOptions.fromJson(Map<String, dynamic> j) => LeadFilterOptions(
        assignees: _l(j['assignees']).map((a) => LeadFilterOption(id: _s(a['id']), label: _s(a['name']), count: _i(a['count']))).toList(),
        campaigns: _l(j['campaigns']).map((c) => LeadFilterOption(id: _s(c['id']), label: _s(c['title']), count: _i(c['count']))).toList(),
        unassigned: _i(j['unassigned']),
        untagged: _i(j['untagged']),
      );
}

class LeadList {
  const LeadList({this.counts = const StageCounts(), this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10, this.canContact = false, this.filters = const LeadFilterOptions()});
  final StageCounts counts;
  final List<LeadRow> items;
  final int total, page, pageSize;
  final bool canContact;
  final LeadFilterOptions filters;
  factory LeadList.fromJson(Map<String, dynamic> j) => LeadList(
        counts: StageCounts.fromJson(_m(j['counts'])),
        filters: LeadFilterOptions.fromJson(_m(j['filters'])),
        items: _l(j['items']).map(LeadRow.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) < 1 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) < 1 ? 10 : _i(j['pageSize']),
        canContact: j['canContact'] == true,
      );
}

/// How a follow-up is done (LeadActivity.channel, logged in the CRM): '' = not said.
const kFollowUpChannels = [('call', 'Call'), ('whatsapp', 'WhatsApp'), ('visit', 'Visit'), ('meeting', 'Meeting'), ('other', 'Other')];
String followUpChannelLabel(String key) => kFollowUpChannels.firstWhere((c) => c.$1 == key, orElse: () => (key, 'Follow-up')).$2;

/// The quality of a lead with no priority (shown only when some lead has none).
const kNotRated = 'Not rated';

class LeadActivityRow {
  const LeadActivityRow({required this.id, this.type = 'followup', this.channel = '', this.status = 'Pending', this.scheduledDate, this.callResponse = '', this.remark = '', this.by = ''});
  final String id, type, channel, status, callResponse, remark, by;
  final DateTime? scheduledDate;
  factory LeadActivityRow.fromJson(Map<String, dynamic> j) => LeadActivityRow(
        id: _s(j['id']),
        type: _s(j['type']),
        channel: _s(j['channel']),
        status: _s(j['status']),
        scheduledDate: _dt(j['scheduledDate']),
        callResponse: _s(j['callResponse']),
        remark: _s(j['remark']),
        by: _s(j['by']),
      );
  String get typeLabel => switch (type) { 'followup' => channel.isEmpty ? 'Follow-up' : 'Follow-up · ${followUpChannelLabel(channel)}', 'call' => 'Call', _ => 'Activity' };
}

class LeadBooking {
  const LeadBooking({this.number = '', this.status = '', this.counted = false, this.value});
  final String number, status;
  final bool counted;
  final double? value;
  factory LeadBooking.fromJson(Map<String, dynamic> j) => LeadBooking(number: _s(j['number']), status: _s(j['status']), counted: j['counted'] == true, value: _dn(j['value']));
}

/// One lead, read-only: its facts, counters, booking and follow-up history.
class LeadDetail {
  const LeadDetail({
    required this.id, this.shortId = '', this.name = '', this.phone = '', this.phoneMasked = '', this.canContact = false, this.sourceLabel = '', this.brand = 'main', this.campaign = '', this.assignedTo = '', this.status = 'New',
    this.stage = 'new', this.priority = kNotRated, this.qualified = false, this.createdAt, this.eventType = '', this.region = '', this.district = '', this.followUpDate, this.followUpState, this.followUpCount = 0,
    this.followUpCompletedCount = 0, this.reason = '', this.remarks = '', this.booking, this.activities = const [], this.firstContact,
  });

  /// Speed to lead: its first contact, or how long it has waited (null from a server without it).
  final FirstContact? firstContact;
  final String id, shortId, name, phone, phoneMasked, sourceLabel, brand, campaign, assignedTo, status, stage, priority, eventType, region, district, reason, remarks;
  final bool canContact, qualified;
  final DateTime? createdAt, followUpDate;
  final String? followUpState;
  final int followUpCount, followUpCompletedCount;
  final LeadBooking? booking;
  final List<LeadActivityRow> activities;
  factory LeadDetail.fromJson(Map<String, dynamic> j) => LeadDetail(
        id: _s(j['id']),
        shortId: _s(j['shortId']),
        name: _s(j['name']),
        phone: _s(j['phone']),
        phoneMasked: _s(j['phoneMasked']),
        canContact: j['canContact'] == true,
        sourceLabel: _s(j['sourceLabel']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        campaign: _s(j['campaign']),
        assignedTo: _s(j['assignedTo']),
        status: _s(j['status']).isEmpty ? 'New' : _s(j['status']),
        stage: _s(j['stage']).isEmpty ? 'new' : _s(j['stage']),
        priority: _s(j['priority']).isEmpty ? kNotRated : _s(j['priority']),
        qualified: j['qualified'] == true,
        createdAt: _dt(j['createdAt']),
        eventType: _s(j['eventType']),
        region: _s(j['region']),
        district: _s(j['district']),
        followUpDate: _dt(j['followUpDate']),
        followUpState: j['followUpState'] == null ? null : _s(j['followUpState']),
        followUpCount: _i(j['followUpCount']),
        followUpCompletedCount: _i(j['followUpCompletedCount']),
        firstContact: j['firstContact'] is Map ? FirstContact.fromJson(_m(j['firstContact'])) : null,
        reason: _s(j['reason']),
        remarks: _s(j['remarks']),
        booking: j['booking'] is Map ? LeadBooking.fromJson(_m(j['booking'])) : null,
        activities: _l(j['activities']).map(LeadActivityRow.fromJson).toList(),
      );
  String get contact => canContact && phone.isNotEmpty ? phone : phoneMasked;
}

/// How the All Leads list is cut: stage chip, source group, assigned to ('all' | 'unassigned' | a user id), campaign ('all' | 'none' | a
/// campaign id), search, sort and page.
class LeadListQuery {
  const LeadListQuery({this.stage = 'all', this.source = 'all', this.assignee = 'all', this.campaign = 'all', this.q = '', this.sort = 'created', this.dir = '', this.page = 1});
  final String stage, source, assignee, campaign, q, sort, dir;
  final int page;
  LeadListQuery copyWith({String? stage, String? source, String? assignee, String? campaign, String? q, String? sort, String? dir, int? page}) =>
      LeadListQuery(stage: stage ?? this.stage, source: source ?? this.source, assignee: assignee ?? this.assignee, campaign: campaign ?? this.campaign, q: q ?? this.q, sort: sort ?? this.sort, dir: dir ?? this.dir, page: page ?? 1);
  @override
  bool operator ==(Object other) =>
      other is LeadListQuery && other.stage == stage && other.source == source && other.assignee == assignee && other.campaign == campaign && other.q == q && other.sort == sort && other.dir == dir && other.page == page;
  @override
  int get hashCode => Object.hash(stage, source, assignee, campaign, q, sort, dir, page);
}

// ── Lead Stages ──────────────────────────────────────────────────────────────────────────────────────────────────────────

class StageRow {
  const StageRow({required this.key, required this.label, this.count = 0, this.pct, this.change});
  final String key, label;
  final int count;
  final double? pct, change;
  factory StageRow.fromJson(Map<String, dynamic> j) => StageRow(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _dn(j['pct']), change: _dn(j['change']));
}

class StatusRow {
  const StatusRow({required this.status, this.count = 0, this.pct});
  final String status;
  final int count;
  final double? pct;
  factory StatusRow.fromJson(Map<String, dynamic> j) => StatusRow(status: _s(j['status']), count: _i(j['count']), pct: _dn(j['pct']));
}

class QualityRow {
  const QualityRow({required this.key, this.count = 0, this.pct});
  final String key;
  final int count;
  final double? pct;
  factory QualityRow.fromJson(Map<String, dynamic> j) => QualityRow(key: _s(j['key']), count: _i(j['count']), pct: _dn(j['pct']));
}

class StagesData {
  const StagesData({this.kpis = const LeadKpis(), this.stages = const [], this.statuses = const [], this.quality = const [], this.qualityTotal = 0, this.trend = const LeadTrend()});
  final LeadKpis kpis;
  final List<StageRow> stages;
  final List<StatusRow> statuses;
  final List<QualityRow> quality;
  final int qualityTotal;
  final LeadTrend trend;
  factory StagesData.fromJson(Map<String, dynamic> j) => StagesData(
        kpis: LeadKpis.fromJson(_m(j['kpis'])),
        stages: _l(j['stages']).map(StageRow.fromJson).toList(),
        statuses: _l(j['statuses']).map(StatusRow.fromJson).toList(),
        quality: _l(_m(j['quality'])['rows']).map(QualityRow.fromJson).toList(),
        qualityTotal: _i(_m(j['quality'])['total']),
        trend: LeadTrend.fromJson(_m(j['trend'])),
      );
}

// ── Sources ──────────────────────────────────────────────────────────────────────────────────────────────────────────────

class SourcesData {
  const SourcesData({this.total = 0, this.groups = const [], this.sources = const [], this.campaigns = const CampaignBlock(), this.campaignTypes = const []});
  final int total;
  final List<SourceGroup> groups;
  final List<SourceRow> sources;
  final CampaignBlock campaigns;
  final List<CampaignTypeRow> campaignTypes;
  factory SourcesData.fromJson(Map<String, dynamic> j) => SourcesData(
        total: _i(j['total']),
        groups: _l(j['groups']).map(SourceGroup.fromJson).toList(),
        sources: _l(j['sources']).map(SourceRow.fromJson).toList(),
        campaigns: CampaignBlock.fromJson(_m(j['campaigns'])),
        campaignTypes: _types(j['campaignTypes']),
      );
}

// ── Follow-ups ───────────────────────────────────────────────────────────────────────────────────────────────────────────

const kFollowUpFilters = [('all', 'All'), ('today', 'Today'), ('overdue', 'Overdue'), ('upcoming', 'Upcoming'), ('completed', 'Completed')];

class FollowUpRow {
  const FollowUpRow({
    required this.id, this.leadId = '', this.shortId = '', this.name = '', this.phone = '', this.phoneMasked = '', this.campaign = '', this.assignedTo = '', this.kind = 'activity', this.channel = '', this.channelLabel = 'Follow-up', this.dueDay = '', this.due, this.state = 'upcoming', this.remark = '',
  });
  /// [channel]: how the follow-up is done (call / whatsapp / visit / meeting / other; '' = not said) and [channelLabel] its words.
  final String id, leadId, shortId, name, phone, phoneMasked, campaign, assignedTo, kind, channel, channelLabel, dueDay, state, remark;
  final DateTime? due;
  factory FollowUpRow.fromJson(Map<String, dynamic> j) => FollowUpRow(
        id: _s(j['id']),
        leadId: _s(j['leadId']),
        shortId: _s(j['shortId']),
        name: _s(j['name']),
        phone: _s(j['phone']),
        phoneMasked: _s(j['phoneMasked']),
        campaign: _s(j['campaign']),
        assignedTo: _s(j['assignedTo']),
        kind: _s(j['kind']),
        channel: _s(j['channel']),
        channelLabel: _s(j['channelLabel']).isEmpty ? followUpChannelLabel(_s(j['channel'])) : _s(j['channelLabel']),
        dueDay: _s(j['dueDay']),
        due: _dt(j['due']),
        state: _s(j['state']),
        remark: _s(j['remark']),
      );
}

class FollowUpList {
  const FollowUpList({this.counts = const FollowUpCounts(), this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10, this.canContact = false, this.filter = 'all'});
  final FollowUpCounts counts;
  final List<FollowUpRow> items;
  final int total, page, pageSize;
  final bool canContact;
  final String filter;
  factory FollowUpList.fromJson(Map<String, dynamic> j) => FollowUpList(
        counts: FollowUpCounts.fromJson(_m(j['counts'])),
        items: _l(j['items']).map(FollowUpRow.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) < 1 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) < 1 ? 10 : _i(j['pageSize']),
        canContact: j['canContact'] == true,
        filter: _s(j['filter']).isEmpty ? 'all' : _s(j['filter']),
      );
}

class FollowUpQuery {
  const FollowUpQuery({this.filter = 'all', this.page = 1});
  final String filter;
  final int page;
  @override
  bool operator ==(Object other) => other is FollowUpQuery && other.filter == filter && other.page == page;
  @override
  int get hashCode => Object.hash(filter, page);
}

// ── Conversion ───────────────────────────────────────────────────────────────────────────────────────────────────────────

class ConversionData {
  const ConversionData({this.kpis = const LeadKpis(), this.costs = const CampaignCosts(), this.funnel = const Funnel(), this.trend = const LeadTrend(), this.bySource = const [], this.campaignTypes = const []});
  final LeadKpis kpis;
  final CampaignCosts costs;
  final Funnel funnel;
  final LeadTrend trend;
  final List<SourceConversion> bySource;
  final List<CampaignTypeRow> campaignTypes;
  factory ConversionData.fromJson(Map<String, dynamic> j) => ConversionData(
        kpis: LeadKpis.fromJson(_m(j['kpis'])),
        costs: CampaignCosts.fromJson(_m(j['costs'])),
        funnel: Funnel.fromJson(_m(j['funnel'])),
        trend: LeadTrend.fromJson(_m(j['trend'])),
        bySource: _l(j['bySource']).map(SourceConversion.fromJson).toList(),
        campaignTypes: _types(j['campaignTypes']),
      );
}

// ── Reports ──────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// The five report cards of the Reports tab (the keys are the server's report types).
const kLeadReportCards = [
  ('summary', 'Lead Summary', 'Overall lead performance'),
  ('sources', 'Source Report', 'Channel-wise results'),
  ('campaigns', 'Campaign Report', 'Campaign-wise leads and cost'),
  ('team', 'Team Performance', 'Leads and follow-ups by person'),
  ('conversion', 'Conversion Report', 'Funnel and booking value'),
];

/// A report as a table: columns and rows (numbers stay numbers, so a spreadsheet can add them up).
class LeadReportTable {
  const LeadReportTable({required this.type, this.title = '', this.from = '', this.to = '', this.brand = 'all', this.columns = const [], this.rows = const [], this.truncated = false, this.canContact = false, this.generatedAt});
  final String type, title, from, to, brand;
  final List<String> columns;
  final List<List<Object?>> rows;
  final bool truncated, canContact;
  final DateTime? generatedAt;
  factory LeadReportTable.fromJson(Map<String, dynamic> j) => LeadReportTable(
        type: _s(j['type']),
        title: _s(j['title']),
        from: _s(j['from']),
        to: _s(j['to']),
        brand: _s(j['brand']).isEmpty ? 'all' : _s(j['brand']),
        columns: ((j['columns'] as List?) ?? const []).map((c) => c.toString()).toList(),
        rows: ((j['rows'] as List?) ?? const []).map((r) => ((r as List?) ?? const []).cast<Object?>().toList()).toList(),
        truncated: j['truncated'] == true,
        canContact: j['canContact'] == true,
        generatedAt: _dt(j['generatedAt']),
      );
}
