// Stylist video consultations (SRS v1.2). Mirrors the backend Consultation
// model; list responses omit the notes fields, and a stylist who may not read a
// consultation's notes gets them stripped, so [notesVisible] says whether the
// server sent them at all.

const kConsultationStatuses = ['Scheduled', 'Completed', 'Cancelled', 'No-show'];
const kConsultationModes = ['Video', 'In-person'];
const kConsultationDurations = [15, 30, 45, 60, 90, 120];

DateTime? _date(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String _id(dynamic raw) {
  if (raw is Map) return (raw['_id'] ?? '').toString();
  return (raw ?? '').toString();
}

/// The client a consultation is for — a few fields of the underlying Lead.
class ConsultationLead {
  final String id;
  final String name;
  final String phone;
  final String eventType;
  final DateTime? eventDate;
  final String location;
  final String status;

  const ConsultationLead({
    this.id = '',
    this.name = '',
    this.phone = '',
    this.eventType = '',
    this.eventDate,
    this.location = '',
    this.status = '',
  });

  factory ConsultationLead.fromJson(dynamic json) {
    if (json is! Map) return ConsultationLead(id: _id(json));
    return ConsultationLead(
      id: _id(json),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      eventDate: _date(json['eventDate'] as String?),
      location: json['location'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

/// The client file a call belongs to — the few fields the server sends with
/// every call (CLIENT_FIELDS in consultationController.js).
class ConsultationClientRef {
  final String id;
  final String clientNo;
  final String company;
  final String name;
  final String phone;
  final String eventType;
  final List<String> eventDates;
  final int requiredCalls;
  final String status;

  const ConsultationClientRef({
    this.id = '',
    this.clientNo = '',
    this.company = '',
    this.name = '',
    this.phone = '',
    this.eventType = '',
    this.eventDates = const [],
    this.requiredCalls = 4,
    this.status = '',
  });

  bool get isEmpty => id.isEmpty;

  factory ConsultationClientRef.fromJson(dynamic json) {
    if (json is! Map) return ConsultationClientRef(id: _id(json));
    return ConsultationClientRef(
      id: _id(json),
      clientNo: json['clientNo'] as String? ?? '',
      company: json['company'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      eventDates: ((json['eventDates'] as List?) ?? const []).map((e) => '$e').toList(),
      requiredCalls: (json['requiredCalls'] as num?)?.toInt() ?? 4,
      status: json['status'] as String? ?? '',
    );
  }
}

/// A user who can be assigned consultations.
class ConsultationStylist {
  final String id;
  final String name;
  final String role;

  const ConsultationStylist({this.id = '', this.name = '', this.role = ''});

  factory ConsultationStylist.fromJson(Map<String, dynamic> json) =>
      ConsultationStylist(
        id: _id(json),
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
      );
}

/// Another consultation that overlaps a requested slot (HTTP 409 payload).
class ConsultationConflict {
  final String id;
  final String consultationNo;
  final DateTime? scheduledAt;
  final DateTime? endsAt;
  final String clientName;

  const ConsultationConflict({
    this.id = '',
    this.consultationNo = '',
    this.scheduledAt,
    this.endsAt,
    this.clientName = '',
  });

  factory ConsultationConflict.fromJson(Map<String, dynamic> json) =>
      ConsultationConflict(
        id: (json['id'] ?? '').toString(),
        consultationNo: json['consultationNo'] as String? ?? '',
        scheduledAt: _date(json['scheduledAt'] as String?),
        endsAt: _date(json['endsAt'] as String?),
        clientName: json['clientName'] as String? ?? '',
      );
}

class ConsultationHistoryEntry {
  final String action;
  final String status;
  final DateTime? at;
  final String byName;
  final String reason;
  final DateTime? fromAt;
  final DateTime? toAt;
  final List<String> fields;
  final bool overrodeConflict;

  const ConsultationHistoryEntry({
    this.action = '',
    this.status = '',
    this.at,
    this.byName = '',
    this.reason = '',
    this.fromAt,
    this.toAt,
    this.fields = const [],
    this.overrodeConflict = false,
  });

  factory ConsultationHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ConsultationHistoryEntry(
        action: json['action'] as String? ?? '',
        status: json['status'] as String? ?? '',
        at: _date(json['at'] as String?),
        byName: json['byName'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        fromAt: _date(json['fromAt'] as String?),
        toAt: _date(json['toAt'] as String?),
        fields: ((json['fields'] as List?) ?? const []).map((e) => '$e').toList(),
        overrodeConflict: json['overrodeConflict'] as bool? ?? false,
      );
}

/// A photo the client shared, attached to a consultation (stored on
/// Cloudinary; [url] is the full-size link).
class ConsultationImage {
  final String id;
  final String url;
  final String caption;
  final String uploadedByName;
  final DateTime? uploadedAt;

  const ConsultationImage({
    this.id = '',
    this.url = '',
    this.caption = '',
    this.uploadedByName = '',
    this.uploadedAt,
  });

  /// A small version for grids — Cloudinary resizes on the fly from the URL.
  String get thumbUrl => url.contains('/image/upload/')
      ? url.replaceFirst('/image/upload/', '/image/upload/c_fill,w_400,h_400,q_auto/')
      : url;

  factory ConsultationImage.fromJson(Map<String, dynamic> json) => ConsultationImage(
        id: _id(json),
        url: json['url'] as String? ?? '',
        caption: json['caption'] as String? ?? '',
        uploadedByName: json['uploadedByName'] as String? ?? '',
        uploadedAt: _date(json['uploadedAt'] as String?),
      );
}

class Consultation {
  final String id;
  final String consultationNo;
  final ConsultationLead lead;

  /// The client file (empty for a call made before client files existed and
  /// not yet migrated).
  final ConsultationClientRef client;

  /// Position in the client's series (1, 2, 3…); null when cancelled or a
  /// no-show, which don't count.
  final int? callNumber;
  final String stylistId;
  final String stylistName;
  final DateTime scheduledAt;
  final DateTime endsAt;
  final int durationMins;
  final String status;
  final String mode;
  final String meetingProvider;
  final String meetingLink;
  final String location;
  final String notes;
  final String preferences;
  final String nextSteps;

  // After-call details (all guarded by the notes permission, like [notes]).
  final String conveyed;
  final String lookMakeup;
  final String lookHair;
  final String lookOutfit;
  final String skinNotes;
  final List<ConsultationImage> referenceImages;

  /// False when the server withheld notes (the list endpoints, or a user
  /// without access) — the UI then hides the notes section instead of showing
  /// it empty.
  final bool notesVisible;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String cancelReason;
  final int rescheduleCount;
  final DateTime? inviteSentAt;
  final List<ConsultationHistoryEntry> history;

  const Consultation({
    this.id = '',
    this.consultationNo = '',
    this.lead = const ConsultationLead(),
    this.client = const ConsultationClientRef(),
    this.callNumber,
    this.stylistId = '',
    this.stylistName = '',
    required this.scheduledAt,
    required this.endsAt,
    this.durationMins = 45,
    this.status = 'Scheduled',
    this.mode = 'Video',
    this.meetingProvider = '',
    this.meetingLink = '',
    this.location = '',
    this.notes = '',
    this.preferences = '',
    this.nextSteps = '',
    this.conveyed = '',
    this.lookMakeup = '',
    this.lookHair = '',
    this.lookOutfit = '',
    this.skinNotes = '',
    this.referenceImages = const [],
    this.notesVisible = false,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason = '',
    this.rescheduleCount = 0,
    this.inviteSentAt,
    this.history = const [],
  });

  bool get isScheduled => status == 'Scheduled';
  bool get isVideo => mode == 'Video';

  /// The client's name: from the client file, else the Team N enquiry.
  String get clientName => client.name.isNotEmpty ? client.name : lead.name;

  /// The client's phone, the same way round (a Nizan client has no enquiry).
  String get clientPhone => client.phone.isNotEmpty ? client.phone : lead.phone;

  /// "Call 2 of 4", "Extra call 5", or '' when the call isn't numbered.
  String get callLabel {
    final n = callNumber;
    if (n == null) return '';
    final required = client.isEmpty ? 4 : client.requiredCalls;
    return n <= required ? 'Call $n of $required' : 'Extra call $n';
  }

  /// The after-call text by field key (the same keys the server uses).
  Map<String, String> get afterCallText => {
        'preferences': preferences,
        'conveyed': conveyed,
        'lookMakeup': lookMakeup,
        'lookHair': lookHair,
        'lookOutfit': lookOutfit,
        'skinNotes': skinNotes,
        'nextSteps': nextSteps,
        'notes': notes,
      };

  bool get hasAfterCallDetails =>
      referenceImages.isNotEmpty || afterCallText.values.any((v) => v.isNotEmpty);

  factory Consultation.fromJson(Map<String, dynamic> json) {
    final start = _date(json['scheduledAt'] as String?) ?? DateTime.now();
    final duration = (json['durationMins'] as num?)?.toInt() ?? 45;
    final stylist = json['stylistId'];
    return Consultation(
      id: _id(json),
      consultationNo: json['consultationNo'] as String? ?? '',
      lead: ConsultationLead.fromJson(json['leadId']),
      client: ConsultationClientRef.fromJson(json['clientId']),
      callNumber: (json['callNumber'] as num?)?.toInt(),
      stylistId: _id(stylist),
      stylistName: stylist is Map ? (stylist['name'] as String? ?? '') : '',
      scheduledAt: start,
      endsAt: _date(json['endsAt'] as String?) ??
          start.add(Duration(minutes: duration)),
      durationMins: duration,
      status: json['status'] as String? ?? 'Scheduled',
      mode: json['mode'] as String? ?? 'Video',
      meetingProvider: json['meetingProvider'] as String? ?? '',
      meetingLink: json['meetingLink'] as String? ?? '',
      location: json['location'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      preferences: json['preferences'] as String? ?? '',
      nextSteps: json['nextSteps'] as String? ?? '',
      conveyed: json['conveyed'] as String? ?? '',
      lookMakeup: json['lookMakeup'] as String? ?? '',
      lookHair: json['lookHair'] as String? ?? '',
      lookOutfit: json['lookOutfit'] as String? ?? '',
      skinNotes: json['skinNotes'] as String? ?? '',
      referenceImages: ((json['referenceImages'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConsultationImage.fromJson)
          .toList(),
      notesVisible: json.containsKey('notes'),
      completedAt: _date(json['completedAt'] as String?),
      cancelledAt: _date(json['cancelledAt'] as String?),
      cancelReason: json['cancelReason'] as String? ?? '',
      rescheduleCount: (json['rescheduleCount'] as num?)?.toInt() ?? 0,
      inviteSentAt: _date(json['inviteSentAt'] as String?),
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConsultationHistoryEntry.fromJson)
          .toList(),
    );
  }
}

/// A client's consultations plus the SRS client status derived server-side.
class LeadConsultations {
  final ConsultationLead lead;
  final String derivedStatus;
  final List<Consultation> consultations;

  const LeadConsultations({
    required this.lead,
    required this.derivedStatus,
    required this.consultations,
  });

  factory LeadConsultations.fromJson(Map<String, dynamic> json) =>
      LeadConsultations(
        lead: ConsultationLead.fromJson(json['lead']),
        derivedStatus: json['derivedStatus'] as String? ?? 'New',
        consultations: ((json['consultations'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Consultation.fromJson)
            .toList(),
      );
}
