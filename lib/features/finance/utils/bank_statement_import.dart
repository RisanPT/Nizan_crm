import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' show CsvDecoder;
import 'package:excel/excel.dart';

/// One parsed statement line, ready to POST to /accounting/bank/import.
/// [amount] is signed: +ve = money IN (deposit/credit), -ve = money OUT.
class ParsedStatementLine {
  final DateTime date;
  final String description;
  final String refNo;
  final double amount;
  final double? balance;

  const ParsedStatementLine({
    required this.date,
    this.description = '',
    this.refNo = '',
    required this.amount,
    this.balance,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'description': description,
        'refNo': refNo,
        'amount': amount,
        'balance': balance,
      };
}

/// Result of parsing an uploaded bank statement.
class StatementImportResult {
  final List<ParsedStatementLine> lines;
  final List<String> warnings;
  final int totalRows;
  final int skipped;

  const StatementImportResult({
    required this.lines,
    required this.warnings,
    required this.totalRows,
    required this.skipped,
  });

  bool get hasLines => lines.isNotEmpty;
}

// Canonical field → accepted (normalised) header aliases.
const _fieldAliases = <String, List<String>>{
  'date': [
    'date',
    'txndate',
    'transactiondate',
    'valuedate',
    'postingdate',
    'bookingdate',
    'trandate',
    'date1',
  ],
  'description': [
    'description',
    'narration',
    'particulars',
    'details',
    'remarks',
    'transactiondetails',
    'transactionremarks',
    'naration',
    'chequedetails',
  ],
  'refNo': [
    'refno',
    'reference',
    'referenceno',
    'chequeno',
    'chqno',
    'cheque',
    'utrno',
    'utr',
    'transactionid',
    'refnumber',
    'instrumentno',
  ],
  'deposit': [
    'deposit',
    'deposits',
    'credit',
    'creditamount',
    'cr',
    'cramount',
    'depositamount',
    'depositcr',
    'moneyin',
    'amountcredit',
    'creditinr',
  ],
  'withdrawal': [
    'withdrawal',
    'withdrawals',
    'debit',
    'debitamount',
    'dr',
    'dramount',
    'withdrawalamount',
    'withdrawaldr',
    'moneyout',
    'amountdebit',
    'debitinr',
    'paymentsdebits',
  ],
  'amount': ['amount', 'amountinr', 'transactionamount', 'txnamount', 'value'],
  'drcr': ['drcr', 'crdr', 'type', 'transactiontype', 'indicator', 'debitcredit'],
  'balance': [
    'balance',
    'runningbalance',
    'closingbalance',
    'availablebalance',
    'balanceinr',
    'balanceamount',
    'runningtotal',
  ],
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String? _fieldForHeader(String header) {
  final n = _norm(header);
  if (n.isEmpty) return null;
  for (final entry in _fieldAliases.entries) {
    if (entry.value.contains(n)) return entry.key;
  }
  return null;
}

/// Sheet names of a workbook (empty for CSV) for a sheet picker.
List<String> statementImportSheets(Uint8List bytes) {
  try {
    final excel = Excel.decodeBytes(bytes);
    return [
      for (final e in excel.tables.entries)
        if (e.value.maxRows > 0) e.key,
    ];
  } catch (_) {
    return const [];
  }
}

/// Parse an uploaded bank statement (.xlsx/.xls/.csv). Never throws for content
/// problems — surfaces them as [warnings].
StatementImportResult parseBankStatement(
  Uint8List bytes,
  String filename, {
  String? sheetName,
}) {
  final lower = filename.toLowerCase();
  List<List<dynamic>> rows;
  try {
    rows = lower.endsWith('.csv') ? _readCsv(bytes) : _readXlsx(bytes, sheetName);
  } catch (e) {
    return StatementImportResult(
      lines: const [],
      warnings: ['Could not read the file: $e'],
      totalRows: 0,
      skipped: 0,
    );
  }

  if (rows.every((r) => r.every((c) => _asStr(c).isEmpty))) {
    return const StatementImportResult(
      lines: [],
      warnings: ['The sheet is empty.'],
      totalRows: 0,
      skipped: 0,
    );
  }

  // Find the header row: statements often carry title/summary rows above the
  // grid, so scan the first rows for the one mapping the most known columns and
  // that includes a date column.
  var headerIdx = -1;
  var colField = <int, String>{};
  final scanLimit = rows.length < 30 ? rows.length : 30;
  for (var i = 0; i < scanLimit; i++) {
    final map = <int, String>{};
    for (var c = 0; c < rows[i].length; c++) {
      final f = _fieldForHeader(_asStr(rows[i][c]));
      if (f != null && !map.containsValue(f)) map[c] = f;
    }
    final hasAmount =
        map.containsValue('deposit') || map.containsValue('withdrawal') || map.containsValue('amount');
    if (map.containsValue('date') && hasAmount && map.length > colField.length) {
      headerIdx = i;
      colField = map;
    }
  }

  if (headerIdx < 0) {
    return StatementImportResult(
      lines: const [],
      warnings: [
        'Could not find a header row with a date and an amount column. '
            'Expected columns like Date, Description, Debit/Withdrawal, '
            'Credit/Deposit (or a single Amount), Balance.',
      ],
      totalRows: rows.length,
      skipped: 0,
    );
  }

  final warnings = <String>[];
  final lines = <ParsedStatementLine>[];
  var dataRows = 0;
  var skipped = 0;

  for (var r = headerIdx + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => _asStr(c).isEmpty)) continue;
    dataRows++;

    final cell = <String, dynamic>{};
    colField.forEach((col, field) {
      if (col < row.length) cell[field] = row[col];
    });

    final date = _asDate(cell['date']);
    if (date == null) {
      skipped++;
      continue;
    }

    // Amount, signed as money-in positive.
    double? amount;
    final deposit = _asMoney(cell['deposit']);
    final withdrawal = _asMoney(cell['withdrawal']);
    if (deposit != null || withdrawal != null) {
      amount = (deposit ?? 0) - (withdrawal ?? 0);
    } else {
      final raw = _asMoney(cell['amount']);
      if (raw != null) {
        final drcr = _asStr(cell['drcr']).toLowerCase();
        if (drcr.isNotEmpty) {
          final isDebit = drcr.startsWith('d') || drcr.contains('dr') || drcr.contains('with');
          final isCredit = drcr.startsWith('c') || drcr.contains('cr') || drcr.contains('dep');
          // Money-out is negative. If the amount already carried a sign, respect it.
          amount = isDebit && !isCredit ? -raw.abs() : (isCredit ? raw.abs() : raw);
        } else {
          amount = raw;
        }
      }
    }

    if (amount == null || amount == 0) {
      skipped++;
      continue;
    }

    lines.add(ParsedStatementLine(
      date: date,
      description: _asStr(cell['description']),
      refNo: _asStr(cell['refNo']),
      amount: _round2(amount),
      balance: _asMoney(cell['balance']),
    ));
  }

  if (skipped > 0) {
    warnings.add('$skipped row${skipped == 1 ? '' : 's'} skipped (no date or amount).');
  }

  return StatementImportResult(
    lines: lines,
    warnings: warnings,
    totalRows: dataRows,
    skipped: skipped,
  );
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

List<List<dynamic>> _readCsv(Uint8List bytes) {
  final text = utf8
      .decode(bytes, allowMalformed: true)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  return const CsvDecoder(parseHeaders: false, dynamicTyping: true).convert(text);
}

List<List<dynamic>> _readXlsx(Uint8List bytes, [String? sheetName]) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const [];
  final sheet = (sheetName != null && excel.tables.containsKey(sheetName))
      ? excel.tables[sheetName]!
      : excel.tables.values.firstWhere(
          (s) => s.maxRows > 0,
          orElse: () => excel.tables.values.first,
        );
  return sheet.rows.map((r) => r.map(_cellRaw).toList()).toList();
}

dynamic _cellRaw(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  return switch (v) {
    TextCellValue() => v.value.toString(),
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    BoolCellValue() => v.value,
    DateCellValue() => v.asDateTimeLocal(),
    DateTimeCellValue() => v.asDateTimeLocal(),
    TimeCellValue() => v.toString(),
    FormulaCellValue() => v.formula,
  };
}

String _asStr(dynamic v) =>
    v == null ? '' : (v is String ? v.trim() : v.toString().trim());

/// Parse a money cell: tolerates ₹, commas, spaces, and (parentheses) negatives.
double? _asMoney(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  var s = v.toString().trim();
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  s = s.replaceAll(RegExp(r'[₹$,\s]'), '');
  if (s.endsWith('-')) {
    negative = true;
    s = s.substring(0, s.length - 1);
  }
  if (s.isEmpty || s == '-') return null;
  final n = double.tryParse(s);
  if (n == null) return null;
  return negative ? -n.abs() : n;
}

/// Parse a date cell: DateTime, or common d/m/y and y-m-d string formats.
DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return DateTime(v.year, v.month, v.day);
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  // d/m/yyyy, d-m-yyyy, d.m.yy, dd/mm/yyyy — day-first (Indian bank format).
  final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(s);
  if (m != null) {
    var day = int.parse(m.group(1)!);
    var month = int.parse(m.group(2)!);
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    // If the first field can't be a day but the second can, it's m/d.
    if (day > 12 && month <= 12) {
      // already day-first, fine
    } else if (month > 12 && day <= 12) {
      final t = day;
      day = month;
      month = t;
    }
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(year, month, day);
    }
  }

  // dd MMM yyyy (e.g. 05 Apr 2026 / 5-Apr-26)
  final m2 = RegExp(r'^(\d{1,2})[\s\-]([A-Za-z]{3,})[\s\-](\d{2,4})').firstMatch(s);
  if (m2 != null) {
    final day = int.parse(m2.group(1)!);
    final month = _monthNum(m2.group(2)!);
    var year = int.parse(m2.group(3)!);
    if (year < 100) year += 2000;
    if (month != null) return DateTime(year, month, day);
  }
  return null;
}

int? _monthNum(String s) {
  const names = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];
  final key = s.toLowerCase().substring(0, 3);
  final i = names.indexOf(key);
  return i < 0 ? null : i + 1;
}
