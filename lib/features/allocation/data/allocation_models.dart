import 'package:dio/dio.dart';

import 'package:nizan_crm/core/error/errors.dart';

// SMART BOOKING ALLOCATION — what the server sends (backend /api/allocation, /api/artist-teams; rules in utils/artistAllocation.js).
// For a NEW booking the ERP ranks the in-house teams: the same artist while the new venue is on her route (her clock + 30 minutes'
// drive), else the next free one in the rotation; a coordinator confirms. Times are 'HH:MM' in India time.

String _s(Object? v) => v == null ? '' : '$v';
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _in(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
List<Map<String, dynamic>> _l(Object? v) => [for (final x in (v as List? ?? const [])) if (x is Map) x.cast<String, dynamic>()];
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
DateTime? _dt(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// "9:00 AM" from 'HH:MM'.
String fmtHHMM(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return hhmm;
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

class AllocationSettings {
  const AllocationSettings({this.mode = 'off', this.guard = 'off', this.guardOn = false, this.autoAllocate = 'off', this.autoOn = false, this.liveSince, this.shadowSince, this.eveningCutoff = '14:00', this.travelLimitMin = 30, this.readyBufferMin = 30, this.defaultJobMin = 180, this.extrasPerDay = 2, this.extraWhen = 'half_full', this.canEdit = false, this.canChangeMode = false, this.canAllocate = false, this.updatedByName = ''});
  final String mode, guard, autoAllocate, eveningCutoff, extraWhen, updatedByName;
  /// [autoOn]: clean matches get their team on their own the moment a new booking is confirmed (the server's word, kill switch included).
  final bool guardOn, autoOn, canEdit, canChangeMode, canAllocate;
  final DateTime? liveSince, shadowSince;
  final int travelLimitMin, readyBufferMin, defaultJobMin, extrasPerDay;

  /// Coordinators get suggestions (and the sheet opens on confirm).
  bool get suggest => mode == 'suggest';
  factory AllocationSettings.fromJson(Map<String, dynamic> j) => AllocationSettings(
        mode: _s(j['mode']).isEmpty ? 'off' : _s(j['mode']),
        guard: _s(j['guard']).isEmpty ? 'off' : _s(j['guard']),
        guardOn: j['guardOn'] == true,
        autoAllocate: _s(j['autoAllocate']).isEmpty ? 'off' : _s(j['autoAllocate']),
        autoOn: j['autoOn'] == true,
        liveSince: _dt(j['liveSince']),
        shadowSince: _dt(j['shadowSince']),
        eveningCutoff: _s(j['eveningCutoff']).isEmpty ? '14:00' : _s(j['eveningCutoff']),
        travelLimitMin: _in(j['travelLimitMin']) ?? 30,
        readyBufferMin: _in(j['readyBufferMin']) ?? 30,
        defaultJobMin: _in(j['defaultJobMin']) ?? 180,
        extrasPerDay: _in(j['extrasPerDay']) ?? 2,
        extraWhen: _s(j['extraWhen']).isEmpty ? 'half_full' : _s(j['extraWhen']),
        canEdit: j['canEdit'] == true,
        canChangeMode: j['canChangeMode'] == true,
        canAllocate: j['canAllocate'] == true,
        updatedByName: _s(j['updatedByName']),
      );
}

class TeamPerson {
  const TeamPerson({required this.id, required this.name});
  final String id, name;
  factory TeamPerson.fromJson(Map<String, dynamic> j) => TeamPerson(id: _s(j['id'] ?? j['_id']), name: _s(j['name']));
}

/// A team's day (the Artist Management card): jobs, slots used, free from, leave.
class TeamLoad {
  const TeamLoad({this.status = 'free', this.used = 0, this.of = 3, this.jobs = const [], this.freeFromText = '', this.onLeave = false, this.halfLeave = false});
  final String status, freeFromText;
  final int used, of;
  final List<({String bookingNumber, String start, String label})> jobs;
  final bool onLeave, halfLeave;
  factory TeamLoad.fromJson(Map<String, dynamic> j) {
    final leave = j['leave'] == null ? null : _m(j['leave']);
    return TeamLoad(
      status: _s(j['status']),
      used: _i(j['used']),
      of: _i(j['of']),
      jobs: [for (final x in _l(j['jobs'])) (bookingNumber: _s(x['bookingNumber']), start: _s(x['start']), label: _s(x['label']))],
      freeFromText: _s(j['freeFromText']),
      onLeave: leave != null && (_s(leave['halfDay']).isEmpty || _s(leave['halfDay']) == 'none'),
      halfLeave: leave != null && _s(leave['halfDay']).isNotEmpty && _s(leave['halfDay']) != 'none',
    );
  }
}

class ArtistTeamView {
  const ArtistTeamView({required this.id, required this.name, required this.lead, this.rotationOrder = 0, this.active = true, this.assistants = const [], this.morningSlots = 2, this.eveningSlots = 1, this.extraAllowed = true, this.preferredDistricts = const [], this.preferredPincodes = const [], this.notes = '', this.load, this.warnings = const []});
  final String id, name, notes;
  final TeamPerson lead;
  final int rotationOrder, morningSlots, eveningSlots;
  final bool active, extraAllowed;
  final List<TeamPerson> assistants;
  final List<({String id, String name})> preferredDistricts;
  final List<String> preferredPincodes;
  final TeamLoad? load;
  final List<String> warnings;
  factory ArtistTeamView.fromJson(Map<String, dynamic> j) => ArtistTeamView(
        id: _s(j['id']),
        name: _s(j['name']),
        lead: TeamPerson.fromJson(_m(j['lead'])),
        rotationOrder: _i(j['rotationOrder']),
        active: j['active'] != false,
        assistants: _l(j['assistants']).map(TeamPerson.fromJson).toList(),
        morningSlots: _in(_m(j['slots'])['morning']) ?? 2,
        eveningSlots: _in(_m(j['slots'])['evening']) ?? 1,
        extraAllowed: j['extraAllowed'] != false,
        preferredDistricts: [for (final d in _l(j['preferredDistricts'])) (id: _s(d['id']), name: _s(d['name']))],
        preferredPincodes: [for (final p in (j['preferredPincodes'] as List? ?? const [])) _s(p)],
        notes: _s(j['notes']),
        load: j['load'] == null ? null : TeamLoad.fromJson(_m(j['load'])),
        warnings: [for (final w in (j['warnings'] as List? ?? const [])) _s(w)],
      );
}

class TeamsPage {
  const TeamsPage({required this.day, this.canManage = false, this.teams = const []});
  final String day;
  final bool canManage;
  final List<ArtistTeamView> teams;
  factory TeamsPage.fromJson(Map<String, dynamic> j) => TeamsPage(day: _s(j['day']), canManage: j['canManage'] == true, teams: _l(j['teams']).map(ArtistTeamView.fromJson).toList());
}

/// Someone who can be on a team (active in-house artist or assistant), and the team she already leads or helps.
class TeamCandidate {
  const TeamCandidate({required this.id, required this.name, this.artistRole = 'artist', this.leadsTeamId, this.leadsTeamName = '', this.assistsTeams = const []});
  final String id, name, artistRole, leadsTeamName;
  final String? leadsTeamId;
  final List<String> assistsTeams;
  factory TeamCandidate.fromJson(Map<String, dynamic> j) {
    final lead = j['leadsTeam'] == null ? null : _m(j['leadsTeam']);
    return TeamCandidate(id: _s(j['id']), name: _s(j['name']), artistRole: _s(j['artistRole']), leadsTeamId: lead == null ? null : _s(lead['id']), leadsTeamName: lead == null ? '' : _s(lead['name']), assistsTeams: [for (final t in (j['assistsTeams'] as List? ?? const [])) _s(t)]);
  }
}

/// One team, ranked for a package of a booking.
class AllocCandidate {
  const AllocCandidate({required this.teamId, required this.teamName, this.lead, this.assistants = const [], this.tier = 'blocked', this.rank = 0, this.recommended = false, this.reason = '', this.details = const [], this.problems = const [], this.warnings = const [], this.slots = const [], this.extraDay, this.needsApproval = false, this.travelMinutes, this.travelKm, this.preferred = 0});
  final String teamId, teamName, tier, reason;
  final TeamPerson? lead;
  final List<TeamPerson> assistants;
  final int rank, preferred;
  final bool recommended, needsApproval;
  final List<String> details, problems, warnings;
  final List<({String day, String half, int? used, int? of})> slots;
  final String? extraDay;
  final int? travelMinutes, travelKm;
  bool get blocked => tier == 'blocked';
  bool get extra => tier == 'extra';
  factory AllocCandidate.fromJson(Map<String, dynamic> j) {
    final t = j['travel'] == null ? null : _m(j['travel']);
    return AllocCandidate(
      teamId: _s(j['teamId']),
      teamName: _s(j['teamName']),
      lead: j['lead'] == null ? null : TeamPerson.fromJson(_m(j['lead'])),
      assistants: _l(j['assistants']).map(TeamPerson.fromJson).toList(),
      tier: _s(j['tier']),
      rank: _i(j['rank']),
      recommended: j['recommended'] == true,
      reason: _s(j['reason']),
      details: [for (final d in (j['details'] as List? ?? const [])) _s(d)],
      problems: [for (final d in (j['problems'] as List? ?? const [])) _s(d)],
      warnings: [for (final d in (j['warnings'] as List? ?? const [])) _s(d)],
      slots: [for (final s in _l(j['slots'])) (day: _s(s['day']), half: _s(s['half']), used: _in(s['used']), of: _in(s['of']))],
      extraDay: j['extra'] == null ? null : _s(_m(j['extra'])['day']),
      needsApproval: j['needsApproval'] == true,
      travelMinutes: t == null ? null : _in(t['minutes']),
      travelKm: t == null ? null : _in(t['km']),
      preferred: _i(j['preferred']),
    );
  }
}

class AllocUnitDay {
  const AllocUnitDay({required this.day, this.start = '', this.end = '', this.half = 'morning', this.timeSet = true, this.placeLabel = '', this.precision = 'unknown'});
  final String day, start, end, half, placeLabel, precision;
  final bool timeSet;
  factory AllocUnitDay.fromJson(Map<String, dynamic> j) {
    final p = _m(j['place']);
    return AllocUnitDay(day: _s(j['day']), start: _s(j['start']), end: _s(j['end']), half: _s(j['half']).isEmpty ? 'morning' : _s(j['half']), timeSet: j['timeSet'] != false, placeLabel: _s(p['label']), precision: _s(p['precision']).isEmpty ? 'unknown' : _s(p['precision']));
  }
}

/// A package of a booking (or the whole booking when it has none) and the teams ranked for it.
class AllocUnit {
  const AllocUnit({required this.unitKey, this.label = '', this.days = const [], this.currentLead = '', this.currentTeamId, this.slotKey = '', this.approval = 'not_needed', this.candidates = const []});
  final String unitKey, label, currentLead, slotKey, approval;
  final String? currentTeamId;
  final List<AllocUnitDay> days;
  final List<AllocCandidate> candidates;
  AllocCandidate? get recommended => candidates.where((c) => c.recommended).firstOrNull;
  factory AllocUnit.fromJson(Map<String, dynamic> j) {
    final cur = j['current'] == null ? null : _m(j['current']);
    final alloc = j['allocation'] == null ? null : _m(j['allocation']);
    return AllocUnit(
      unitKey: _s(j['unitKey']),
      label: _s(j['label']),
      days: _l(j['days']).map(AllocUnitDay.fromJson).toList(),
      currentLead: cur == null ? '' : _s(cur['leadName']),
      currentTeamId: cur == null || cur['teamId'] == null ? null : _s(cur['teamId']),
      slotKey: alloc == null ? '' : _s(alloc['slotKey']),
      approval: alloc == null ? 'not_needed' : _s(alloc['approval']),
      candidates: _l(j['candidates']).map(AllocCandidate.fromJson).toList(),
    );
  }
}

class BookingAllocation {
  const BookingAllocation({required this.bookingId, this.mode = 'off', this.eligible = false, this.canConfirm = false, this.canApproveExtra = false, this.bookingNumber = '', this.customerName = '', this.updatedAt, this.units = const [], this.message = ''});
  final String bookingId, mode, bookingNumber, customerName, message;
  final bool eligible, canConfirm, canApproveExtra;
  final String? updatedAt; // sent back on confirm as it came (a precondition)
  final List<AllocUnit> units;
  factory BookingAllocation.fromJson(Map<String, dynamic> j) => BookingAllocation(
        bookingId: _s(j['bookingId']),
        mode: _s(j['mode']),
        eligible: j['eligible'] == true,
        canConfirm: j['canConfirm'] == true,
        canApproveExtra: j['canApproveExtra'] == true,
        bookingNumber: _s(j['bookingNumber']),
        customerName: _s(j['customerName']),
        updatedAt: j['updatedAt'] == null ? null : _s(j['updatedAt']),
        units: _l(j['units']).map(AllocUnit.fromJson).toList(),
        message: _s(j['message']),
      );
}

/// What the server refused, in its words: a clash to confirm (ARTIST_CONFLICT), a slot just taken, a booking just changed…
class AllocationRefusal implements Exception {
  const AllocationRefusal({required this.code, required this.message, this.problems = const [], this.warnings = const []});
  final String code, message;
  final List<String> problems, warnings;
  bool get isConflict => code == 'ARTIST_CONFLICT';

  /// The refusal inside [error] (a 400/403/404/409 with a message), else null.
  static AllocationRefusal? of(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException) return null;
    final status = cause.response?.statusCode ?? 0;
    final data = cause.response?.data;
    if (![400, 403, 404, 409].contains(status) || data is! Map || (data['message'] ?? '').toString().isEmpty) return null;
    String reasonOf(Object? p) => p is Map ? _s(p['reason']).isNotEmpty ? [if (_s(p['person'] ?? p['team']).isNotEmpty) _s(p['person'] ?? p['team']), _s(p['reason'])].join(': ') : _s(p['message']) : _s(p);
    return AllocationRefusal(
      code: _s(data['code']),
      message: _s(data['message']),
      problems: [for (final p in (data['problems'] as List? ?? const [])) reasonOf(p)],
      warnings: [for (final p in (data['warnings'] as List? ?? const [])) reasonOf(p)],
    );
  }

  @override
  String toString() => message;
}

class BoardSlot {
  const BoardSlot({required this.key, this.half = 'morning', this.over = false, this.extra = false, this.approval = 'not_needed', this.bookingId, this.bookingNumber = '', this.customerName = '', this.start = '', this.end = '', this.label = ''});
  /// [customerName] — the client the slot is for; [label] — the place.
  final String key, half, approval, bookingNumber, customerName, start, end, label;
  final bool over, extra;
  final String? bookingId;
  bool get taken => bookingId != null;
  factory BoardSlot.fromJson(Map<String, dynamic> j) {
    final job = j['job'] == null ? null : _m(j['job']);
    return BoardSlot(key: _s(j['key']), half: _s(j['half']), over: j['over'] == true, extra: j['extra'] == true, approval: _s(j['approval']).isEmpty ? 'not_needed' : _s(j['approval']), bookingId: job == null ? null : _s(job['bookingId']), bookingNumber: job == null ? '' : _s(job['bookingNumber']), customerName: job == null ? '' : _s(job['customerName']), start: job == null ? '' : _s(job['start']), end: job == null ? '' : _s(job['end']), label: job == null ? '' : _s(job['label']));
  }
}

class BoardJob {
  const BoardJob({required this.bookingId, this.bookingNumber = '', this.customerName = '', this.start = '', this.end = '', this.half = 'morning', this.label = '', this.districtId = ''});
  final String bookingId, bookingNumber, customerName, start, end, half, label, districtId;
  factory BoardJob.fromJson(Map<String, dynamic> j) {
    final p = _m(j['place']);
    return BoardJob(bookingId: _s(j['bookingId']), bookingNumber: _s(j['bookingNumber']), customerName: _s(j['customerName']), start: _s(j['start']), end: _s(j['end']), half: _s(j['half']), label: _s(p['label']), districtId: _s(p['districtId']));
  }
}

class BoardTeam {
  const BoardTeam({required this.id, required this.name, this.lead, this.assistants = const [], this.status = 'free', this.used = 0, this.of = 3, this.jobs = const [], this.slots = const [], this.freeFromText = '', this.onLeave = false, this.halfLeave = false, this.leaveHalf = ''});
  final String id, name, status, freeFromText;

  /// a half-day leave: 'first' (morning) or 'second' (evening); '' otherwise
  final String leaveHalf;
  final TeamPerson? lead;
  final List<TeamPerson> assistants;
  final int used, of;
  final List<BoardJob> jobs;
  final List<BoardSlot> slots;
  final bool onLeave, halfLeave;
  factory BoardTeam.fromJson(Map<String, dynamic> j) {
    final leave = j['leave'] == null ? null : _m(j['leave']);
    return BoardTeam(
      id: _s(j['id']),
      name: _s(j['name']),
      lead: j['lead'] == null ? null : TeamPerson.fromJson(_m(j['lead'])),
      assistants: _l(j['assistants']).map(TeamPerson.fromJson).toList(),
      status: _s(j['status']),
      used: _i(j['used']),
      of: _i(j['of']),
      jobs: _l(j['jobs']).map(BoardJob.fromJson).toList(),
      slots: _l(j['slots']).map(BoardSlot.fromJson).toList(),
      freeFromText: _s(j['freeFromText']),
      onLeave: leave != null && (_s(leave['halfDay']).isEmpty || _s(leave['halfDay']) == 'none'),
      halfLeave: leave != null && _s(leave['halfDay']).isNotEmpty && _s(leave['halfDay']) != 'none',
      leaveHalf: leave == null || _s(leave['halfDay']) == 'none' ? '' : _s(leave['halfDay']),
    );
  }

  /// Her lead is away for this slot's half (all day, or the matching half-day).
  bool awayFor(String half) => onLeave || (halfLeave && (leaveHalf == 'first') == (half == 'morning'));
}

class BoardQueueItem {
  const BoardQueueItem({required this.bookingId, required this.unitKey, this.bookingNumber = '', this.customerName = '', this.label = '', this.start = '', this.end = '', this.half = 'morning', this.timeSet = true, this.placeLabel = '', this.districtId = '', this.precision = 'unknown', this.topTeamId, this.topTeamName = '', this.topTier = '', this.topReason = '', this.nearTeams = const [], this.nearWorks = const []});
  final String bookingId, unitKey, bookingNumber, customerName, label, start, end, half, placeLabel, districtId, precision, topTeamName, topTier, topReason;
  final bool timeSet;
  final String? topTeamId;
  final List<({String teamId, int minutes})> nearTeams;
  final List<({String bookingId, String unitKey, int minutes})> nearWorks;
  factory BoardQueueItem.fromJson(Map<String, dynamic> j) {
    final p = _m(j['place']);
    final top = j['top'] == null ? null : _m(j['top']);
    return BoardQueueItem(
      bookingId: _s(j['bookingId']),
      unitKey: _s(j['unitKey']),
      bookingNumber: _s(j['bookingNumber']),
      customerName: _s(j['customerName']),
      label: _s(j['label']),
      start: _s(j['start']),
      end: _s(j['end']),
      half: _s(j['half']),
      timeSet: j['timeSet'] != false,
      placeLabel: _s(p['label']),
      districtId: _s(p['districtId']),
      precision: _s(p['precision']),
      topTeamId: top == null ? null : _s(top['teamId']),
      topTeamName: top == null ? '' : _s(top['teamName']),
      topTier: top == null ? '' : _s(top['tier']),
      topReason: top == null ? '' : _s(top['reason']),
      nearTeams: [for (final n in _l(j['nearTeams'])) (teamId: _s(n['teamId']), minutes: _i(n['minutes']))],
      nearWorks: [for (final n in _l(j['nearWorks'])) (bookingId: _s(n['bookingId']), unitKey: _s(n['unitKey']), minutes: _i(n['minutes']))],
    );
  }
}

class PendingExtra {
  const PendingExtra({required this.id, this.bookingId = '', this.bookingNumber = '', this.customerName = '', this.day = '', this.start = '', this.teamName = '', this.askedBy = '', this.reason = ''});
  final String id, bookingId, bookingNumber, customerName, day, start, teamName, askedBy, reason;
  factory PendingExtra.fromJson(Map<String, dynamic> j) => PendingExtra(id: _s(j['id']), bookingId: _s(j['bookingId']), bookingNumber: _s(j['bookingNumber']), customerName: _s(j['customerName']), day: _s(j['day']), start: _s(j['start']), teamName: _s(j['teamName']), askedBy: _s(j['askedBy']), reason: _s(j['reason']));
}

class DayBoard {
  const DayBoard({required this.day, this.mode = 'off', this.canAllocate = false, this.canApproveExtra = false, this.planned = 0, this.booked = 0, this.extrasUsed = 0, this.extrasPending = 0, this.unallocated = 0, this.outsourced = 0, this.extrasPerDay = 2, this.travelLimitMin = 30, this.teams = const [], this.queue = const [], this.pendingExtras = const [], this.week = const []});
  final String day, mode;
  /// The day's week (Mon–Sun), each day counted — the little lines on the Board's cards.
  final List<({String day, int booked, int extras, int toAllocate, int pending})> week;
  final bool canAllocate, canApproveExtra;
  final int planned, booked, extrasUsed, extrasPending, unallocated, outsourced, extrasPerDay, travelLimitMin;
  final List<BoardTeam> teams;
  final List<BoardQueueItem> queue;
  final List<PendingExtra> pendingExtras;
  factory DayBoard.fromJson(Map<String, dynamic> j) {
    final s = _m(j['summary']);
    final st = _m(j['settings']);
    return DayBoard(
      day: _s(j['day']),
      mode: _s(j['mode']),
      canAllocate: j['canAllocate'] == true,
      canApproveExtra: j['canApproveExtra'] == true,
      planned: _i(s['planned']),
      booked: _i(s['booked']),
      extrasUsed: _i(s['extrasUsed']),
      extrasPending: _i(s['extrasPending']),
      unallocated: _i(s['unallocated']),
      outsourced: _i(s['outsourced']),
      extrasPerDay: _in(st['extrasPerDay']) ?? 2,
      travelLimitMin: _in(st['travelLimitMin']) ?? 30,
      teams: _l(j['teams']).map(BoardTeam.fromJson).toList(),
      queue: _l(j['queue']).map(BoardQueueItem.fromJson).toList(),
      pendingExtras: _l(j['pendingExtras']).map(PendingExtra.fromJson).toList(),
      week: [for (final w in _l(j['week'])) (day: _s(w['day']), booked: _i(w['booked']), extras: _i(w['extras']), toAllocate: _i(w['toAllocate']), pending: _i(w['pending']))],
    );
  }
}

class AllocationMetrics {
  const AllocationMetrics({this.decided = 0, this.accepted = 0, this.overridden = 0, this.manual = 0, this.top3 = 0, this.overrideReasons = const {}, this.shadowCompared = 0, this.shadowMatched = 0, this.extrasRequested = 0, this.extrasApproved = 0, this.extrasRejected = 0, this.conflictsConfirmed = 0});
  final int decided, accepted, overridden, manual, top3, shadowCompared, shadowMatched, extrasRequested, extrasApproved, extrasRejected, conflictsConfirmed;
  final Map<String, int> overrideReasons;
  factory AllocationMetrics.fromJson(Map<String, dynamic> j) {
    final sh = _m(j['shadow']);
    final ex = _m(j['extras']);
    return AllocationMetrics(
      decided: _i(j['decided']),
      accepted: _i(j['accepted']),
      overridden: _i(j['overridden']),
      manual: _i(j['manual']),
      top3: _i(j['top3']),
      overrideReasons: {for (final e in _m(j['overrideReasons']).entries) e.key: _i(e.value)},
      shadowCompared: _i(sh['compared']),
      shadowMatched: _i(sh['matched']),
      extrasRequested: _i(ex['requested']),
      extrasApproved: _i(ex['approved']),
      extrasRejected: _i(ex['rejected']),
      conflictsConfirmed: _i(j['conflictsConfirmed']),
    );
  }
}

/// One booking's artist allocation — who has each package, or why it waits (GET /api/allocation/booking/:id/status). The salespeople
/// read this too.
class BookingAllocationStatus {
  const BookingAllocationStatus({required this.bookingId, this.bookingNumber = '', this.mode = 'off', this.auto = false, this.eligible = false, this.status = '', this.units = const []});
  final String bookingId, bookingNumber, mode, status;
  final bool auto, eligible;
  final List<AllocationUnitStatus> units;

  bool get anyWaiting => units.any((u) => u.waiting);
  bool get allAssigned => units.isNotEmpty && units.every((u) => u.assigned);

  factory BookingAllocationStatus.fromJson(Map<String, dynamic> j) => BookingAllocationStatus(
        bookingId: _s(j['bookingId']),
        bookingNumber: _s(j['bookingNumber']),
        mode: _s(j['mode']).isEmpty ? 'off' : _s(j['mode']),
        auto: j['auto'] == true,
        eligible: j['eligible'] == true,
        status: _s(j['status']),
        units: _l(j['units']).map(AllocationUnitStatus.fromJson).toList(),
      );
}

class AllocationUnitStatus {
  const AllocationUnitStatus({required this.unitKey, this.label = '', this.days = const [], this.status = 'waiting', this.teamName = '', this.lead = '', this.assistants = const [], this.how = '', this.by = '', this.reason = ''});
  final String unitKey, label, status, teamName, lead, how, by, reason;
  final List<({String day, String start, String place})> days;
  final List<String> assistants;

  /// assigned | waiting | waiting_approval (an EXTRA for the Artist Head)
  bool get assigned => status == 'assigned';
  bool get waiting => status == 'waiting' || status == 'waiting_approval';

  /// "Nihala, with Ameena and Fathima"
  String get people {
    final with_ = assistants.length < 2 ? assistants.join() : '${assistants.sublist(0, assistants.length - 1).join(', ')} and ${assistants.last}';
    return [if (lead.isNotEmpty) lead, if (with_.isNotEmpty) 'with $with_'].join(', ');
  }

  /// assigned automatically / by CRM / on Manage Booking
  String get howText => switch (how) {
        'auto' => 'assigned automatically',
        'crm' => by.isEmpty ? 'assigned by CRM' : 'assigned by $by',
        'by_hand' => 'assigned on Manage Booking',
        _ => '',
      };

  factory AllocationUnitStatus.fromJson(Map<String, dynamic> j) => AllocationUnitStatus(
        unitKey: _s(j['unitKey']),
        label: _s(j['label']),
        days: [for (final d in _l(j['days'])) (day: _s(d['day']), start: _s(d['start']), place: _s(d['place']))],
        status: _s(j['status']).isEmpty ? 'waiting' : _s(j['status']),
        teamName: _s(j['teamName']),
        lead: _s(j['lead']),
        assistants: [for (final a in (j['assistants'] as List? ?? const [])) a.toString()].where((a) => a.isNotEmpty).toList(),
        how: _s(j['how']),
        by: _s(j['by']),
        reason: _s(j['reason']),
      );
}

/// The Add Booking form's preview (POST /api/allocation/preview): the teams that prefer the venue's area, and — once the event days
/// and times are in — who would take each package (the same rule as on confirm), or why CRM would decide. Nothing is saved.
class AllocationPreview {
  const AllocationPreview({this.on = false, this.auto = false, this.pincode = '', this.districtName = '', this.preferredTeams = const [], this.teams = 0, this.units = const [], this.day});
  final bool on, auto;
  /// The date's own state when it has reached HR's day limit — where a 4th work could still go (null: not checked / not full).
  final FullDay? day;
  final String pincode, districtName;
  final List<({String teamName, String lead, List<String> assistants, String match})> preferredTeams;
  final int teams;
  final List<PreviewUnit> units;

  /// "Malappuram", else "PIN 679576", else ''
  String get areaName => districtName.isNotEmpty ? districtName : pincode.isNotEmpty ? 'PIN $pincode' : '';

  factory AllocationPreview.fromJson(Map<String, dynamic> j) {
    final area = (j['area'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return AllocationPreview(
      on: j['on'] == true,
      auto: j['auto'] == true,
      pincode: _s(area['pincode']),
      districtName: _s(area['districtName']),
      preferredTeams: [
        for (final t in _l(area['preferredTeams']))
          (teamName: _s(t['teamName']), lead: _s(t['lead']), assistants: [for (final a in (t['assistants'] as List? ?? const [])) a.toString()], match: _s(t['match'])),
      ],
      teams: _in(area['teams']) ?? 0,
      units: _l(j['units']).map(PreviewUnit.fromJson).toList(),
      day: j['day'] is Map ? FullDay.fromJson((j['day'] as Map).cast<String, dynamic>()) : null,
    );
  }
}

/// A date at HR's day limit: for each package, the artist who can take it at the asked time as a 4th work (her works that day close
/// together, her gap fits), or the other times it would fit. [canBook] — this person may save it (CRM / Artist Head / managers).
class FullDay {
  const FullDay({this.full = false, this.blocked = false, this.day = '', this.booked = 0, this.capacity = 0, this.left = 0, this.canBook = false, this.message = '', this.units = const []});
  final bool full, blocked, canBook;
  final String day, message;
  final int booked, capacity, left;
  final List<FullDayUnit> units;

  bool get anyFit => units.any((u) => u.fit != null);
  bool get allFit => units.isNotEmpty && units.every((u) => u.fit != null);
  bool get anyOption => units.any((u) => u.options.isNotEmpty);

  factory FullDay.fromJson(Map<String, dynamic> j) => FullDay(
        full: j['full'] == true,
        blocked: j['blocked'] == true,
        day: _s(j['day']),
        booked: _i(j['booked']),
        capacity: _i(j['capacity']),
        left: _i(j['left']),
        canBook: j['canBook'] == true,
        message: _s(j['message']),
        units: _l(j['units']).map(FullDayUnit.fromJson).toList(),
      );
}

class FullDayUnit {
  const FullDayUnit({required this.unitKey, this.label = '', this.start = '', this.end = '', this.place = '', this.fit, this.options = const []});
  final String unitKey, label, start, end, place;
  final ({String teamName, String lead, List<String> assistants, String reason, bool needsOk})? fit;
  final List<({String teamName, String lead, List<({String from, String to, String reason})> windows})> options;

  factory FullDayUnit.fromJson(Map<String, dynamic> j) {
    final f = j['fit'] is Map ? (j['fit'] as Map).cast<String, dynamic>() : null;
    return FullDayUnit(
      unitKey: _s(j['unitKey']),
      label: _s(j['label']),
      start: _s(j['start']),
      end: _s(j['end']),
      place: _s(j['place']),
      fit: f == null
          ? null
          : (
              teamName: _s(f['teamName']),
              lead: _s(f['lead']),
              assistants: [for (final a in (f['assistants'] as List? ?? const [])) a.toString()],
              // the rule's words without the slot talk ("EXTRA 2nd slot — every evening slot is full; … Needs the Artist Head's OK")
              reason: _s(f['reason']).replaceFirst(RegExp(r"^EXTRA [^—]*— [^;]*; "), '').replaceFirst(RegExp(r"\. Needs the Artist Head's OK$"), ''),
              needsOk: f['needsOk'] == true,
            ),
      options: [
        for (final o in _l(j['options']))
          (
            teamName: _s(o['teamName']),
            lead: _s(o['lead']),
            windows: [for (final w in _l(o['windows'])) (from: _s(w['from']), to: _s(w['to']), reason: _s(w['reason']))],
          ),
      ],
    );
  }
}

class PreviewUnit {
  const PreviewUnit({required this.unitKey, this.label = '', this.days = const [], this.ok = false, this.reason = '', this.teamName = '', this.lead = '', this.assistants = const []});
  final String unitKey, label, reason, teamName, lead;
  final bool ok;
  final List<({String day, String start, String place})> days;
  final List<String> assistants;

  /// "Fayiza, with Anjali"
  String get people {
    final with_ = assistants.length < 2 ? assistants.join() : '${assistants.sublist(0, assistants.length - 1).join(', ')} and ${assistants.last}';
    return [if (lead.isNotEmpty) lead, if (with_.isNotEmpty) 'with $with_'].join(', ');
  }

  factory PreviewUnit.fromJson(Map<String, dynamic> j) {
    final top = (j['top'] as Map?)?.cast<String, dynamic>();
    return PreviewUnit(
      unitKey: _s(j['unitKey']),
      label: _s(j['label']),
      days: [for (final d in _l(j['days'])) (day: _s(d['day']), start: _s(d['start']), place: _s(d['place']))],
      ok: j['ok'] == true,
      reason: _s(j['reason']),
      teamName: top == null ? '' : _s(top['teamName']),
      lead: top == null ? '' : _s(top['lead']),
      assistants: top == null ? const [] : [for (final a in (top['assistants'] as List? ?? const [])) a.toString()],
    );
  }
}
