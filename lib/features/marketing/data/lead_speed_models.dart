// Lead Report → Speed to lead (backend controllers/marketingLeadReportController.js getSpeed; rules in utils/leadResponse.js).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// Working minutes in words: "—" when unknown, "8 min", "1 h 05 min", "2 d 3 h" (a working day being the hours set).
String workingTime(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '$minutes min';
  if (minutes < 24 * 60) return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
  return '${minutes ~/ (24 * 60)} d ${(minutes % (24 * 60)) ~/ 60} h';
}

/// The target, when the waiting alert goes out, the working hours (IST) waiting is counted in, and whether alerts are on.
class SpeedSettings {
  const SpeedSettings({this.targetMinutes = 15, this.alertAfterMinutes = 30, this.dayStart = '09:00', this.dayEnd = '21:00', this.alertsOn = true, this.updatedByName = '', this.updatedAt, this.canEdit = false});
  final int targetMinutes, alertAfterMinutes;
  final String dayStart, dayEnd, updatedByName;
  final bool alertsOn, canEdit;
  final DateTime? updatedAt;
  factory SpeedSettings.fromJson(Map<String, dynamic> j, {bool? canEdit}) => SpeedSettings(
        targetMinutes: _in(j['targetMinutes']) ?? 15,
        alertAfterMinutes: _in(j['alertAfterMinutes']) ?? 30,
        dayStart: _s(j['dayStart']).isEmpty ? '09:00' : _s(j['dayStart']),
        dayEnd: _s(j['dayEnd']).isEmpty ? '21:00' : _s(j['dayEnd']),
        alertsOn: j['alertsOn'] != false,
        updatedByName: _s(j['updatedByName']),
        updatedAt: _dt(j['updatedAt']),
        canEdit: canEdit ?? j['canEdit'] == true,
      );
}

/// The figures of a set of leads: came in, contacted, the median working minutes to a first contact, the share inside the target,
/// waiting now (and how many past the target), and those moved on with no contact recorded.
class SpeedStats {
  const SpeedStats({this.leads = 0, this.contacted = 0, this.medianMinutes, this.withinPct, this.waiting = 0, this.late = 0, this.unrecorded = 0});
  final int leads, contacted, waiting, late, unrecorded;
  final int? medianMinutes, withinPct;
  factory SpeedStats.fromJson(Map<String, dynamic> j) => SpeedStats(leads: _i(j['leads']), contacted: _i(j['contacted']), medianMinutes: _in(j['medianMinutes']), withinPct: _in(j['withinPct']), waiting: _i(j['waiting']), late: _i(j['late']), unrecorded: _i(j['unrecorded']));
}

class SpeedGroup {
  const SpeedGroup({required this.name, this.stats = const SpeedStats()});
  final String name;
  final SpeedStats stats;
  factory SpeedGroup.fromJson(Map<String, dynamic> j) => SpeedGroup(name: _s(j['name']), stats: SpeedStats.fromJson(j));
}

class WaitingLead {
  const WaitingLead({required this.id, this.name = '', this.source = '', this.assignee = '', this.arrivedAt, this.waitingMinutes = 0, this.late = false, this.alerted = false});
  final String id, name, source, assignee;
  final DateTime? arrivedAt;
  final int waitingMinutes;
  final bool late, alerted;
  factory WaitingLead.fromJson(Map<String, dynamic> j) => WaitingLead(id: _s(j['id']), name: _s(j['name']), source: _s(j['source']), assignee: _s(j['assignee']), arrivedAt: _dt(j['arrivedAt']), waitingMinutes: _i(j['waitingMinutes']), late: j['late'] == true, alerted: j['alerted'] == true);
}

class SlowLead {
  const SlowLead({required this.id, this.name = '', this.source = '', this.assignee = '', this.minutes = 0, this.firstBy = '', this.firstVia = ''});
  final String id, name, source, assignee, firstBy, firstVia;
  final int minutes;
  factory SlowLead.fromJson(Map<String, dynamic> j) => SlowLead(id: _s(j['id']), name: _s(j['name']), source: _s(j['source']), assignee: _s(j['assignee']), minutes: _i(j['minutes']), firstBy: _s(j['firstBy']), firstVia: _s(j['firstVia']));
}

class LeadSpeed {
  const LeadSpeed({this.scope = 'auto', this.settings = const SpeedSettings(), this.kpis = const SpeedStats(), this.previous = const SpeedStats(), this.byPerson = const [], this.bySource = const [], this.waiting = const [], this.slowest = const [], this.capped = false});
  final String scope;
  final SpeedSettings settings;
  final SpeedStats kpis, previous;
  final List<SpeedGroup> byPerson, bySource;
  final List<WaitingLead> waiting;
  final List<SlowLead> slowest;
  final bool capped;
  factory LeadSpeed.fromJson(Map<String, dynamic> j) => LeadSpeed(
        scope: _s(j['scope']).isEmpty ? 'auto' : _s(j['scope']),
        settings: SpeedSettings.fromJson(_m(j['settings']), canEdit: j['canEdit'] == true),
        kpis: SpeedStats.fromJson(_m(j['kpis'])),
        previous: SpeedStats.fromJson(_m(j['previous'])),
        byPerson: _l(j['byPerson']).map(SpeedGroup.fromJson).toList(),
        bySource: _l(j['bySource']).map(SpeedGroup.fromJson).toList(),
        waiting: _l(j['waiting']).map(WaitingLead.fromJson).toList(),
        slowest: _l(j['slowest']).map(SlowLead.fromJson).toList(),
        capped: j['capped'] == true,
      );
}

/// A lead's own first contact (the lead's page).
class FirstContact {
  const FirstContact({this.state = '', this.minutes, this.waitingMinutes, this.within, this.by = '', this.via = '', this.cameOnItsOwn = false, this.targetMinutes = 15});
  final String state, by, via;
  final int? minutes, waitingMinutes;
  final bool? within;
  final bool cameOnItsOwn;
  final int targetMinutes;
  factory FirstContact.fromJson(Map<String, dynamic> j) => FirstContact(state: _s(j['state']), minutes: _in(j['minutes']), waitingMinutes: _in(j['waitingMinutes']), within: j['within'] as bool?, by: _s(j['by']), via: _s(j['via']), cameOnItsOwn: j['cameOnItsOwn'] == true, targetMinutes: _in(j['targetMinutes']) ?? 15);

  /// In words: "First contact after 12 working min — call by Arjun", "Waiting 40 working min", "No contact recorded".
  String get text => switch (state) {
        'contacted' => 'First contact after ${workingTime(minutes)} (working time)${via.isNotEmpty || by.isNotEmpty ? ' — ${[if (via.isNotEmpty) via == 'status' ? 'moved on' : via, if (by.isNotEmpty) 'by $by'].join(' ')}' : ''}',
        'waiting' => 'Waiting ${workingTime(waitingMinutes)} (working time) for a first contact',
        'unrecorded' => 'Moved on with no contact recorded',
        _ => '',
      };
}
