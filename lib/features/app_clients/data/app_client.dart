/// A bridal-app client (ClientUser) as seen by staff. Mirrors the backend
/// `listView` / `getAppClient` serializers in `staffClientController.js`.
class AppClient {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String status; // active | blocked
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final int savedLookCount;
  final bool hasPreferences;

  const AppClient({
    required this.id,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.status = 'active',
    this.lastLoginAt,
    this.createdAt,
    this.savedLookCount = 0,
    this.hasPreferences = false,
  });

  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : (phone.isNotEmpty ? phone : 'Client');

  factory AppClient.fromJson(Map<String, dynamic> j) => AppClient(
        id: (j['_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        status: (j['status'] ?? 'active').toString(),
        lastLoginAt:
            DateTime.tryParse((j['lastLoginAt'] ?? '').toString())?.toLocal(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
        savedLookCount: (j['savedLookCount'] as num?)?.toInt() ?? 0,
        hasPreferences: j['hasPreferences'] == true,
      );
}

class SavedLook {
  final String id, look, culture;
  const SavedLook({this.id = '', this.look = '', this.culture = ''});
  factory SavedLook.fromJson(Map<String, dynamic> j) => SavedLook(
        id: (j['id'] ?? '').toString(),
        look: (j['look'] ?? '').toString(),
        culture: (j['culture'] ?? '').toString(),
      );
}

/// One chosen option (e.g. Outfit -> "Kanjeevaram red & gold").
class LookPick {
  final String category, optionId, name;
  const LookPick({this.category = '', this.optionId = '', this.name = ''});
  factory LookPick.fromJson(Map<String, dynamic> j) => LookPick(
        category: (j['category'] ?? '').toString(),
        optionId: (j['optionId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}

/// The look the bride built for one function of one tradition.
class LookPlanEntry {
  final String tradition, traditionName, function;
  final List<LookPick> picks;
  const LookPlanEntry({
    this.tradition = '',
    this.traditionName = '',
    this.function = '',
    this.picks = const [],
  });

  /// The pick for [category] (outfit | jewellery | hair | makeup), if any.
  LookPick? pick(String category) {
    for (final p in picks) {
      if (p.category == category) return p;
    }
    return null;
  }

  factory LookPlanEntry.fromJson(Map<String, dynamic> j) => LookPlanEntry(
        tradition: (j['tradition'] ?? '').toString(),
        traditionName: (j['traditionName'] ?? '').toString(),
        function: (j['function'] ?? '').toString(),
        picks: ((j['picks'] as List?) ?? const [])
            .map((e) => LookPick.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class AppClientBooking {
  final String id, bookingNumber, status, service;
  final DateTime? bookingDate;
  final num totalPrice, collectedAmount, balanceDue;
  final bool isTrial;
  final String culture;

  /// Look-plan brief the bride attached when requesting a trial.
  final String brief;

  const AppClientBooking({
    required this.id,
    this.bookingNumber = '',
    this.status = 'pending',
    this.service = '',
    this.bookingDate,
    this.totalPrice = 0,
    this.collectedAmount = 0,
    this.balanceDue = 0,
    this.isTrial = false,
    this.culture = '',
    this.brief = '',
  });

  factory AppClientBooking.fromJson(Map<String, dynamic> j) => AppClientBooking(
        id: (j['_id'] ?? '').toString(),
        bookingNumber: (j['bookingNumber'] ?? '').toString(),
        status: (j['status'] ?? 'pending').toString(),
        service: (j['service'] ?? '').toString(),
        bookingDate:
            DateTime.tryParse((j['bookingDate'] ?? '').toString())?.toLocal(),
        totalPrice: (j['totalPrice'] as num?) ?? 0,
        collectedAmount: (j['collectedAmount'] as num?) ?? 0,
        balanceDue: (j['balanceDue'] as num?) ?? 0,
        isTrial: j['isTrial'] == true,
        culture: (j['culture'] ?? '').toString(),
        brief: (j['brief'] ?? '').toString(),
      );
}

class AppClientDetail {
  final AppClient client;
  final String communityTag;
  final Map<String, List<String>> preferences;
  final List<SavedLook> savedLooks;
  final List<LookPlanEntry> lookPlan;
  final List<AppClientBooking> bookings;
  final String? conversationId;

  const AppClientDetail({
    required this.client,
    this.communityTag = '',
    this.preferences = const {},
    this.savedLooks = const [],
    this.lookPlan = const [],
    this.bookings = const [],
    this.conversationId,
  });

  factory AppClientDetail.fromJson(Map<String, dynamic> j) {
    final c = (j['client'] as Map<String, dynamic>?) ?? const {};
    final prefsRaw = (c['preferences'] as Map?) ?? const {};
    final prefs = <String, List<String>>{};
    prefsRaw.forEach((k, v) {
      prefs[k.toString()] =
          ((v as List?) ?? const []).map((e) => e.toString()).toList();
    });
    return AppClientDetail(
      client: AppClient.fromJson(c),
      communityTag: (c['communityTag'] ?? '').toString(),
      preferences: prefs,
      savedLooks: ((c['savedLooks'] as List?) ?? const [])
          .map((e) => SavedLook.fromJson(e as Map<String, dynamic>))
          .toList(),
      lookPlan: ((c['lookPlan'] as List?) ?? const [])
          .map((e) => LookPlanEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bookings: ((j['bookings'] as List?) ?? const [])
          .map((e) => AppClientBooking.fromJson(e as Map<String, dynamic>))
          .toList(),
      conversationId: (j['conversationId'])?.toString(),
    );
  }
}
