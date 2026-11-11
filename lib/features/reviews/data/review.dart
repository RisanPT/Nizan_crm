/// A submitted (or pending) post-service client review.
class Review {
  final String id;
  final String bookingNumber;
  final String brideName;
  final DateTime? weddingDate;
  final String venue;
  final String artistName;
  final List<String> artistNames;
  final List<({String name, String role})> teamMembers;
  final String status; // pending | submitted | expired
  final DateTime? submittedAt;
  final DateTime createdAt;

  // How the link reached the client: by hand ("Send Review") or the automatic
  // next-day WhatsApp send. autoSendStatus: '' | sending | retry | sent | skipped | failed.
  final DateTime? manualSentAt;
  final String autoSendStatus;
  final DateTime? autoSentAt;
  final String autoSendError;

  // Bride answers
  final int overall, makeup, hair, saree;
  final Map<String, int> teamBehaviour;
  final String lookMatch, comfortable, recommend, bookAgain;
  final String likedMost, couldBeBetter;

  // Team-member answers
  final Map<String, int> teamMember;
  final String teamMemberDidWell, teamMemberImprove;

  // Marketing
  final String testimonial;
  final bool marketingConsent, tagConsent;
  final String instagram;

  // NPS
  final int? nps;

  // Internal
  final double brideScore, teamMemberScore;
  final bool complaint, compliment, followUpRequired, reviewPosted, referralOpportunity;
  final String managerComments;

  const Review({
    required this.id,
    this.bookingNumber = '',
    this.brideName = '',
    this.weddingDate,
    this.venue = '',
    this.artistName = '',
    this.artistNames = const [],
    this.teamMembers = const [],
    this.status = 'pending',
    this.submittedAt,
    required this.createdAt,
    this.manualSentAt,
    this.autoSendStatus = '',
    this.autoSentAt,
    this.autoSendError = '',
    this.overall = 0,
    this.makeup = 0,
    this.hair = 0,
    this.saree = 0,
    this.teamBehaviour = const {},
    this.lookMatch = '',
    this.comfortable = '',
    this.recommend = '',
    this.bookAgain = '',
    this.likedMost = '',
    this.couldBeBetter = '',
    this.teamMember = const {},
    this.teamMemberDidWell = '',
    this.teamMemberImprove = '',
    this.testimonial = '',
    this.marketingConsent = false,
    this.tagConsent = false,
    this.instagram = '',
    this.nps,
    this.brideScore = 0,
    this.teamMemberScore = 0,
    this.complaint = false,
    this.compliment = false,
    this.followUpRequired = false,
    this.reviewPosted = false,
    this.referralOpportunity = false,
    this.managerComments = '',
  });

  bool get isSubmitted => status == 'submitted';

  /// One line on how the review link was sent, for a pending review; empty
  /// when nothing has happened yet.
  String get sendNote {
    if (autoSendStatus == 'sent' && autoSentAt != null) {
      final d = autoSentAt!.toLocal();
      return 'Sent on WhatsApp automatically ${d.day}/${d.month}';
    }
    if (manualSentAt != null) {
      final d = manualSentAt!.toLocal();
      return 'Sent by staff ${d.day}/${d.month}';
    }
    if (autoSendStatus == 'failed') {
      return 'Auto-send failed: ${autoSendError.isEmpty ? 'unknown error' : autoSendError}';
    }
    if (autoSendStatus == 'skipped' && autoSendError.isNotEmpty) return 'Not auto-sent: $autoSendError';
    if (autoSendStatus == 'retry') return 'Auto-send will retry tomorrow';
    return '';
  }

  /// Auto-send gave up or was refused — staff should send it by hand.
  bool get needsManualSend =>
      !isSubmitted && manualSentAt == null && (autoSendStatus == 'failed' || autoSendStatus == 'skipped');

  static int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
  static double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  static Map<String, int> _map(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _i(val)));
    }
    return const {};
  }

  static DateTime? _date(dynamic v) =>
      (v == null || '$v'.isEmpty) ? null : DateTime.tryParse('$v');

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        bookingNumber: (j['bookingNumber'] ?? '').toString(),
        brideName: (j['brideName'] ?? '').toString(),
        weddingDate: _date(j['weddingDate']),
        venue: (j['venue'] ?? '').toString(),
        artistName: (j['artistName'] ?? '').toString(),
        artistNames: ((j['artistNames'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        teamMembers: ((j['teamMembers'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => (
                  name: (m['name'] ?? '').toString(),
                  role: (m['role'] ?? '').toString(),
                ))
            .toList(),
        status: (j['status'] ?? 'pending').toString(),
        submittedAt: _date(j['submittedAt']),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        manualSentAt: _date(j['manualSentAt']),
        autoSendStatus: (j['autoSendStatus'] ?? '').toString(),
        autoSentAt: _date(j['autoSentAt']),
        autoSendError: (j['autoSendError'] ?? '').toString(),
        overall: _i(j['overall']),
        makeup: _i(j['makeup']),
        hair: _i(j['hair']),
        saree: _i(j['saree']),
        teamBehaviour: _map(j['teamBehaviour']),
        lookMatch: (j['lookMatch'] ?? '').toString(),
        comfortable: (j['comfortable'] ?? '').toString(),
        recommend: (j['recommend'] ?? '').toString(),
        bookAgain: (j['bookAgain'] ?? '').toString(),
        likedMost: (j['likedMost'] ?? '').toString(),
        couldBeBetter: (j['couldBeBetter'] ?? '').toString(),
        teamMember: _map(j['teamMember']),
        teamMemberDidWell: (j['teamMemberDidWell'] ?? '').toString(),
        teamMemberImprove: (j['teamMemberImprove'] ?? '').toString(),
        testimonial: (j['testimonial'] ?? '').toString(),
        marketingConsent: j['marketingConsent'] == true,
        tagConsent: j['tagConsent'] == true,
        instagram: (j['instagram'] ?? '').toString(),
        nps: j['nps'] == null ? null : _i(j['nps']),
        brideScore: _d(j['brideScore']),
        teamMemberScore: _d(j['teamMemberScore']),
        complaint: j['complaint'] == true,
        compliment: j['compliment'] == true,
        followUpRequired: j['followUpRequired'] == true,
        reviewPosted: j['reviewPosted'] == true,
        referralOpportunity: j['referralOpportunity'] == true,
        managerComments: (j['managerComments'] ?? '').toString(),
      );
}
