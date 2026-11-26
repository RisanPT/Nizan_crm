// The WORK behind a gallery photo / video (a CRM booking: its client, day, services, place and artists) and the client's review of
// it — the one the CRM sends the morning after the work, matched by the booking (backend utils/workReview.js). Every artist on a work
// gets the work's rating. Also the Artist Quality view built from those reviews.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// The client-review filters on the gallery, in their order, with their words.
const kReviewFilters = [('great', '★ 4.5 and up'), ('good', '★ 3.5 – 4.4'), ('low', '★ below 3.5'), ('complaint', 'Complaint'), ('waiting', 'Review sent, waiting')];
String reviewFilterLabel(String v) => kReviewFilters.firstWhere((e) => e.$1 == v, orElse: () => (v, v)).$2;

/// A rating's colour: green 4.5 and up, amber from 3.5, red below; grey when there is none.
Color ratingColor(double score) => score >= 4.5
    ? const Color(0xFF22A06B)
    : score >= 3.5
        ? const Color(0xFFF5A524)
        : score > 0
            ? const Color(0xFFE5484D)
            : const Color(0xFF9AA0A6);

/// "4.5" / "4" — a rating as people say it.
String ratingText(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// 'YYYY-MM-DD' → "Sun 1 Nov 2026" (or [pattern]); '' stays ''.
String workDayText(String day, {String pattern = 'EEE d MMM yyyy'}) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat(pattern).format(d);
}

class WorkArtist {
  const WorkArtist({required this.key, this.id = '', required this.name, this.role = ''});

  /// The employee id, or "n:name" for a person kept by name only.
  final String key, id, name, role;
  bool get isLead => role == 'Lead Artist';
  factory WorkArtist.fromJson(Map<String, dynamic> j) => WorkArtist(key: _s(j['key']).isEmpty ? _s(j['id']) : _s(j['key']), id: _s(j['id']), name: _s(j['name']), role: _s(j['role']));
}

class ScoreArea {
  const ScoreArea({required this.key, required this.label, this.value = 0, this.count = 0});
  final String key, label;
  final double value;
  final int count;
  factory ScoreArea.fromJson(Map<String, dynamic> j) => ScoreArea(key: _s(j['key']), label: _s(j['label']), value: _dn(j['value'] ?? j['avg']) ?? 0, count: _i(j['count']));
}

/// The client's review of a work. [status] 'submitted' (answered), 'pending' (sent, waiting) or 'expired'.
class WorkReview {
  const WorkReview({
    this.id = '',
    required this.status,
    this.sentAt,
    this.submittedAt,
    this.score = 0,
    this.band = 'none',
    this.overall = 0,
    this.nps,
    this.areas = const [],
    this.answers = const [],
    this.likedMost = '',
    this.couldBeBetter = '',
    this.artistDidWell = '',
    this.artistImprove = '',
    this.testimonial = '',
    this.marketingConsent = false,
    this.complaint = false,
    this.compliment = false,
    this.followUpRequired = false,
    this.needsAttention = false,
  });
  final String id, status, band;
  final DateTime? sentAt, submittedAt;
  final double score, overall;
  final int? nps;
  final List<ScoreArea> areas;

  /// The multiple-choice answers in words: (question, answer).
  final List<(String, String)> answers;
  final String likedMost, couldBeBetter, artistDidWell, artistImprove, testimonial;
  final bool marketingConsent, complaint, compliment, followUpRequired, needsAttention;

  bool get answered => status == 'submitted';
  bool get waiting => status == 'pending';

  factory WorkReview.fromJson(Map<String, dynamic> j) => WorkReview(
        id: _s(j['id']),
        status: _s(j['status']),
        sentAt: _dt(j['sentAt']),
        submittedAt: _dt(j['submittedAt']),
        score: _dn(j['score']) ?? 0,
        band: _s(j['band']).isEmpty ? 'none' : _s(j['band']),
        overall: _dn(j['overall']) ?? 0,
        nps: (j['nps'] as num?)?.toInt(),
        areas: _l(j['areas']).map(ScoreArea.fromJson).toList(),
        answers: [for (final a in _l(j['answers'])) (_s(a['label']), _s(a['value']))],
        likedMost: _s(j['likedMost']),
        couldBeBetter: _s(j['couldBeBetter']),
        artistDidWell: _s(j['artistDidWell']),
        artistImprove: _s(j['artistImprove']),
        testimonial: _s(j['testimonial']),
        marketingConsent: j['marketingConsent'] == true,
        complaint: j['complaint'] == true,
        compliment: j['compliment'] == true,
        followUpRequired: j['followUpRequired'] == true,
        needsAttention: j['needsAttention'] == true,
      );
}

/// The work a gallery item came from.
class AssetWork {
  const AssetWork({required this.bookingId, this.bookingNumber = '', this.client = '', this.eventDay = '', this.workDay = '', this.services = const [], this.place = '', this.bookingStatus = '', this.artists = const [], this.review});
  final String bookingId, bookingNumber, client, eventDay, workDay, place, bookingStatus;
  final List<String> services;
  final List<WorkArtist> artists;

  /// null = no review sent for this work yet.
  final WorkReview? review;

  /// The day shown: the day of a multi-day work this item is from, else the event day.
  String get day => workDay.isNotEmpty ? workDay : eventDay;

  /// "#BK-1001 · Amina K"
  String get title => [if (bookingNumber.isNotEmpty) '#$bookingNumber', if (client.isNotEmpty) client].join(' · ');

  /// "Nihala, Sana" — the lead first.
  String get artistNames => artists.map((a) => a.name).where((n) => n.isNotEmpty).join(', ');

  factory AssetWork.fromJson(Map<String, dynamic> j) => AssetWork(
        bookingId: _s(j['bookingId']),
        bookingNumber: _s(j['bookingNumber']),
        client: _s(j['client']),
        eventDay: _s(j['eventDay']),
        workDay: _s(j['workDay']),
        services: ((j['services'] as List?) ?? const []).map(_s).where((x) => x.isNotEmpty).toList(),
        place: _s(j['place']),
        bookingStatus: _s(j['bookingStatus']),
        artists: _l(j['artists']).map(WorkArtist.fromJson).toList(),
        review: j['review'] is Map ? WorkReview.fromJson(_m(j['review'])) : null,
      );
}

// ── Artist Quality ──────────────────────────────────────────────────────────

/// One artist's quality from the clients' reviews of their works.
class ArtistQuality {
  const ArtistQuality({required this.key, this.id = '', required this.name, this.works = 0, this.reviewed = 0, this.waiting = 0, this.avgScore, this.nps, this.npsResponses = 0, this.complaints = 0, this.low = 0, this.great = 0, this.assets = 0, this.areas = const [], this.weakest, this.lastIssueDay = '', this.needsAttention = false});
  final String key, id, name, lastIssueDay;
  final int works, reviewed, waiting, npsResponses, complaints, low, great, assets;
  final double? avgScore;
  final int? nps;
  final List<ScoreArea> areas;

  /// Where the clients rate this artist lowest (below 4 stars); null = no weak area.
  final ScoreArea? weakest;
  final bool needsAttention;

  factory ArtistQuality.fromJson(Map<String, dynamic> j) => ArtistQuality(
        key: _s(j['key']),
        id: _s(j['id']),
        name: _s(j['name']),
        works: _i(j['works']),
        reviewed: _i(j['reviewed']),
        waiting: _i(j['waiting']),
        avgScore: _dn(j['avgScore']),
        nps: (j['nps'] as num?)?.toInt(),
        npsResponses: _i(j['npsResponses']),
        complaints: _i(j['complaints']),
        low: _i(j['low']),
        great: _i(j['great']),
        assets: _i(j['assets']),
        areas: _l(j['areas']).map(ScoreArea.fromJson).toList(),
        weakest: j['weakest'] is Map ? ScoreArea.fromJson(_m(j['weakest'])) : null,
        lastIssueDay: _s(j['lastIssueDay']),
        needsAttention: j['needsAttention'] == true,
      );
}

class QualityTotals {
  const QualityTotals({this.works = 0, this.reviewed = 0, this.waiting = 0, this.avgScore, this.nps, this.complaints = 0, this.low = 0, this.great = 0});
  final int works, reviewed, waiting, complaints, low, great;
  final double? avgScore;
  final int? nps;
  factory QualityTotals.fromJson(Map<String, dynamic> j) => QualityTotals(works: _i(j['works']), reviewed: _i(j['reviewed']), waiting: _i(j['waiting']), avgScore: _dn(j['avgScore']), nps: (j['nps'] as num?)?.toInt(), complaints: _i(j['complaints']), low: _i(j['low']), great: _i(j['great']));
}

class QualityReport {
  const QualityReport({required this.from, required this.to, this.totals = const QualityTotals(), this.artists = const []});
  final String from, to;
  final QualityTotals totals;
  final List<ArtistQuality> artists;
  factory QualityReport.fromJson(Map<String, dynamic> j) => QualityReport(from: _s(j['from']), to: _s(j['to']), totals: QualityTotals.fromJson(_m(j['totals'])), artists: _l(j['artists']).map(ArtistQuality.fromJson).toList());
}

/// One of an artist's works in the quality view, with its gallery items (raw JSON — the caller builds them as assets).
class QualityWork {
  const QualityWork({required this.work, this.items = const [], this.raw = const {}});
  final AssetWork work;
  final List<Map<String, dynamic>> items;

  /// The work as the server sent it — put on each item, so opening one shows the work and the review too.
  final Map<String, dynamic> raw;
}

class ArtistQualityDetail {
  const ArtistQualityDetail({required this.artist, this.works = const []});
  final ArtistQuality artist;
  final List<QualityWork> works;
  factory ArtistQualityDetail.fromJson(Map<String, dynamic> j) => ArtistQualityDetail(
        artist: ArtistQuality.fromJson(_m(j['artist'])),
        works: [for (final w in _l(j['works'])) QualityWork(work: AssetWork.fromJson(w), items: _l(w['items']), raw: Map<String, dynamic>.from(w)..remove('items'))],
      );
}
