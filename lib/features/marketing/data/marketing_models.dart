// Marketing / Competitor Intelligence models (Phase 1).

/// A weekly reading for a competitor. Numeric fields feed the master DB; the
/// boolean flags drive the deterministic 1-25 Weekly Growth Score.
class CompetitorSnapshot {
  final String id;
  final String competitorId;
  final DateTime weekOf;
  final double followers;
  final double weeklyGrowthPct;
  final double engagementRate;
  final int adCampaigns;
  final int offers;
  final int newServicesCount;
  final int postingFrequency;
  final int seoScore;
  final int reviews;
  final int collaborations;
  final String contentThemes;
  final bool newCampaign;
  final bool viralContent;
  final bool qualityCreative;
  final bool followerGrowth;
  final bool engagementIncrease;
  final bool newService;
  final bool newPartnership;
  final int score;
  final String notes;

  const CompetitorSnapshot({
    this.id = '',
    this.competitorId = '',
    required this.weekOf,
    this.followers = 0,
    this.weeklyGrowthPct = 0,
    this.engagementRate = 0,
    this.adCampaigns = 0,
    this.offers = 0,
    this.newServicesCount = 0,
    this.postingFrequency = 0,
    this.seoScore = 0,
    this.reviews = 0,
    this.collaborations = 0,
    this.contentThemes = '',
    this.newCampaign = false,
    this.viralContent = false,
    this.qualityCreative = false,
    this.followerGrowth = false,
    this.engagementIncrease = false,
    this.newService = false,
    this.newPartnership = false,
    this.score = 0,
    this.notes = '',
  });

  /// Score breakdown for display: label → points contributed.
  Map<String, int> get breakdown => {
        if (newCampaign) 'New campaign': 6,
        if (viralContent) 'Viral content': 5,
        if (qualityCreative) 'Quality creative': 5,
        if (followerGrowth) 'Follower growth': 3,
        if (engagementIncrease) 'Engagement increase': 3,
        if (newService) 'New service': 2,
        if (newPartnership) 'New partnership': 2,
      };

  factory CompetitorSnapshot.fromJson(Map<String, dynamic> json) {
    String cid(dynamic v) => (v is Map) ? (v['_id'] ?? '').toString() : (v ?? '').toString();
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    bool b(dynamic v) => v == true;
    return CompetitorSnapshot(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      competitorId: cid(json['competitor']),
      weekOf: DateTime.tryParse(json['weekOf'] as String? ?? '') ?? DateTime.now(),
      followers: d(json['followers']),
      weeklyGrowthPct: d(json['weeklyGrowthPct']),
      engagementRate: d(json['engagementRate']),
      adCampaigns: i(json['adCampaigns']),
      offers: i(json['offers']),
      newServicesCount: i(json['newServicesCount']),
      postingFrequency: i(json['postingFrequency']),
      seoScore: i(json['seoScore']),
      reviews: i(json['reviews']),
      collaborations: i(json['collaborations']),
      contentThemes: json['contentThemes'] as String? ?? '',
      newCampaign: b(json['newCampaign']),
      viralContent: b(json['viralContent']),
      qualityCreative: b(json['qualityCreative']),
      followerGrowth: b(json['followerGrowth']),
      engagementIncrease: b(json['engagementIncrease']),
      newService: b(json['newService']),
      newPartnership: b(json['newPartnership']),
      score: i(json['score']),
      notes: json['notes'] as String? ?? '',
    );
  }
}

class Competitor {
  final String id;
  final String name;
  final String city;
  final String website;
  final String category;
  final String instagram;
  final String facebook;
  final String youtube;
  final String linkedin;
  final bool active;
  final String notes;
  final CompetitorSnapshot? latestSnapshot;

  const Competitor({
    required this.id,
    required this.name,
    this.city = '',
    this.website = '',
    this.category = '',
    this.instagram = '',
    this.facebook = '',
    this.youtube = '',
    this.linkedin = '',
    this.active = true,
    this.notes = '',
    this.latestSnapshot,
  });

  int get score => latestSnapshot?.score ?? 0;
  double get followers => latestSnapshot?.followers ?? 0;

  factory Competitor.fromJson(Map<String, dynamic> json) {
    final snap = json['latestSnapshot'];
    return Competitor(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      website: json['website'] as String? ?? '',
      category: json['category'] as String? ?? '',
      instagram: json['instagram'] as String? ?? '',
      facebook: json['facebook'] as String? ?? '',
      youtube: json['youtube'] as String? ?? '',
      linkedin: json['linkedin'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      latestSnapshot: (snap is Map<String, dynamic>)
          ? CompetitorSnapshot.fromJson(snap)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'city': city,
        'website': website,
        'category': category,
        'instagram': instagram,
        'facebook': facebook,
        'youtube': youtube,
        'linkedin': linkedin,
        'active': active,
        'notes': notes,
      };
}

/// One row of the Weekly Growth Score ranking board.
class CompetitorRanking {
  final int rank;
  final String competitorId;
  final String name;
  final String city;
  final String category;
  final String instagram;
  final int score;
  final int? previousScore;
  final int? movement; // score - previousScore

  const CompetitorRanking({
    required this.rank,
    required this.competitorId,
    required this.name,
    this.city = '',
    this.category = '',
    this.instagram = '',
    this.score = 0,
    this.previousScore,
    this.movement,
  });

  factory CompetitorRanking.fromJson(Map<String, dynamic> json) =>
      CompetitorRanking(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        competitorId: json['competitorId']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        city: json['city'] as String? ?? '',
        category: json['category'] as String? ?? '',
        instagram: json['instagram'] as String? ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        previousScore: (json['previousScore'] as num?)?.toInt(),
        movement: (json['movement'] as num?)?.toInt(),
      );
}

class RankingBoard {
  final DateTime weekOf;
  final List<CompetitorRanking> rankings;
  const RankingBoard({required this.weekOf, required this.rankings});

  factory RankingBoard.fromJson(Map<String, dynamic> json) => RankingBoard(
        weekOf:
            DateTime.tryParse(json['weekOf'] as String? ?? '') ?? DateTime.now(),
        rankings: ((json['rankings'] as List?) ?? const [])
            .map((e) => CompetitorRanking.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
