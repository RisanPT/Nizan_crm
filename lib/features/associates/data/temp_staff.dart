// CONVERT THE OLD "TEMPORARY STAFF" BOX INTO ASSOCIATES — the models and the rules of the review screen. Before associates existed,
// Operations typed outside artists' names into one free-text box on a booking; the server reads those texts into one row per person
// (GET /api/associate-works/temp-staff) and a person decides, row by row, what each is (POST …/convert). Nothing changes until they do.

/// What a row is. [later] is not sent: the row stays for another time.
enum TempStaffAction { create, link, merge, skip, later }

extension TempStaffActionText on TempStaffAction {
  String get wire => name;
  String get label => switch (this) {
    TempStaffAction.create => 'A new associate',
    TempStaffAction.link => 'An associate already registered',
    TempStaffAction.merge => 'The same person as another name here',
    TempStaffAction.skip => 'Not an associate — ignore',
    TempStaffAction.later => 'Decide later',
  };
}

class TempStaffSample {
  const TempStaffSample({required this.bookingId, required this.bookingNumber, required this.customerName, required this.day, required this.text});
  final String bookingId, bookingNumber, customerName, day, text;

  factory TempStaffSample.fromJson(Map<String, dynamic> j) => TempStaffSample(
    bookingId: '${j['bookingId'] ?? ''}',
    bookingNumber: '${j['bookingNumber'] ?? ''}',
    customerName: '${j['customerName'] ?? ''}',
    day: '${j['day'] ?? ''}',
    text: '${j['text'] ?? ''}',
  );
}

class TempStaffVariant {
  const TempStaffVariant(this.name, this.count);
  final String name;
  final int count;
}

class TempStaffSuggestion {
  const TempStaffSuggestion({required this.employeeId, required this.name, required this.exact});
  final String employeeId, name;

  /// The same spelling (otherwise one letter off).
  final bool exact;
}

/// One person typed into the box, across every pending booking.
class TempStaffRow {
  const TempStaffRow({
    required this.key,
    required this.name,
    this.variants = const [],
    this.roleHint = '',
    this.phone = '',
    this.count = 0,
    this.samples = const [],
    this.similar = const [],
    this.suggestion,
  });

  /// The name's letters, lower-case — what the server and the other rows call this person.
  final String key;
  final String name;
  final List<TempStaffVariant> variants;
  final String roleHint, phone;
  final int count;
  final List<TempStaffSample> samples;

  /// Keys of other rows spelled one letter differently — maybe the same person.
  final List<String> similar;
  final TempStaffSuggestion? suggestion;

  factory TempStaffRow.fromJson(Map<String, dynamic> j) {
    final s = j['suggestion'];
    return TempStaffRow(
      key: '${j['key'] ?? ''}',
      name: '${j['name'] ?? ''}',
      variants: [for (final v in (j['variants'] as List? ?? const [])) TempStaffVariant('${(v as Map)['name']}', (v['count'] as num?)?.toInt() ?? 0)],
      roleHint: '${j['roleHint'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      count: (j['count'] as num?)?.toInt() ?? 0,
      samples: [for (final x in (j['samples'] as List? ?? const [])) TempStaffSample.fromJson(Map<String, dynamic>.from(x as Map))],
      similar: [for (final k in (j['similar'] as List? ?? const [])) '$k'],
      suggestion: s is Map ? TempStaffSuggestion(employeeId: '${s['employeeId']}', name: '${s['name']}', exact: s['exact'] == true) : null,
    );
  }
}

class TempStaffAssociate {
  const TempStaffAssociate({required this.id, required this.name, this.phone = '', this.status = ''});
  final String id, name, phone, status;
}

class TempStaffScan {
  const TempStaffScan({this.pendingBookings = 0, this.rows = const [], this.associates = const []});
  final int pendingBookings;
  final List<TempStaffRow> rows;
  final List<TempStaffAssociate> associates;

  factory TempStaffScan.fromJson(Map<String, dynamic> j) => TempStaffScan(
    pendingBookings: (j['pendingBookings'] as num?)?.toInt() ?? 0,
    rows: [for (final r in (j['rows'] as List? ?? const [])) TempStaffRow.fromJson(Map<String, dynamic>.from(r as Map))],
    associates: [
      for (final a in (j['associates'] as List? ?? const []))
        TempStaffAssociate(id: '${(a as Map)['id']}', name: '${a['name']}', phone: '${a['phone'] ?? ''}', status: '${a['status'] ?? ''}'),
    ],
  );
}

class TempStaffResult {
  const TempStaffResult({this.created = 0, this.linked = 0, this.reused = 0, this.skipped = 0, this.bookingsUpdated = 0, this.bookingsReviewed = 0, this.assignmentsAdded = 0, this.errors = const {}});
  final int created, linked, reused, skipped, bookingsUpdated, bookingsReviewed, assignmentsAdded;

  /// row key → what went wrong
  final Map<String, String> errors;

  factory TempStaffResult.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return TempStaffResult(
      created: n('created'),
      linked: n('linked'),
      reused: n('reused'),
      skipped: n('skipped'),
      bookingsUpdated: n('bookingsUpdated'),
      bookingsReviewed: n('bookingsReviewed'),
      assignmentsAdded: n('assignmentsAdded'),
      errors: {for (final e in (j['errors'] as List? ?? const [])) '${(e as Map)['key']}': '${e['message']}'},
    );
  }

  /// One plain sentence for the snackbar / result.
  String get summary {
    final parts = <String>[
      if (created > 0) '$created new ${created == 1 ? 'associate' : 'associates'}',
      if (linked + reused > 0) '${linked + reused} already registered',
      if (bookingsUpdated > 0) 'added to $bookingsUpdated ${bookingsUpdated == 1 ? 'booking' : 'bookings'}',
      if (skipped > 0) '$skipped ignored',
    ];
    return parts.isEmpty ? 'Nothing was changed.' : '${parts.join(' · ')}.';
  }
}

/// What a person has decided for one row so far.
class TempStaffDraft {
  TempStaffDraft({required this.row, required this.action, required this.name, this.phone = '', this.role = '', this.employeeId, this.into});

  /// The starting point: a name that is already a registered associate is linked to them; everyone else is a new associate (a lookalike
  /// registered name is only suggested — a person decides).
  factory TempStaffDraft.initial(TempStaffRow row) {
    final s = row.suggestion;
    final link = s != null && s.exact;
    return TempStaffDraft(
      row: row,
      action: link ? TempStaffAction.link : TempStaffAction.create,
      name: row.name,
      phone: row.phone,
      role: row.roleHint,
      employeeId: link ? s.employeeId : null,
    );
  }

  final TempStaffRow row;
  TempStaffAction action;
  String name, phone, role;
  String? employeeId;

  /// The key of the row this one is the same person as (action merge).
  String? into;

  /// One row of the request, or null when it stays for later.
  Map<String, dynamic>? toJson() => switch (action) {
    TempStaffAction.later => null,
    TempStaffAction.skip => {'key': row.key, 'action': 'skip'},
    TempStaffAction.merge => {'key': row.key, 'action': 'merge', 'into': into ?? '', if (role.trim().isNotEmpty) 'role': role.trim()},
    TempStaffAction.link => {'key': row.key, 'action': 'link', 'employeeId': employeeId ?? '', if (role.trim().isNotEmpty) 'role': role.trim()},
    TempStaffAction.create => {
      'key': row.key,
      'action': 'create',
      'name': name.trim(),
      if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (role.trim().isNotEmpty) 'role': role.trim(),
    },
  };

  /// Why this row cannot be converted yet, in plain words — or null when it can. [all] is every row's draft, by key.
  String? problem(Map<String, TempStaffDraft> all) {
    switch (action) {
      case TempStaffAction.later:
      case TempStaffAction.skip:
        return null;
      case TempStaffAction.create:
        if (name.trim().length < 2) return 'Give the associate’s name.';
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (phone.trim().isNotEmpty && (digits.length < 7 || digits.length > 15)) return 'The phone number does not look right.';
        return null;
      case TempStaffAction.link:
        return (employeeId ?? '').isEmpty ? 'Pick the registered associate.' : null;
      case TempStaffAction.merge:
        final target = all[into];
        if (target == null || target.row.key == row.key) return 'Choose who this is the same as.';
        if (target.action != TempStaffAction.create && target.action != TempStaffAction.link) return '“${target.row.name}” is not being added, so this cannot be the same person.';
        return null;
    }
  }
}

/// The review as a whole: what is ready to send, what is wrong, what it will do.
class TempStaffPlan {
  TempStaffPlan(this.drafts);
  final Map<String, TempStaffDraft> drafts;

  Iterable<TempStaffDraft> get _all => drafts.values;
  int count(TempStaffAction a) => _all.where((d) => d.action == a).length;

  /// row key → problem, for the rows that have one (left-for-later rows are never a problem).
  Map<String, String> get problems => {for (final d in _all) d.row.key: ?d.problem(drafts)};

  /// What goes to the server: every row that is not "later".
  List<Map<String, dynamic>> get request => [for (final d in _all) ?d.toJson()];

  /// Anything to send, and nothing wrong with it.
  bool get ready => request.isNotEmpty && problems.isEmpty;

  /// The names this plan adds to bookings (create + link + merge) — the rows that change bookings.
  int get adding => count(TempStaffAction.create) + count(TempStaffAction.link) + count(TempStaffAction.merge);
}
