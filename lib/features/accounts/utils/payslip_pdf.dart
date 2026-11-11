import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';

/// Shared payslip PDF (Team N Makeovers branding) used by the HR salaries,
/// Accounts salaries and ESS "My Payslips" screens.
///
/// The built-in PDF fonts have no rupee glyph, so amounts print as "Rs."
/// (same convention as the HR letters).

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String payslipMonthLabel(Salary s) =>
    '${(s.month >= 1 && s.month <= 12) ? _months[s.month - 1] : 'Month ${s.month}'} ${s.year}';

/// "XXXX1234" style mask: only the last 4 digits stay visible.
String maskAccountNumber(String account) {
  final a = account.replaceAll(RegExp(r'\s'), '');
  if (a.isEmpty) return '';
  // Already masked by the server (e.g. "••••1234").
  final digits = a.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  final tail = digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  return 'XXXX$tail';
}

/// Indian-grouped amount, e.g. 1234567.5 -> "12,34,567.50".
String formatIndianAmount(double amount, {bool withPaise = true}) =>
    NumberFormat(withPaise ? '#,##,##0.00' : '#,##,##0', 'en_IN').format(amount);

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];
const _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
];

String _belowHundred(int n) {
  if (n < 20) return _ones[n];
  final t = _tens[n ~/ 10];
  final o = n % 10;
  return o == 0 ? t : '$t ${_ones[o]}';
}

String _belowThousand(int n) {
  final h = n ~/ 100;
  final r = n % 100;
  final parts = <String>[];
  if (h > 0) parts.add('${_ones[h]} Hundred');
  if (r > 0) parts.add(_belowHundred(r));
  return parts.join(' ');
}

/// Whole number in Indian words (crore / lakh / thousand / hundred).
String numberToIndianWords(int n) {
  if (n == 0) return 'Zero';
  if (n < 0) return 'Minus ${numberToIndianWords(-n)}';
  final parts = <String>[];
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;
  if (crore > 0) parts.add('${numberToIndianWords(crore)} Crore');
  if (lakh > 0) parts.add('${_belowHundred(lakh)} Lakh');
  if (thousand > 0) parts.add('${_belowHundred(thousand)} Thousand');
  if (n > 0) parts.add(_belowThousand(n));
  return parts.join(' ');
}

/// "Rupees Twelve Thousand Five Hundred and Fifty Paise Only".
String amountInWordsIndian(double amount) {
  final paiseTotal = (amount.abs() * 100).round();
  final rupees = paiseTotal ~/ 100;
  final paise = paiseTotal % 100;
  final sign = amount < 0 ? 'Minus ' : '';
  final r = 'Rupees ${numberToIndianWords(rupees)}';
  final p = paise > 0 ? ' and ${numberToIndianWords(paise)} Paise' : '';
  return '$sign$r$p Only';
}

/// Earnings / deductions breakdown for one slip. Lines always add up to the
/// stored net (server rule: net = base + incentives + roomRent + allowances +
/// bonus - deductions, floored at 0; HRA is paid separately).
class PayslipTotals {
  final double basic;
  final double incentives;
  final double roomRent;
  final double allowances;
  final double bonus;
  final double attendanceDeduction;
  final double otherDeductions;
  final double net;

  const PayslipTotals({
    required this.basic,
    required this.incentives,
    required this.roomRent,
    required this.allowances,
    required this.bonus,
    required this.attendanceDeduction,
    required this.otherDeductions,
    required this.net,
  });

  double get grossEarnings => basic + incentives + roomRent + allowances + bonus;
  double get totalDeductions => attendanceDeduction + otherDeductions;

  /// Net from the components (what the server stores).
  double get computedNet {
    final n = grossEarnings - totalDeductions;
    return n < 0 ? 0 : n;
  }

  factory PayslipTotals.fromSalary(Salary s) {
    final totalDed = s.deductions < 0 ? 0.0 : s.deductions;
    var att = s.attendanceDeduction ?? 0;
    if (att < 0) att = 0;
    if (att > totalDed) att = totalDed;
    return PayslipTotals(
      basic: s.baseSalary,
      incentives: s.incentives,
      roomRent: s.roomRent,
      allowances: s.allowances,
      bonus: s.bonus,
      attendanceDeduction: att,
      otherDeductions: totalDed - att,
      net: s.netAmount,
    );
  }
}

/// The attendance note line(s) written by attendance payroll ("Attendance ...").
String payslipAttendanceNote(Salary s) => s.notes
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.startsWith('Attendance '))
    .join('\n');

String _methodLabel(String m) {
  switch (m) {
    case 'bank_transfer':
      return 'Bank Transfer';
    case 'upi':
      return 'UPI';
    case 'cash':
      return 'Cash';
    case 'cheque':
      return 'Cheque';
    default:
      return m.isEmpty ? '-' : m[0].toUpperCase() + m.substring(1);
  }
}

String _rs(double v) => 'Rs. ${formatIndianAmount(v)}';

pw.Widget _kv(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 82,
          child: pw.Text(pdfSafe(k), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(pdfSafe(v.isEmpty ? '-' : v),
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
        ),
      ]),
    );

pw.Widget _amountTable(String title, List<MapEntry<String, double>> rows, String totalLabel, double total) {
  final cellPad = const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5);
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: kPdfBrandLt),
        children: [
          pw.Padding(
              padding: cellPad,
              child: pw.Text(title,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand))),
          pw.Padding(
              padding: cellPad,
              child: pw.Text('Amount',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand))),
        ],
      ),
      for (final r in rows)
        pw.TableRow(children: [
          pw.Padding(padding: cellPad, child: pw.Text(pdfSafe(r.key), style: const pw.TextStyle(fontSize: 9.5))),
          pw.Padding(
              padding: cellPad,
              child: pw.Text(_rs(r.value), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5))),
        ]),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          pw.Padding(
              padding: cellPad,
              child: pw.Text(totalLabel, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
          pw.Padding(
              padding: cellPad,
              child: pw.Text(_rs(total),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    ],
  );
}

/// Builds the payslip PDF bytes.
Future<Uint8List> buildPayslipPdfBytes(Salary s) async {
  final logo = await brandedPdfLogo();
  final t = PayslipTotals.fromSalary(s);
  final period = payslipMonthLabel(s);
  final attNote = payslipAttendanceNote(s);
  final designation = s.designation.isNotEmpty ? s.designation : s.role;
  final bankLine = [
    if (s.bankName.isNotEmpty) s.bankName,
    if (s.accountNumber.isNotEmpty) 'A/c ${maskAccountNumber(s.accountNumber)}',
    if (s.ifscCode.isNotEmpty) 'IFSC ${s.ifscCode}',
  ].join('  |  ');

  final earnings = <MapEntry<String, double>>[
    MapEntry('Basic Salary', t.basic),
    MapEntry('Incentives', t.incentives),
    MapEntry('Room Rent', t.roomRent),
    MapEntry('Allowances', t.allowances),
    MapEntry('Bonus', t.bonus),
  ];
  final deductions = <MapEntry<String, double>>[
    if (t.attendanceDeduction > 0) MapEntry('Attendance / Absence (LOP)', t.attendanceDeduction),
    MapEntry(t.attendanceDeduction > 0 ? 'Other Deductions / Advances' : 'Deductions / Advances',
        t.otherDeductions),
  ];

  final doc = pw.Document(title: 'Payslip - ${s.employeeName} - $period');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      // Header
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (logo != null) ...[
          pw.SizedBox(height: 48, width: 48, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Team N Makeovers',
                style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
            pw.Text('+91 9645424283  |  www.nizanmakeovers.com',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('PAYSLIP',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          pw.Text(pdfSafe(period), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        ]),
      ]),
      pw.SizedBox(height: 8),
      pw.Container(height: 2.5, color: kPdfBrand),
      pw.SizedBox(height: 14),

      // Employee block
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(children: [
              _kv('Employee', s.employeeName),
              _kv('Employee code', s.employeeCode),
              _kv('Department', s.department),
              _kv('Designation', designation),
            ]),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(children: [
              _kv('Pay period', period),
              _kv('Bank', bankLine),
              if (s.upiId.isNotEmpty) _kv('UPI', s.upiId),
              _kv('Status', s.isPaid ? 'Paid' : 'Approved'),
            ]),
          ),
        ]),
      ),
      pw.SizedBox(height: 14),

      // Earnings / deductions
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _amountTable('Earnings', earnings, 'Gross Earnings', t.grossEarnings)),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _amountTable('Deductions', deductions, 'Total Deductions', t.totalDeductions)),
      ]),
      pw.SizedBox(height: 14),

      // Net pay
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        color: kPdfBrandLt,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Net Pay',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
            pw.Text(_rs(t.net),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          ]),
          pw.SizedBox(height: 4),
          pw.Text(amountInWordsIndian(t.net),
              style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic)),
        ]),
      ),

      if (attNote.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text('Attendance', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
        pw.SizedBox(height: 2),
        pw.Text(pdfSafe(attNote), style: const pw.TextStyle(fontSize: 9)),
      ],

      if (s.isPaid) ...[
        pw.SizedBox(height: 10),
        pw.Text('Payment', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
        pw.SizedBox(height: 2),
        pw.Text(
          pdfSafe([
            'Paid on ${s.paymentDate != null ? DateFormat('d MMM yyyy').format(s.paymentDate!.toLocal()) : '-'}',
            'via ${_methodLabel(s.paymentMethod)}',
            if (s.transactionRef.isNotEmpty) 'Ref: ${s.transactionRef}',
          ].join('  |  ')),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],

      pw.Spacer(),
      pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.6)),
        ),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('This is a system-generated payslip and does not require a signature.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text('Generated ${DateFormat('d MMM yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ]),
      ),
    ]),
  ));
  return doc.save();
}

/// File name like "Payslip_Anu_Thomas_2026_10.pdf".
String payslipFileName(Salary s) {
  final name = s.employeeName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  return 'Payslip_${name.isEmpty ? 'employee' : name}_${s.year}_${s.month.toString().padLeft(2, '0')}.pdf';
}

/// Build + save / share the payslip (browser download on web, share on mobile).
Future<void> downloadPayslipPdf(Salary s) async {
  final bytes = await buildPayslipPdfBytes(s);
  await saveFileBytes(payslipFileName(s), bytes, mime: 'application/pdf');
}
