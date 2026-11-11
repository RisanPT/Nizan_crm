// Sales Dashboard (redesigned) — every number comes from the server
// (GET /api/dashboard/sales-overview, salesOverviewController.js), so the
// screen can't disagree with the Sales EOD, the enquiry check or Sales
// Targets. Bookings count on the day they were made; order value is the
// complete value (package + add-ons, no discount deducted).

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
Map<String, dynamic> _m(Object? v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
List<Map<String, dynamic>> _l(Object? v) =>
    [for (final x in (v as List? ?? const [])) if (x is Map) x.cast<String, dynamic>()];

class OverviewKpis {
  /// Team manual count over the days that have one; null = none entered.
  final int? enquiries;
  final int enquiryDays;
  final int days;
  final int savedOnCountDays;
  final int notSaved;
  final int leads;
  final int converted;
  final int bookings;
  final double orderValue;
  final double avgOrderValue;
  final double advance;
  final double collected;
  final double outstanding;
  final double conversion;

  /// 'enquiries' or 'leads' — what [conversion] divides by.
  final String conversionBasis;

  const OverviewKpis({
    this.enquiries,
    this.enquiryDays = 0,
    this.days = 0,
    this.savedOnCountDays = 0,
    this.notSaved = 0,
    this.leads = 0,
    this.converted = 0,
    this.bookings = 0,
    this.orderValue = 0,
    this.avgOrderValue = 0,
    this.advance = 0,
    this.collected = 0,
    this.outstanding = 0,
    this.conversion = 0,
    this.conversionBasis = 'leads',
  });

  double get received => advance + collected;

  factory OverviewKpis.fromJson(Map<String, dynamic> j) => OverviewKpis(
        enquiries: (j['enquiries'] as num?)?.toInt(),
        enquiryDays: _i(j['enquiryDays']),
        days: _i(j['days']),
        savedOnCountDays: _i(j['savedOnCountDays']),
        notSaved: _i(j['notSaved']),
        leads: _i(j['leads']),
        converted: _i(j['converted']),
        bookings: _i(j['bookings']),
        orderValue: _d(j['orderValue']),
        avgOrderValue: _d(j['avgOrderValue']),
        advance: _d(j['advance']),
        collected: _d(j['collected']),
        outstanding: _d(j['outstanding']),
        conversion: _d(j['conversion']),
        conversionBasis: '${j['conversionBasis'] ?? 'leads'}',
      );
}

class OverviewTarget {
  final int month;
  final int year;
  final String scope; // 'team' | 'person'
  final int bookingsTarget;
  final int bookings;
  final double valueTarget;
  final double value;
  final int workingDays;
  final int workingDaysElapsed;
  final double expectedBookings;
  final double expectedValue;

  const OverviewTarget({
    this.month = 1,
    this.year = 2026,
    this.scope = 'team',
    this.bookingsTarget = 0,
    this.bookings = 0,
    this.valueTarget = 0,
    this.value = 0,
    this.workingDays = 0,
    this.workingDaysElapsed = 0,
    this.expectedBookings = 0,
    this.expectedValue = 0,
  });

  bool get hasTarget => bookingsTarget > 0 || valueTarget > 0;

  factory OverviewTarget.fromJson(Map<String, dynamic> j) => OverviewTarget(
        month: _i(j['month']),
        year: _i(j['year']),
        scope: '${j['scope'] ?? 'team'}',
        bookingsTarget: _i(j['bookingsTarget']),
        bookings: _i(j['bookings']),
        valueTarget: _d(j['valueTarget']),
        value: _d(j['value']),
        workingDays: _i(j['workingDays']),
        workingDaysElapsed: _i(j['workingDaysElapsed']),
        expectedBookings: _d(j['expectedBookings']),
        expectedValue: _d(j['expectedValue']),
      );
}

class OverviewFunnel {
  final int leads, contacted, followUp, qualified, converted, lost;
  const OverviewFunnel({
    this.leads = 0,
    this.contacted = 0,
    this.followUp = 0,
    this.qualified = 0,
    this.converted = 0,
    this.lost = 0,
  });
  factory OverviewFunnel.fromJson(Map<String, dynamic> j) => OverviewFunnel(
        leads: _i(j['leads']),
        contacted: _i(j['contacted']),
        followUp: _i(j['followUp']),
        qualified: _i(j['qualified']),
        converted: _i(j['converted']),
        lost: _i(j['lost']),
      );
}

class OverviewSource {
  final String channel;
  final int enquiries, saved, notSaved, leads, converted, bookings;
  final double orderValue, conversion;
  const OverviewSource({
    required this.channel,
    this.enquiries = 0,
    this.saved = 0,
    this.notSaved = 0,
    this.leads = 0,
    this.converted = 0,
    this.bookings = 0,
    this.orderValue = 0,
    this.conversion = 0,
  });
  bool get isEmpty => enquiries == 0 && saved == 0 && leads == 0 && bookings == 0;
  factory OverviewSource.fromJson(Map<String, dynamic> j) => OverviewSource(
        channel: '${j['channel'] ?? ''}',
        enquiries: _i(j['enquiries']),
        saved: _i(j['saved']),
        notSaved: _i(j['notSaved']),
        leads: _i(j['leads']),
        converted: _i(j['converted']),
        bookings: _i(j['bookings']),
        orderValue: _d(j['orderValue']),
        conversion: _d(j['conversion']),
      );
}

class OverviewDay {
  final String day; // YYYY-MM-DD
  final int? enquiries; // null = no team count that day
  final int saved, leads, bookings;
  final double orderValue;
  const OverviewDay({
    required this.day,
    this.enquiries,
    this.saved = 0,
    this.leads = 0,
    this.bookings = 0,
    this.orderValue = 0,
  });
  DateTime get date => DateTime.tryParse(day) ?? DateTime(2000);
  factory OverviewDay.fromJson(Map<String, dynamic> j) => OverviewDay(
        day: '${j['day'] ?? ''}',
        enquiries: (j['enquiries'] as num?)?.toInt(),
        saved: _i(j['saved']),
        leads: _i(j['leads']),
        bookings: _i(j['bookings']),
        orderValue: _d(j['orderValue']),
      );
}

class OverviewPerson {
  final String id, name, role;
  final int leads, converted, calls, followUps, overdueFollowUps, bookings;
  final double orderValue;
  final double monthValueTarget, monthValue;
  final int monthBookingsTarget, monthBookings;
  const OverviewPerson({
    required this.id,
    required this.name,
    this.role = '',
    this.leads = 0,
    this.converted = 0,
    this.calls = 0,
    this.followUps = 0,
    this.overdueFollowUps = 0,
    this.bookings = 0,
    this.orderValue = 0,
    this.monthValueTarget = 0,
    this.monthValue = 0,
    this.monthBookingsTarget = 0,
    this.monthBookings = 0,
  });
  factory OverviewPerson.fromJson(Map<String, dynamic> j) {
    final t = _m(j['monthTarget']);
    return OverviewPerson(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? 'Unknown'}',
      role: '${j['role'] ?? ''}',
      leads: _i(j['leads']),
      converted: _i(j['converted']),
      calls: _i(j['calls']),
      followUps: _i(j['followUps']),
      overdueFollowUps: _i(j['overdueFollowUps']),
      bookings: _i(j['bookings']),
      orderValue: _d(j['orderValue']),
      monthValueTarget: _d(t['salesTarget']),
      monthValue: _d(t['salesValue']),
      monthBookingsTarget: _i(t['bookingsTarget']),
      monthBookings: _i(t['bookings']),
    );
  }
}

class OverviewLead {
  final String id, name, phone, source, status, assignedTo, date;
  const OverviewLead({
    required this.id,
    required this.name,
    this.phone = '',
    this.source = '',
    this.status = '',
    this.assignedTo = '',
    this.date = '',
  });
  factory OverviewLead.fromJson(Map<String, dynamic> j) => OverviewLead(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? 'Lead'}',
        phone: '${j['phone'] ?? ''}',
        source: '${j['source'] ?? ''}',
        status: '${j['status'] ?? ''}',
        assignedTo: '${j['assignedTo'] ?? ''}',
        date: '${j['date'] ?? ''}',
      );
}

class SalesOverview {
  final String from, to;
  final bool selfScoped;
  final String? salesPersonId;
  final OverviewKpis kpis;
  final int prevLeads, prevBookings;
  final double prevOrderValue;
  final int alertNotSaved, alertOverdue;
  final bool todayCountEntered;
  final OverviewTarget target;
  final OverviewFunnel funnel;
  final List<OverviewSource> sources;
  final int directBookings;
  final double directOrderValue;
  final List<OverviewDay> trend;
  final List<OverviewPerson> team;
  final int othersBookings;
  final double othersOrderValue;
  final List<OverviewLead> recentLeads;
  final List<({String id, String name})> salespeople;

  const SalesOverview({
    required this.from,
    required this.to,
    this.selfScoped = false,
    this.salesPersonId,
    this.kpis = const OverviewKpis(),
    this.prevLeads = 0,
    this.prevBookings = 0,
    this.prevOrderValue = 0,
    this.alertNotSaved = 0,
    this.alertOverdue = 0,
    this.todayCountEntered = false,
    this.target = const OverviewTarget(),
    this.funnel = const OverviewFunnel(),
    this.sources = const [],
    this.directBookings = 0,
    this.directOrderValue = 0,
    this.trend = const [],
    this.team = const [],
    this.othersBookings = 0,
    this.othersOrderValue = 0,
    this.recentLeads = const [],
    this.salespeople = const [],
  });

  factory SalesOverview.fromJson(Map<String, dynamic> j) {
    final range = _m(j['range']);
    final prev = _m(j['previous']);
    final alerts = _m(j['alerts']);
    final direct = _m(j['direct']);
    final others = _m(j['othersCredited']);
    return SalesOverview(
      from: '${range['from'] ?? ''}',
      to: '${range['to'] ?? ''}',
      selfScoped: j['selfScoped'] == true,
      salesPersonId: j['salesPersonId'] as String?,
      kpis: OverviewKpis.fromJson(_m(j['kpis'])),
      prevLeads: _i(prev['leads']),
      prevBookings: _i(prev['bookings']),
      prevOrderValue: _d(prev['orderValue']),
      alertNotSaved: _i(alerts['notSaved']),
      alertOverdue: _i(alerts['overdueFollowUps']),
      todayCountEntered: alerts['todayCountEntered'] == true,
      target: OverviewTarget.fromJson(_m(j['target'])),
      funnel: OverviewFunnel.fromJson(_m(j['funnel'])),
      sources: [for (final s in _l(j['sources'])) OverviewSource.fromJson(s)],
      directBookings: _i(direct['bookings']),
      directOrderValue: _d(direct['orderValue']),
      trend: [for (final d in _l(j['trend'])) OverviewDay.fromJson(d)],
      team: [for (final p in _l(j['team'])) OverviewPerson.fromJson(p)],
      othersBookings: _i(others['bookings']),
      othersOrderValue: _d(others['orderValue']),
      recentLeads: [for (final l in _l(j['recentLeads'])) OverviewLead.fromJson(l)],
      salespeople: [
        for (final p in _l(j['salespeople'])) (id: '${p['id'] ?? ''}', name: '${p['name'] ?? ''}'),
      ],
    );
  }
}
