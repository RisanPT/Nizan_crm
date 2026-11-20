import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/assignment_rules.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/core/utils/monthly_works_report.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/calendar_screen.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/services/region_service.dart';
import 'package:nizan_crm/services/state_service.dart';
import 'package:nizan_crm/services/zone_service.dart';

// The Calendar Scheduler's staff filter and the monthly works report: "All Associates" and one associate, next to All Staff / Not Assigned
// / one artist. The ASSOCIATE report keeps only the works an associate is on and marks them on the team.

Employee _e(
  String id,
  String name, {
  String role = 'artist',
  bool associate = false,
  String status = 'active',
}) => Employee.fromJson({
  '_id': id,
  'name': name,
  'artistRole': role,
  'type': associate ? 'outsource' : 'in-house',
  'isAssociate': associate,
  'status': status,
  'phone': '90000$id',
});

Map<String, dynamic> _a(
  String id,
  String name,
  String roleType, {
  String role = '',
}) => {
  'employeeId': id,
  'artistName': name,
  'role': role.isEmpty
      ? (roleType == 'lead' ? 'Lead Artist' : 'Assistant')
      : role,
  'roleType': roleType,
  'type': 'in-house',
};

const _day = {
  '18': '2026-11-18',
  '20': '2026-11-20',
  '22': '2026-11-22',
  '24': '2026-11-24',
  '25': '2026-11-25',
  '26': '2026-11-26',
  '28': '2026-11-28',
};

Booking _b(
  String id,
  String customer,
  String day, {
  List<Map<String, dynamic>> staff = const [],
  List<Map<String, dynamic>> items = const [],
  String status = 'confirmed',
}) => Booking.fromJson({
  '_id': id,
  'bookingNumber': 'BK-$id',
  'customerName': customer,
  'phone': '9895499872',
  'status': status,
  'service': 'Bridal',
  'totalPrice': 10000,
  'advanceAmount': 1000,
  'selectedDates': [_day[day]],
  'bookingDate': '${_day[day]}T04:00:00.000Z',
  'serviceStart': '${_day[day]}T04:00:00.000Z',
  'serviceEnd': '${_day[day]}T08:00:00.000Z',
  'assignedStaff': staff,
  'bookingItems': items,
});

Map<String, dynamic> _item(
  String service,
  List<Map<String, dynamic>> staff,
  String day,
) => {
  'service': service,
  'eventSlot': 'Morning',
  'selectedDates': [_day[day]],
  'totalPrice': 5000,
  'assignedStaff': staff,
};

final _anu = _a('a1', 'Anu', 'lead');
final _asha = _a('x1', 'Asha', 'assistant', role: 'Associate');
final _binu = _a('x2', 'Binu', 'assistant', role: 'Hair');
final _staff = [
  _e('a1', 'Anu'),
  _e('a2', 'Chitra'),
  _e('x1', 'Asha', role: 'assistant', associate: true),
  _e('x2', 'Binu', role: 'assistant', associate: true),
  _e('x3', 'Dina', role: 'assistant', associate: true, status: 'inactive'),
  _e('f1', 'Freelancer', role: 'assistant'),
  _e('o1', 'Office Staff', role: 'staff'),
];
final _associateIds = associateIdsOf(_staff);

// Meera: Anu + Asha. Divya: Anu only. Kala: two packages — Binu on the first, Anu on the second (the booking-level list is the roll-up of
// both). Latha: only the package lists Asha, the booking-level list is empty. Cancelled: Asha, but cancelled. Nobody: no one.
final _meera = _b('1', 'Meera', '18', staff: [_anu, _asha]);
final _divya = _b('2', 'Divya', '20', staff: [_anu]);
final _kala = _b(
  '3',
  'Kala',
  '22',
  staff: [_anu, _binu],
  items: [
    _item('Bridal', [_binu], '22'),
    _item('Party', [_anu], '22'),
  ],
);
final _latha = _b(
  '4',
  'Latha',
  '24',
  items: [
    _item('Bridal', [_asha], '24'),
  ],
);
final _cancelled = _b(
  '5',
  'Cancelled',
  '25',
  staff: [_asha],
  status: 'cancelled',
);
final _nobody = _b('6', 'Nobody', '26');
final _all = [_meera, _divya, _kala, _latha, _cancelled, _nobody];

List<String> _who(Iterable<Booking> l) => l.map((b) => b.customerName).toList();
List<String> _under(String filter, [List<Booking>? from]) => _who(
  (from ?? _all).where(
    (b) => bookingMatchesStaffFilter(b, filter, _associateIds),
  ),
);

/// What the Report button asked the PDF builder for.
class _Request {
  _Request(
    this.bookings,
    this.month,
    this.note,
    this.associateIds,
    this.onlyStaffIds,
    this.fileTag, [
    this.range,
  ]);
  final List<String> bookings;
  final DateTime month;
  final String note;
  final Set<String> associateIds;
  final Set<String>? onlyStaffIds;
  final String fileTag;

  /// The days chosen instead of the month on screen; null = the month itself.
  final ReportRange? range;
}

class _Bookings extends BookingNotifier {
  _Bookings(this.list);
  final List<Booking> list;
  @override
  FutureOr<List<Booking>> build() => list;
}

void main() {
  group('the staff filter rules', () {
    test(
      'All Staff shows every work; Not Assigned only the works nobody is on',
      () {
        expect(_under('all'), [
          'Meera',
          'Divya',
          'Kala',
          'Latha',
          'Cancelled',
          'Nobody',
        ]);
        expect(_under('unassigned'), ['Nobody']);
      },
    );

    test(
      'All Associates: every work an associate is on — on the booking OR only on one of its packages',
      () {
        expect(_under(kAssociatesFilter), [
          'Meera',
          'Kala',
          'Latha',
          'Cancelled',
        ]);
      },
    );

    test(
      'one associate: just their works; one artist: unchanged (by employee id, booking or package)',
      () {
        expect(_under('x1'), ['Meera', 'Latha', 'Cancelled']);
        expect(_under('x2'), ['Kala']);
        expect(_under('a1'), ['Meera', 'Divya', 'Kala']);
        expect(_under('a2'), isEmpty);
      },
    );

    test(
      'with no associates registered, All Associates matches nothing (never everything)',
      () {
        expect(
          _who(
            _all.where(
              (b) => bookingMatchesStaffFilter(b, kAssociatesFilter, const {}),
            ),
          ),
          isEmpty,
        );
      },
    );

    test(
      'an inactive associate still counts for All Associates (they did the work)',
      () {
        final past = _b(
          '9',
          'Past',
          '28',
          staff: [_a('x3', 'Dina', 'assistant')],
        );
        expect(
          bookingMatchesStaffFilter(past, kAssociatesFilter, _associateIds),
          isTrue,
        );
      },
    );
  });

  group('who the report is about', () {
    test(
      'All Associates -> every associate; one associate -> just them; anything else -> a plain works report',
      () {
        expect(associateFocus(kAssociatesFilter, _associateIds), {
          'x1',
          'x2',
          'x3',
        });
        expect(associateFocus('x2', _associateIds), {'x2'});
        expect(
          associateFocus('a1', _associateIds),
          isNull,
          reason: 'an artist is not an associate report',
        );
        expect(associateFocus('all', _associateIds), isNull);
        expect(associateFocus('unassigned', _associateIds), isNull);
      },
    );

    test('the file name says which report it is', () {
      expect(associateReportFileTag(kAssociatesFilter, _staff), 'associates');
      expect(associateReportFileTag('x1', _staff), 'associate_asha');
      expect(
        associateReportFileTag('a1', _staff),
        '',
        reason: 'an artist is not an associate',
      );
      expect(associateReportFileTag('all', _staff), '');
      expect(associateReportFileTag('x9', _staff), '', reason: 'unknown id');
      final odd = [
        _e('x7', "  Mary-Ann  O'Neil ", associate: true),
        _e('x8', '!!!', associate: true),
      ];
      expect(associateReportFileTag('x7', odd), 'associate_mary_ann_o_neil');
      expect(associateReportFileTag('x8', odd), 'associate');
    });
  });

  group('the associates on a chip', () {
    List<String> on(Booking b, Set<String> ids) =>
        associateNamesOn(b.displayEntries, ids);

    test(
      'names each associate on the works once, in order; the lead and drivers are not listed',
      () {
        expect(on(_meera, _associateIds), ['Asha']);
        expect(on(_latha, _associateIds), [
          'Asha',
        ], reason: 'only on the package');
        expect(on(_kala, _associateIds), [
          'Binu',
        ], reason: "across both packages, only Binu is an associate");
        expect(on(_divya, _associateIds), isEmpty);
        expect(on(_nobody, _associateIds), isEmpty);
      },
    );

    test(
      'the same associate on two works of a chip is named once; with no associates registered nobody is',
      () {
        final both = [..._meera.displayEntries, ..._latha.displayEntries];
        expect(associateNamesOn(both, _associateIds), ['Asha']);
        expect(associateNamesOn(both, const {}), isEmpty);
        expect(associateNamesOn(const [], _associateIds), isEmpty);
      },
    );

    test('a person with no name on the booking is not named', () {
      final b = _b('7', 'Blank', '28', staff: [_a('x1', ' ', 'assistant')]);
      expect(on(b, _associateIds), isEmpty);
    });
  });

  group('the monthly works report', () {
    final nov = DateTime(2026, 11, 1);
    List<String> works(List<BookingDisplayEntry> l) => [
      for (final e in l) '${e.booking.customerName}/${e.service}',
    ];

    test(
      'a plain report is unchanged: every work with someone on it, not cancelled, not empty-handed',
      () {
        expect(works(monthlyWorks(_all, nov)), [
          'Meera/Bridal',
          'Divya/Bridal',
          'Kala/Bridal',
          'Kala/Party',
          'Latha/Bridal',
        ]);
      },
    );

    test(
      'any days instead of a month: the works dated on them, both ends in, across a month end too',
      () {
        ReportRange days(String a, String b) =>
            ReportRange(from: DateTime.parse(a), to: DateTime.parse(b));
        expect(
          works(
            monthlyWorks(_all, nov, range: days('2026-11-20', '2026-11-22')),
          ),
          ['Divya/Bridal', 'Kala/Bridal', 'Kala/Party'],
        );
        expect(
          works(
            monthlyWorks(_all, nov, range: days('2026-11-22', '2026-11-22')),
          ),
          ['Kala/Bridal', 'Kala/Party'],
          reason: 'one day',
        );
        expect(
          works(
            monthlyWorks(_all, nov, range: days('2026-10-25', '2026-11-18')),
          ),
          ['Meera/Bridal'],
          reason: 'the 18th is the last day, and it is in',
        );
        expect(
          works(
            monthlyWorks(_all, nov, range: days('2026-11-19', '2026-11-19')),
          ),
          isEmpty,
        );
        // the month is ignored when days are given
        expect(
          works(
            monthlyWorks(
              _all,
              DateTime(2030, 1, 1),
              range: days('2026-11-24', '2026-11-26'),
            ),
          ),
          ['Latha/Bridal'],
        );
        // and the associate rule still applies inside them
        expect(
          works(
            monthlyWorks(
              _all,
              nov,
              onlyStaffIds: _associateIds,
              range: days('2026-11-20', '2026-11-26'),
            ),
          ),
          ['Kala/Bridal', 'Latha/Bridal'],
        );
      },
    );

    test('the PDF is built over any days, and says them', () async {
      final r = ReportRange(
        from: DateTime(2026, 11, 20),
        to: DateTime(2026, 11, 22),
      );
      final bytes = await buildMonthlyWorksReportBytes(
        bookings: _all,
        month: nov,
        range: r,
      );
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final empty = await buildMonthlyWorksReportBytes(
        bookings: _all,
        month: nov,
        range: ReportRange(
          from: DateTime(2026, 12, 1),
          to: DateTime(2026, 12, 5),
        ),
      );
      expect(
        empty.length,
        greaterThan(300),
        reason: 'no works in those days: still a report, an empty one',
      );
    });

    test(
      'the associate report keeps only the works an associate is actually on — not the other package of the same booking',
      () {
        expect(works(monthlyWorks(_all, nov, onlyStaffIds: _associateIds)), [
          'Meera/Bridal',
          'Kala/Bridal',
          'Latha/Bridal',
        ]);
        expect(works(monthlyWorks(_all, nov, onlyStaffIds: {'x1'})), [
          'Meera/Bridal',
          'Latha/Bridal',
        ]);
        expect(works(monthlyWorks(_all, nov, onlyStaffIds: {'x2'})), [
          'Kala/Bridal',
        ]);
      },
    );

    test(
      'a cancelled work is left out of the associate report too; nobody to report on = an empty report',
      () {
        expect(
          works(monthlyWorks([_cancelled], nov, onlyStaffIds: {'x1'})),
          isEmpty,
        );
        expect(monthlyWorks(_all, nov, onlyStaffIds: const {}), isEmpty);
      },
    );

    test(
      'associates are marked on the team list, whatever role was typed; artists are not',
      () {
        final meera = monthlyWorks([_meera], nov).single;
        expect(worksReportTeamLines(meera, associateIds: _associateIds), [
          'Anu  Lead',
          'Asha  Associate',
        ]);
        final kala = monthlyWorks([_kala], nov, onlyStaffIds: {'x2'}).single;
        expect(worksReportTeamLines(kala, associateIds: _associateIds), [
          'Binu  Hair - Associate',
        ]);
        expect(worksReportTeamLines(kala), [
          'Binu  Hair',
        ], reason: 'a plain report does not mark anyone');
      },
    );

    test(
      'the PDF is built for the associate report, titled as one — and for an empty month',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        String text(List<int> b) => String.fromCharCodes(b);
        final assoc = await buildMonthlyWorksReportBytes(
          bookings: _all,
          month: nov,
          associateIds: _associateIds,
          onlyStaffIds: _associateIds,
          filterNote: 'All associates',
        );
        expect(text(assoc.take(5).toList()), '%PDF-');
        expect(text(assoc), contains('Associate Works Schedule'));
        final plain = await buildMonthlyWorksReportBytes(
          bookings: _all,
          month: nov,
        );
        expect(text(plain), isNot(contains('Associate Works Schedule')));
        expect(text(plain), contains('Works Schedule'));
        final empty = await buildMonthlyWorksReportBytes(
          bookings: _all,
          month: DateTime(2027, 3, 1),
          associateIds: _associateIds,
          onlyStaffIds: _associateIds,
        );
        expect(text(empty.take(5).toList()), '%PDF-');
      },
    );
  });

  group('the Calendar Scheduler screen', () {
    Size viewSize = const Size(1400, 1100);
    void size(WidgetTester t) {
      t.view.physicalSize = viewSize;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Future<void> open(
      WidgetTester t, {
      String? artistId,
      List<Employee>? staff,
      List<_Request>? asked,
      DateTime? focus,
    }) async {
      size(t);
      await t.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            bookingProvider.overrideWith(() => _Bookings(_all)),
            worksReportDownloaderProvider.overrideWith(
              (ref) =>
                  ({
                    required bookings,
                    required month,
                    filterNote = '',
                    associateIds = const {},
                    onlyStaffIds,
                    fileTag = '',
                    range,
                  }) async {
                    asked?.add(
                      _Request(
                        _who(bookings),
                        month,
                        filterNote,
                        associateIds,
                        onlyStaffIds,
                        fileTag,
                        range,
                      ),
                    );
                  },
            ),
            employeesProvider.overrideWith((ref) async => staff ?? _staff),
            zonesProvider.overrideWith((ref) async => const []),
            statesProvider.overrideWith((ref) async => const []),
            regionsProvider.overrideWith((ref) async => const []),
            districtsProvider.overrideWith((ref) async => const []),
            authSessionProvider.overrideWithValue(
              const AuthSession(
                token: 't',
                userId: 'u',
                name: 'U',
                email: 'u@x',
                role: 'admin',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: CalendarScreen(
                initialFocusDate: focus ?? DateTime(2026, 11, 16),
                initialArtistId: artistId,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> pick(WidgetTester t, Finder item) async {
      await t.tap(find.byTooltip('Filter by artist'));
      await t.pumpAndSettle();
      await t.tap(item);
      await t.pumpAndSettle();
    }

    final plainReport = find.text('November 2026 Report');
    final assocReport = find.text('November 2026 Associate Report');

    testWidgets(
      'the staff menu offers All Associates, and each ACTIVE associate under their own heading',
      (t) async {
        await open(t);
        await t.tap(find.byTooltip('Filter by artist'));
        await t.pumpAndSettle();
        expect(find.text('All Staff'), findsWidgets);
        expect(find.text('Not Assigned'), findsOneWidget);
        expect(find.byKey(const Key('cal_staff_associates')), findsOneWidget);
        expect(find.text('All Associates'), findsOneWidget);
        expect(find.text('ASSOCIATES'), findsOneWidget);
        expect(find.byKey(const Key('cal_staff_x1')), findsOneWidget);
        expect(find.byKey(const Key('cal_staff_x2')), findsOneWidget);
        expect(
          find.byKey(const Key('cal_staff_x3')),
          findsNothing,
          reason: 'Dina is no longer active',
        );
        expect(find.text('Anu'), findsOneWidget);
        expect(find.text('Chitra'), findsOneWidget);
        expect(
          find.text('Freelancer'),
          findsOneWidget,
          reason: 'a plain assistant is listed as before',
        );
        expect(
          find.text('Office Staff'),
          findsNothing,
          reason: 'not an artist and not an associate',
        );
      },
    );

    testWidgets(
      'an associate is not in the artist list: listed once, under ASSOCIATES',
      (t) async {
        await open(
          t,
          staff: [
            ..._staff,
            _e('x5', 'Eda', role: 'artist', associate: true),
          ],
        );
        await t.tap(find.byTooltip('Filter by artist'));
        await t.pumpAndSettle();
        expect(find.text('Eda'), findsOneWidget);
        expect(find.byKey(const Key('cal_staff_x5')), findsOneWidget);
      },
    );

    testWidgets(
      'with no associates yet, All Associates is still offered but there is no empty ASSOCIATES heading',
      (t) async {
        await open(t, staff: [_e('a1', 'Anu')]);
        await t.tap(find.byTooltip('Filter by artist'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('cal_staff_associates')), findsOneWidget);
        expect(find.text('ASSOCIATES'), findsNothing);
      },
    );

    testWidgets(
      'All Associates: the calendar shows only works with an associate, and the report becomes the Associate Report',
      (t) async {
        await open(t);
        expect(plainReport, findsOneWidget);
        expect(assocReport, findsNothing);
        expect(
          find.text('ANU • BRIDAL'),
          findsNWidgets(2),
        ); // Meera on the 18th, Divya on the 20th
        expect(find.text('NOBODY • BRIDAL'), findsOneWidget);

        await pick(t, find.byKey(const Key('cal_staff_associates')));

        expect(
          find.text('All Associates'),
          findsOneWidget,
          reason: 'the filter button names the choice',
        );
        expect(assocReport, findsOneWidget);
        expect(plainReport, findsNothing);
        expect(
          find.text('ANU • BRIDAL'),
          findsOneWidget,
          reason: 'Meera stays; Divya (no associate) goes',
        );
        expect(find.text('NOBODY • BRIDAL'), findsNothing);
        expect(
          find.text('BINU • MORNING'),
          findsOneWidget,
          reason: 'Kala has Binu on a package',
        );
        expect(
          find.text('ASHA • MORNING'),
          findsOneWidget,
          reason: 'Latha: the associate is only on the package',
        );
        expect(
          find.text('CANCELLED • BRIDAL'),
          findsOneWidget,
          reason:
              'the calendar still shows a cancelled work, as it does for any filter',
        );
      },
    );

    testWidgets(
      'one associate: only their works; the month summary follows the filter',
      (t) async {
        await open(t);
        expect(
          find.text('5'),
          findsWidgets,
        ); // total bookings this month, all staff
        await pick(t, find.byKey(const Key('cal_staff_x1')));
        expect(
          find.text('Asha'),
          findsOneWidget,
          reason: 'the filter button shows the associate',
        );
        expect(assocReport, findsOneWidget);
        expect(
          find.text('BINU • MORNING'),
          findsNothing,
          reason: "Kala is Binu's work, not Asha's",
        );
        expect(find.text('ASHA • MORNING'), findsOneWidget);
        expect(
          find.text('2'),
          findsWidgets,
        ); // Meera + Latha (the cancelled one is not counted)
      },
    );

    testWidgets(
      'an artist keeps the plain report; going back to All Staff brings everything back',
      (t) async {
        await open(t);
        await pick(t, find.text('Anu').last);
        expect(plainReport, findsOneWidget);
        expect(assocReport, findsNothing);
        await pick(t, find.byKey(const Key('cal_staff_associates')));
        expect(assocReport, findsOneWidget);
        await t.tap(find.byTooltip('Filter by artist'));
        await t.pumpAndSettle();
        await t.tap(find.text('All Staff').last);
        await t.pumpAndSettle();
        expect(plainReport, findsOneWidget);
        expect(find.text('NOBODY • BRIDAL'), findsOneWidget);
      },
    );

    testWidgets(
      'opened for one associate (initialArtistId): their name on the filter and the Associate Report',
      (t) async {
        await open(t, artistId: 'x1');
        expect(find.text('Asha'), findsOneWidget);
        expect(assocReport, findsOneWidget);
      },
    );

    group('the Report button', () {
      testWidgets(
        'asks which dates; the month on screen is the usual monthly report (no days), another choice goes as days',
        (t) async {
          final asked = <_Request>[];
          await open(t, asked: asked);
          await t.tap(find.text('November 2026 Report'));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('report_range_dialog')), findsOneWidget);
          expect(find.text('Works report for which dates?'), findsOneWidget);
          // the month on screen is what it begins on: nothing to change, so the usual report
          await t.tap(find.byKey(const Key('report_range_confirm')));
          await t.pumpAndSettle();
          expect(asked.single.range, isNull);
          expect(asked.single.month, DateTime(2026, 11, 1));

          // today only: days, not the month
          await t.tap(find.text('November 2026 Report'));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('report_range_chip_today')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('report_range_confirm')));
          await t.pumpAndSettle();
          expect(asked, hasLength(2));
          final today = DateTime.now();
          expect(asked[1].range, ReportRange(from: today, to: today));
          expect(asked[1].bookings, [
            'Meera',
            'Divya',
            'Kala',
            'Latha',
            'Cancelled',
            'Nobody',
          ], reason: 'the same filters; the days are applied by the report');
        },
      );

      testWidgets('backing out of the dates asks for nothing', (t) async {
        final asked = <_Request>[];
        await open(t, asked: asked);
        await t.tap(find.text('November 2026 Report'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('report_range_cancel')));
        await t.pumpAndSettle();
        expect(asked, isEmpty);
      });

      testWidgets(
        'All Associates: the PDF is the associate report for every associate, tagged, and the works that have one',
        (t) async {
          final asked = <_Request>[];
          await open(t, asked: asked);
          await pick(t, find.byKey(const Key('cal_staff_associates')));
          await t.tap(find.text('November 2026 Associate Report'));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('report_range_confirm')));
          await t.pumpAndSettle();
          expect(asked, hasLength(1));
          final r = asked.single;
          expect(r.bookings, ['Meera', 'Kala', 'Latha', 'Cancelled']);
          expect(r.month, DateTime(2026, 11, 1));
          expect(r.note, 'All associates');
          expect(r.onlyStaffIds, {'x1', 'x2', 'x3'});
          expect(r.associateIds, {'x1', 'x2', 'x3'});
          expect(r.fileTag, 'associates');
        },
      );

      testWidgets(
        'one associate: only that person, named in the header and the file name',
        (t) async {
          final asked = <_Request>[];
          await open(t, asked: asked);
          await pick(t, find.byKey(const Key('cal_staff_x2')));
          await t.tap(find.text('November 2026 Associate Report'));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('report_range_confirm')));
          await t.pumpAndSettle();
          final r = asked.single;
          expect(r.bookings, ['Kala']);
          expect(r.note, 'Associate: Binu');
          expect(r.onlyStaffIds, {'x2'});
          expect(r.fileTag, 'associate_binu');
        },
      );

      testWidgets(
        'an artist or All Staff: a plain report (nothing narrowed to associates) that still marks any associate on the team',
        (t) async {
          final asked = <_Request>[];
          await open(t, asked: asked);
          await t.tap(find.text('November 2026 Report'));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('report_range_confirm')));
          await t.pumpAndSettle();
          await pick(t, find.text('Anu').last);
          await t.tap(find.text('November 2026 Report'));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('report_range_confirm')));
          await t.pumpAndSettle();
          expect(asked, hasLength(2));
          expect(asked[0].bookings, [
            'Meera',
            'Divya',
            'Kala',
            'Latha',
            'Cancelled',
            'Nobody',
          ]);
          expect(
            [asked[0].note, asked[0].onlyStaffIds, asked[0].fileTag],
            ['', null, ''],
          );
          expect(asked[1].bookings, ['Meera', 'Divya', 'Kala']);
          expect(
            [asked[1].note, asked[1].onlyStaffIds, asked[1].fileTag],
            ['Artist: Anu', null, ''],
          );
          expect(asked[1].associateIds, {'x1', 'x2', 'x3'});
        },
      );

      testWidgets('opened for one associate: the report is already theirs', (
        t,
      ) async {
        final asked = <_Request>[];
        await open(t, artistId: 'x1', asked: asked);
        await t.tap(find.text('November 2026 Associate Report'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('report_range_confirm')));
        await t.pumpAndSettle();
        expect(asked.single.bookings, ['Meera', 'Latha', 'Cancelled']);
        expect(asked.single.onlyStaffIds, {'x1'});
      });
    });

    group('the associate badge on the calendar', () {
      final badge = find.byKey(const Key('cal_assoc_badge'));

      // Is there a badge inside the chip that carries [text]? (the nth chip with that text)
      bool chipHasBadge(Finder chipText, int n) => find
          .descendant(
            of: find
                .ancestor(of: chipText.at(n), matching: find.byType(InkWell))
                .first,
            matching: badge,
          )
          .evaluate()
          .isNotEmpty;

      testWidgets(
        'month view: a chip gets the badge when an associate is on any of its works — and only then',
        (t) async {
          await open(t);
          // Meera (Anu + Asha), Kala's Binu package, Latha (Asha) and the cancelled work (Asha): four chips. Divya (Anu), Kala's Anu package, Nobody: none.
          expect(badge, findsNWidgets(4));
          expect(
            [
              chipHasBadge(find.text('ANU • BRIDAL'), 0),
              chipHasBadge(find.text('ANU • BRIDAL'), 1),
            ],
            [true, false],
            reason: 'Meera on the 18th, then Divya on the 20th',
          );
          expect(chipHasBadge(find.text('NOBODY • BRIDAL'), 0), isFalse);
          expect(
            chipHasBadge(find.text('BINU • MORNING'), 0),
            isTrue,
            reason: 'Binu is the only one on that package',
          );
          expect(
            chipHasBadge(find.text('ANU • MORNING'), 0),
            isFalse,
            reason: "Kala's other package is Anu alone",
          );
          expect(chipHasBadge(find.text('ASHA • MORNING'), 0), isTrue);
          expect(
            chipHasBadge(find.text('CANCELLED • BRIDAL'), 0),
            isTrue,
            reason: 'a cancelled work still shows who was on it',
          );
        },
      );

      testWidgets(
        'its tooltip names the associates; it is the icon alone on the tight month chip',
        (t) async {
          await open(t);
          expect(find.byTooltip('Associate: Asha'), findsNWidgets(3));
          expect(find.byTooltip('Associate: Binu'), findsOneWidget);
          expect(
            find.text('ASSOC.'),
            findsNothing,
            reason: 'no room for words on a month chip',
          );
          expect(find.byIcon(Icons.handshake_outlined), findsWidgets);
        },
      );

      testWidgets(
        'with nobody registered as an associate there is no badge at all',
        (t) async {
          await open(
            t,
            staff: [
              _e('a1', 'Anu'),
              _e('x1', 'Asha', role: 'assistant'),
              _e('x2', 'Binu', role: 'assistant'),
            ],
          );
          expect(badge, findsNothing);
        },
      );

      testWidgets(
        'the badge follows the staff filter: one associate, only their works',
        (t) async {
          await open(t);
          await pick(t, find.byKey(const Key('cal_staff_x2')));
          expect(badge, findsOneWidget);
          expect(find.byTooltip('Associate: Binu'), findsOneWidget);
        },
      );

      testWidgets(
        'day view: the chip says ASSOC. in words, with the associate in the tooltip',
        (t) async {
          await open(t, focus: DateTime(2026, 11, 18));
          await t.tap(find.text('Day'));
          await t.pumpAndSettle();
          expect(
            find.text('ASSOC.'),
            findsOneWidget,
            reason: "Meera's work on the 18th; the 17th and 19th have none",
          );
          expect(find.byTooltip('Associate: Asha'), findsOneWidget);
        },
      );

      testWidgets('day view: no badge on a day whose works have no associate', (
        t,
      ) async {
        await open(t, focus: DateTime(2026, 11, 20));
        await t.tap(find.text('Day'));
        await t.pumpAndSettle();
        expect(
          find.text('Divya'),
          findsNothing,
          reason: 'the chip is named after the lead',
        );
        expect(find.text('Anu'), findsWidgets);
        expect(badge, findsNothing);
      });

      testWidgets(
        'week view: the pills carry the same icon badge as the month view',
        (t) async {
          await open(t, focus: DateTime(2026, 11, 18));
          await t.tap(find.text('Week'));
          await t.pumpAndSettle();
          // Mon 16 – Sun 22: Meera (the 18th) and Kala's Binu package (the 22nd) have an associate; Divya (the 20th) does not.
          expect(badge, findsNWidgets(2));
          expect(
            [
              chipHasBadge(find.text('ANU • BRIDAL'), 0),
              chipHasBadge(find.text('ANU • BRIDAL'), 1),
            ],
            [true, false],
          );
        },
      );

      // On a phone, Day view uses the same chip as the desktop Day view; Week view lists a card per work.
      Future<void> phone(WidgetTester t, String mode) async {
        viewSize = const Size(390, 900);
        addTearDown(() => viewSize = const Size(1400, 1100));
        // The test font (Ahem) is about twice as wide as a real one, so the page header overflows on a phone-width screen; that is not what is under test.
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (!d.exception.toString().contains('overflowed')) previous?.call(d);
        };
        addTearDown(() => FlutterError.onError = previous);
        await open(t, focus: DateTime(2026, 11, 18));
        await t.tap(find.text(mode));
        await t.pumpAndSettle();
      }

      testWidgets('phone, Day view: the chip says ASSOC.', (t) async {
        await phone(t, 'Day');
        expect(
          find.text('ASSOC.'),
          findsOneWidget,
          reason: "Meera's work on the 18th",
        );
        expect(find.byTooltip('Associate: Asha'), findsOneWidget);
      });

      testWidgets(
        'phone, Week view: the work card shows the full ASSOCIATE badge next to the artist',
        (t) async {
          await phone(t, 'Week');
          expect(
            find.text('ASSOCIATE'),
            findsOneWidget,
            reason: "Meera's work on the 18th",
          );
          expect(find.byTooltip('Associate: Asha'), findsOneWidget);
        },
      );

      testWidgets(
        'the work popup marks the associate on the team list, and nobody else',
        (t) async {
          await open(t, focus: DateTime(2026, 11, 18));
          await t.tap(find.text('Day'));
          await t.pumpAndSettle();
          await t.tap(find.text('Anu').first);
          await t.pumpAndSettle();
          expect(
            find.text('ASSOCIATE'),
            findsOneWidget,
            reason: 'Asha only — Anu is the lead',
          );
        },
      );
    });
  });
}
