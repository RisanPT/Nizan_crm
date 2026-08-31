/// One entry in a ticket's activity thread. Mirrors the backend sub-document.
class TicketActivity {
  final String byId;
  final String byName;
  final String kind; // created | comment | status | assign
  final String text;
  final DateTime? at;

  const TicketActivity({
    this.byId = '',
    this.byName = '',
    this.kind = 'comment',
    this.text = '',
    this.at,
  });

  factory TicketActivity.fromJson(Map<String, dynamic> j) {
    final by = j['by'];
    return TicketActivity(
      byId: by is Map ? (by['_id'] ?? '').toString() : (by ?? '').toString(),
      byName: by is Map ? (by['name'] ?? j['byName'] ?? '').toString() : (j['byName'] ?? '').toString(),
      kind: (j['kind'] ?? 'comment').toString(),
      text: (j['text'] ?? '').toString(),
      at: _date(j['at']),
    );
  }

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
}

/// An internal support ticket. Mirrors backend models/Ticket.js.
class Ticket {
  final String id;
  final String ticketNumber;
  final String title;
  final String description;
  final String type; // bug | feature | support
  final String priority; // low | medium | high | critical
  final String status; // open | in-progress | resolved | closed | rejected
  final String module;
  final String raisedById;
  final String raisedByName;
  final String departmentId;
  final String assignedToId;
  final String assignedToName;
  final List<String> screenshots;
  final List<TicketActivity> activity;
  final String resolution;
  final String linkedTaskId;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  const Ticket({
    required this.id,
    this.ticketNumber = '',
    this.title = '',
    this.description = '',
    this.type = 'bug',
    this.priority = 'medium',
    this.status = 'open',
    this.module = '',
    this.raisedById = '',
    this.raisedByName = '',
    this.departmentId = '',
    this.assignedToId = '',
    this.assignedToName = '',
    this.screenshots = const [],
    this.activity = const [],
    this.resolution = '',
    this.linkedTaskId = '',
    this.resolvedAt,
    this.createdAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> j) {
    final assignee = j['assignedTo'];
    final raiser = j['raisedBy'];
    final dept = j['departmentId'];
    return Ticket(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      ticketNumber: (j['ticketNumber'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      type: (j['type'] ?? 'bug').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      status: (j['status'] ?? 'open').toString(),
      module: (j['module'] ?? '').toString(),
      raisedById: raiser is Map ? (raiser['_id'] ?? '').toString() : (raiser ?? '').toString(),
      raisedByName: raiser is Map ? (raiser['name'] ?? j['raisedByName'] ?? '').toString() : (j['raisedByName'] ?? '').toString(),
      departmentId: dept is Map ? (dept['_id'] ?? '').toString() : (dept ?? '').toString(),
      assignedToId: assignee is Map ? (assignee['_id'] ?? '').toString() : (assignee ?? '').toString(),
      assignedToName: assignee is Map ? (assignee['name'] ?? j['assignedToName'] ?? '').toString() : (j['assignedToName'] ?? '').toString(),
      screenshots: (j['screenshots'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      activity: (j['activity'] as List?)
              ?.map((e) => TicketActivity.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      resolution: (j['resolution'] ?? '').toString(),
      linkedTaskId: () {
        final l = j['linkedTaskId'];
        return l is Map ? (l['_id'] ?? '').toString() : (l ?? '').toString();
      }(),
      resolvedAt: TicketActivity._date(j['resolvedAt']),
      createdAt: TicketActivity._date(j['createdAt']),
    );
  }
}

const ticketStatuses = ['open', 'in-progress', 'resolved', 'closed', 'rejected'];
const ticketTypes = ['bug', 'feature', 'support'];
const ticketPriorities = ['low', 'medium', 'high', 'critical'];

String ticketStatusLabel(String s) => switch (s) {
      'in-progress' => 'In Progress',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      'rejected' => 'Rejected',
      _ => 'Open',
    };

String ticketTypeLabel(String t) => switch (t) {
      'feature' => 'Feature',
      'support' => 'Support',
      _ => 'Bug',
    };
