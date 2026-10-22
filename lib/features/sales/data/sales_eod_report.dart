// Models for the Sales End of Day (EOD) Report.

double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;
int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// Today Target vs Achieved row (Screenshot 2 - Table 1)
class EodTargetRow {
  final String metric;
  final double achievableTarget;
  final double achieved;
  final double achievementPct;
  final double shortExcess;

  const EodTargetRow({
    this.metric = '',
    this.achievableTarget = 0.0,
    this.achieved = 0.0,
    this.achievementPct = 0.0,
    this.shortExcess = 0.0,
  });

  factory EodTargetRow.fromJson(Map<String, dynamic> j) {
    return EodTargetRow(
      metric: '${j['metric'] ?? ''}',
      achievableTarget: _d(j['achievableTarget']),
      achieved: _d(j['achieved']),
      achievementPct: _d(j['achievementPct']),
      shortExcess: _d(j['shortExcess']),
    );
  }
}

/// Month-to-Date Target vs Achieved row (Screenshot 2 - Table 2)
class EodMtdTargetRow {
  final String metric;
  final double mtdTarget; // Target accumulated till that report date
  final double monthlyTarget; // Full month target
  final double mtdAchieved;
  final double mtdAchievementPct; // vs target till date
  final double fullMonthAchievementPct; // vs full month target
  final double balanceToTarget;
  final double shortExcessMtd;

  const EodMtdTargetRow({
    this.metric = '',
    this.mtdTarget = 0.0,
    this.monthlyTarget = 0.0,
    this.mtdAchieved = 0.0,
    this.mtdAchievementPct = 0.0,
    this.fullMonthAchievementPct = 0.0,
    this.balanceToTarget = 0.0,
    this.shortExcessMtd = 0.0,
  });

  factory EodMtdTargetRow.fromJson(Map<String, dynamic> j) {
    return EodMtdTargetRow(
      metric: '${j['metric'] ?? ''}',
      mtdTarget: _d(j['mtdTarget'] ?? j['monthlyTarget']),
      monthlyTarget: _d(j['monthlyTarget']),
      mtdAchieved: _d(j['mtdAchieved']),
      mtdAchievementPct: _d(j['mtdAchievementPct']),
      fullMonthAchievementPct: _d(j['fullMonthAchievementPct']),
      balanceToTarget: _d(j['balanceToTarget']),
      shortExcessMtd: _d(j['shortExcessMtd']),
    );
  }
}

/// Bookings by Source item (Screenshot 2 - Table 3)
class EodBookingSourceItem {
  final String source;
  final int today;
  final int mtd;
  final double shareOfMtd;

  const EodBookingSourceItem({
    this.source = '',
    this.today = 0,
    this.mtd = 0,
    this.shareOfMtd = 0.0,
  });

  factory EodBookingSourceItem.fromJson(Map<String, dynamic> j) {
    return EodBookingSourceItem(
      source: '${j['source'] ?? ''}',
      today: _i(j['today']),
      mtd: _i(j['mtd']),
      shareOfMtd: _d(j['shareOfMtd']),
    );
  }
}

/// Generic Today / MTD metric cell (Screenshots 2 & 3)
class EodMetricCell {
  final String label;
  final double today;
  final double mtd;
  final bool isPercentage;

  const EodMetricCell({
    this.label = '',
    this.today = 0.0,
    this.mtd = 0.0,
    this.isPercentage = false,
  });

  factory EodMetricCell.fromJson(Map<String, dynamic> j, {bool isPercentage = false}) {
    return EodMetricCell(
      label: '${j['label'] ?? j['metric'] ?? ''}',
      today: _d(j['today']),
      mtd: _d(j['mtd']),
      isPercentage: isPercentage,
    );
  }
}

/// Team Daily Ledger Row (Screenshot 1)
class SalesEodLedgerRow {
  final String userId;
  final String date;
  final String salesPersonName;
  final String role;
  final int whatsappLeads;
  final int igMainLeads;
  final int igKeralaLeads;
  final int paidAdsLeads;
  final int trialCampaignLeads;
  final int leadsContacted;
  final int followUpsDone;
  final int organicBookings;
  final int paidAdsBookings;
  final int trialBookings;
  final double totalOrderValue;
  final double advancePaid;
  final String comment;

  const SalesEodLedgerRow({
    this.userId = '',
    this.date = '',
    this.salesPersonName = '',
    this.role = '',
    this.whatsappLeads = 0,
    this.igMainLeads = 0,
    this.igKeralaLeads = 0,
    this.paidAdsLeads = 0,
    this.trialCampaignLeads = 0,
    this.leadsContacted = 0,
    this.followUpsDone = 0,
    this.organicBookings = 0,
    this.paidAdsBookings = 0,
    this.trialBookings = 0,
    this.totalOrderValue = 0.0,
    this.advancePaid = 0.0,
    this.comment = '',
  });

  factory SalesEodLedgerRow.fromJson(Map<String, dynamic> j) {
    return SalesEodLedgerRow(
      userId: '${j['userId'] ?? ''}',
      date: '${j['date'] ?? ''}',
      salesPersonName: '${j['salesPersonName'] ?? ''}',
      role: '${j['role'] ?? ''}',
      whatsappLeads: _i(j['whatsappLeads']),
      igMainLeads: _i(j['igMainLeads']),
      igKeralaLeads: _i(j['igKeralaLeads']),
      paidAdsLeads: _i(j['paidAdsLeads']),
      trialCampaignLeads: _i(j['trialCampaignLeads']),
      leadsContacted: _i(j['leadsContacted']),
      followUpsDone: _i(j['followUpsDone']),
      organicBookings: _i(j['organicBookings']),
      paidAdsBookings: _i(j['paidAdsBookings']),
      trialBookings: _i(j['trialBookings']),
      totalOrderValue: _d(j['totalOrderValue']),
      advancePaid: _d(j['advancePaid']),
      comment: '${j['comment'] ?? ''}',
    );
  }
}

class SalesEodSummary {
  final int callsMade;
  final int callsConnected;
  final int callsNoAnswer;
  final int callsBusy;
  final int followUpsCompleted;
  final int followUpsPending;
  final int newLeadsAssigned;
  final int leadsConverted;
  final int bookingsCount;
  final double totalRevenue;
  final double totalAdvance;
  final int pendingFollowUpsCount;

  const SalesEodSummary({
    this.callsMade = 0,
    this.callsConnected = 0,
    this.callsNoAnswer = 0,
    this.callsBusy = 0,
    this.followUpsCompleted = 0,
    this.followUpsPending = 0,
    this.newLeadsAssigned = 0,
    this.leadsConverted = 0,
    this.bookingsCount = 0,
    this.totalRevenue = 0.0,
    this.totalAdvance = 0.0,
    this.pendingFollowUpsCount = 0,
  });

  factory SalesEodSummary.fromJson(Map<String, dynamic> j) {
    return SalesEodSummary(
      callsMade: _i(j['callsMade']),
      callsConnected: _i(j['callsConnected']),
      callsNoAnswer: _i(j['callsNoAnswer']),
      callsBusy: _i(j['callsBusy']),
      followUpsCompleted: _i(j['followUpsCompleted']),
      followUpsPending: _i(j['followUpsPending']),
      newLeadsAssigned: _i(j['newLeadsAssigned']),
      leadsConverted: _i(j['leadsConverted']),
      bookingsCount: _i(j['bookingsCount']),
      totalRevenue: _d(j['totalRevenue']),
      totalAdvance: _d(j['totalAdvance']),
      pendingFollowUpsCount: _i(j['pendingFollowUpsCount']),
    );
  }
}

class SalesEodBooking {
  final String id;
  final String bookingNumber;
  final String customerName;
  final String phone;
  final String service;
  final double totalPrice;
  final double advanceAmount;
  final String status;
  final String source;
  final String time;

  const SalesEodBooking({
    required this.id,
    required this.bookingNumber,
    required this.customerName,
    required this.phone,
    required this.service,
    required this.totalPrice,
    required this.advanceAmount,
    required this.status,
    this.source = 'WhatsApp (Organic)',
    required this.time,
  });

  factory SalesEodBooking.fromJson(Map<String, dynamic> j) {
    return SalesEodBooking(
      id: '${j['id'] ?? ''}',
      bookingNumber: '${j['bookingNumber'] ?? ''}',
      customerName: '${j['customerName'] ?? 'Unknown'}',
      phone: '${j['phone'] ?? ''}',
      service: '${j['service'] ?? 'Service'}',
      totalPrice: _d(j['totalPrice']),
      advanceAmount: _d(j['advanceAmount']),
      status: '${j['status'] ?? 'confirmed'}',
      source: '${j['source'] ?? 'WhatsApp (Organic)'}',
      time: '${j['time'] ?? ''}',
    );
  }
}

class SalesEodActivity {
  final String id;
  final String leadName;
  final String leadPhone;
  final String type;
  final String status;
  final String callResponse;
  final String remark;
  final String userName;
  final String time;

  const SalesEodActivity({
    required this.id,
    required this.leadName,
    required this.leadPhone,
    required this.type,
    required this.status,
    required this.callResponse,
    required this.remark,
    required this.userName,
    required this.time,
  });

  factory SalesEodActivity.fromJson(Map<String, dynamic> j) {
    return SalesEodActivity(
      id: '${j['id'] ?? ''}',
      leadName: '${j['leadName'] ?? 'Lead'}',
      leadPhone: '${j['leadPhone'] ?? ''}',
      type: '${j['type'] ?? 'call'}',
      status: '${j['status'] ?? 'Completed'}',
      callResponse: '${j['callResponse'] ?? 'N/A'}',
      remark: '${j['remark'] ?? ''}',
      userName: '${j['userName'] ?? ''}',
      time: '${j['time'] ?? ''}',
    );
  }
}

class SalesEodPendingFollowUp {
  final String id;
  final String customerName;
  final String phone;
  final String followUpDate;
  final String notes;

  const SalesEodPendingFollowUp({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.followUpDate,
    required this.notes,
  });

  factory SalesEodPendingFollowUp.fromJson(Map<String, dynamic> j) {
    return SalesEodPendingFollowUp(
      id: '${j['id'] ?? ''}',
      customerName: '${j['customerName'] ?? 'Lead'}',
      phone: '${j['phone'] ?? ''}',
      followUpDate: '${j['followUpDate'] ?? ''}',
      notes: '${j['notes'] ?? ''}',
    );
  }
}

class SalesEodTeamMember {
  final String id;
  final String name;
  final String role;
  final int callsMade;
  final int callsConnected;
  final int newLeads;
  final int bookingsCount;
  final double revenue;
  final double advance;

  const SalesEodTeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.callsMade,
    required this.callsConnected,
    required this.newLeads,
    required this.bookingsCount,
    required this.revenue,
    required this.advance,
  });

  factory SalesEodTeamMember.fromJson(Map<String, dynamic> j) {
    return SalesEodTeamMember(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? 'Unknown'}',
      role: '${j['role'] ?? 'sales'}',
      callsMade: _i(j['callsMade']),
      callsConnected: _i(j['callsConnected']),
      newLeads: _i(j['newLeads']),
      bookingsCount: _i(j['bookingsCount']),
      revenue: _d(j['revenue']),
      advance: _d(j['advance']),
    );
  }
}

class SalesPersonInfo {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;

  const SalesPersonInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory SalesPersonInfo.fromJson(Map<String, dynamic> j) {
    return SalesPersonInfo(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      email: '${j['email'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      role: '${j['role'] ?? 'sales'}',
    );
  }
}

class SalesEodReport {
  final String date;
  final String reportDateFormatted;
  final String monthName;
  final String leadCountTask;
  final bool isTeam;
  final SalesPersonInfo? salesPerson;

  // Exact spreadsheet sections
  final EodTargetRow bookingsTargetToday;
  final EodTargetRow bookingValueTargetToday;
  final EodMtdTargetRow bookingsTargetMtd;
  final EodMtdTargetRow bookingValueTargetMtd;

  final EodBookingSourceItem organicBookings;
  final EodBookingSourceItem paidAdsBookings;
  final EodBookingSourceItem trialBookings;
  final EodBookingSourceItem totalBookings;

  final EodMetricCell whatsappLeads;
  final EodMetricCell igMainLeads;
  final EodMetricCell igKeralaLeads;
  final EodMetricCell paidAdsLeads;
  final EodMetricCell trialCampaignLeads;
  final EodMetricCell leadsContacted;
  final EodMetricCell followUpsDone;
  final EodMetricCell contactedToBookingPct;
  final EodMetricCell teamMissedLeads;

  final EodMetricCell trialCampaignLeadsMetric;
  final EodMetricCell trialBookingsMetric;
  final EodMetricCell trialConversionPctMetric;

  final EodMetricCell totalOrderValueMetric;
  final EodMetricCell advancePaidMetric;
  final EodMetricCell balanceDueMetric;

  // Screenshot 1: Team Daily Ledger
  final List<SalesEodLedgerRow> ledgerRows;
  final SalesEodLedgerRow? ledgerTotals;

  // General Summary & Lists
  final SalesEodSummary summary;
  final List<SalesEodBooking> bookings;
  final List<SalesEodActivity> activities;
  final List<SalesEodPendingFollowUp> pendingFollowUps;
  final List<SalesEodTeamMember> teamBreakdown;

  const SalesEodReport({
    required this.date,
    this.reportDateFormatted = '',
    this.monthName = '',
    this.leadCountTask = 'WhatsApp',
    required this.isTeam,
    this.salesPerson,
    this.bookingsTargetToday = const EodTargetRow(),
    this.bookingValueTargetToday = const EodTargetRow(),
    this.bookingsTargetMtd = const EodMtdTargetRow(),
    this.bookingValueTargetMtd = const EodMtdTargetRow(),
    this.organicBookings = const EodBookingSourceItem(),
    this.paidAdsBookings = const EodBookingSourceItem(),
    this.trialBookings = const EodBookingSourceItem(),
    this.totalBookings = const EodBookingSourceItem(),
    this.whatsappLeads = const EodMetricCell(),
    this.igMainLeads = const EodMetricCell(),
    this.igKeralaLeads = const EodMetricCell(),
    this.paidAdsLeads = const EodMetricCell(),
    this.trialCampaignLeads = const EodMetricCell(),
    this.leadsContacted = const EodMetricCell(),
    this.followUpsDone = const EodMetricCell(),
    this.contactedToBookingPct = const EodMetricCell(),
    this.teamMissedLeads = const EodMetricCell(),
    this.trialCampaignLeadsMetric = const EodMetricCell(),
    this.trialBookingsMetric = const EodMetricCell(),
    this.trialConversionPctMetric = const EodMetricCell(),
    this.totalOrderValueMetric = const EodMetricCell(),
    this.advancePaidMetric = const EodMetricCell(),
    this.balanceDueMetric = const EodMetricCell(),
    this.ledgerRows = const [],
    this.ledgerTotals,
    required this.summary,
    required this.bookings,
    required this.activities,
    required this.pendingFollowUps,
    required this.teamBreakdown,
  });

  factory SalesEodReport.fromJson(Map<String, dynamic> j) {
    final todayT = (j['todayTargetVsAchieved'] as Map?)?.cast<String, dynamic>() ?? {};
    final mtdT = (j['mtdTargetVsAchieved'] as Map?)?.cast<String, dynamic>() ?? {};
    final bSrc = (j['bookingsBySource'] as Map?)?.cast<String, dynamic>() ?? {};
    final leadsF = (j['leadsAndFollowUps'] as Map?)?.cast<String, dynamic>() ?? {};
    final trialC = (j['trialCampaign'] as Map?)?.cast<String, dynamic>() ?? {};
    final orderP = (j['orderValueAndPayments'] as Map?)?.cast<String, dynamic>() ?? {};

    return SalesEodReport(
      date: '${j['date'] ?? ''}',
      reportDateFormatted: '${j['reportDateFormatted'] ?? j['date'] ?? ''}',
      monthName: '${j['monthName'] ?? ''}',
      leadCountTask: '${j['leadCountTask'] ?? 'WhatsApp'}',
      isTeam: j['isTeam'] == true,
      salesPerson: j['salesPerson'] != null
          ? SalesPersonInfo.fromJson((j['salesPerson'] as Map).cast<String, dynamic>())
          : null,

      // Target tables
      bookingsTargetToday: todayT['bookings'] is Map
          ? EodTargetRow.fromJson((todayT['bookings'] as Map).cast<String, dynamic>())
          : const EodTargetRow(),
      bookingValueTargetToday: todayT['bookingValue'] is Map
          ? EodTargetRow.fromJson((todayT['bookingValue'] as Map).cast<String, dynamic>())
          : const EodTargetRow(),
      bookingsTargetMtd: mtdT['bookings'] is Map
          ? EodMtdTargetRow.fromJson((mtdT['bookings'] as Map).cast<String, dynamic>())
          : const EodMtdTargetRow(),
      bookingValueTargetMtd: mtdT['bookingValue'] is Map
          ? EodMtdTargetRow.fromJson((mtdT['bookingValue'] as Map).cast<String, dynamic>())
          : const EodMtdTargetRow(),

      // Bookings by Source
      organicBookings: bSrc['organic'] is Map
          ? EodBookingSourceItem.fromJson((bSrc['organic'] as Map).cast<String, dynamic>())
          : const EodBookingSourceItem(),
      paidAdsBookings: bSrc['paidAds'] is Map
          ? EodBookingSourceItem.fromJson((bSrc['paidAds'] as Map).cast<String, dynamic>())
          : const EodBookingSourceItem(),
      trialBookings: bSrc['trialBookings'] is Map
          ? EodBookingSourceItem.fromJson((bSrc['trialBookings'] as Map).cast<String, dynamic>())
          : const EodBookingSourceItem(),
      totalBookings: bSrc['totalBookings'] is Map
          ? EodBookingSourceItem.fromJson((bSrc['totalBookings'] as Map).cast<String, dynamic>())
          : const EodBookingSourceItem(),

      // Leads & Follow-ups
      whatsappLeads: leadsF['whatsappLeads'] is Map
          ? EodMetricCell.fromJson((leadsF['whatsappLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'WhatsApp Leads (Organic)'),
      igMainLeads: leadsF['igMainLeads'] is Map
          ? EodMetricCell.fromJson((leadsF['igMainLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'IG Leads — Main Page'),
      igKeralaLeads: leadsF['igKeralaLeads'] is Map
          ? EodMetricCell.fromJson((leadsF['igKeralaLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'IG Leads — Kerala Page'),
      paidAdsLeads: leadsF['paidAdsLeads'] is Map
          ? EodMetricCell.fromJson((leadsF['paidAdsLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Paid Ads Leads'),
      trialCampaignLeads: leadsF['trialCampaignLeads'] is Map
          ? EodMetricCell.fromJson((leadsF['trialCampaignLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Trial Campaign Leads'),
      leadsContacted: leadsF['leadsContacted'] is Map
          ? EodMetricCell.fromJson((leadsF['leadsContacted'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Leads Contacted'),
      followUpsDone: leadsF['followUpsDone'] is Map
          ? EodMetricCell.fromJson((leadsF['followUpsDone'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Follow-ups Done'),
      contactedToBookingPct: leadsF['contactedToBookingPct'] is Map
          ? EodMetricCell.fromJson((leadsF['contactedToBookingPct'] as Map).cast<String, dynamic>(), isPercentage: true)
          : const EodMetricCell(label: 'Contacted → Booking %', isPercentage: true),
      teamMissedLeads: leadsF['teamMissedLeads'] is Map
          ? EodMetricCell.fromJson((leadsF['teamMissedLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Team Missed Leads (IG – WhatsApp)'),

      // Trial campaign
      trialCampaignLeadsMetric: trialC['trialCampaignLeads'] is Map
          ? EodMetricCell.fromJson((trialC['trialCampaignLeads'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Trial Campaign Leads'),
      trialBookingsMetric: trialC['trialBookings'] is Map
          ? EodMetricCell.fromJson((trialC['trialBookings'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Trial Bookings'),
      trialConversionPctMetric: trialC['trialConversionPct'] is Map
          ? EodMetricCell.fromJson((trialC['trialConversionPct'] as Map).cast<String, dynamic>(), isPercentage: true)
          : const EodMetricCell(label: 'Trial Conversion %', isPercentage: true),

      // Order values
      totalOrderValueMetric: orderP['totalOrderValue'] is Map
          ? EodMetricCell.fromJson((orderP['totalOrderValue'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Total Order Value (₹)'),
      advancePaidMetric: orderP['advancePaid'] is Map
          ? EodMetricCell.fromJson((orderP['advancePaid'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Advance Paid (₹)'),
      balanceDueMetric: orderP['balanceDue'] is Map
          ? EodMetricCell.fromJson((orderP['balanceDue'] as Map).cast<String, dynamic>())
          : const EodMetricCell(label: 'Balance Due (₹)'),

      // Ledger rows
      ledgerRows: ((j['ledgerRows'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SalesEodLedgerRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
      ledgerTotals: j['ledgerTotals'] is Map
          ? SalesEodLedgerRow.fromJson((j['ledgerTotals'] as Map).cast<String, dynamic>())
          : null,

      // Summary backward-compatibility
      summary: j['summary'] != null
          ? SalesEodSummary.fromJson((j['summary'] as Map).cast<String, dynamic>())
          : const SalesEodSummary(),
      bookings: ((j['bookings'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SalesEodBooking.fromJson(m.cast<String, dynamic>()))
          .toList(),
      activities: ((j['activities'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SalesEodActivity.fromJson(m.cast<String, dynamic>()))
          .toList(),
      pendingFollowUps: ((j['pendingFollowUps'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SalesEodPendingFollowUp.fromJson(m.cast<String, dynamic>()))
          .toList(),
      teamBreakdown: ((j['teamBreakdown'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SalesEodTeamMember.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}
