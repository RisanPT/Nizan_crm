// A marketing campaign with its costs (ad spend + production) and the return it
// generated. ROI / ROAS come computed from the backend.
class Campaign {
  final String id;
  final String title;
  final String channel;
  final String status; // planned | active | paused | completed
  final String notes;
  final DateTime? startDate, endDate;
  final double adSpend, productionCost, revenue, totalCost, profit;
  final double? roiPct, roas, costPerLead, costPerAcquisition;
  final int leads, conversions;
  // Auto attribution — from leads tagged to this campaign + their bookings.
  final double autoRevenue;
  final int autoLeads, autoConversions;
  final bool autoAttributed; // true when the displayed revenue came from attribution

  const Campaign({
    this.id = '',
    required this.title,
    this.channel = '',
    this.status = 'active',
    this.notes = '',
    this.startDate,
    this.endDate,
    this.adSpend = 0,
    this.productionCost = 0,
    this.revenue = 0,
    this.totalCost = 0,
    this.profit = 0,
    this.roiPct,
    this.roas,
    this.costPerLead,
    this.costPerAcquisition,
    this.leads = 0,
    this.conversions = 0,
    this.autoRevenue = 0,
    this.autoLeads = 0,
    this.autoConversions = 0,
    this.autoAttributed = false,
  });

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static double? _dn(dynamic v) => (v as num?)?.toDouble();
  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        channel: j['channel'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        notes: j['notes'] as String? ?? '',
        startDate: _dt(j['startDate']),
        endDate: _dt(j['endDate']),
        adSpend: _d(j['adSpend']),
        productionCost: _d(j['productionCost']),
        revenue: _d(j['revenue']),
        totalCost: _d(j['totalCost']),
        profit: _d(j['profit']),
        roiPct: _dn(j['roiPct']),
        roas: _dn(j['roas']),
        costPerLead: _dn(j['costPerLead']),
        costPerAcquisition: _dn(j['costPerAcquisition']),
        leads: _i(j['leads']),
        conversions: _i(j['conversions']),
        autoRevenue: _d(j['autoRevenue']),
        autoLeads: _i(j['autoLeads']),
        autoConversions: _i(j['autoConversions']),
        autoAttributed: j['autoAttributed'] == true,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'channel': channel,
        'status': status,
        'notes': notes,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'adSpend': adSpend,
        'productionCost': productionCost,
        'revenue': revenue,
        'leads': leads,
        'conversions': conversions,
      };
}

class CampaignBoard {
  final List<Campaign> campaigns;
  final int count;
  final double totalAdSpend, totalProductionCost, totalCost, totalRevenue;
  final double? blendedRoiPct, blendedRoas;

  const CampaignBoard({
    this.campaigns = const [],
    this.count = 0,
    this.totalAdSpend = 0,
    this.totalProductionCost = 0,
    this.totalCost = 0,
    this.totalRevenue = 0,
    this.blendedRoiPct,
    this.blendedRoas,
  });

  factory CampaignBoard.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] as Map<String, dynamic>? ?? const {};
    return CampaignBoard(
      campaigns: ((j['campaigns'] as List<dynamic>?) ?? const [])
          .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: Campaign._i(s['count']),
      totalAdSpend: Campaign._d(s['totalAdSpend']),
      totalProductionCost: Campaign._d(s['totalProductionCost']),
      totalCost: Campaign._d(s['totalCost']),
      totalRevenue: Campaign._d(s['totalRevenue']),
      blendedRoiPct: Campaign._dn(s['blendedRoiPct']),
      blendedRoas: Campaign._dn(s['blendedRoas']),
    );
  }
}
