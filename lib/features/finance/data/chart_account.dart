/// A ledger account in the Chart of Accounts.
class ChartAccount {
  final String id;
  final String code;
  final String name;
  final String nature; // asset | liability | equity | income | expense
  final String group;
  final bool isBank;
  final bool isCash;
  final bool isParty;
  final bool gstApplicable;
  final double gstRate;
  final double openingBalance;
  final String openingType; // dr | cr
  final String status; // active | archived
  final bool isSystem;

  const ChartAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.nature,
    this.group = '',
    this.isBank = false,
    this.isCash = false,
    this.isParty = false,
    this.gstApplicable = false,
    this.gstRate = 0,
    this.openingBalance = 0,
    this.openingType = 'dr',
    this.status = 'active',
    this.isSystem = false,
  });

  String get naturalSide =>
      (nature == 'asset' || nature == 'expense') ? 'dr' : 'cr';

  factory ChartAccount.fromJson(Map<String, dynamic> j) => ChartAccount(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        nature: j['nature'] as String? ?? 'expense',
        group: j['group'] as String? ?? '',
        isBank: j['isBank'] as bool? ?? false,
        isCash: j['isCash'] as bool? ?? false,
        isParty: j['isParty'] as bool? ?? false,
        gstApplicable: j['gstApplicable'] as bool? ?? false,
        gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
        openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
        openingType: j['openingType'] as String? ?? 'dr',
        status: j['status'] as String? ?? 'active',
        isSystem: j['isSystem'] as bool? ?? false,
      );
}

const kAccountNatures = <String>['asset', 'liability', 'equity', 'income', 'expense'];

String natureLabel(String n) {
  switch (n) {
    case 'asset':
      return 'Assets';
    case 'liability':
      return 'Liabilities';
    case 'equity':
      return 'Equity';
    case 'income':
      return 'Income';
    case 'expense':
      return 'Expenses';
    default:
      return n;
  }
}
