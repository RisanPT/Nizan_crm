import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

/// Monthly works schedule: every work in [month] that has an artist assigned,
/// grouped by date, with client, service, time, team and location. Downloads a
/// PDF on web; opens the share sheet on mobile.
///
/// [bookings] should already be filtered the way the calendar is (artist /
/// geography); [filterNote] describes those filters for the header.
Future<void> downloadMonthlyWorksReport({
  required List<Booking> bookings,
  required DateTime month,
  String filterNote = '',
}) async {
  final bytes = await buildMonthlyWorksReportBytes(
    bookings: bookings,
    month: month,
    filterNote: filterNote,
  );
  final fileName =
      'works_${DateFormat('yyyy_MM').format(month)}_${DateFormat('MMM').format(month).toLowerCase()}.pdf';
  await saveFileBytes(fileName, bytes, mime: 'application/pdf');
}

/// The report as PDF bytes (no saving) — used by [downloadMonthlyWorksReport]
/// and handy for tests.
Future<List<int>> buildMonthlyWorksReportBytes({
  required List<Booking> bookings,
  required DateTime month,
  String filterNote = '',
}) => _buildPdf(monthlyWorks(bookings, month), month, filterNote);

/// The works that go in the report: entries dated inside [month] with at least
/// one non-driver team member assigned, excluding cancelled / postponed /
/// rejected works. Sorted by date, then start time, then client.
List<BookingDisplayEntry> monthlyWorks(List<Booking> bookings, DateTime month) {
  const skip = {'cancelled', 'postponed', 'rejected'};
  final works =
      bookings
          .expand((b) => b.displayEntries)
          .where(
            (e) =>
                e.calendarDate.year == month.year &&
                e.calendarDate.month == month.month &&
                !skip.contains(e.status.toLowerCase()) &&
                _team(e).any((m) => !m.isDriver),
          )
          .toList()
        ..sort((a, b) {
          final d = _day(a.calendarDate).compareTo(_day(b.calendarDate));
          if (d != 0) return d;
          final t = a.serviceStart.compareTo(b.serviceStart);
          if (t != 0) return t;
          return a.booking.customerName.compareTo(b.booking.customerName);
        });
  return works;
}

// ── Row helpers ────────────────────────────────────────────────────────────

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class _Member {
  final String name;
  final String role;
  final bool isLead;
  final bool isDriver;
  const _Member(
    this.name,
    this.role, {
    this.isLead = false,
    this.isDriver = false,
  });
}

/// Everyone going for this work: lead first, then artists/assistants, then the
/// driver (from the assignment list, or the booking's driver as a fallback).
List<_Member> _team(BookingDisplayEntry e) {
  final seen = <String>{};
  final out = <_Member>[];
  for (final a in e.assignedStaff) {
    final name = a.artistName.trim();
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    final rt = a.roleType.toLowerCase();
    final isDriver = rt == 'driver';
    final isLead = rt == 'lead' || rt == 'artist';
    final role = isDriver
        ? 'Driver'
        : rt == 'lead'
        ? 'Lead'
        : rt == 'artist'
        ? 'Artist'
        : (a.role.trim().isNotEmpty ? a.role.trim() : 'Assistant');
    out.add(_Member(name, role, isLead: isLead, isDriver: isDriver));
  }
  final driver = e.booking.driverName.trim();
  if (driver.isNotEmpty && seen.add(driver.toLowerCase())) {
    out.add(_Member(driver, 'Driver', isDriver: true));
  }
  int rank(_Member m) => m.isLead ? 0 : (m.isDriver ? 2 : 1);
  out.sort((a, b) => rank(a).compareTo(rank(b)));
  return out;
}

String _time(BookingDisplayEntry e) {
  final s = e.serviceStart, t = e.serviceEnd;
  final hasStart = s.hour != 0 || s.minute != 0;
  final hasEnd = t.hour != 0 || t.minute != 0;
  final f = DateFormat('h:mm a');
  final slot = e.eventSlot.trim();
  if (!hasStart) return slot.isEmpty ? '-' : slot;
  final range = hasEnd && t.isAfter(s)
      ? '${f.format(s)} - ${f.format(t)}'
      : f.format(s);
  return slot.isEmpty ? range : '$range\n$slot';
}

String _location(BookingDisplayEntry e) {
  final b = e.booking;
  final parts = <String>[
    b.address.trim(),
    [b.district.trim(), b.region.trim()].where((s) => s.isNotEmpty).join(', '),
    if (b.pincode.trim().isNotEmpty) 'PIN ${b.pincode.trim()}',
  ].where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? '-' : parts.join('\n');
}

String _status(BookingDisplayEntry e) {
  final s = e.status.trim();
  if (s.isEmpty) return '';
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── PDF ────────────────────────────────────────────────────────────────────

const _ink = PdfColor.fromInt(0xFF1F2937);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);
const _zebra = PdfColor.fromInt(0xFFFAF7F8);
const _gold = PdfColor.fromInt(0xFFC9A66B);

Future<List<int>> _buildPdf(
  List<BookingDisplayEntry> works,
  DateTime month,
  String filterNote,
) async {
  final logo = await brandedPdfLogo();
  final monthLabel = DateFormat('MMMM yyyy').format(month);
  final generated = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

  // Group by day.
  final byDay = <DateTime, List<BookingDisplayEntry>>{};
  for (final w in works) {
    byDay.putIfAbsent(_day(w.calendarDate), () => []).add(w);
  }

  // Artist workload (non-drivers).
  final perArtist = <String, int>{};
  for (final w in works) {
    for (final m in _team(w).where((m) => !m.isDriver)) {
      perArtist[m.name] = (perArtist[m.name] ?? 0) + 1;
    }
  }
  final artistRows = perArtist.entries.toList()
    ..sort(
      (a, b) => b.value.compareTo(a.value) != 0
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key),
    );
  final clients = works.map((w) => w.booking.id).toSet().length;

  final doc = pw.Document(title: 'Works Schedule - $monthLabel');

  pw.Widget txt(
    String s, {
    double size = 8.5,
    bool bold = false,
    PdfColor color = _ink,
    pw.TextAlign? align,
  }) => pw.Text(
    pdfSafe(s),
    textAlign: align,
    style: pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  );

  pw.Widget stat(String k, String v) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          txt(k.toUpperCase(), size: 7, color: _muted),
          pw.SizedBox(height: 3),
          txt(v, size: 15, bold: true, color: kPdfBrand),
        ],
      ),
    ),
  );

  const widths = <int, pw.TableColumnWidth>{
    0: pw.FixedColumnWidth(20), // #
    1: pw.FlexColumnWidth(1.25), // time
    2: pw.FlexColumnWidth(1.75), // client
    3: pw.FlexColumnWidth(1.6), // service
    4: pw.FlexColumnWidth(2.2), // team
    5: pw.FlexColumnWidth(2.5), // location
  };

  pw.Widget headerCell(String s) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: txt(s.toUpperCase(), size: 7, bold: true, color: PdfColors.white),
  );

  pw.Widget pad(pw.Widget child) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: child,
  );

  pw.Widget teamCell(BookingDisplayEntry e) {
    final team = _team(e);
    return pad(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final m in team)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1.5),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: pdfSafe(m.name),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: _ink,
                        fontWeight: m.isLead
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                      ),
                    ),
                    pw.TextSpan(
                      text: '  ${m.role}',
                      style: const pw.TextStyle(fontSize: 7, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget clientCell(BookingDisplayEntry e) {
    final b = e.booking;
    return pad(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          txt(
            b.customerName.trim().isEmpty ? '-' : b.customerName.trim(),
            bold: true,
          ),
          if (b.phone.trim().isNotEmpty)
            txt(b.phone.trim(), size: 7.5, color: _muted),
          if (b.bookingNumber.trim().isNotEmpty)
            txt('#${b.bookingNumber.trim()}', size: 7, color: _muted),
        ],
      ),
    );
  }

  pw.Widget serviceCell(BookingDisplayEntry e) {
    final st = _status(e);
    return pad(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          txt(e.service.trim().isEmpty ? '-' : e.service.trim()),
          if (st.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            txt(st, size: 7, color: _muted),
          ],
        ],
      ),
    );
  }

  // Returned as separate top-level widgets (not wrapped in a Column) so the
  // table can break across pages on busy days.
  List<pw.Widget> dayBlock(DateTime day, List<BookingDisplayEntry> list) {
    return [
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: const pw.BoxDecoration(
          color: kPdfBrandLt,
          border: pw.Border(left: pw.BorderSide(color: kPdfBrand, width: 3)),
        ),
        child: pw.Row(
          children: [
            txt(
              DateFormat('EEEE, d MMMM yyyy').format(day),
              size: 10.5,
              bold: true,
              color: kPdfBrand,
            ),
            pw.Spacer(),
            txt(
              '${list.length} work${list.length == 1 ? '' : 's'}',
              size: 8.5,
              color: _muted,
            ),
          ],
        ),
      ),
      pw.Table(
        columnWidths: widths,
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.5),
          bottom: pw.BorderSide(color: _line, width: 0.5),
        ),
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: kPdfBrand),
            children: [
              headerCell('#'),
              headerCell('Time'),
              headerCell('Client'),
              headerCell('Service'),
              headerCell('Team'),
              headerCell('Location'),
            ],
          ),
          for (var i = 0; i < list.length; i++)
            pw.TableRow(
              decoration: i.isOdd
                  ? const pw.BoxDecoration(color: _zebra)
                  : null,
              children: [
                pad(txt('${i + 1}', color: _muted)),
                pad(txt(_time(list[i]), bold: true)),
                clientCell(list[i]),
                serviceCell(list[i]),
                teamCell(list[i]),
                pad(txt(_location(list[i]), size: 8)),
              ],
            ),
        ],
      ),
    ];
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                children: [
                  txt(
                    'Works Schedule - $monthLabel',
                    size: 8.5,
                    bold: true,
                    color: kPdfBrand,
                  ),
                  pw.Spacer(),
                  txt('Team N Makeovers', size: 8, color: _muted),
                ],
              ),
            ),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: 0.6)),
        ),
        child: pw.Row(
          children: [
            txt(
              'Team N ERP - generated $generated - internal use only',
              size: 7.5,
              color: _muted,
            ),
            pw.Spacer(),
            txt(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              size: 7.5,
              color: _muted,
            ),
          ],
        ),
      ),
      build: (ctx) => [
        // Title block
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.SizedBox(
                width: 48,
                height: 48,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  txt('Works Schedule', size: 20, bold: true, color: kPdfBrand),
                  txt(monthLabel, size: 12, color: _ink),
                  if (filterNote.trim().isNotEmpty)
                    txt(
                      'Filters: ${filterNote.trim()}',
                      size: 8.5,
                      color: _muted,
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                txt('TEAM N MAKEOVERS', size: 10, bold: true, color: kPdfBrand),
                txt('Works with artists assigned', size: 8, color: _muted),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: kPdfBrand),
        pw.Container(height: 1, width: 90, color: _gold),
        pw.SizedBox(height: 12),

        if (works.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 40),
            child: pw.Center(
              child: txt(
                'No works with an assigned artist in $monthLabel.',
                size: 12,
                color: _muted,
              ),
            ),
          )
        else ...[
          pw.Row(
            children: [
              stat('Total works', '${works.length}'),
              stat('Working days', '${byDay.length}'),
              stat('Clients', '$clients'),
              stat('Artists on duty', '${perArtist.length}'),
            ],
          ),
          // Artist workload — heading and chips kept together in one block.
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 12),
              txt(
                'Artist workload this month',
                size: 10.5,
                bold: true,
                color: kPdfBrand,
              ),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in artistRows)
                    pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(9, 5, 9, 5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _line),
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: pdfSafe(a.key),
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: _ink,
                              ),
                            ),
                            pw.TextSpan(
                              text:
                                  '   ${a.value} work${a.value == 1 ? '' : 's'}',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                color: kPdfBrand,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          for (final e in byDay.entries) ...dayBlock(e.key, e.value),
        ],
      ],
    ),
  );

  return doc.save();
}
