import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

// Manual daily enquiry counts — ONE SHARED TEAM COUNT per day per channel.
// Anyone in sales enters / corrects it each morning and everyone (sales, sales
// head, marketing head) sees the same numbers. The Sales Dashboard compares it
// with the leads actually saved, and the Sales EOD uses it for lead counts on
// days that have one (days without one fall back to saved leads).
// Backend: /api/enquiry-counts (enquiryCountController.js).

/// One change to the shared team count.
class EnquiryHistoryEntry {
  final String channel;
  final int? from; // null = first entry
  final int to;
  final String byName;
  final DateTime? at;

  const EnquiryHistoryEntry({required this.channel, this.from, required this.to, required this.byName, this.at});

  factory EnquiryHistoryEntry.fromJson(Map<String, dynamic> j) => EnquiryHistoryEntry(
        channel: '${j['channel'] ?? ''}',
        from: (j['from'] as num?)?.toInt(),
        to: (j['to'] as num?)?.toInt() ?? 0,
        byName: '${j['byName'] ?? ''}',
        at: DateTime.tryParse('${j['at'] ?? ''}')?.toLocal(),
      );
}

/// One day's SHARED TEAM counts (the same for every salesperson).
class MyEnquiryCounts {
  final String date;
  final List<String> channels;
  final Map<String, int> counts;
  final bool entered;
  final bool canEdit;
  final DateTime? updatedAt;

  /// Who last changed the shared count, and the change log (newest first).
  final String updatedByName;
  final List<EnquiryHistoryEntry> history;

  const MyEnquiryCounts({
    required this.date,
    required this.channels,
    required this.counts,
    required this.entered,
    required this.canEdit,
    this.updatedAt,
    this.updatedByName = '',
    this.history = const [],
  });

  int get total => counts.values.fold(0, (s, v) => s + v);

  factory MyEnquiryCounts.fromJson(Map<String, dynamic> j) {
    final channels = [for (final c in (j['channels'] as List? ?? const [])) '$c'];
    final raw = (j['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MyEnquiryCounts(
      date: '${j['date'] ?? ''}',
      channels: channels,
      counts: {for (final c in channels) c: (raw[c] as num?)?.toInt() ?? 0},
      entered: j['entered'] == true,
      canEdit: j['canEdit'] == true,
      updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}')?.toLocal(),
      updatedByName: '${j['updatedByName'] ?? ''}',
      history: [
        for (final h in (j['history'] as List? ?? const []))
          EnquiryHistoryEntry.fromJson((h as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// Enquiries entered vs leads saved for one channel.
class EnquiryChannelCheck {
  final String channel;
  final int enquiries;
  final int leads;
  final int gap; // enquiries − leads saved; > 0 = enquiries not logged as leads

  const EnquiryChannelCheck(this.channel, this.enquiries, this.leads, this.gap);

  factory EnquiryChannelCheck.fromJson(Map<String, dynamic> j) => EnquiryChannelCheck(
        '${j['channel'] ?? ''}',
        (j['enquiries'] as num?)?.toInt() ?? 0,
        (j['leads'] as num?)?.toInt() ?? 0,
        (j['gap'] as num?)?.toInt() ?? 0,
      );
}

class EnquiryPersonCheck {
  final String userId;
  final String name;
  final int enquiries;
  final int leads;
  final int gap;
  final int daysEntered;
  final List<EnquiryChannelCheck> channels;

  const EnquiryPersonCheck({
    required this.userId,
    required this.name,
    required this.enquiries,
    required this.leads,
    required this.gap,
    required this.daysEntered,
    required this.channels,
  });

  factory EnquiryPersonCheck.fromJson(Map<String, dynamic> j) => EnquiryPersonCheck(
        userId: '${j['userId'] ?? ''}',
        name: '${j['name'] ?? 'Unknown'}',
        enquiries: (j['enquiries'] as num?)?.toInt() ?? 0,
        leads: (j['leads'] as num?)?.toInt() ?? 0,
        gap: (j['gap'] as num?)?.toInt() ?? 0,
        daysEntered: (j['daysEntered'] as num?)?.toInt() ?? 0,
        channels: [
          for (final c in (j['channels'] as List? ?? const []))
            EnquiryChannelCheck.fromJson((c as Map).cast<String, dynamic>()),
        ],
      );
}

class EnquiryVerification {
  final String from;
  final String to;
  final List<EnquiryChannelCheck> channels;
  final int totalEnquiries;
  final int totalLeads;
  final int totalGap;
  final List<EnquiryPersonCheck> people;
  final bool readOnly;

  /// Days in the range that have a manual team count.
  final int daysEntered;

  const EnquiryVerification({
    required this.from,
    required this.to,
    required this.channels,
    required this.totalEnquiries,
    required this.totalLeads,
    required this.totalGap,
    required this.people,
    required this.readOnly,
    this.daysEntered = 0,
  });

  factory EnquiryVerification.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return EnquiryVerification(
      from: '${j['from'] ?? ''}',
      to: '${j['to'] ?? ''}',
      channels: [
        for (final c in (j['channels'] as List? ?? const []))
          EnquiryChannelCheck.fromJson((c as Map).cast<String, dynamic>()),
      ],
      totalEnquiries: (t['enquiries'] as num?)?.toInt() ?? 0,
      totalLeads: (t['leads'] as num?)?.toInt() ?? 0,
      totalGap: (t['gap'] as num?)?.toInt() ?? 0,
      people: [
        for (final p in (j['people'] as List? ?? const []))
          EnquiryPersonCheck.fromJson((p as Map).cast<String, dynamic>()),
      ],
      readOnly: j['readOnly'] == true,
      daysEntered: (j['daysEntered'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 'YYYY-MM-DD' for a local date.
String enquiryDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class EnquiryCountService {
  final Dio _dio;
  EnquiryCountService(this._dio);

  Map<String, dynamic> _map(Object? data) => (data as Map).cast<String, dynamic>();

  Future<MyEnquiryCounts> getMine(String date) async {
    try {
      final res = await _dio.get('/enquiry-counts/day', queryParameters: {'date': date});
      return MyEnquiryCounts.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load the team enquiry counts');
    }
  }

  Future<MyEnquiryCounts> saveMine(String date, Map<String, int> counts) async {
    try {
      final res = await _dio.put('/enquiry-counts/day', data: {'date': date, 'counts': counts});
      return MyEnquiryCounts.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'save the team enquiry counts');
    }
  }

  Future<EnquiryVerification> verification({required String from, required String to}) async {
    try {
      final res = await _dio.get('/enquiry-counts/verification',
          queryParameters: {'from': from, 'to': to});
      return EnquiryVerification.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load the enquiry check');
    }
  }
}

final enquiryCountServiceProvider = Provider<EnquiryCountService>(
  (ref) => EnquiryCountService(ref.watch(dioProvider)),
);

/// The team's shared counts for a day ('YYYY-MM-DD').
final myEnquiryCountsProvider = FutureProvider.autoDispose.family<MyEnquiryCounts, String>(
  (ref, date) => ref.watch(enquiryCountServiceProvider).getMine(date),
);

/// Enquiries vs saved leads for an inclusive date range.
final enquiryVerificationProvider =
    FutureProvider.autoDispose.family<EnquiryVerification, ({String from, String to})>(
  (ref, r) => ref.watch(enquiryCountServiceProvider).verification(from: r.from, to: r.to),
);
