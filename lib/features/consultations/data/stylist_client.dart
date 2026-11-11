// A stylist's client file (backend models/StylistClient.js): who the client
// is, their event, and their numbered series of consultation calls. Team N
// clients are filled in from a CRM enquiry/booking; Nizan clients are typed in.

import 'consultation.dart';

const kClientCompanies = ['Team N', 'Nizan'];
const kClientStatuses = ['Active', 'Completed', 'Cancelled'];
const kDefaultRequiredCalls = 4;

DateTime? _date(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String _id(dynamic raw) {
  if (raw is Map) return (raw['_id'] ?? '').toString();
  return (raw ?? '').toString();
}

List<String> _strings(dynamic raw) =>
    ((raw as List?) ?? const []).map((e) => '$e').where((s) => s.isNotEmpty).toList();

/// 'YYYY-MM-DD' → a local date (no time-zone shift).
DateTime? parseDay(String day) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// A local date → 'YYYY-MM-DD'.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Where a client's series stands.
class ClientProgress {
  final int done;
  final int required;
  final int booked;
  final DateTime? nextCallAt;
  final String nextCallId;

  const ClientProgress({
    this.done = 0,
    this.required = kDefaultRequiredCalls,
    this.booked = 0,
    this.nextCallAt,
    this.nextCallId = '',
  });

  /// Completed calls beyond the required number.
  int get extra => done > required ? done - required : 0;
  bool get seriesDone => done >= required;

  factory ClientProgress.fromJson(dynamic json) {
    if (json is! Map) return const ClientProgress();
    return ClientProgress(
      done: (json['done'] as num?)?.toInt() ?? 0,
      required: (json['required'] as num?)?.toInt() ?? kDefaultRequiredCalls,
      booked: (json['booked'] as num?)?.toInt() ?? 0,
      nextCallAt: _date(json['nextCallAt'] as String?),
      nextCallId: _id(json['nextCallId']),
    );
  }
}

/// A reference image as gathered on the client page, with the call it is from.
class ClientImage {
  final ConsultationImage image;
  final String consultationId;
  final int? callNumber;
  final DateTime? callAt;

  const ClientImage({required this.image, this.consultationId = '', this.callNumber, this.callAt});

  factory ClientImage.fromJson(Map<String, dynamic> json) => ClientImage(
        image: ConsultationImage.fromJson(json),
        consultationId: _id(json['consultationId']),
        callNumber: (json['callNumber'] as num?)?.toInt(),
        callAt: _date(json['callAt'] as String?),
      );
}

class StylistClient {
  final String id;
  final String clientNo;
  final String company; // Team N | Nizan
  final String leadId;
  final String bookingId;
  final DateTime? syncedAt;

  final String name;
  final String phone;
  final String altPhone;
  final String email;
  final String eventType;
  final List<String> eventDates; // 'YYYY-MM-DD', sorted
  final String eventSlot;
  final String venue;
  final String district;
  final String culture;
  final String packageName;
  final String bookingNumber;
  final List<String> artistNames;
  final String outfitDetails;
  final String notes;

  final String stylistId;
  final String stylistName;
  final String status; // Active | Completed | Cancelled
  final int requiredCalls;
  final DateTime? createdAt;

  final ClientProgress progress;

  /// Only on the client page (GET /stylist-clients/:id), oldest first.
  final List<Consultation> calls;
  final List<ClientImage> images;

  const StylistClient({
    this.id = '',
    this.clientNo = '',
    this.company = 'Team N',
    this.leadId = '',
    this.bookingId = '',
    this.syncedAt,
    this.name = '',
    this.phone = '',
    this.altPhone = '',
    this.email = '',
    this.eventType = '',
    this.eventDates = const [],
    this.eventSlot = '',
    this.venue = '',
    this.district = '',
    this.culture = '',
    this.packageName = '',
    this.bookingNumber = '',
    this.artistNames = const [],
    this.outfitDetails = '',
    this.notes = '',
    this.stylistId = '',
    this.stylistName = '',
    this.status = 'Active',
    this.requiredCalls = kDefaultRequiredCalls,
    this.createdAt,
    this.progress = const ClientProgress(),
    this.calls = const [],
    this.images = const [],
  });

  bool get isTeamN => company == 'Team N';
  bool get isActive => status == 'Active';

  List<DateTime> get eventDays => eventDates.map(parseDay).whereType<DateTime>().toList();

  /// The next event day from today, or the last one when they've all passed.
  DateTime? get nextEventDay {
    final days = eventDays;
    if (days.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final d in days) {
      if (!d.isBefore(today)) return d;
    }
    return days.last;
  }

  /// Days until the next event (0 = today); null with no future event.
  int? get daysToEvent {
    final d = nextEventDay;
    if (d == null) return null;
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff < 0 ? null : diff;
  }

  /// Details for a create/update request (Nizan, or editing either kind).
  Map<String, dynamic> toEditJson() => {
        'name': name,
        'phone': phone,
        'altPhone': altPhone,
        'email': email,
        'eventType': eventType,
        'eventDates': eventDates,
        'eventSlot': eventSlot,
        'venue': venue,
        'district': district,
        'culture': culture,
        'packageName': packageName,
        'artistNames': artistNames,
        'outfitDetails': outfitDetails,
        'notes': notes,
        'requiredCalls': requiredCalls,
      };

  factory StylistClient.fromJson(Map<String, dynamic> json) {
    final stylist = json['stylistId'];
    return StylistClient(
      id: _id(json),
      clientNo: json['clientNo'] as String? ?? '',
      company: json['company'] as String? ?? 'Team N',
      leadId: _id(json['leadId']),
      bookingId: _id(json['bookingId']),
      syncedAt: _date(json['syncedAt'] as String?),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      altPhone: json['altPhone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      eventDates: _strings(json['eventDates']),
      eventSlot: json['eventSlot'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      district: json['district'] as String? ?? '',
      culture: json['culture'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      bookingNumber: json['bookingNumber'] as String? ?? '',
      artistNames: _strings(json['artistNames']),
      outfitDetails: json['outfitDetails'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      stylistId: _id(stylist),
      stylistName: stylist is Map ? (stylist['name'] as String? ?? '') : '',
      status: json['status'] as String? ?? 'Active',
      requiredCalls: (json['requiredCalls'] as num?)?.toInt() ?? kDefaultRequiredCalls,
      createdAt: _date(json['createdAt'] as String?),
      progress: ClientProgress.fromJson(json['progress']),
      calls: ((json['calls'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Consultation.fromJson)
          .toList(),
      images: ((json['images'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClientImage.fromJson)
          .toList(),
    );
  }
}

/// A Team N enquiry/booking found by "add a Team N client".
class TeamNCandidate {
  final String leadId;
  final String bookingId;
  final String name;
  final String phone;
  final String eventType;
  final DateTime? eventDate;
  final String bookingNumber;

  /// Set when this enquiry/booking already has a client file.
  final String clientId;

  /// Whether the caller may open that existing file (theirs, or a lead).
  final bool clientIsOwn;

  const TeamNCandidate({
    this.leadId = '',
    this.bookingId = '',
    this.name = '',
    this.phone = '',
    this.eventType = '',
    this.eventDate,
    this.bookingNumber = '',
    this.clientId = '',
    this.clientIsOwn = false,
  });

  bool get hasClient => clientId.isNotEmpty;

  factory TeamNCandidate.fromJson(Map<String, dynamic> json) => TeamNCandidate(
        leadId: _id(json['leadId']),
        bookingId: _id(json['bookingId']),
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        eventType: json['eventType'] as String? ?? '',
        eventDate: _date(json['eventDate'] as String?),
        bookingNumber: json['bookingNumber'] as String? ?? '',
        clientId: _id(json['clientId']),
        clientIsOwn: json['clientIsOwn'] as bool? ?? false,
      );
}
