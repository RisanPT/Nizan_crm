
// ── Master Entities ─────────────────────────────────────────────────────────

class MarketingGroupModel {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  MarketingGroupModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory MarketingGroupModel.fromJson(Map<String, dynamic> j) {
    return MarketingGroupModel(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] as bool? ?? true,
    );
  }
}

class MarketingRoleModel {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  MarketingRoleModel({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory MarketingRoleModel.fromJson(Map<String, dynamic> j) {
    return MarketingRoleModel(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] as bool? ?? true,
    );
  }
}

class MarketingMetricModel {
  final String id;
  final String groupId;
  final String? groupName;
  final int code;
  final String name;
  final String unitType; // 'count' | 'currency'
  final bool inTotalOutput;
  final bool isActive;
  final int sortOrder;
  final double? maxPerDay; // soft daily ceiling (FR-6)

  MarketingMetricModel({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.code,
    required this.name,
    this.unitType = 'count',
    this.inTotalOutput = true,
    this.isActive = true,
    this.sortOrder = 0,
    this.maxPerDay,
  });

  factory MarketingMetricModel.fromJson(Map<String, dynamic> j) {
    String gId = '';
    String? gName;
    if (j['groupId'] is Map) {
      gId = j['groupId']['_id']?.toString() ?? '';
      gName = j['groupId']['name']?.toString();
    } else {
      gId = j['groupId']?.toString() ?? '';
      gName = j['groupName']?.toString();
    }

    return MarketingMetricModel(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      groupId: gId,
      groupName: gName,
      code: (j['code'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      unitType: j['unitType']?.toString() ?? 'count',
      inTotalOutput: j['inTotalOutput'] as bool? ?? true,
      isActive: j['isActive'] as bool? ?? true,
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      maxPerDay: (j['maxPerDay'] as num?)?.toDouble(),
    );
  }
}

class MarketingTeamMemberModel {
  final String id;
  final String name;
  final String shortName;
  final String? userId;
  final String? role;
  final int sortOrder;
  final bool isActive;

  MarketingTeamMemberModel({
    required this.id,
    required this.name,
    required this.shortName,
    this.userId,
    this.role,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory MarketingTeamMemberModel.fromJson(Map<String, dynamic> j) {
    return MarketingTeamMemberModel(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      shortName: j['shortName']?.toString() ?? j['name']?.toString() ?? '',
      userId: j['userId']?.toString(),
      role: j['role']?.toString(),
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] as bool? ?? true,
    );
  }
}

// ── Setup Master Data Payload ───────────────────────────────────────────────

class MarketingSetupData {
  final List<MarketingGroupModel> groups;
  final List<MarketingMetricModel> metrics;
  final List<MarketingRoleModel> roles;
  final List<Map<String, dynamic>> roleMetrics;
  final List<MarketingTeamMemberModel> members;
  final Map<String, dynamic> calendarSettings;
  final Map<String, dynamic> thresholds;
  final List<Map<String, dynamic>> memberRoles; // role history by month

  MarketingSetupData({
    required this.groups,
    required this.metrics,
    required this.roles,
    required this.roleMetrics,
    required this.members,
    required this.calendarSettings,
    required this.thresholds,
    this.memberRoles = const [],
  });

  factory MarketingSetupData.fromJson(Map<String, dynamic> j) {
    return MarketingSetupData(
      groups: (j['groups'] as List? ?? [])
          .map((e) => MarketingGroupModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      metrics: (j['metrics'] as List? ?? [])
          .map((e) => MarketingMetricModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      roles: (j['roles'] as List? ?? [])
          .map((e) => MarketingRoleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      roleMetrics: (j['roleMetrics'] as List? ?? []).cast<Map<String, dynamic>>(),
      members: (j['members'] as List? ?? [])
          .map((e) => MarketingTeamMemberModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      calendarSettings: (j['calendarSettings'] as Map?)?.cast<String, dynamic>() ?? {},
      thresholds: (j['thresholds'] as Map?)?.cast<String, dynamic>() ?? {},
      memberRoles: (j['memberRoles'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

// ── Daily EOD Entry Payload ─────────────────────────────────────────────────

class MarketingGroupedMetrics {
  final String groupId;
  final String groupName;
  final int sortOrder;
  final List<MarketingMetricModel> metrics;

  MarketingGroupedMetrics({
    required this.groupId,
    required this.groupName,
    required this.sortOrder,
    required this.metrics,
  });

  factory MarketingGroupedMetrics.fromJson(Map<String, dynamic> j) {
    return MarketingGroupedMetrics(
      groupId: j['groupId']?.toString() ?? '',
      groupName: j['groupName']?.toString() ?? 'General',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      metrics: (j['metrics'] as List? ?? [])
          .map((m) => MarketingMetricModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MarketingEodEntryPayload {
  final MarketingTeamMemberModel member;
  final String entryDate;
  final bool canEdit;
  final String editNotice;
  final bool isManager;
  final bool reasonRequired; // manager edit of another member / late row
  final double standardHours;
  final double hoursWorked;
  final String notes;
  final String checkStatus;
  final String checkMessage;
  final double totalOutput;
  final Map<String, double> values; // metricId -> count
  final List<MarketingGroupedMetrics> groupedMetrics;

  MarketingEodEntryPayload({
    required this.member,
    required this.entryDate,
    required this.canEdit,
    required this.editNotice,
    required this.isManager,
    this.reasonRequired = false,
    this.standardHours = 8,
    required this.hoursWorked,
    required this.notes,
    required this.checkStatus,
    required this.checkMessage,
    required this.totalOutput,
    required this.values,
    required this.groupedMetrics,
  });

  factory MarketingEodEntryPayload.fromJson(Map<String, dynamic> j) {
    final entry = (j['entry'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawValues = (j['values'] as Map?)?.cast<String, dynamic>() ?? {};
    final parsedValues = rawValues.map(
      (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
    );

    return MarketingEodEntryPayload(
      member: MarketingTeamMemberModel.fromJson(
        (j['member'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      entryDate: j['entryDate']?.toString() ?? '',
      canEdit: j['canEdit'] as bool? ?? true,
      editNotice: j['editNotice']?.toString() ?? '',
      isManager: j['isManager'] as bool? ?? false,
      reasonRequired: j['reasonRequired'] as bool? ?? false,
      standardHours: (j['standardHours'] as num?)?.toDouble() ?? 8,
      hoursWorked: (entry['hoursWorked'] as num?)?.toDouble() ?? 0.0,
      notes: entry['notes']?.toString() ?? '',
      checkStatus: entry['checkStatus']?.toString() ?? 'OK',
      checkMessage: entry['checkMessage']?.toString() ?? '',
      totalOutput: (j['totalOutput'] as num?)?.toDouble() ?? 0.0,
      values: parsedValues,
      groupedMetrics: (j['groupedMetrics'] as List? ?? [])
          .map((g) => MarketingGroupedMetrics.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Individual Monthly Dashboard Payload (FR-8) ─────────────────────────────

class ActivityDashboardRow {
  final String metricId;
  final int code;
  final String name;
  final String groupName;
  final String unitType;
  final bool inTotalOutput;
  final double? target;
  final double achieved;
  final int? achievedPct;
  final String dailyAvg;
  final Map<String, dynamic> bestDay; // { count: 5, date: '2026-10-14' }
  final String status; // 'green' | 'amber' | 'red' | 'none'
  // MTD vs pro-rated target: monthly target × working days so far ÷ working days.
  final double? expectedToDate;
  final int? pacePct;
  final String paceStatus; // 'green' | 'amber' | 'red' | 'none'

  ActivityDashboardRow({
    this.expectedToDate,
    this.pacePct,
    this.paceStatus = 'none',
    required this.metricId,
    required this.code,
    required this.name,
    required this.groupName,
    required this.unitType,
    required this.inTotalOutput,
    this.target,
    required this.achieved,
    this.achievedPct,
    required this.dailyAvg,
    required this.bestDay,
    required this.status,
  });

  factory ActivityDashboardRow.fromJson(Map<String, dynamic> j) {
    return ActivityDashboardRow(
      metricId: j['metricId']?.toString() ?? '',
      code: (j['code'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      groupName: j['groupName']?.toString() ?? 'General',
      unitType: j['unitType']?.toString() ?? 'count',
      inTotalOutput: j['inTotalOutput'] as bool? ?? true,
      target: (j['target'] as num?)?.toDouble(),
      achieved: (j['achieved'] as num?)?.toDouble() ?? 0.0,
      achievedPct: (j['achievedPct'] as num?)?.toInt(),
      dailyAvg: j['dailyAvg']?.toString() ?? '0.0',
      bestDay: (j['bestDay'] as Map?)?.cast<String, dynamic>() ?? {'count': 0, 'date': '—'},
      status: j['status']?.toString() ?? 'none',
      expectedToDate: (j['expectedToDate'] as num?)?.toDouble(),
      pacePct: (j['pacePct'] as num?)?.toInt(),
      paceStatus: j['paceStatus']?.toString() ?? 'none',
    );
  }
}

class WeekWiseDashboardRow {
  final String metricId;
  final int code;
  final String name;
  final String groupName;
  final double w1;
  final double w2;
  final double w3;
  final double w4;
  final double w5;
  final double monthTotal;

  WeekWiseDashboardRow({
    required this.metricId,
    required this.code,
    required this.name,
    required this.groupName,
    required this.w1,
    required this.w2,
    required this.w3,
    required this.w4,
    required this.w5,
    required this.monthTotal,
  });

  factory WeekWiseDashboardRow.fromJson(Map<String, dynamic> j) {
    return WeekWiseDashboardRow(
      metricId: j['metricId']?.toString() ?? '',
      code: (j['code'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      groupName: j['groupName']?.toString() ?? 'General',
      w1: (j['w1'] as num?)?.toDouble() ?? 0.0,
      w2: (j['w2'] as num?)?.toDouble() ?? 0.0,
      w3: (j['w3'] as num?)?.toDouble() ?? 0.0,
      w4: (j['w4'] as num?)?.toDouble() ?? 0.0,
      w5: (j['w5'] as num?)?.toDouble() ?? 0.0,
      monthTotal: (j['monthTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyGridDay {
  final int day;
  final String date;
  final int dayOfWeek;
  final double hours;
  final double output;
  final String color; // 'green' | 'red' | 'grey' | 'future' | 'neutral'
  final bool hasEod;

  DailyGridDay({
    required this.day,
    required this.date,
    required this.dayOfWeek,
    required this.hours,
    required this.output,
    required this.color,
    required this.hasEod,
  });

  factory DailyGridDay.fromJson(Map<String, dynamic> j) {
    return DailyGridDay(
      day: (j['day'] as num?)?.toInt() ?? 0,
      date: j['date']?.toString() ?? '',
      dayOfWeek: (j['dayOfWeek'] as num?)?.toInt() ?? 0,
      hours: (j['hours'] as num?)?.toDouble() ?? 0.0,
      output: (j['output'] as num?)?.toDouble() ?? 0.0,
      color: j['color']?.toString() ?? 'neutral',
      hasEod: j['hasEod'] as bool? ?? false,
    );
  }
}

class MarketingIndividualDashboardData {
  final MarketingTeamMemberModel member;
  final String month;
  final String period;
  final Map<String, dynamic> summaryTiles;
  final List<ActivityDashboardRow> activityNumbers;
  final List<WeekWiseDashboardRow> weekWiseRows;
  final WeekWiseDashboardRow totalOutputRow;
  final List<DailyGridDay> dailyGrid;
  final Map<String, dynamic> remarks;
  final List<Map<String, dynamic>> weeklyStats;

  MarketingIndividualDashboardData({
    required this.member,
    required this.month,
    required this.period,
    required this.summaryTiles,
    required this.activityNumbers,
    required this.weekWiseRows,
    required this.totalOutputRow,
    required this.dailyGrid,
    required this.remarks,
    required this.weeklyStats,
  });

  factory MarketingIndividualDashboardData.fromJson(Map<String, dynamic> j) {
    final weekWise = (j['weekWiseNumbers'] as Map?)?.cast<String, dynamic>() ?? {};
    final tRow = (weekWise['totalOutputRow'] as Map?)?.cast<String, dynamic>() ?? {};

    return MarketingIndividualDashboardData(
      member: MarketingTeamMemberModel.fromJson(
        (j['member'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      month: j['month']?.toString() ?? '',
      period: j['period']?.toString() ?? '',
      summaryTiles: (j['summaryTiles'] as Map?)?.cast<String, dynamic>() ?? {},
      activityNumbers: (j['activityNumbers'] as List? ?? [])
          .map((a) => ActivityDashboardRow.fromJson(a as Map<String, dynamic>))
          .toList(),
      weekWiseRows: (weekWise['rows'] as List? ?? [])
          .map((w) => WeekWiseDashboardRow.fromJson(w as Map<String, dynamic>))
          .toList(),
      totalOutputRow: WeekWiseDashboardRow.fromJson(tRow),
      dailyGrid: (j['dailyGrid'] as List? ?? [])
          .map((d) => DailyGridDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      remarks: (j['remarks'] as Map?)?.cast<String, dynamic>() ?? {},
      weeklyStats: (j['weeklyStats'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

// ── Team Summary Payload (FR-9) ─────────────────────────────────────────────

class TeamSummaryMetricRow {
  final String metricId;
  final int code;
  final String name;
  final String groupName;
  final String unitType;
  final bool inTotalOutput;
  final Map<String, dynamic> memberValues; // memberId -> count or '—'
  final dynamic teamTotal;
  // MTD vs pro-rated target, summed over members with a target.
  final double? teamExpected;
  final int? teamPacePct;

  TeamSummaryMetricRow({
    this.teamExpected,
    this.teamPacePct,
    required this.metricId,
    required this.code,
    required this.name,
    required this.groupName,
    required this.unitType,
    required this.inTotalOutput,
    required this.memberValues,
    required this.teamTotal,
  });

  factory TeamSummaryMetricRow.fromJson(Map<String, dynamic> j) {
    return TeamSummaryMetricRow(
      metricId: j['metricId']?.toString() ?? '',
      code: (j['code'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      groupName: j['groupName']?.toString() ?? 'General',
      unitType: j['unitType']?.toString() ?? 'count',
      inTotalOutput: j['inTotalOutput'] as bool? ?? true,
      memberValues: (j['memberValues'] as Map?)?.cast<String, dynamic>() ?? {},
      teamTotal: j['teamTotal'],
      teamExpected: (j['teamExpected'] as num?)?.toDouble(),
      teamPacePct: (j['teamPacePct'] as num?)?.toInt(),
    );
  }
}

class MarketingTeamSummaryData {
  final String month;
  final List<MarketingTeamMemberModel> members;
  final Map<String, dynamic> overviewRows;
  final List<TeamSummaryMetricRow> metricRows;

  MarketingTeamSummaryData({
    required this.month,
    required this.members,
    required this.overviewRows,
    required this.metricRows,
  });

  factory MarketingTeamSummaryData.fromJson(Map<String, dynamic> j) {
    return MarketingTeamSummaryData(
      month: j['month']?.toString() ?? '',
      members: (j['members'] as List? ?? [])
          .map((m) => MarketingTeamMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      overviewRows: (j['overviewRows'] as Map?)?.cast<String, dynamic>() ?? {},
      metricRows: (j['metricRows'] as List? ?? [])
          .map((r) => TeamSummaryMetricRow.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Missed EODs Payload (FR-11) ─────────────────────────────────────────────

class MissedEodItem {
  final String memberId;
  final String memberName;
  final String shortName;
  final String date;

  MissedEodItem({
    required this.memberId,
    required this.memberName,
    required this.shortName,
    required this.date,
  });

  factory MissedEodItem.fromJson(Map<String, dynamic> j) {
    return MissedEodItem(
      memberId: j['memberId']?.toString() ?? '',
      memberName: j['memberName']?.toString() ?? '',
      shortName: j['shortName']?.toString() ?? '',
      date: j['date']?.toString() ?? '',
    );
  }
}

class MarketingMissedEodsData {
  final String month;
  final int totalMissedCount;
  final Map<String, int> memberMissedCounts;
  final List<MissedEodItem> missedList;

  MarketingMissedEodsData({
    required this.month,
    required this.totalMissedCount,
    required this.memberMissedCounts,
    required this.missedList,
  });

  factory MarketingMissedEodsData.fromJson(Map<String, dynamic> j) {
    final counts = (j['memberMissedCounts'] as Map?)?.cast<String, dynamic>() ?? {};
    final parsedCounts = counts.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));

    return MarketingMissedEodsData(
      month: j['month']?.toString() ?? '',
      totalMissedCount: (j['totalMissedCount'] as num?)?.toInt() ?? 0,
      memberMissedCounts: parsedCounts,
      missedList: (j['missedList'] as List? ?? [])
          .map((m) => MissedEodItem.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Access (who may see which tabs) ─────────────────────────────────────────

class MarketingEodAccess {
  final bool isManager;
  final bool canViewTeam;
  final String? memberId; // the logged-in user's own team-member record

  const MarketingEodAccess({
    this.isManager = false,
    this.canViewTeam = false,
    this.memberId,
  });

  factory MarketingEodAccess.fromJson(Map<String, dynamic> j) {
    return MarketingEodAccess(
      isManager: j['isManager'] as bool? ?? false,
      canViewTeam: j['canViewTeam'] as bool? ?? false,
      memberId: j['memberId']?.toString(),
    );
  }
}
