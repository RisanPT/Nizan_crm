// A booking's CRM care (verified / photos ticks, medical notes, emergencies) and the CRM weekly report — as the server sends them
// (backend controllers/crmCareController.js, services/crmWeekly.js). A figure that could not be known is null ("—").

Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
int? _io(Object? v) => v == null ? null : (v as num).toInt();
num? _n(Object? v) => v is num ? v : null;
DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

const crmMedicalConditions = ['allergy', 'skin', 'pregnancy', 'other'];
String crmMedicalLabel(String c) => switch (c) {
  'allergy' => 'Allergy',
  'skin' => 'Skin condition',
  'pregnancy' => 'Pregnancy',
  'other' => 'Other',
  _ => c,
};

class CrmDayMark {
  final String day;
  final DateTime? at;
  final String byName;
  final String note;
  const CrmDayMark({required this.day, this.at, this.byName = '', this.note = ''});
  factory CrmDayMark.fromJson(Map<String, dynamic> j) => CrmDayMark(day: _s(j['day']), at: _d(j['at']), byName: _s(j['byName']), note: _s(j['note']));
}

class CrmEmergency {
  final String day;
  final DateTime? at;
  final String what;
  final String action;
  final String byName;
  const CrmEmergency({required this.day, this.at, this.what = '', this.action = '', this.byName = ''});
  factory CrmEmergency.fromJson(Map<String, dynamic> j) => CrmEmergency(day: _s(j['day']), at: _d(j['at']), what: _s(j['what']), action: _s(j['action']), byName: _s(j['byName']));
}

/// What the CRM did for one booking. [full] is false for an artist on the booking: they get the medical notes only.
class CrmCare {
  final String bookingId;
  final List<String> days;
  final List<String> conditions;
  final String medicalNote;
  final String medicalByName;
  final DateTime? medicalAt;
  final List<CrmEmergency> emergencies;
  final List<CrmDayMark>? verifications;
  final List<CrmDayMark>? photos;
  final bool canWrite;
  const CrmCare({
    required this.bookingId,
    this.days = const [],
    this.conditions = const [],
    this.medicalNote = '',
    this.medicalByName = '',
    this.medicalAt,
    this.emergencies = const [],
    this.verifications,
    this.photos,
    this.canWrite = false,
  });

  bool get full => verifications != null;
  bool get hasMedical => conditions.isNotEmpty;
  CrmDayMark? verifiedOn(String day) => verifications?.where((m) => m.day == day).firstOrNull;
  CrmDayMark? photosOn(String day) => photos?.where((m) => m.day == day).firstOrNull;

  factory CrmCare.fromJson(Map<String, dynamic> j) {
    final med = _m(j['medical']);
    return CrmCare(
      bookingId: _s(j['bookingId']),
      days: (j['days'] as List? ?? const []).map(_s).toList(),
      conditions: (med['conditions'] as List? ?? const []).map(_s).toList(),
      medicalNote: _s(med['note']),
      medicalByName: _s(med['updatedByName']),
      medicalAt: _d(med['updatedAt']),
      emergencies: _l(j['emergencies']).map(CrmEmergency.fromJson).toList(),
      verifications: j['verifications'] is List ? _l(j['verifications']).map(CrmDayMark.fromJson).toList() : null,
      photos: j['photos'] is List ? _l(j['photos']).map(CrmDayMark.fromJson).toList() : null,
      canWrite: j['canWrite'] == true,
    );
  }
}

/// One work on a to-do list (to verify with the client, photos to collect).
class CrmCareListItem {
  final String bookingId, bookingNumber, client, phone, day, byName;
  final bool done;
  final bool medical;
  const CrmCareListItem({required this.bookingId, required this.day, this.bookingNumber = '', this.client = '', this.phone = '', this.byName = '', this.done = false, this.medical = false});
  factory CrmCareListItem.fromJson(Map<String, dynamic> j) => CrmCareListItem(
    bookingId: _s(j['bookingId']),
    day: _s(j['day']),
    bookingNumber: _s(j['bookingNumber']),
    client: _s(j['client']),
    phone: _s(j['phone']),
    byName: _s(j['byName']),
    done: j['done'] == true,
    medical: j['medical'] == true,
  );
}

class CrmCareList {
  final String kind, from, to;
  final int works, done;
  final List<CrmCareListItem> items;
  const CrmCareList({this.kind = 'verify', this.from = '', this.to = '', this.works = 0, this.done = 0, this.items = const []});
  factory CrmCareList.fromJson(Map<String, dynamic> j) => CrmCareList(
    kind: _s(j['kind']),
    from: _s(j['from']),
    to: _s(j['to']),
    works: _i(j['works']),
    done: _i(j['done']),
    items: _l(j['items']).map(CrmCareListItem.fromJson).toList(),
  );
}

// ── the weekly report ───────────────────────────────────────────────────────

class CrmWeek {
  final String from, to, label;
  const CrmWeek({required this.from, required this.to, this.label = ''});
  factory CrmWeek.fromJson(Map<String, dynamic> j) => CrmWeek(from: _s(j['from']), to: _s(j['to']), label: _s(j['label']));
}

/// A work in a list of the report (missing photos, not verified …).
class CrmWorkRef {
  final String bookingId, bookingNumber, client, phone, day;
  const CrmWorkRef({this.bookingId = '', this.bookingNumber = '', this.client = '', this.phone = '', this.day = ''});
  factory CrmWorkRef.fromJson(Map<String, dynamic> j) =>
      CrmWorkRef(bookingId: _s(j['bookingId']), bookingNumber: _s(j['bookingNumber']), client: _s(j['client']), phone: _s(j['phone']), day: _s(j['day']));
}

/// What the CRM Head types.
class CrmWeeklyTyped {
  final int? startingMessagesNizan;
  final int? startingMessagesTeamN;
  final String startingMessagesNote;
  final String manpowerPlan;
  final String enoughWork; // '' | yes | no
  final String enoughWorkNote;
  final String notes;

  /// Figures typed by hand in place of the records' (key → count).
  final Map<String, int> overrides;

  /// A note per item (why a figure was typed, where it came from).
  final Map<String, String> sectionNotes;

  /// Outside-artist works typed in.
  final List<CrmOutsourceLine> outsourceLines;
  const CrmWeeklyTyped({
    this.startingMessagesNizan,
    this.startingMessagesTeamN,
    this.startingMessagesNote = '',
    this.manpowerPlan = '',
    this.enoughWork = '',
    this.enoughWorkNote = '',
    this.notes = '',
    this.overrides = const {},
    this.sectionNotes = const {},
    this.outsourceLines = const [],
  });
  factory CrmWeeklyTyped.fromJson(Map<String, dynamic> j) => CrmWeeklyTyped(
    startingMessagesNizan: _io(j['startingMessagesNizan']),
    startingMessagesTeamN: _io(j['startingMessagesTeamN']),
    startingMessagesNote: _s(j['startingMessagesNote']),
    manpowerPlan: _s(j['manpowerPlan']),
    enoughWork: _s(j['enoughWork']),
    enoughWorkNote: _s(j['enoughWorkNote']),
    notes: _s(j['notes']),
    overrides: {for (final e in _m(j['overrides']).entries) if (e.value is num) e.key: (e.value as num).toInt()},
    sectionNotes: {for (final e in _m(j['sectionNotes']).entries) if (_s(e.value).trim().isNotEmpty) e.key: _s(e.value)},
    outsourceLines: _l(j['outsourceLines']).map(CrmOutsourceLine.fromJson).toList(),
  );

  bool typedByHand(String key) => overrides.containsKey(key);
}

class CrmWorkloadDay {
  final String day;
  final int booked, capacity, spare;
  final bool over, blocked;
  const CrmWorkloadDay({required this.day, this.booked = 0, this.capacity = 0, this.spare = 0, this.over = false, this.blocked = false});
  factory CrmWorkloadDay.fromJson(Map<String, dynamic> j) =>
      CrmWorkloadDay(day: _s(j['day']), booked: _i(j['booked']), capacity: _i(j['capacity']), spare: _i(j['spare']), over: j['over'] == true, blocked: j['blocked'] == true);
}

class CrmWorkload {
  final String from, to;
  final List<CrmWorkloadDay> days;
  final int booked, capacity, overDays;
  const CrmWorkload({this.from = '', this.to = '', this.days = const [], this.booked = 0, this.capacity = 0, this.overDays = 0});
  factory CrmWorkload.fromJson(Map<String, dynamic> j) => CrmWorkload(
    from: _s(j['from']),
    to: _s(j['to']),
    days: _l(j['days']).map(CrmWorkloadDay.fromJson).toList(),
    booked: _i(j['booked']),
    capacity: _i(j['capacity']),
    overDays: _i(j['overDays']),
  );
}

class CrmVerification {
  final String from, to;
  final int works;
  final int? verified;
  final num? pct;
  final List<CrmWorkRef> unverified;
  const CrmVerification({this.from = '', this.to = '', this.works = 0, this.verified, this.pct, this.unverified = const []});
  factory CrmVerification.fromJson(Map<String, dynamic> j) => CrmVerification(
    from: _s(j['from']),
    to: _s(j['to']),
    works: _i(j['works']),
    verified: _io(j['verified']),
    pct: _n(j['pct']),
    unverified: _l(j['unverified']).map(CrmWorkRef.fromJson).toList(),
  );
}

class CrmMedicalRow {
  final String bookingId, client, bookingNumber, note;
  final List<String> days, conditions;
  const CrmMedicalRow({this.bookingId = '', this.client = '', this.bookingNumber = '', this.note = '', this.days = const [], this.conditions = const []});
  factory CrmMedicalRow.fromJson(Map<String, dynamic> j) => CrmMedicalRow(
    bookingId: _s(j['bookingId']),
    client: _s(j['client']),
    bookingNumber: _s(j['bookingNumber']),
    note: _s(j['note']),
    days: (j['days'] as List? ?? const []).map(_s).toList(),
    conditions: (j['conditions'] as List? ?? const []).map(_s).toList(),
  );
}

class CrmEmergencyRow {
  final String bookingId, client, day, what, action, byName;
  const CrmEmergencyRow({this.bookingId = '', this.client = '', this.day = '', this.what = '', this.action = '', this.byName = ''});
  factory CrmEmergencyRow.fromJson(Map<String, dynamic> j) =>
      CrmEmergencyRow(bookingId: _s(j['bookingId']), client: _s(j['client']), day: _s(j['day']), what: _s(j['what']), action: _s(j['action']), byName: _s(j['byName']));
}

class CrmOutsourceLine {
  final String bride, outsource, work, phone, day, bookingNumber;

  /// Typed in by the CRM Head (the records did not have it).
  final bool byHand;
  const CrmOutsourceLine({this.bride = '', this.outsource = '', this.work = '', this.phone = '', this.day = '', this.bookingNumber = '', this.byHand = false});
  factory CrmOutsourceLine.fromJson(Map<String, dynamic> j) => CrmOutsourceLine(
    bride: _s(j['bride']),
    outsource: _s(j['outsource']),
    work: _s(j['work']),
    phone: _s(j['phone']),
    day: _s(j['day']),
    bookingNumber: _s(j['bookingNumber']),
    byHand: j['byHand'] == true,
  );

  /// As a line typed in (PUT /crm/weekly outsourceLines).
  Map<String, dynamic> toTyped() => {'bride': bride, 'outsource': outsource, 'work': work, 'phone': phone, 'day': day};
}

/// A figure of the report the CRM Head can type by hand: its key, the item it belongs to, its name.
class CrmWeeklyField {
  final String key, section, label;
  const CrmWeeklyField({required this.key, required this.section, required this.label});
  factory CrmWeeklyField.fromJson(Map<String, dynamic> j) => CrmWeeklyField(key: _s(j['key']), section: _s(j['section']), label: _s(j['label']));
}

/// The eight items' figures.
class CrmWeeklyFigures {
  final CrmWeek nextWeek;
  // 1 trials
  final int trialsHeld, trialsCompleted, trialsCancelled, trialsPostponed, trialsConverted, trialsMaturing, trialsPrevHeld;
  // 2 photos & reviews
  final int worksDone, clientsDone, reviews;
  final int? photos;
  final num? photosPct, reviewsPct;
  final List<CrmWorkRef> missingPhotos, missingReviews;
  // 3 support
  final int supportClients, supportPrevClients, monthToDate, monthTarget;
  final String monthFrom, monthTo;
  final List<(String, int)> supportByMember;
  // 5 verification
  final CrmVerification verifyThisWeek, verifyNextWeek;
  // 6 medical
  final List<CrmMedicalRow>? withConditions;
  final List<CrmEmergencyRow>? emergencies;
  final int? medicalConditions, medicalEmergencies; // counts (typed by hand, else the lists')
  // 7 workload
  final CrmWorkload workloadThisWeek, workloadNextWeek;
  // 8 outsource
  final List<CrmOutsourceLine> outsource;
  final List<(String, String, int)> outsourceByPerson;
  final int outsourceTotal;

  const CrmWeeklyFigures({
    required this.nextWeek,
    this.trialsHeld = 0,
    this.trialsCompleted = 0,
    this.trialsCancelled = 0,
    this.trialsPostponed = 0,
    this.trialsConverted = 0,
    this.trialsMaturing = 0,
    this.trialsPrevHeld = 0,
    this.worksDone = 0,
    this.clientsDone = 0,
    this.reviews = 0,
    this.photos,
    this.photosPct,
    this.reviewsPct,
    this.missingPhotos = const [],
    this.missingReviews = const [],
    this.supportClients = 0,
    this.supportPrevClients = 0,
    this.monthToDate = 0,
    this.monthTarget = 100,
    this.monthFrom = '',
    this.monthTo = '',
    this.supportByMember = const [],
    this.verifyThisWeek = const CrmVerification(),
    this.verifyNextWeek = const CrmVerification(),
    this.withConditions,
    this.emergencies,
    this.medicalConditions,
    this.medicalEmergencies,
    this.workloadThisWeek = const CrmWorkload(),
    this.workloadNextWeek = const CrmWorkload(),
    this.outsource = const [],
    this.outsourceByPerson = const [],
    this.outsourceTotal = 0,
  });

  factory CrmWeeklyFigures.fromJson(Map<String, dynamic> j) {
    final t = _m(j['trials']);
    final p = _m(j['photosReviews']);
    final s = _m(j['support']);
    final v = _m(j['verification']);
    final med = _m(j['medical']);
    final w = _m(j['workload']);
    final o = _m(j['outsource']);
    return CrmWeeklyFigures(
      nextWeek: CrmWeek.fromJson(_m(j['nextWeek'])),
      trialsHeld: _i(t['held']),
      trialsCompleted: _i(t['completed']),
      trialsCancelled: _i(t['cancelled']),
      trialsPostponed: _i(t['postponed']),
      trialsConverted: _i(t['converted']),
      trialsMaturing: _i(t['maturing']),
      trialsPrevHeld: _i(t['prevHeld']),
      worksDone: _i(p['worksDone']),
      clientsDone: _i(p['clientsDone']),
      reviews: _i(p['reviews']),
      photos: _io(p['photos']),
      photosPct: _n(p['photosPct']),
      reviewsPct: _n(p['reviewsPct']),
      missingPhotos: _l(p['missingPhotos']).map(CrmWorkRef.fromJson).toList(),
      missingReviews: _l(p['missingReviews']).map(CrmWorkRef.fromJson).toList(),
      supportClients: _i(s['clients']),
      supportPrevClients: _i(s['prevClients']),
      monthToDate: _i(s['monthToDate']),
      monthTarget: _i(s['monthTarget'] ?? 100),
      monthFrom: _s(s['monthFrom']),
      monthTo: _s(s['monthTo']),
      supportByMember: [for (final m in _l(s['byMember'])) (_s(m['name']), _i(m['clients']))],
      verifyThisWeek: CrmVerification.fromJson(_m(v['thisWeek'])),
      verifyNextWeek: CrmVerification.fromJson(_m(v['nextWeek'])),
      withConditions: med['withConditions'] is List ? _l(med['withConditions']).map(CrmMedicalRow.fromJson).toList() : null,
      emergencies: med['emergencies'] is List ? _l(med['emergencies']).map(CrmEmergencyRow.fromJson).toList() : null,
      medicalConditions: _io(med['conditionsCount']) ?? (med['withConditions'] is List ? (med['withConditions'] as List).length : null),
      medicalEmergencies: _io(med['emergenciesCount']) ?? (med['emergencies'] is List ? (med['emergencies'] as List).length : null),
      workloadThisWeek: CrmWorkload.fromJson(_m(w['thisWeek'])),
      workloadNextWeek: CrmWorkload.fromJson(_m(w['nextWeek'])),
      outsource: _l(o['lines']).map(CrmOutsourceLine.fromJson).toList(),
      outsourceByPerson: [for (final x in _l(o['byPerson'])) (_s(x['name']), _s(x['phone']), _i(x['works']))],
      outsourceTotal: _io(o['total']) ?? _l(o['lines']).length,
    );
  }
}

class CrmWeeklyReport {
  final CrmWeek week;
  final String status; // new | draft | submitted
  final bool live;
  final CrmWeeklyTyped typed;

  /// The figures as the report shows them (what was typed by hand put in).
  final CrmWeeklyFigures figures;

  /// The records' own figure of each that can be typed by hand (key → value; null = not known).
  final Map<String, num?> records;

  /// The figures that can be typed by hand, item by item.
  final List<CrmWeeklyField> fields;
  final DateTime? submittedAt;
  final String submittedByName;
  final String updatedByName;
  final DateTime? updatedAt;
  const CrmWeeklyReport({
    required this.week,
    required this.figures,
    this.status = 'new',
    this.live = true,
    this.typed = const CrmWeeklyTyped(),
    this.records = const {},
    this.fields = const [],
    this.submittedAt,
    this.submittedByName = '',
    this.updatedByName = '',
    this.updatedAt,
  });

  bool get submitted => status == 'submitted';

  /// The figures of [section] that can be typed by hand.
  List<CrmWeeklyField> fieldsOf(String section) => [for (final f in fields) if (f.section == section) f];

  /// Was anything of [section] typed by hand?
  bool sectionTyped(String section) =>
      fieldsOf(section).any((f) => typed.typedByHand(f.key)) || (section == 'outsource' && typed.outsourceLines.isNotEmpty);

  factory CrmWeeklyReport.fromJson(Map<String, dynamic> j) => CrmWeeklyReport(
    week: CrmWeek.fromJson(_m(j['week'])),
    status: _s(j['status']).isEmpty ? 'new' : _s(j['status']),
    live: j['live'] != false,
    typed: CrmWeeklyTyped.fromJson(_m(j['typed'])),
    figures: CrmWeeklyFigures.fromJson(_m(j['figures'])),
    records: {for (final e in _m(j['records']).entries) e.key: _n(e.value)},
    fields: _l(j['fields']).map(CrmWeeklyField.fromJson).toList(),
    submittedAt: _d(j['submittedAt']),
    submittedByName: _s(j['submittedByName']),
    updatedByName: _s(j['updatedByName']),
    updatedAt: _d(j['updatedAt']),
  );
}

/// One week in the list of past weeks.
class CrmWeekStatus {
  final CrmWeek week;
  final String status;
  final String submittedByName;
  const CrmWeekStatus({required this.week, this.status = 'new', this.submittedByName = ''});
  factory CrmWeekStatus.fromJson(Map<String, dynamic> j) => CrmWeekStatus(week: CrmWeek.fromJson(j), status: _s(j['status']).isEmpty ? 'new' : _s(j['status']), submittedByName: _s(j['submittedByName']));
}
