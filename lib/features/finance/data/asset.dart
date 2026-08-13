/// A company asset — digital (domains, licenses, social accounts…) or physical
/// (equipment, furniture, vehicles…). Managed under Finance → Assets.
class Asset {
  final String id;
  final String name;
  final String assetType; // 'digital' | 'physical'
  final String category;
  final double value;
  final int quantity;
  final DateTime? purchaseDate;
  final String status;
  final String custodian;
  final String custodianEmployeeId;
  final String custodianName;
  // Physical
  final String location;
  final String condition;
  final String serialNumber;
  final String imageUrl;
  // Digital
  final String provider;
  final String url;
  final DateTime? expiryDate;
  final String notes;
  // Depreciation
  final bool depreciable;
  final String depreciationMethod; // 'straight_line' | 'wdv'
  final double depreciationRate;
  final double usefulLifeYears;
  final double salvageValue;
  final DateTime? depreciationStart;
  final double accumulatedDepreciation;
  final DateTime? lastDepreciatedOn;
  final DateTime createdAt;

  const Asset({
    required this.id,
    required this.name,
    required this.assetType,
    this.category = 'other',
    this.value = 0,
    this.quantity = 1,
    this.purchaseDate,
    this.status = 'active',
    this.custodian = '',
    this.custodianEmployeeId = '',
    this.custodianName = '',
    this.location = '',
    this.condition = '',
    this.serialNumber = '',
    this.imageUrl = '',
    this.provider = '',
    this.url = '',
    this.expiryDate,
    this.notes = '',
    this.depreciable = false,
    this.depreciationMethod = 'straight_line',
    this.depreciationRate = 0,
    this.usefulLifeYears = 0,
    this.salvageValue = 0,
    this.depreciationStart,
    this.accumulatedDepreciation = 0,
    this.lastDepreciatedOn,
    required this.createdAt,
  });

  bool get isDigital => assetType == 'digital';
  double get totalValue => value * (quantity <= 0 ? 1 : quantity);

  /// Cost minus depreciation written off so far.
  double get bookValue => (totalValue - accumulatedDepreciation).clamp(0, double.infinity);

  /// Days until a digital asset's renewal/expiry (null when no date). Negative
  /// means already expired.
  int? get daysToExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return t.difference(today).inDays;
  }

  static String _id(dynamic v) {
    if (v is Map) return v['_id'] as String? ?? v['id'] as String? ?? '';
    return v as String? ?? '';
  }

  static String _custodianName(dynamic v) =>
      v is Map ? (v['name'] as String? ?? '') : '';

  static DateTime? _date(dynamic v) =>
      (v == null || (v is String && v.isEmpty)) ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetType: json['assetType'] as String? ?? 'physical',
      category: json['category'] as String? ?? 'other',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      purchaseDate: _date(json['purchaseDate']),
      status: json['status'] as String? ?? 'active',
      custodian: json['custodian'] as String? ?? '',
      custodianEmployeeId: _id(json['custodianEmployeeId']),
      custodianName: _custodianName(json['custodianEmployeeId']),
      location: json['location'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      url: json['url'] as String? ?? '',
      expiryDate: _date(json['expiryDate']),
      notes: json['notes'] as String? ?? '',
      depreciable: json['depreciable'] as bool? ?? false,
      depreciationMethod: json['depreciationMethod'] as String? ?? 'straight_line',
      depreciationRate: (json['depreciationRate'] as num?)?.toDouble() ?? 0,
      usefulLifeYears: (json['usefulLifeYears'] as num?)?.toDouble() ?? 0,
      salvageValue: (json['salvageValue'] as num?)?.toDouble() ?? 0,
      depreciationStart: _date(json['depreciationStart']),
      accumulatedDepreciation: (json['accumulatedDepreciation'] as num?)?.toDouble() ?? 0,
      lastDepreciatedOn: _date(json['lastDepreciatedOn']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
    );
  }
}

const kDepreciationMethods = <String>['straight_line', 'wdv'];

String depreciationMethodLabel(String m) =>
    m == 'wdv' ? 'Written-down value' : 'Straight line';

/// A count + value pair (per category / per type).
class AssetBucket {
  final int count;
  final double value;
  const AssetBucket(this.count, this.value);
  factory AssetBucket.fromJson(Map<String, dynamic> j) => AssetBucket(
        (j['count'] as num?)?.toInt() ?? 0,
        (j['value'] as num?)?.toDouble() ?? 0,
      );
}

/// Portfolio stats for the Finance dashboard.
class AssetStats {
  final int totalCount;
  final double totalValue;
  final AssetBucket digital;
  final AssetBucket physical;
  final Map<String, AssetBucket> byCategory;
  final Map<String, int> byStatus;
  final int upcomingRenewals;
  final int expired;

  const AssetStats({
    this.totalCount = 0,
    this.totalValue = 0,
    this.digital = const AssetBucket(0, 0),
    this.physical = const AssetBucket(0, 0),
    this.byCategory = const {},
    this.byStatus = const {},
    this.upcomingRenewals = 0,
    this.expired = 0,
  });

  factory AssetStats.fromJson(Map<String, dynamic> json) {
    final cat = <String, AssetBucket>{};
    (json['byCategory'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      cat[k] = AssetBucket.fromJson(v as Map<String, dynamic>);
    });
    final st = <String, int>{};
    (json['byStatus'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      st[k] = (v as num?)?.toInt() ?? 0;
    });
    return AssetStats(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      digital: AssetBucket.fromJson(
          (json['digital'] as Map<String, dynamic>?) ?? const {}),
      physical: AssetBucket.fromJson(
          (json['physical'] as Map<String, dynamic>?) ?? const {}),
      byCategory: cat,
      byStatus: st,
      upcomingRenewals: (json['upcomingRenewals'] as num?)?.toInt() ?? 0,
      expired: (json['expired'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Suggested categories per asset type (client-side picker options).
const kDigitalAssetCategories = <String>[
  'domain',
  'website',
  'software_license',
  'subscription_tool',
  'social_account',
  'design_asset',
  'data',
  'other',
];
const kPhysicalAssetCategories = <String>[
  'equipment',
  'camera_gear',
  'furniture',
  'vehicle',
  'property',
  'tool',
  'electronics',
  'other',
];
const kAssetStatuses = <String>[
  'active',
  'in_use',
  'idle',
  'maintenance',
  'disposed',
  'expired',
];
