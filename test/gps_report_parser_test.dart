import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/fleet/data/gps_report_parser.dart';

/// The vendor's day-wise report: every cell is text, dates read "Oct 29, 2026",
/// distance is km with many decimals, Running / Stop / Idle are hours.
List<List<dynamic>> vendorTable() => [
      ['Vehicle No.', 'Date', 'Running', 'Stop', 'Idle', 'Distance', 'Start Address', 'End Address', '', '', '', ''],
      ['KL-57-Y-6100', 'Oct 29, 2026', '0.98', '22.75', '0.00', '23.767842436662626', ' Kozhikode, 673574', ' Kozhikode, 673574', '', '', '', ''],
      ['KL-57-Y-6100', 'Oct 28, 2026', '9.61', '12.66', '0.72', '559.1230885201172', ' Thamarassery', ' Thamarassery', '', '', '', ''],
      ['KL-57-Y-6100', 'Oct 09, 2026', '5.09', '17.21', '0.17', '290.474579123725', ' Address not found in databse', ' Mathara', '', '', '', ''],
      ['KL-57-Y-6100', 'Oct 21, 2026', '0.00', '17.56', '6.44', '0', ' HiLITE', ' HiLITE', '', '', '', ''],
    ];

void main() {
  group('the vendor report', () {
    test('reads one row per day with the numbers the report gives', () {
      final p = parseGpsTable(vendorTable());
      expect(p.error, isNull);
      expect(p.rows.length, 4);
      expect(p.skipped, 0);
      final r = p.rows.first;
      expect(r.registrationNumber, 'KL-57-Y-6100');
      expect(r.date, '2026-10-29');
      expect(r.distanceKm, closeTo(23.768, 0.001));
      expect(r.runningHours, 0.98);
      expect(r.stopHours, 22.75);
      expect(r.idleHours, 0);
      expect(r.startAddress, 'Kozhikode, 673574');
    });

    test('a day with a leading zero ("Oct 09") and a parked day (0 km) are kept', () {
      final p = parseGpsTable(vendorTable());
      expect(p.rows.map((r) => r.date), containsAll(['2026-10-09', '2026-10-21']));
      expect(p.rows.last.distanceKm, 0);
    });

    test('summary: days per vehicle, first and last day, total km', () {
      final p = parseGpsTable(vendorTable());
      expect(p.vehicleDays, {'KL-57-Y-6100': 4});
      expect(p.from, '2026-10-09');
      expect(p.to, '2026-10-29');
      expect(p.totalKm, closeTo(23.768 + 559.123 + 290.475, 0.01));
    });

    test('the columns that were recognised are listed, the blank ones are not', () {
      final p = parseGpsTable(vendorTable());
      expect(p.columns, ['Vehicle No.', 'Date', 'Running', 'Stop', 'Idle', 'Distance', 'Start Address', 'End Address']);
    });

    test('toJson sends only what there is', () {
      final j = parseGpsTable(vendorTable()).rows[2].toJson();
      expect(j['date'], '2026-10-09');
      expect(j.containsKey('startAddress'), isTrue); // "Address not found" is cleaned by the server
      final none = const GpsReportRow(registrationNumber: 'X', date: '2026-10-01', distanceKm: 5).toJson();
      expect(none.keys, unorderedEquals(['registrationNumber', 'date', 'distanceKm']));
    });
  });

  group('dates', () {
    String? d(dynamic v) => parseReportDay(v);

    test('the formats GPS apps and Excel produce', () {
      expect(d('Oct 29, 2026'), '2026-10-29');
      expect(d('October 9 2026'), '2026-10-09');
      expect(d('29-Oct-2026'), '2026-10-29');
      expect(d('29 Oct 2026'), '2026-10-29');
      expect(d('2026-10-29'), '2026-10-29');
      expect(d('2026-10-29 00:00:00'), '2026-10-29');
      expect(d('29/10/2026'), '2026-10-29');
      expect(d('29-10-2026'), '2026-10-29');
      expect(d('29.10.26'), '2026-10-29');
    });

    test('day first (Indian order), unless a number over 12 says otherwise', () {
      expect(d('02/11/2026'), '2026-11-02');
      expect(d('10/29/2026'), '2026-10-29');
    });

    test('a real date cell and an Excel serial number', () {
      expect(d(DateTime(2026, 10, 29)), '2026-10-29');
      expect(d(46324), '2026-10-29'); // 29 Oct 2026
    });

    test('things that are not dates', () {
      expect(d('31/02/2026'), isNull);
      expect(d('Octember 3, 2026'), isNull);
      expect(d('hello'), isNull);
      expect(d(''), isNull);
      expect(d(null), isNull);
      expect(d(12), isNull); // too small to be a serial
    });
  });

  group('numbers', () {
    test('text with separators or a unit', () {
      expect(parseReportNumber('1,234.5'), 1234.5);
      expect(parseReportNumber('23.7 km'), 23.7);
      expect(parseReportNumber(' 0 '), 0);
      expect(parseReportNumber(12), 12);
      expect(parseReportNumber('abc'), isNull);
      expect(parseReportNumber(''), isNull);
    });

    test('hours as a number or a duration', () {
      expect(parseReportHours('0.98'), 0.98);
      expect(parseReportHours('01:30'), 1.5);
      expect(parseReportHours('1:30:36'), 1.51);
      expect(parseReportHours(''), isNull);
    });
  });

  group('layouts', () {
    test('a title row above the header, and other names for the columns', () {
      final p = parseGpsTable([
        ['Distance report — Oct 2026', '', ''],
        [],
        ['Reg. No', 'Report Date', 'Total Distance (KM)'],
        ['KL 07 AB 1234', '03/10/2026', '41.5'],
      ]);
      expect(p.error, isNull);
      expect(p.rows.single.registrationNumber, 'KL 07 AB 1234');
      expect(p.rows.single.date, '2026-10-03');
      expect(p.rows.single.distanceKm, 41.5);
    });

    test('a distance in metres or miles is converted, not trusted as km', () {
      final m = parseGpsTable([['Vehicle', 'Date', 'Distance (m)'], ['A1', '2026-10-01', '12500']]);
      expect(m.rows.single.distanceKm, 12.5);
      final mi = parseGpsTable([['Vehicle', 'Date', 'Distance (miles)'], ['A1', '2026-10-01', '10']]);
      expect(mi.rows.single.distanceKm, closeTo(16.093, 0.001));
    });

    test('a vehicle named once per block carries down to its days', () {
      final p = parseGpsTable([
        ['Vehicle', 'Date', 'Distance'],
        ['KL-01-AA-0001', '2026-10-01', '10'],
        ['', '2026-10-02', '20'],
        ['KL-02-BB-0002', '2026-10-01', '30'],
        ['', '2026-10-02', '40'],
      ]);
      expect(p.rows.map((r) => r.registrationNumber), ['KL-01-AA-0001', 'KL-01-AA-0001', 'KL-02-BB-0002', 'KL-02-BB-0002']);
    });

    test('a totals line and blank lines are not days', () {
      final p = parseGpsTable([
        ['Vehicle', 'Date', 'Distance'],
        ['KL-01-AA-0001', '2026-10-01', '10'],
        [],
        ['Total', '', '10'],
        ['', '', '10'],
      ]);
      expect(p.rows.length, 1);
      expect(p.skipped, 0);
    });

    test('rows that cannot be read are counted with their row number', () {
      final p = parseGpsTable([
        ['Vehicle', 'Date', 'Distance'],
        ['KL-01-AA-0001', '2026-10-01', '10'],
        ['KL-01-AA-0001', 'someday', '10'],
        ['KL-01-AA-0001', '2026-10-03', 'lots'],
      ]);
      expect(p.rows.length, 1);
      expect(p.skipped, 2);
      expect(p.problems, ['Row 3: date “someday” not understood', 'Row 4: distance “lots” is not a number']);
    });
  });

  group('files that are not usable say why', () {
    test('no recognisable columns', () {
      final p = parseGpsTable([['Name', 'Phone'], ['Anu', '999']]);
      expect(p.hasRows, isFalse);
      expect(p.error, contains('vehicle number, a date and a distance'));
      expect(p.error, contains('Name'));
    });

    test('empty sheet, header only, nothing readable', () {
      expect(parseGpsTable([[], ['', '']]).error, 'The sheet is empty.');
      expect(parseGpsTable([['Vehicle', 'Date', 'Distance']]).error, contains('no days'));
      expect(parseGpsTable([['Vehicle', 'Date', 'Distance'], ['A', 'x', 'y']]).error, contains('could be read'));
    });

    test('bytes that are not an Excel file', () {
      final p = parseGpsReport(Uint8List.fromList(utf8.encode('not a workbook')), 'report.xlsx');
      expect(p.error, contains('Could not read this file'));
    });
  });

  group('real files', () {
    test('an .xlsx whose cells are all text, like the vendor writes it', () {
      final book = Excel.createExcel();
      final sheet = book[book.getDefaultSheet()!];
      for (final row in vendorTable()) {
        sheet.appendRow([for (final c in row) TextCellValue(c.toString())]);
      }
      final bytes = Uint8List.fromList(book.save()!);
      final p = parseGpsReport(bytes, '866221071468727-02 Nov 2026.xlsx');
      expect(p.error, isNull);
      expect(p.rows.length, 4);
      expect(p.rows[1].date, '2026-10-28');
      expect(p.rows[1].distanceKm, closeTo(559.123, 0.001));
    });

    test('an .xlsx with real numbers and real dates', () {
      final book = Excel.createExcel();
      final sheet = book[book.getDefaultSheet()!];
      sheet.appendRow([TextCellValue('Vehicle'), TextCellValue('Date'), TextCellValue('Distance')]);
      sheet.appendRow([TextCellValue('KL-01-AA-0001'), DateCellValue(year: 2026, month: 10, day: 5), DoubleCellValue(88.25)]);
      final p = parseGpsReport(Uint8List.fromList(book.save()!), 'r.xlsx');
      expect(p.rows.single.date, '2026-10-05');
      expect(p.rows.single.distanceKm, 88.25);
    });

    test('a .csv export', () {
      final csv = 'Vehicle No.,Date,Distance\nKL-57-Y-6100,"Oct 29, 2026",23.77\nKL-57-Y-6100,"Oct 28, 2026",559.12\n';
      final p = parseGpsReport(Uint8List.fromList(utf8.encode(csv)), 'r.csv');
      expect(p.error, isNull);
      expect(p.rows.map((r) => r.date), ['2026-10-29', '2026-10-28']);
    });
  });
}
