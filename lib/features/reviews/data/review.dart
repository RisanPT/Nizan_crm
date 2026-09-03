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
