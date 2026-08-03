import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';

import 'financial_report_stub.dart'
    if (dart.library.io) 'financial_report_mobile.dart'
    if (dart.library.html) 'financial_report_web.dart' as impl;

/// Exports the monthly Financial-Analyst report. Web → browser print dialog;
/// mobile → PDF share sheet.
Future<void> printFinancialReport(FinancialAnalystReport report) =>
    impl.printFinancialReport(report);
