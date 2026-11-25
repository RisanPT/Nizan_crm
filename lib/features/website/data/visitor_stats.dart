/// Website visitor counts from `GET /website/admin/visitors?days=…`
/// (the website's own anonymous page-view counter).
class VisitorStats {
  final String from;
  final String to;
  final int days;
  final int visitors;
  final int newVisitors;
  final int visits;
  final int pageViews;
  final double pagesPerVisit;
  final int todayVisitors;
  final int todayPageViews;
  final int bookingRequests;
  final int contactEnquiries;

  /// % of visitors who sent a booking request.
  final double bookingRate;

  /// % of visitors who sent any enquiry (booking or contact).
  final double enquiryRate;
  final List<VisitorDay> daily;
  final List<VisitorRow> pages;
  final List<VisitorRow> sources;
  final List<VisitorRow> devices;
  final int retentionDays;

  const VisitorStats({
    required this.from,
    required this.to,
    required this.days,
    required this.visitors,
    required this.newVisitors,
    required this.visits,
    required this.pageViews,
    required this.pagesPerVisit,
    required this.todayVisitors,
    required this.todayPageViews,
    required this.bookingRequests,
    required this.contactEnquiries,
    required this.bookingRate,
    required this.enquiryRate,
    required this.daily,
    required this.pages,
    required this.sources,
    required this.devices,
    required this.retentionDays,
  });

  int get returningVisitors => (visitors - newVisitors).clamp(0, visitors);

  factory VisitorStats.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    List<VisitorRow> rows(Object? v, String key) => [
          for (final r in (v as List? ?? const []))
            VisitorRow.fromJson(m(r), key),
        ];

    final range = m(j['range']);
    final totals = m(j['totals']);
    final today = m(j['today']);
    final enq = m(j['enquiries']);
    return VisitorStats(
      from: range['from']?.toString() ?? '',
      to: range['to']?.toString() ?? '',
      days: i(range['days']),
      visitors: i(totals['visitors']),
      newVisitors: i(totals['newVisitors']),
      visits: i(totals['visits']),
      pageViews: i(totals['pageViews']),
      pagesPerVisit: d(totals['pagesPerVisit']),
      todayVisitors: i(today['visitors']),
      todayPageViews: i(today['pageViews']),
      bookingRequests: i(enq['booking']),
      contactEnquiries: i(enq['contact']),
      bookingRate: d(enq['bookingRate']),
      enquiryRate: d(enq['enquiryRate']),
      daily: [
        for (final r in (j['daily'] as List? ?? const []))
          VisitorDay(
            day: m(r)['day']?.toString() ?? '',
            visitors: i(m(r)['visitors']),
            pageViews: i(m(r)['pageViews']),
          ),
      ],
      pages: rows(j['pages'], 'path'),
      sources: rows(j['sources'], 'name'),
      devices: rows(j['devices'], 'name'),
      retentionDays: i(j['retentionDays']),
    );
  }
}

class VisitorDay {
  final String day; // YYYY-MM-DD (IST)
  final int visitors;
  final int pageViews;
  const VisitorDay({required this.day, required this.visitors, required this.pageViews});
}

/// One row of a breakdown (a page, a traffic source or a device type).
class VisitorRow {
  final String label;
  final int views;
  final int visitors;
  const VisitorRow({required this.label, required this.views, required this.visitors});

  factory VisitorRow.fromJson(Map<String, dynamic> j, String key) => VisitorRow(
        label: j[key]?.toString() ?? '',
        views: (j['views'] as num?)?.toInt() ?? 0,
        visitors: (j['visitors'] as num?)?.toInt() ?? 0,
      );
}

/// Friendly names for website pages and traffic sources.
String visitorPageLabel(String path) => switch (path) {
      '/' => 'Home',
      '/packages' => 'Packages',
      '/portfolio' => 'Portfolio',
      '/book' => 'Book',
      '/contact' => 'Contact',
      '/policies' => 'Policies',
      _ => path,
    };

String visitorSourceLabel(String source) => switch (source) {
      'direct' => 'Direct / typed in',
      'google' => 'Google',
      'bing' => 'Bing',
      'search' => 'Other search',
      'instagram' => 'Instagram',
      'facebook' => 'Facebook',
      'whatsapp' => 'WhatsApp',
      'youtube' => 'YouTube',
      'twitter' => 'X / Twitter',
      'linkedin' => 'LinkedIn',
      'pinterest' => 'Pinterest',
      _ => source,
    };

String visitorDeviceLabel(String device) => switch (device) {
      'mobile' => 'Phone',
      'tablet' => 'Tablet',
      'desktop' => 'Computer',
      _ => device,
    };
