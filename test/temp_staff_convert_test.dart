import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart'
    show effectiveAccessProvider;
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/associates/data/associate_works.dart';
import 'package:nizan_crm/features/associates/data/temp_staff.dart';
import 'package:nizan_crm/features/associates/presentation/screens/associate_works_screen.dart';
import 'package:nizan_crm/features/associates/presentation/screens/temp_staff_convert_screen.dart';
import 'package:nizan_crm/features/associates/services/associate_works_service.dart';

// "Convert old temporary staff": the names typed into the booking's free-text box, reviewed row by row and made into associates. The server
// reads the texts and applies the answers; these check the app asks the right thing, never lets an unanswered row through, says why, and shows
// what happened.

Map<String, dynamic> _row(
  String key,
  String name, {
  int count = 1,
  List<List<Object>>? variants,
  String role = '',
  String phone = '',
  List<String> similar = const [],
  Map<String, dynamic>? suggestion,
  String text = '',
}) => {
  'key': key,
  'name': name,
  'variants': [
    for (final v
        in variants ??
            [
              [name.toLowerCase(), count],
            ])
      {'name': v[0], 'count': v[1]},
  ],
  'roleHint': role,
  'phone': phone,
  'count': count,
  'samples': [
    {
      'bookingId': 'b-$key',
      'bookingNumber': 'BK-$key',
      'customerName': 'Bride of $name',
      'day': '2026-10-12',
      'text': text.isEmpty ? name.toLowerCase() : text,
    },
  ],
  'similar': similar,
  'suggestion': suggestion,
};

Map<String, dynamic> _scanJson({
  List<Map<String, dynamic>>? rows,
  int pending = 7,
}) => {
  'pendingBookings': pending,
  'rows':
      rows ??
      [
        _row(
          'thesliya',
          'Thesliya',
          count: 3,
          variants: [
            ['thesliya', 2],
            ['thesliyaa', 1],
          ],
          similar: ['thasliya'],
        ),
        _row('reem', 'Reem', count: 2),
        _row(
          'thasliya',
          'Thasliya',
          similar: ['thesliya'],
          suggestion: {'employeeId': 'e9', 'name': 'Thasliya', 'exact': false},
        ),
        _row(
          'asha',
          'Asha',
          suggestion: {'employeeId': 'e1', 'name': 'Asha', 'exact': true},
        ),
        _row('feeniyamaam', 'Feeniya Maam'),
        _row(
          'ajila',
          'Ajila',
          role: 'Saree draping',
          phone: '9000000099',
          text: 'ajila saree drapist',
        ),
      ],
  'associates': [
    {'id': 'e1', 'name': 'Asha', 'phone': '9000000001', 'status': 'active'},
    {'id': 'e9', 'name': 'Thasliya', 'phone': '', 'status': 'active'},
  ],
};

class _Fake extends AssociateWorksService {
  _Fake([Map<String, dynamic>? scan])
    : _data = scan ?? _scanJson(),
      super(Dio());
  Map<String, dynamic> _data;
  Map<String, dynamic>? afterConvert;
  Map<String, dynamic> result = {
    'created': 3,
    'linked': 1,
    'reused': 0,
    'skipped': 1,
    'bookingsUpdated': 6,
    'bookingsReviewed': 7,
    'assignmentsAdded': 8,
    'errors': <Map<String, dynamic>>[],
  };
  bool scanFails = false;
  final sent = <List<Map<String, dynamic>>>[];
  int scans = 0;

  @override
  Future<TempStaffScan> tempStaff() async {
    scans += 1;
    if (scanFails) {
      throw AppException(
        DioException(
          requestOptions: RequestOptions(path: '/associate-works/temp-staff'),
          type: DioExceptionType.connectionError,
        ),
        action: 'load the old temporary staff',
      );
    }
    return TempStaffScan.fromJson(_data);
  }

  @override
  Future<TempStaffResult> convertTempStaff(
    List<Map<String, dynamic>> rows,
  ) async {
    sent.add(rows);
    if (afterConvert != null) _data = afterConvert!;
    return TempStaffResult.fromJson(result);
  }

  @override
  Future<AssociateWorksPage> page(AssociateWorksQuery q) async =>
      AssociateWorksPage.fromJson({
        'from': '2026-11-01',
        'to': '2026-11-30',
        'canSeeFees': false,
        'summary': {'associates': 0, 'works': 0, 'days': 0},
        'associates': <Map<String, dynamic>>[],
        'items': <Map<String, dynamic>>[],
        'page': 1,
        'limit': 20,
        'totalItems': 0,
        'totalPages': 1,
        'truncated': false,
        'elsewhere': null,
        'registered': 0,
      });
}

const _crm = Access(AppRole.crm, {'bookings'});
const _sales = Access(AppRole.sales, {'bookings'});

Future<_Fake> _pump(
  WidgetTester t, {
  _Fake? fake,
  Access access = _crm,
  Size size = const Size(1280, 3600),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final f = fake ?? _Fake();
  await t.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        associateWorksServiceProvider.overrideWithValue(f),
        effectiveAccessProvider.overrideWithValue(access),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: TempStaffConvertScreen()),
      ),
    ),
  );
  await t.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));

/// Pick [label] in the "This is" dropdown of row [key].
Future<void> _choose(WidgetTester t, String key, String label) async {
  await t.tap(_k('tsAction_$key'));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

TempStaffRow _r(
  String key, {
  List<String> similar = const [],
  Map<String, dynamic>? suggestion,
  String phone = '',
  String role = '',
}) => TempStaffRow.fromJson(
  _row(
    key,
    key[0].toUpperCase() + key.substring(1),
    similar: similar,
    suggestion: suggestion,
    phone: phone,
    role: role,
  ),
);

void main() {
  group('a row, as the person has answered it so far', () {
    test(
      'it starts as a new associate; a name already registered (same spelling) starts linked; a lookalike is only a suggestion',
      () {
        final fresh = TempStaffDraft.initial(
          _r('reem', phone: '9000000050', role: 'Hair'),
        );
        expect(
          [fresh.action, fresh.name, fresh.phone, fresh.role, fresh.employeeId],
          [TempStaffAction.create, 'Reem', '9000000050', 'Hair', null],
        );
        final same = TempStaffDraft.initial(
          _r(
            'asha',
            suggestion: {'employeeId': 'e1', 'name': 'Asha', 'exact': true},
          ),
        );
        expect([same.action, same.employeeId], [TempStaffAction.link, 'e1']);
        final near = TempStaffDraft.initial(
          _r(
            'thasliya',
            suggestion: {
              'employeeId': 'e9',
              'name': 'Thesliya',
              'exact': false,
            },
          ),
        );
        expect(
          [near.action, near.employeeId],
          [TempStaffAction.create, null],
          reason: 'never decided for the person',
        );
      },
    );

    test(
      'what is sent for each answer: only what that answer needs; "later" sends nothing',
      () {
        final d = TempStaffDraft.initial(_r('reem'));
        d.name = '  Reem K ';
        d.phone = ' 90000 00050 ';
        d.role = ' Hair ';
        expect(d.toJson(), {
          'key': 'reem',
          'action': 'create',
          'name': 'Reem K',
          'phone': '90000 00050',
          'role': 'Hair',
        });
        d.phone = '';
        d.role = '';
        expect(d.toJson(), {
          'key': 'reem',
          'action': 'create',
          'name': 'Reem K',
        });
        d.action = TempStaffAction.link;
        d.employeeId = 'e1';
        expect(d.toJson(), {
          'key': 'reem',
          'action': 'link',
          'employeeId': 'e1',
        });
        d.action = TempStaffAction.merge;
        d.into = 'thesliya';
        expect(d.toJson(), {
          'key': 'reem',
          'action': 'merge',
          'into': 'thesliya',
        });
        d.action = TempStaffAction.skip;
        expect(d.toJson(), {'key': 'reem', 'action': 'skip'});
        d.action = TempStaffAction.later;
        expect(d.toJson(), isNull);
      },
    );

    test('what is wrong with a row, in plain words', () {
      final a = TempStaffDraft.initial(_r('reem'));
      final b = TempStaffDraft.initial(_r('thesliya'));
      final all = {'reem': a, 'thesliya': b};
      expect(a.problem(all), isNull);
      a.name = ' R ';
      expect(a.problem(all), contains('name'));
      a.name = 'Reem';
      a.phone = '12345';
      expect(a.problem(all), contains('phone number'));
      a.phone = '+91 90000-00050';
      expect(a.problem(all), isNull, reason: 'formatting is fine');
      a.action = TempStaffAction.link;
      expect(a.problem(all), contains('registered associate'));
      a.employeeId = 'e1';
      expect(a.problem(all), isNull);
      a.action = TempStaffAction.merge;
      expect(a.problem(all), contains('same as'), reason: 'no target chosen');
      a.into = 'reem';
      expect(a.problem(all), contains('same as'), reason: 'not itself');
      a.into = 'nobody';
      expect(a.problem(all), contains('same as'));
      a.into = 'thesliya';
      expect(a.problem(all), isNull);
      b.action = TempStaffAction.skip;
      expect(
        a.problem(all),
        contains('not being added'),
        reason: 'cannot be the same person as one that is ignored',
      );
      b.action = TempStaffAction.merge;
      expect(a.problem(all), contains('not being added'), reason: 'no chains');
      b.action = TempStaffAction.link;
      b.employeeId = 'e1';
      expect(a.problem(all), isNull);
      a.action = TempStaffAction.skip;
      expect(a.problem(all), isNull);
      a.action = TempStaffAction.later;
      expect(a.problem(all), isNull);
    });
  });

  group('the review as a whole', () {
    TempStaffPlan plan() => TempStaffPlan({
      for (final r in TempStaffScan.fromJson(_scanJson()).rows)
        r.key: TempStaffDraft.initial(r),
    });

    test(
      'every row not left for later is sent; counts say what it will do',
      () {
        final p = plan();
        expect(
          [
            p.count(TempStaffAction.create),
            p.count(TempStaffAction.link),
            p.adding,
          ],
          [5, 1, 6],
        );
        expect(p.request, hasLength(6));
        expect(p.ready, isTrue);
        p.drafts['reem']!.action = TempStaffAction.later;
        p.drafts['feeniyamaam']!.action = TempStaffAction.skip;
        expect(p.request.map((j) => j['key']), isNot(contains('reem')));
        expect(
          p.request.map((j) => j['key']),
          contains('feeniyamaam'),
          reason: 'ignored is an answer too',
        );
        expect(p.count(TempStaffAction.later), 1);
      },
    );

    test('not ready with nothing to send, or with a row that is wrong', () {
      final p = plan();
      for (final d in p.drafts.values) {
        d.action = TempStaffAction.later;
      }
      expect([p.request, p.ready], [isEmpty, isFalse]);
      p.drafts['reem']!.action = TempStaffAction.create;
      p.drafts['reem']!.name = '';
      expect(p.ready, isFalse);
      expect(p.problems.keys, ['reem']);
    });
  });

  group('how the answers read', () {
    test(
      'a scan: rows with their counts, variants, samples, lookalikes and suggestion; the registered associates',
      () {
        final s = TempStaffScan.fromJson(_scanJson());
        expect(
          [s.pendingBookings, s.rows.length, s.associates.map((a) => a.name)],
          [
            7,
            6,
            ['Asha', 'Thasliya'],
          ],
        );
        final t = s.rows.first;
        expect(
          [
            t.key,
            t.count,
            t.variants.map((v) => '${v.name}×${v.count}'),
            t.similar,
            t.samples.first.bookingNumber,
          ],
          [
            'thesliya',
            3,
            ['thesliya×2', 'thesliyaa×1'],
            ['thasliya'],
            'BK-thesliya',
          ],
        );
        expect(s.rows[3].suggestion!.exact, isTrue);
        expect(s.rows[2].suggestion!.exact, isFalse);
        expect(s.rows[1].suggestion, isNull);
        expect(TempStaffScan.fromJson({}).rows, isEmpty);
      },
    );

    test('a result says what happened in one plain sentence', () {
      expect(
        TempStaffResult.fromJson(_Fake().result).summary,
        '3 new associates · 1 already registered · added to 6 bookings · 1 ignored.',
      );
      expect(const TempStaffResult().summary, 'Nothing was changed.');
      expect(
        const TempStaffResult(created: 1, bookingsUpdated: 1).summary,
        '1 new associate · added to 1 booking.',
      );
      final r = TempStaffResult.fromJson({
        'errors': [
          {'key': 'reem', 'message': 'No booking has this name any more'},
        ],
      });
      expect(r.errors, {'reem': 'No booking has this name any more'});
    });
  });

  group('the review screen', () {
    testWidgets(
      'one card per person with how many bookings, how it was typed and a role; starting answers; the summary',
      (t) async {
        await _pump(t);
        expect(_k('tsTitle'), findsOneWidget);
        expect(
          find.textContaining('7 bookings have names in the box — 6 people'),
          findsOneWidget,
        );
        for (final k in [
          'thesliya',
          'reem',
          'thasliya',
          'asha',
          'feeniyamaam',
          'ajila',
        ]) {
          expect(_k('tsRow_$k'), findsOneWidget, reason: k);
        }
        expect(find.text('3 bookings'), findsOneWidget);
        expect(
          find.textContaining('typed as “thesliya” ×2, “thesliyaa” ×1'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _k('tsRow_ajila'),
            matching: find.byWidgetPredicate(
              (w) => w is Text && w.data == 'Saree draping',
            ),
          ),
          findsOneWidget,
          reason: 'the role read from the text, as a pill on the card',
        );
        expect(
          find.descendant(
            of: _k('tsRow_asha'),
            matching: find.text('An associate already registered'),
          ),
          findsOneWidget,
          reason: 'already registered: linked to Asha',
        );
        expect(
          find.descendant(
            of: _k('tsRow_reem'),
            matching: find.text('A new associate'),
          ),
          findsOneWidget,
        );
        expect(
          tester(t, 'tsPhone_ajila'),
          '9000000099',
          reason: 'the phone typed in the text',
        );
        expect(tester(t, 'tsRole_ajila'), 'Saree draping');
        expect(tester(t, 'tsName_reem'), 'Reem');
        expect(
          find.text(
            '5 new · 1 registered · 0 same as another · 0 ignored · 0 for later',
          ),
          findsOneWidget,
        );
        expect(t.widget<FilledButton>(_k('tsConvert')).onPressed, isNotNull);
      },
    );

    testWidgets(
      'a lookalike spelling offers "same person?" — one tap joins it; the join is shown and counted',
      (t) async {
        await _pump(t);
        expect(_k('tsSimilar_thasliya_thesliya'), findsOneWidget);
        expect(_k('tsSimilar_thesliya_thasliya'), findsOneWidget);
        await t.tap(_k('tsSimilar_thasliya_thesliya'));
        await t.pumpAndSettle();
        expect(
          find.descendant(
            of: _k('tsRow_thasliya'),
            matching: find.text('The same person as another name here'),
          ),
          findsOneWidget,
        );
        expect(_k('tsInto_thasliya'), findsOneWidget);
        expect(
          find.descendant(
            of: _k('tsRow_thasliya'),
            matching: find.text('Thesliya (3)'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '4 new · 1 registered · 1 same as another · 0 ignored · 0 for later',
          ),
          findsOneWidget,
        );
        expect(
          _k('tsSimilar_thasliya_thesliya'),
          findsNothing,
          reason: 'already joined',
        );
      },
    );

    testWidgets(
      'a lookalike REGISTERED associate is a suggestion, and one tap links it',
      (t) async {
        await _pump(t);
        expect(
          find.textContaining('Looks like registered: Thasliya — link?'),
          findsOneWidget,
        );
        await t.tap(_k('tsSuggest_thasliya'));
        await t.pumpAndSettle();
        expect(
          find.descendant(
            of: _k('tsRow_thasliya'),
            matching: find.text('An associate already registered'),
          ),
          findsOneWidget,
        );
        expect(_k('tsSuggest_thasliya'), findsNothing);
        expect(
          find.text(
            '4 new · 2 registered · 0 same as another · 0 ignored · 0 for later',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '"Not an associate" ignores the name; "Decide later" leaves it — each says so',
      (t) async {
        await _pump(t);
        await _choose(t, 'feeniyamaam', 'Not an associate — ignore');
        expect(
          find.textContaining('Ignored: nothing is added'),
          findsOneWidget,
        );
        await _choose(t, 'reem', 'Decide later');
        expect(find.textContaining('Stays in this list'), findsOneWidget);
        expect(
          find.text(
            '3 new · 1 registered · 0 same as another · 1 ignored · 1 for later',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an unanswered row says why and holds back Convert, with the count in the footer',
      (t) async {
        await _pump(t);
        await t.enterText(_k('tsName_reem'), '');
        await t.pumpAndSettle();
        expect(find.byKey(const Key('tsProblem_reem')), findsOneWidget);
        expect(find.text('Give the associate’s name.'), findsOneWidget);
        expect(
          find.text('1 name needs an answer before converting.'),
          findsOneWidget,
        );
        expect(t.widget<FilledButton>(_k('tsConvert')).onPressed, isNull);
        await t.enterText(_k('tsName_reem'), 'Reem K');
        await t.pumpAndSettle();
        expect(find.byKey(const Key('tsProblem_reem')), findsNothing);
        expect(t.widget<FilledButton>(_k('tsConvert')).onPressed, isNotNull);
      },
    );

    testWidgets('a bad phone number is caught before anything is sent', (
      t,
    ) async {
      await _pump(t);
      await t.enterText(_k('tsPhone_reem'), '123');
      await t.pumpAndSettle();
      expect(
        find.text('The phone number does not look right.'),
        findsOneWidget,
      );
      expect(t.widget<FilledButton>(_k('tsConvert')).onPressed, isNull);
    });

    testWidgets(
      'Convert asks first, says what it will do, and Cancel sends nothing',
      (t) async {
        final f = await _pump(t);
        await t.tap(_k('tsConvert'));
        await t.pumpAndSettle();
        expect(find.text('Convert these names?'), findsOneWidget);
        expect(
          find.textContaining(
            '5 new associates · 1 already registered · 0 same as another name · 0 ignored',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('The text in the box is kept as it was'),
          findsOneWidget,
        );
        await t.tap(_k('tsCancel'));
        await t.pumpAndSettle();
        expect(f.sent, isEmpty);
      },
    );

    testWidgets(
      'Convert sends exactly the answers, then shows what happened and re-reads the list',
      (t) async {
        final f = _Fake()..afterConvert = _scanJson(rows: [], pending: 0);
        await _pump(t, fake: f);
        await t.tap(_k('tsSimilar_thasliya_thesliya'));
        await t.pumpAndSettle();
        await _choose(t, 'feeniyamaam', 'Not an associate — ignore');
        await _choose(t, 'reem', 'Decide later');
        await t.enterText(_k('tsName_thesliya'), 'Thasliya');
        await t.pumpAndSettle();
        final scansBefore = f.scans;
        await t.tap(_k('tsConvert'));
        await t.pumpAndSettle();
        await t.tap(_k('tsConfirm'));
        await t.pumpAndSettle();
        expect(f.sent, hasLength(1));
        expect(f.sent.single, [
          {'key': 'thesliya', 'action': 'create', 'name': 'Thasliya'},
          {'key': 'thasliya', 'action': 'merge', 'into': 'thesliya'},
          {'key': 'asha', 'action': 'link', 'employeeId': 'e1'},
          {'key': 'feeniyamaam', 'action': 'skip'},
          {
            'key': 'ajila',
            'action': 'create',
            'name': 'Ajila',
            'phone': '9000000099',
            'role': 'Saree draping',
          },
        ]);
        expect(
          find.text(
            '3 new associates · 1 already registered · added to 6 bookings · 1 ignored.',
          ),
          findsOneWidget,
        );
        expect(
          f.scans,
          greaterThan(scansBefore),
          reason: 'the list is read again',
        );
        expect(_k('tsEmpty'), findsOneWidget, reason: 'nothing is left');
      },
    );

    testWidgets(
      'a row the server could not convert stays, with its reason under it',
      (t) async {
        final f = _Fake()
          ..result = {
            'created': 1,
            'bookingsUpdated': 1,
            'errors': [
              {
                'key': 'reem',
                'message':
                    'This number already belongs to Ravi, who is on the team and not an associate.',
              },
            ],
          };
        await _pump(t, fake: f);
        await t.tap(_k('tsConvert'));
        await t.pumpAndSettle();
        await t.tap(_k('tsConfirm'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('tsError_reem')), findsOneWidget);
        expect(
          find.textContaining('This number already belongs to Ravi'),
          findsOneWidget,
        );
        expect(find.textContaining('1 could not be converted'), findsOneWidget);
        await t.enterText(_k('tsName_reem'), 'Reem K');
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('tsError_reem')),
          findsNothing,
          reason: 'edited, so the old note goes',
        );
      },
    );

    testWidgets('nothing waiting: a plain message and no footer', (t) async {
      await _pump(t, fake: _Fake(_scanJson(rows: [], pending: 0)));
      expect(_k('tsEmpty'), findsOneWidget);
      expect(_k('tsConvert'), findsNothing);
    });

    testWidgets('a failed load says so in plain words, with a retry', (
      t,
    ) async {
      final f = _Fake()..scanFails = true;
      await _pump(t, fake: f);
      expect(find.textContaining('Try again'), findsWidgets);
      expect(_k('tsConvert'), findsNothing);
    });

    testWidgets(
      'only Operations and managers: anyone else sees a plain note and nothing is asked of the server',
      (t) async {
        final f = await _pump(t, access: _sales);
        expect(_k('tsNotAllowed'), findsOneWidget);
        expect(f.scans, 0);
        expect(_k('tsRow_reem'), findsNothing);
      },
    );

    testWidgets('it fits a phone', (t) async {
      await _pump(t, size: const Size(390, 3600));
      expect(find.byType(ErrorWidget), findsNothing);
      expect(_k('tsConvert'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('the banner on Associate Works', () {
    Future<void> openWorks(
      WidgetTester t, {
      Access access = _crm,
      _Fake? fake,
      bool settle = true,
    }) async {
      t.view.physicalSize = const Size(1280, 3200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final router = GoRouter(
        initialLocation: '/associate-works',
        routes: [
          GoRoute(
            path: '/associate-works',
            builder: (_, _) => const Scaffold(body: AssociateWorksScreen()),
          ),
          GoRoute(
            path: '/associate-works/temp-staff',
            builder: (_, _) => const Scaffold(body: Text('CONVERT PAGE')),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            associateWorksServiceProvider.overrideWithValue(fake ?? _Fake()),
            effectiveAccessProvider.overrideWithValue(access),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      if (settle) await t.pumpAndSettle();
    }

    testWidgets(
      'Operations see how many bookings are waiting, and the button opens the conversion',
      (t) async {
        await openWorks(t);
        expect(
          find.textContaining(
            '7 bookings have names typed in the old “Temporary staff” box',
          ),
          findsOneWidget,
        );
        await t.tap(_k('tsOpen'));
        await t.pumpAndSettle();
        expect(find.text('CONVERT PAGE'), findsOneWidget);
      },
    );

    testWidgets('one booking reads in the singular', (t) async {
      await openWorks(t, fake: _Fake(_scanJson(pending: 1)));
      expect(find.textContaining('1 booking has names typed'), findsOneWidget);
    });

    testWidgets(
      'no banner for anyone who may not convert, when nothing is waiting, or when it cannot be read',
      (t) async {
        await openWorks(t, access: _sales);
        expect(_k('tsBanner'), findsNothing);
        await openWorks(t, fake: _Fake(_scanJson(rows: [], pending: 0)));
        expect(_k('tsBanner'), findsNothing);
        await openWorks(t, fake: _Fake()..scanFails = true);
        expect(_k('tsBanner'), findsNothing);
        expect(
          _k('assocTitle'),
          findsOneWidget,
          reason: 'the report itself is untouched',
        );
      },
    );
  });

  group('who may convert', () {
    test(
      'Operations (CRM), managers and admins — not sales, artists, accounts or the owners',
      () {
        bool may(Access a) => a.canConvertTempStaff;
        expect(may(const Access(AppRole.admin, {})), isTrue);
        expect(may(const Access(AppRole.manager, {})), isTrue);
        expect(may(const Access(AppRole.crm, {'bookings'})), isTrue);
        expect(may(const Access(AppRole.sales, {'bookings'})), isFalse);
        expect(may(const Access(AppRole.artist, {'bookings'})), isFalse);
        expect(may(const Access(AppRole.accounts, {'bookings'})), isFalse);
        expect(may(const Access(AppRole.ceo, {'bookings'})), isFalse);
        expect(may(const Access(AppRole.artistHead, {'bookings'})), isFalse);
      },
    );
  });
}

String tester(WidgetTester t, String key) =>
    t.widget<TextFormField>(_k(key)).controller?.text ??
    t.widget<TextFormField>(_k(key)).initialValue ??
    '';
