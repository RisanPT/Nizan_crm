import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/features/sales/services/lead_service.dart';

/// Download helpers for the marketing Leads Report — CSV (data) and a branded
/// PDF (Team N logo + styled tables). Both deliver cross-platform (browser
/// download on web, share sheet on Android).

List<List<dynamic>> _kpiRows(LeadsReport r) => [
      ['Leads received', r.total],
      ['Converted', r.converted],
      ['Conversion rate', '${r.conversionRate}%'],
      ['Lost', r.lost],
      ['Follow-ups due', r.followUpsDue],
      ['Follow-ups overdue', r.followUpsOverdue],
    ];

List<List<dynamic>> _bucketRows(List<LeadReportBucket> b) =>
    b.map((x) => [x.key, x.count]).toList();

Future<void> exportLeadsReportCsv(
  LeadsReport r, {
  required String periodLabel,
  required String fileBase,
}) async {
  final rows = <List<dynamic>>[
    ['Leads Report'],
    [periodLabel],
    [],
    ['Metric', 'Value'],
    ..._kpiRows(r),
  ];
  void section(String title, List<LeadReportBucket> b) {
    rows..add([])..add([title, 'Count']);
    for (final x in b) {
      rows.add([x.key, x.count]);
    }
  }

  section('By source', r.bySource);
  section('By status', r.byStatus);
  section('By added-by', r.byAddedBy);
  section('By assignee', r.byAssignee);
  rows..add([])..add(['Date', 'Leads']);
  for (final p in r.series) {
    rows.add([p.date, p.count]);
  }
  await ExportUtils.exportCsv('$fileBase.csv', rows);
}

Future<void> exportLeadsReportPdf(
  LeadsReport r, {
  required String periodLabel,
  required String fileBase,
}) async {
  await saveBrandedReportPdf(
    fileName: '$fileBase.pdf',
    title: 'Leads Report',
    subtitle: periodLabel,
    sections: [
      PdfSection('Summary', ['Metric', 'Value'], _kpiRows(r)),
      PdfSection('By source', ['Source', 'Leads'], _bucketRows(r.bySource)),
      PdfSection('By status', ['Status', 'Leads'], _bucketRows(r.byStatus)),
      PdfSection('By added-by', ['Added by', 'Leads'], _bucketRows(r.byAddedBy)),
      PdfSection('By assignee', ['Assignee', 'Leads'], _bucketRows(r.byAssignee)),
      PdfSection('Daily trend', ['Date', 'Leads'],
          r.series.map((p) => [p.date, p.count]).toList()),
    ],
  );
}
