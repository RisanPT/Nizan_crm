/// One party's outstanding balance, split across aging buckets.
class AgingParty {
  final String name;
  final String phone;
  final double outstanding;
  final double notYetDue; // due date still in the future
  final double current; // 0–30 days overdue
  final double days30; // 31–60
  final double days60; // 61–90
  final double days90; // 90+
  final double overdue; // current + days30 + days60 + days90
  final int oldestDays;
  final int count;

  const AgingParty({
    required this.name,
    this.phone = '',
    this.outstanding = 0,
    this.notYetDue = 0,
    this.current = 0,
    this.days30 = 0,
    this.days60 = 0,
    this.days90 = 0,
    this.overdue = 0,
    this.oldestDays = 0,
    this.count = 0,
  });

  factory AgingParty.fromJson(Map<String, dynamic> j) => AgingParty(
        name: j['name'] as String? ?? 'Unknown',
        phone: j['phone'] as String? ?? '',
        outstanding: (j['outstanding'] as num?)?.toDouble() ?? 0,
        notYetDue: (j['notYetDue'] as num?)?.toDouble() ?? 0,
        current: (j['current'] as num?)?.toDouble() ?? 0,
        days30: (j['days30'] as num?)?.toDouble() ?? 0,
        days60: (j['days60'] as num?)?.toDouble() ?? 0,
        days90: (j['days90'] as num?)?.toDouble() ?? 0,
        overdue: (j['overdue'] as num?)?.toDouble() ?? 0,
        oldestDays: (j['oldestDays'] as num?)?.toInt() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// One line of a party's statement of account (a booking or a bill).
class PartyStatementRow {
  final DateTime? date;
  final String description;
  final double invoiced;
  final double received;
  final double balance;
  final double runningBalance;

  const PartyStatementRow({
    this.date,
    this.description = '',
    this.invoiced = 0,
    this.received = 0,
    this.balance = 0,
    this.runningBalance = 0,
  });

  factory PartyStatementRow.fromJson(Map<String, dynamic> j) => PartyStatementRow(
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
        description: j['description'] as String? ?? '',
        invoiced: (j['invoiced'] as num?)?.toDouble() ?? 0,
        received: (j['received'] as num?)?.toDouble() ?? 0,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        runningBalance: (j['runningBalance'] as num?)?.toDouble() ?? 0,
      );
}

/// A party's full statement of account.
class PartyStatement {
  final String kind; // receivables | payables
  final String name;
  final String phone;
  final List<PartyStatementRow> rows;
  final double invoicedTotal;
  final double receivedTotal;
  final double outstanding;

  const PartyStatement({
    this.kind = 'receivables',
    this.name = '',
    this.phone = '',
    this.rows = const [],
    this.invoicedTotal = 0,
    this.receivedTotal = 0,
    this.outstanding = 0,
  });

  factory PartyStatement.fromJson(Map<String, dynamic> j) {
    final p = j['party'] as Map<String, dynamic>? ?? const {};
    return PartyStatement(
      kind: j['kind'] as String? ?? 'receivables',
      name: p['name'] as String? ?? '',
      phone: p['phone'] as String? ?? '',
      rows: (j['rows'] as List<dynamic>? ?? const [])
          .map((e) => PartyStatementRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      invoicedTotal: (j['invoicedTotal'] as num?)?.toDouble() ?? 0,
      receivedTotal: (j['receivedTotal'] as num?)?.toDouble() ?? 0,
      outstanding: (j['outstanding'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Receivables or payables aging report.
class AgingReport {
  final DateTime? asOf;
  final double totalOutstanding;
  final double totalOverdue;
  final double totalNotYetDue;
  final double current;
  final double days30;
  final double days60;
  final double days90;
  final List<AgingParty> parties;

  const AgingReport({
    this.asOf,
    this.totalOutstanding = 0,
    this.totalOverdue = 0,
    this.totalNotYetDue = 0,
    this.current = 0,
    this.days30 = 0,
    this.days60 = 0,
    this.days90 = 0,
    this.parties = const [],
  });

  factory AgingReport.fromJson(Map<String, dynamic> j) {
    final b = j['buckets'] as Map<String, dynamic>? ?? const {};
    return AgingReport(
      asOf: DateTime.tryParse(j['asOf']?.toString() ?? '')?.toLocal(),
      totalOutstanding: (j['totalOutstanding'] as num?)?.toDouble() ?? 0,
      totalOverdue: (j['totalOverdue'] as num?)?.toDouble() ?? 0,
      totalNotYetDue: (j['totalNotYetDue'] as num?)?.toDouble() ?? 0,
      current: (b['current'] as num?)?.toDouble() ?? 0,
      days30: (b['days30'] as num?)?.toDouble() ?? 0,
      days60: (b['days60'] as num?)?.toDouble() ?? 0,
      days90: (b['days90'] as num?)?.toDouble() ?? 0,
      parties: (j['parties'] as List<dynamic>? ?? const [])
          .map((e) => AgingParty.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
