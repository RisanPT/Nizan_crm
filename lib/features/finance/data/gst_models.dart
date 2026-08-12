/// Studio GST configuration.
class GstSettings {
  final bool enabled;
  final double rate;
  final bool pricesIncludeTax;
  final bool interState;
  final String homeStateCode;
  final String gstin;

  const GstSettings({
    this.enabled = true,
    this.rate = 5,
    this.pricesIncludeTax = true,
    this.interState = false,
    this.homeStateCode = '',
    this.gstin = '',
  });

  factory GstSettings.fromJson(Map<String, dynamic> j) => GstSettings(
        enabled: j['enabled'] as bool? ?? true,
        rate: (j['rate'] as num?)?.toDouble() ?? 5,
        pricesIncludeTax: j['pricesIncludeTax'] as bool? ?? true,
        interState: j['interState'] as bool? ?? false,
        homeStateCode: j['homeStateCode'] as String? ?? '',
        gstin: j['gstin'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'rate': rate,
        'pricesIncludeTax': pricesIncludeTax,
        'interState': interState,
        'homeStateCode': homeStateCode,
        'gstin': gstin,
      };

  GstSettings copyWith({bool? enabled, double? rate, bool? pricesIncludeTax, bool? interState, String? homeStateCode, String? gstin}) =>
      GstSettings(
        enabled: enabled ?? this.enabled,
        rate: rate ?? this.rate,
        pricesIncludeTax: pricesIncludeTax ?? this.pricesIncludeTax,
        interState: interState ?? this.interState,
        homeStateCode: homeStateCode ?? this.homeStateCode,
        gstin: gstin ?? this.gstin,
      );
}

/// GSTR-3B style summary: output tax − input credit = net payable.
class GstSummary {
  final double outputCgst;
  final double outputSgst;
  final double outputIgst;
  final double totalOutput;
  final double inputCredit;
  final double netPayable;

  const GstSummary({
    this.outputCgst = 0,
    this.outputSgst = 0,
    this.outputIgst = 0,
    this.totalOutput = 0,
    this.inputCredit = 0,
    this.netPayable = 0,
  });

  factory GstSummary.fromJson(Map<String, dynamic> j) => GstSummary(
        outputCgst: (j['outputCgst'] as num?)?.toDouble() ?? 0,
        outputSgst: (j['outputSgst'] as num?)?.toDouble() ?? 0,
        outputIgst: (j['outputIgst'] as num?)?.toDouble() ?? 0,
        totalOutput: (j['totalOutput'] as num?)?.toDouble() ?? 0,
        inputCredit: (j['inputCredit'] as num?)?.toDouble() ?? 0,
        netPayable: (j['netPayable'] as num?)?.toDouble() ?? 0,
      );
}

/// One outward-supply line of GSTR-1.
class Gstr1Row {
  final String invoiceNo;
  final String customer;
  final DateTime? date;
  final double rate;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  const Gstr1Row({
    this.invoiceNo = '',
    this.customer = '',
    this.date,
    this.rate = 0,
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.total = 0,
  });

  factory Gstr1Row.fromJson(Map<String, dynamic> j) => Gstr1Row(
        invoiceNo: j['invoiceNo'] as String? ?? '',
        customer: j['customer'] as String? ?? '',
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
        taxable: (j['taxable'] as num?)?.toDouble() ?? 0,
        cgst: (j['cgst'] as num?)?.toDouble() ?? 0,
        sgst: (j['sgst'] as num?)?.toDouble() ?? 0,
        igst: (j['igst'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

class Gstr1Report {
  final double rate;
  final bool interState;
  final List<Gstr1Row> rows;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;
  final int count;

  const Gstr1Report({
    this.rate = 0,
    this.interState = false,
    this.rows = const [],
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.total = 0,
    this.count = 0,
  });

  factory Gstr1Report.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>? ?? const {};
    return Gstr1Report(
      rate: (j['rate'] as num?)?.toDouble() ?? 0,
      interState: j['interState'] as bool? ?? false,
      rows: (j['rows'] as List<dynamic>? ?? const [])
          .map((e) => Gstr1Row.fromJson(e as Map<String, dynamic>))
          .toList(),
      taxable: (t['taxable'] as num?)?.toDouble() ?? 0,
      cgst: (t['cgst'] as num?)?.toDouble() ?? 0,
      sgst: (t['sgst'] as num?)?.toDouble() ?? 0,
      igst: (t['igst'] as num?)?.toDouble() ?? 0,
      total: (t['total'] as num?)?.toDouble() ?? 0,
      count: (t['count'] as num?)?.toInt() ?? 0,
    );
  }
}
