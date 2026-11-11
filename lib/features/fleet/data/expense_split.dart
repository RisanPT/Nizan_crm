// Which work(s) a driver's expense belongs to, who the artist on each is, and how
// much each carries (computed by the server — services/expenseDayContext.js).
//
// A "whole day" expense is shared EQUALLY across that day's works: ₹3,000 over
// 3 works is ₹1,000 each.

double _num0(Object? v) => (v as num?)?.toDouble() ?? 0;

class SplitArtist {
  final String name;

  /// lead | assistant
  final String roleType;
  const SplitArtist(this.name, this.roleType);

  bool get isLead => roleType == 'lead';
}

/// "Artist: Priya  ·  Assistants: Neha, Meera" — or "No artist assigned".
String artistSummary(List<SplitArtist> artists) {
  final named = artists.where((a) => a.name.trim().isNotEmpty).toList();
  final leads = named.where((a) => a.isLead).map((a) => a.name.trim()).toList();
  final others = named.where((a) => !a.isLead).map((a) => a.name.trim()).toList();
  if (leads.isEmpty && others.isEmpty) {
    return artists.isEmpty ? 'No artist assigned' : '${artists.length} artist${artists.length == 1 ? '' : 's'} (names missing)';
  }
  if (leads.isEmpty) return 'Artist: ${others.join(', ')}';
  return 'Artist: ${leads.join(', ')}'
      '${others.isEmpty ? '' : '  ·  Assistant${others.length == 1 ? '' : 's'}: ${others.join(', ')}'}';
}

class SplitWork {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final DateTime? start;
  final List<SplitArtist> artists;

  /// Address · pincode of the venue.
  final String place;
  final String mapUrl;

  /// This work's share of the expense.
  final double amount;

  const SplitWork({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.start,
    required this.artists,
    required this.place,
    required this.mapUrl,
    required this.amount,
  });

  factory SplitWork.fromJson(Map<String, dynamic> j) => SplitWork(
        bookingId: j['bookingId']?.toString() ?? '',
        bookingNumber: j['bookingNumber'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        start: DateTime.tryParse(j['serviceStart']?.toString() ?? '')?.toLocal(),
        artists: [
          for (final a in (j['artists'] as List? ?? const []))
            SplitArtist((a as Map)['name'] as String? ?? '', a['roleType'] as String? ?? 'assistant'),
        ],
        place: j['place'] as String? ?? '',
        mapUrl: j['mapUrl'] as String? ?? '',
        amount: _num0(j['amount']),
      );
}

class ExpenseSplit {
  /// direct | shared | unallocated
  final String mode;

  /// false for a rejected bill — shown, but not a cost.
  final bool counted;
  final String reason;
  final double total;
  final List<SplitWork> works;

  const ExpenseSplit({
    required this.mode,
    required this.counted,
    required this.reason,
    required this.total,
    required this.works,
  });

  bool get isShared => mode == 'shared';

  /// The per-work amount when every work carries the same (the usual case).
  double? get eachAmount {
    if (works.isEmpty) return null;
    final first = works.first.amount;
    return works.every((w) => (w.amount - first).abs() < 0.005) ? first : null;
  }

  factory ExpenseSplit.fromJson(Map<String, dynamic> j) => ExpenseSplit(
        mode: j['mode'] as String? ?? 'unallocated',
        counted: j['counted'] != false,
        reason: j['reason'] as String? ?? '',
        total: _num0(j['total']),
        works: [
          for (final w in (j['works'] as List? ?? const [])) SplitWork.fromJson((w as Map).cast<String, dynamic>()),
        ],
      );
}
