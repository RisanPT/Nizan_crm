/// Accounting settings — currently the period lock (books closed through a date).
class AccountingSettings {
  final DateTime? lockDate;
  final String lockedByName;

  const AccountingSettings({this.lockDate, this.lockedByName = ''});

  bool get isLocked => lockDate != null;

  factory AccountingSettings.fromJson(Map<String, dynamic> j) {
    final by = j['lockedBy'];
    return AccountingSettings(
      lockDate: DateTime.tryParse(j['lockDate']?.toString() ?? '')?.toLocal(),
      lockedByName: by is Map ? (by['name'] as String? ?? '') : '',
    );
  }
}
