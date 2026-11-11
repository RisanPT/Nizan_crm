import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/features/accounts/utils/payslip_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildPayslipPdfBytes renders a PDF', () async {
    final bytes = await buildPayslipPdfBytes(Salary(
      id: 's', employeeId: 'e', employeeName: 'Anu Thomas', employeeCategory: 'administrative',
      month: 10, year: 2026, baseSalary: 20000, deductions: 500, attendanceDeduction: 500,
      netAmount: 19500, status: 'paid', accountNumber: '123456789012', bankName: 'SBI',
      notes: 'Attendance 25/26 days', paymentDate: DateTime(2026, 11, 1), transactionRef: 'UTR1',
    ));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  group('amountInWordsIndian', () {
    test('zero and small numbers', () {
      expect(amountInWordsIndian(0), 'Rupees Zero Only');
      expect(amountInWordsIndian(7), 'Rupees Seven Only');
      expect(amountInWordsIndian(19), 'Rupees Nineteen Only');
      expect(amountInWordsIndian(40), 'Rupees Forty Only');
      expect(amountInWordsIndian(101), 'Rupees One Hundred One Only');
    });

    test('Indian grouping: thousand / lakh / crore', () {
      expect(amountInWordsIndian(12500), 'Rupees Twelve Thousand Five Hundred Only');
      expect(amountInWordsIndian(100000), 'Rupees One Lakh Only');
      expect(amountInWordsIndian(2534999),
          'Rupees Twenty Five Lakh Thirty Four Thousand Nine Hundred Ninety Nine Only');
      expect(amountInWordsIndian(10000000), 'Rupees One Crore Only');
      expect(amountInWordsIndian(123456789),
          'Rupees Twelve Crore Thirty Four Lakh Fifty Six Thousand Seven Hundred Eighty Nine Only');
    });

    test('paise', () {
      expect(amountInWordsIndian(1500.5), 'Rupees One Thousand Five Hundred and Fifty Paise Only');
      expect(amountInWordsIndian(0.99), 'Rupees Zero and Ninety Nine Paise Only');
    });
  });

  test('formatIndianAmount groups the Indian way', () {
    expect(formatIndianAmount(1234567.5), '12,34,567.50');
    expect(formatIndianAmount(999, withPaise: false), '999');
  });

  test('maskAccountNumber keeps only the last 4', () {
    expect(maskAccountNumber('123456789012'), 'XXXX9012');
    expect(maskAccountNumber('••••9012'), 'XXXX9012');
    expect(maskAccountNumber(''), '');
  });

  group('PayslipTotals', () {
    Salary slip({double? att, double ded = 3000, double net = 27500}) => Salary(
          id: 's1',
          employeeId: 'e1',
          employeeName: 'Anu',
          employeeCategory: 'administrative',
          month: 10,
          year: 2026,
          baseSalary: 25000,
          incentives: 2000,
          roomRent: 1500,
          allowances: 1000,
          bonus: 1000,
          deductions: ded,
          attendanceDeduction: att,
          netAmount: net,
        );

    test('lines add up to the net', () {
      final t = PayslipTotals.fromSalary(slip(att: 1200));
      expect(t.grossEarnings, 30500);
      expect(t.attendanceDeduction, 1200);
      expect(t.otherDeductions, 1800);
      expect(t.totalDeductions, 3000);
      expect(t.computedNet, 27500);
      expect(t.net, t.computedNet);
    });

    test('legacy slip without attendance part puts all in other deductions', () {
      final t = PayslipTotals.fromSalary(slip());
      expect(t.attendanceDeduction, 0);
      expect(t.otherDeductions, 3000);
    });

    test('attendance part is capped at total deductions; net floors at 0', () {
      final t = PayslipTotals.fromSalary(slip(att: 50000, ded: 40000, net: 0));
      expect(t.attendanceDeduction, 40000);
      expect(t.otherDeductions, 0);
      expect(t.computedNet, 0);
    });
  });

  test('payslipAttendanceNote picks only attendance lines', () {
    final s = Salary(
      id: 's',
      employeeId: 'e',
      employeeName: 'X',
      employeeCategory: 'administrative',
      month: 1,
      year: 2026,
      netAmount: 0,
      notes: 'Advance adjusted\nAttendance 24/26 days, 2 absent',
    );
    expect(payslipAttendanceNote(s), 'Attendance 24/26 days, 2 absent');
    expect(payslipMonthLabel(s), 'January 2026');
  });
}
