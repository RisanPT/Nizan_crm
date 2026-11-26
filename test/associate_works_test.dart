import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/associates/data/associate_works.dart';
import 'package:nizan_crm/features/associates/presentation/screens/associate_works_screen.dart';
import 'package:nizan_crm/features/associates/services/associate_works_service.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/add_associate_dialog.dart';
import 'package:nizan_crm/services/employee_service.dart';

// The Associate Works report (which works each outside associate artist did, and the fee Accounts recorded) and the quick-add of an associate
// while assigning a work. The server does the joining; these check the app reads it faithfully, asks for the right cuts, shows every number
// and caveat plainly, hides money from those who may not see it, and fits a phone.

Map<String, dynamic> _row(String booking, String associate, {String name = 'Asha', String client = 'Anjali', String number = '2611001', double? fee = 2000, double? paid = 1500, double? owed = 500, String? payout = 'owed', int days = 2, String role = 'Hair', String roleType = 'assistant', String firstDay = '2026-11-10', List<String> services = const ['Bridal'], String place = 'Kozhikode, Calicut'}) => {
      'associateId': associate, 'associateName': name, 'phone': '9000000001', 'bookingId': booking, 'bookingNumber': number, 'customerName': client, 'services': services, 'role': role, 'roleType': roleType,
      'firstDay': firstDay, 'days': days, 'place': place, 'status': 'confirmed', 'fee': fee, 'paid': paid, 'owed': owed, 'payout': payout,
    };

Map<String, dynamic> _payload({bool fees = true, List<Map<String, dynamic>>? items, int registered = 2, Map<String, dynamic>? elsewhere, int page = 1, int totalPages = 1, int? totalItems, Map<String, dynamic>? summary, List<Map<String, dynamic>>? associates}) {
  final rows = items ??
      [
        _row('b1', 'e1'),
        _row('b2', 'e2', name: 'Binu', client: 'Meera K', number: '2611002', fee: 700, paid: 0, owed: 700, days: 1, role: '', roleType: 'lead', services: ['Wedding', 'Reception'], firstDay: '2026-11-20', place: 'Kochi'),
        _row('b3', 'e1', client: 'No fee bride', number: '2611003', fee: 0, paid: 0, owed: 0, payout: 'none', days: 1, firstDay: '2026-11-22'),
      ];
  final money = fees;
  return {
    'from': '2026-11-01', 'to': '2026-11-30', 'canSeeFees': fees,
    'summary': summary ?? {'associates': 2, 'works': 3, 'days': 4, 'fee': money ? 2700 : null, 'paid': money ? 1500 : null, 'owed': money ? 1200 : null, 'noFee': money ? 1 : null},
    'associates': associates ??
        [
          {'id': 'e1', 'name': 'Asha', 'phone': '9000000001', 'works': 2, 'days': 3, 'fee': money ? 2000 : null, 'paid': money ? 1500 : null, 'owed': money ? 500 : null, 'noFee': money ? 1 : null, 'lastDay': '2026-11-22'},
          {'id': 'e2', 'name': 'Binu', 'phone': '9000000002', 'works': 1, 'days': 1, 'fee': money ? 700 : null, 'paid': money ? 0 : null, 'owed': money ? 700 : null, 'noFee': money ? 0 : null, 'lastDay': '2026-11-20'},
        ],
    'items': money ? rows : [for (final r in rows) {...r, 'fee': null, 'paid': null, 'owed': null, 'payout': null}],
    'page': page, 'limit': 20, 'totalItems': totalItems ?? rows.length, 'totalPages': totalPages, 'truncated': false,
    'elsewhere': money ? (elsewhere ?? {'count': 0, 'amount': 0}) : null,
    'registered': registered,
  };
}

class _Fake extends AssociateWorksService {
  _Fake([Map<String, dynamic>? payload]) : _p = payload ?? _payload(), super(Dio());
  Map<String, dynamic> _p;
  bool fails = false;
  final queries = <AssociateWorksQuery>[];
  final exports = <AssociateWorksQuery>[];

  set payload(Map<String, dynamic> v) => _p = v;

  @override
  Future<AssociateWorksPage> page(AssociateWorksQuery q) async {
    queries.add(q);
    if (fails) throw AppException(DioException(requestOptions: RequestOptions(path: '/associate-works'), type: DioExceptionType.connectionError), action: 'load the associate works'); // what the real service throws
    return AssociateWorksPage.fromJson(_p);
  }

  @override
  Future<AssociateWorksPage> export(AssociateWorksQuery q) async {
    exports.add(q);
    return AssociateWorksPage.fromJson(_p);
  }
}

typedef _Saved = ({String name, List<List<Object?>> rows});

Future<({_Fake f, List<_Saved> saved})> _pump(WidgetTester t, {_Fake? fake, Size size = const Size(1280, 3200)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final f = fake ?? _Fake();
  final saved = <_Saved>[];
  await t.pumpWidget(ProviderScope(
    overrides: <Override>[associateWorksServiceProvider.overrideWithValue(f), associateCsvSaverProvider.overrideWithValue((n, r) async => saved.add((name: n, rows: r)))],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: AssociateWorksScreen())),
  ));
  await t.pumpAndSettle();
  return (f: f, saved: saved);
}

Finder _k(String key) => find.byKey(Key(key));
String _txt(WidgetTester t, Finder f) => t.widgetList<Text>(find.descendant(of: f, matching: find.byType(Text))).map((e) => e.data ?? '').join(' | ');

void main() {
  group('how the report reads', () {
    test('a full answer: works, the money split, the per-associate lines, the money elsewhere', () {
      final p = AssociateWorksPage.fromJson(_payload(elsewhere: {'count': 1, 'amount': 300}));
      expect(p.canSeeFees, isTrue);
      expect(p.summary.works, 3);
      expect(p.summary.fee, 2700);
      expect(p.summary.noFee, 1);
      expect(p.associates.first.name, 'Asha');
      expect(p.associates.first.lastDay, '2026-11-22');
      final w = p.items.first;
      expect([w.associateName, w.days, w.role, w.payout, w.fee, w.paid, w.owed], ['Asha', 2, 'Hair', 'owed', 2000, 1500, 500]);
      expect(p.items[1].isLead, isTrue);
      expect(p.items[1].services, ['Wedding', 'Reception']);
      expect(p.elsewhere!.amount, 300);
      expect(payoutLabel('paid'), 'Paid');
      expect(payoutLabel('owed'), 'Still to pay');
      expect(payoutLabel('none'), 'No fee yet');
      expect(payoutLabel(null), '');
    });

    test('a viewer who may not see money gets works only: every figure is null, never zero', () {
      final p = AssociateWorksPage.fromJson(_payload(fees: false));
      expect(p.canSeeFees, isFalse);
      expect(p.items.every((w) => w.fee == null && w.paid == null && w.owed == null && w.payout == null), isTrue);
      expect([p.summary.fee, p.summary.paid, p.summary.owed, p.summary.noFee], [null, null, null, null]);
      expect(p.elsewhere, isNull);
    });

    test('an empty answer is an empty report, not a crash', () {
      final p = AssociateWorksPage.fromJson(const {});
      expect(p.items, isEmpty);
      expect(p.page, 1);
      expect(p.totalPages, 1);
      expect(p.canSeeFees, isFalse);
      expect(p.summary.works, 0);
      expect(AssociateWork.fromJson(const {}).roleType, 'assistant');
    });

    test('the request: period, one associate, one payout state, search, page — and the export asks for everything', () {
      const q = AssociateWorksQuery(from: '2026-11-01', to: '2026-11-30');
      expect(q.toParams(), {'from': '2026-11-01', 'to': '2026-11-30', 'page': 1, 'limit': 20});
      final cut = q.copyWith(associateId: 'e1', payout: 'owed', search: '  anjali ', page: 3);
      expect(cut.toParams(), {'from': '2026-11-01', 'to': '2026-11-30', 'associateId': 'e1', 'payout': 'owed', 'search': 'anjali', 'page': 3, 'limit': 20});
      expect(cut.toParams(export: true), {'from': '2026-11-01', 'to': '2026-11-30', 'associateId': 'e1', 'payout': 'owed', 'search': 'anjali', 'export': '1'});
      expect(cut.refiltered(payout: 'paid').page, 1, reason: 'a new filter goes back to page 1');
      expect(q == const AssociateWorksQuery(from: '2026-11-01', to: '2026-11-30'), isTrue);
      expect(q == q.copyWith(page: 2), isFalse);
    });

    test('the CSV: the period, then a row per work; the money columns only for those who may see them; formulas are written as text', () {
      final withFees = associateWorksCsvRows(AssociateWorksPage.fromJson(_payload(items: [_row('b1', 'e1', client: '=HYPERLINK("x")')])));
      expect(withFees.first, ['Associate Works']);
      expect(withFees[1], ['From', '2026-11-01', 'To', '2026-11-30']);
      final head = withFees.firstWhere((r) => r.isNotEmpty && r.first == 'Associate');
      expect(head.sublist(head.length - 4), ['Fee (₹)', 'Paid (₹)', 'Still to pay (₹)', 'Fee state']);
      final row = withFees.last;
      expect(row[3], "'=HYPERLINK(\"x\")");
      expect(row.sublist(row.length - 4), [2000.0, 1500.0, 500.0, 'Still to pay']);
      final noMoney = associateWorksCsvRows(AssociateWorksPage.fromJson(_payload(fees: false)));
      final head2 = noMoney.firstWhere((r) => r.isNotEmpty && r.first == 'Associate');
      expect(head2.contains('Fee (₹)'), isFalse);
      expect(noMoney.last.length, head2.length);
      expect(associateCsvFileName(AssociateWorksPage.fromJson(_payload())), 'associate-works-2026-11-01-to-2026-11-30.csv');
      final lead = associateWorksCsvRows(AssociateWorksPage.fromJson(_payload(items: [_row('b9', 'e2', role: '', roleType: 'lead', services: ['A', 'B'])]))).last;
      expect([lead[5], lead[4]], ['Lead', 'A + B']);
    });

    test('who gets the menu entry: Operations, the artist head, Accounts, the owners; not Sales or an artist', () {
      bool sees(Access a) => a.canSeeAssociateWorks;
      expect(sees(const Access(AppRole.admin, {})), isTrue);
      expect(sees(const Access(AppRole.manager, {})), isTrue);
      expect(sees(const Access(AppRole.crm, {'bookings'})), isTrue);
      expect(sees(const Access(AppRole.artistHead, {'bookings'})), isTrue);
      expect(sees(const Access(AppRole.accounts, {'bookings', 'payables'})), isTrue);
      expect(sees(const Access(AppRole.ceo, {})), isTrue);
      expect(sees(const Access(AppRole.sales, {'bookings', 'sales'})), isFalse);
      expect(sees(const Access(AppRole.artist, {})), isFalse);
      expect(sees(const Access(AppRole.artist, {}, artistHead: true)), isTrue, reason: 'an artist flagged as also-head');
    });
  });

  group('the screen', () {
    testWidgets('the totals say what the server counted: associates, works and days, fees recorded and paid, still to pay and no-fee works', (t) async {
      await _pump(t);
      expect(find.text('Associates working · 2 registered'), findsOneWidget);
      expect(find.text('Works · 4 days'), findsOneWidget);
      expect(find.text('Fees recorded · ₹1,500 paid'), findsOneWidget);
      expect(find.text('Still to pay · 1 work has no fee yet'), findsOneWidget);
      expect(find.text('₹2,700'), findsOneWidget);
      expect(find.text('₹1,200'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('each work: client, booking number, services and place, the associate with their role, the dates, and the fee state with the money', (t) async {
      await _pump(t);
      final r = _k('assocRow_b1_e1');
      final text = _txt(t, r);
      for (final part in ['Anjali', '#2611001', 'Bridal', 'Kozhikode, Calicut', 'Asha', 'HAIR', '2 days', '10 Nov', 'Tue', 'STILL TO PAY', '₹2,000', '₹1,500 paid · ₹500 to pay']) {
        expect(text, contains(part), reason: part);
      }
      final lead = _txt(t, _k('assocRow_b2_e2'));
      expect(lead, allOf(contains('LEAD'), contains('Wedding + Reception'), contains('₹700'), contains('₹0 paid · ₹700 to pay')));
      expect(lead, isNot(contains('days')), reason: 'one day is not "1 days"');
      final none = _txt(t, _k('assocRow_b3_e1'));
      expect(none, allOf(contains('NO FEE YET'), contains('Accounts has not recorded a fee for this work.')));
      expect(none, isNot(contains('₹')), reason: 'no fee is not ₹0');
    });

    testWidgets('a paid work reads Paid', (t) async {
      await _pump(t, fake: _Fake(_payload(items: [_row('b1', 'e1', fee: 1000, paid: 1000, owed: 0, payout: 'paid')])));
      final text = _txt(t, _k('assocRow_b1_e1'));
      expect(text, allOf(contains('PAID'), contains('₹1,000'), contains('₹1,000 paid')));
      expect(text, isNot(contains('to pay')));
    });

    testWidgets('the associate chips: All, then each associate with their works and fees; tapping one asks for only their works, tapping again clears it', (t) async {
      final (:f, :saved) = await _pump(t);
      expect(f.queries.single.associateId, '');
      expect(_txt(t, _k('assocLine_all')), contains('3 works'));
      expect(_txt(t, _k('assocLine_e1')), allOf(contains('Asha'), contains('2 works'), contains('₹2,000')));
      expect(_txt(t, _k('assocLine_e2')), allOf(contains('1 work'), isNot(contains('1 works'))));
      await t.tap(_k('assocLine_e1'));
      await t.pumpAndSettle();
      expect(f.queries.last.associateId, 'e1');
      expect(f.queries.last.page, 1);
      await t.tap(_k('assocLine_e1'));
      await t.pumpAndSettle();
      expect(f.queries.last.associateId, '');
      expect(saved, isEmpty);
    });

    testWidgets('the payout chips ask for Paid / Still to pay / No fee yet, and All clears it', (t) async {
      final (:f, :saved) = await _pump(t);
      for (final (key, wire) in [('assocChip_paid', 'paid'), ('assocChip_owed', 'owed'), ('assocChip_none', 'none')]) {
        await t.tap(_k(key));
        await t.pumpAndSettle();
        expect(f.queries.last.payout, wire, reason: key);
      }
      await t.tap(_k('assocChip_all'));
      await t.pumpAndSettle();
      expect(f.queries.last.payout, '');
      expect(saved, isEmpty);
    });

    testWidgets('search waits for the typing to stop, then asks once', (t) async {
      final (:f, :saved) = await _pump(t);
      final before = f.queries.length;
      await t.enterText(_k('assocSearch'), 'anj');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(_k('assocSearch'), 'anjali');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(f.queries.length, before + 1);
      expect(f.queries.last.search, 'anjali');
      expect(saved, isEmpty);
    });

    testWidgets('paging: Next and Previous ask for the page after and before', (t) async {
      final fake = _Fake(_payload(page: 1, totalPages: 3, totalItems: 41));
      final (:f, :saved) = await _pump(t, fake: fake);
      expect(find.textContaining('41'), findsWidgets);
      await t.tap(find.text('Next').first);
      await t.pumpAndSettle();
      expect(f.queries.last.page, 2);
      expect(saved, isEmpty);
    });

    testWidgets('money paid to associates that is on no listed work is shown beside the totals', (t) async {
      await _pump(t, fake: _Fake(_payload(elsewhere: {'count': 2, 'amount': 800})));
      expect(_txt(t, _k('assocElsewhere')), allOf(contains('₹800'), contains('2 payouts'), contains('not on any of these works')));
      await _pump(t, fake: _Fake(_payload(elsewhere: {'count': 1, 'amount': 50.5})));
      expect(_txt(t, _k('assocElsewhere')), allOf(contains('₹50.50'), contains('1 payout')));
    });

    testWidgets('nothing elsewhere: no such note', (t) async {
      await _pump(t);
      expect(_k('assocElsewhere'), findsNothing);
    });

    testWidgets('Operations (no money): works only — no fee tiles, no payout chips, no amounts, a note about who sees fees', (t) async {
      await _pump(t, fake: _Fake(_payload(fees: false)));
      expect(find.text('Associates registered'), findsOneWidget);
      expect(find.text('Days per work'), findsOneWidget);
      expect(find.textContaining('Fees recorded'), findsNothing);
      expect(find.textContaining('Still to pay'), findsNothing);
      expect(_k('assocChip_all'), findsNothing);
      expect(_k('assocState'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(t.widget<Text>(_k('assocNote')).data, contains('Fees are shown to Accounts and the owners'));
      expect(_k('assocElsewhere'), findsNothing);
      expect(_txt(t, _k('assocRow_b1_e1')), allOf(contains('Anjali'), contains('Asha')));
      expect(_txt(t, _k('assocLine_e1')), isNot(contains('₹')));
    });

    testWidgets('the note says nothing is guessed when money is shown', (t) async {
      await _pump(t);
      expect(t.widget<Text>(_k('assocNote')).data, allOf(contains('Artist Payouts'), contains('No fee yet'), contains('nothing is guessed')));
    });

    testWidgets('no associates registered: it says how to add one', (t) async {
      await _pump(t, fake: _Fake(_payload(items: [], registered: 0, associates: [], summary: {'associates': 0, 'works': 0, 'days': 0, 'fee': 0, 'paid': 0, 'owed': 0, 'noFee': 0})));
      expect(_txt(t, _k('assocEmpty')), allOf(contains('No associates yet'), contains('Add a new associate')));
      expect(_k('assocLine_all'), findsNothing);
    });

    testWidgets('associates exist but none worked in the period; and a filter that matches nothing', (t) async {
      final quiet = _payload(items: [], associates: [], summary: {'associates': 0, 'works': 0, 'days': 0, 'fee': 0, 'paid': 0, 'owed': 0, 'noFee': 0});
      await _pump(t, fake: _Fake(quiet));
      expect(find.text('No associate has a work in this period.'), findsOneWidget);
      final fake = _Fake(quiet);
      await _pump(t, fake: fake);
      await t.tap(_k('assocChip_owed'));
      await t.pumpAndSettle();
      expect(find.text('No work matches these filters.'), findsOneWidget);
    });

    testWidgets('Export downloads every work that matches, as a CSV named for the period', (t) async {
      final (:f, :saved) = await _pump(t);
      await t.tap(_k('assocExport'));
      await t.pumpAndSettle();
      expect(f.exports.length, 1);
      expect(f.exports.single.toParams(export: true)['export'], '1');
      expect(saved.single.name, 'associate-works-2026-11-01-to-2026-11-30.csv');
      expect(saved.single.rows.length, greaterThan(5));
    });

    testWidgets('Export with nothing to export says so and downloads nothing', (t) async {
      final (:f, :saved) = await _pump(t, fake: _Fake(_payload(items: [])));
      await t.tap(_k('assocExport'));
      await t.pumpAndSettle();
      expect(find.text('Nothing to export for these filters.'), findsOneWidget);
      expect(saved, isEmpty);
      expect(f.exports, hasLength(1));
    });

    testWidgets('a failing source says so with Try again, and trying again loads the report; nothing raw is shown', (t) async {
      final fake = _Fake()..fails = true;
      await _pump(t, fake: fake);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      fake.fails = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(_k('assocRow_b1_e1'), findsOneWidget);
    });

    testWidgets('the whole page fits a 390-wide phone without overflow — with money, without money, and empty', (t) async {
      await _pump(t, size: const Size(390, 3600));
      expect(t.takeException(), isNull);
      await _pump(t, fake: _Fake(_payload(fees: false)), size: const Size(390, 3600));
      expect(t.takeException(), isNull);
      await _pump(t, fake: _Fake(_payload(items: [], registered: 0, associates: [], summary: {'associates': 0, 'works': 0, 'days': 0})), size: const Size(390, 2400));
      expect(t.takeException(), isNull);
    });
  });

  group('the service', () {
    test('asks /associate-works with the cuts, and for everything on export', () async {
      final seen = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'))..httpClientAdapter = _Capture(seen, body: '{"canSeeFees":true,"items":[]}');
      final s = AssociateWorksService(dio);
      await s.page(const AssociateWorksQuery(from: '2026-11-01', to: '2026-11-30', payout: 'owed'));
      expect(seen.single.method, 'GET');
      expect(seen.single.path, '/associate-works');
      expect(seen.single.queryParameters, {'from': '2026-11-01', 'to': '2026-11-30', 'payout': 'owed', 'page': 1, 'limit': 20});
      await s.export(const AssociateWorksQuery(from: '2026-11-01', to: '2026-11-30'));
      expect(seen.last.queryParameters, {'from': '2026-11-01', 'to': '2026-11-30', 'export': '1'});
    });

    test('a refusal becomes a plain-words error, not a DioException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'))..httpClientAdapter = _Capture([], status: 403, body: '{"message":"Not authorized"}');
      await expectLater(AssociateWorksService(dio).page(const AssociateWorksQuery(from: 'a', to: 'b')), throwsA(isNot(isA<DioException>())));
    });
  });

  group('adding an associate while assigning a work', () {
    test('an employee knows when they are an associate, and a copy keeps it', () {
      final e = Employee.fromJson(const {'_id': 'e1', 'name': 'Asha', 'type': 'outsource', 'isAssociate': true, 'artistRole': 'assistant'});
      expect(e.isAssociate, isTrue);
      expect(e.copyWith(name: 'Asha K').isAssociate, isTrue);
      expect(e.toJson()['isAssociate'], isTrue);
      final plain = Employee.fromJson(const {'_id': 'e2', 'name': 'Meera'});
      expect(plain.isAssociate, isFalse);
      expect(plain.toJson().containsKey('isAssociate'), isFalse, reason: 'an ordinary employee never sends the flag');
    });

    Future<({_FakeEmployees svc, List<Object?> popped})> openDialog(WidgetTester t, _FakeEmployees svc) async {
      final popped = <Object?>[];
      t.view.physicalSize = const Size(900, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[employeeServiceProvider.overrideWithValue(svc), employeesProvider.overrideWith((ref) async => const <Employee>[])],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: Builder(builder: (context) => Center(child: ElevatedButton(key: const Key('open'), onPressed: () async => popped.add(await showAddAssociateDialog(context)), child: const Text('open'))))),
        ),
      ));
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      return (svc: svc, popped: popped);
    }

    testWidgets('name is required; a short or empty name is refused in the form and nothing is sent', (t) async {
      final (:svc, :popped) = await openDialog(t, _FakeEmployees());
      await t.tap(_k('assoc_save'));
      await t.pumpAndSettle();
      expect(find.text('Give the associate’s name.'), findsOneWidget);
      expect(svc.calls, isEmpty);
      expect(popped, isEmpty);
    });

    testWidgets('Add & assign sends the name, phone and what they do, and hands the new associate back', (t) async {
      final (:svc, :popped) = await openDialog(t, _FakeEmployees());
      await t.enterText(_k('assoc_name'), '  Divya Nair ');
      await t.enterText(_k('assoc_phone'), '98765 43210');
      await t.enterText(_k('assoc_spec'), 'Saree draping');
      await t.tap(_k('assoc_save'));
      await t.pumpAndSettle();
      expect(svc.calls.single, {'name': 'Divya Nair', 'phone': '98765 43210', 'spec': 'Saree draping'});
      final r = popped.single as ({Employee employee, bool existing});
      expect([r.employee.name, r.employee.isAssociate, r.existing], ['Divya Nair', true, false]);
      expect(_k('assoc_name'), findsNothing, reason: 'the dialog closed');
    });

    testWidgets('a number that is already an associate comes back as the existing one', (t) async {
      final (:svc, :popped) = await openDialog(t, _FakeEmployees(existing: true));
      await t.enterText(_k('assoc_name'), 'Divya');
      await t.enterText(_k('assoc_phone'), '9876543210');
      await t.tap(_k('assoc_save'));
      await t.pumpAndSettle();
      expect((popped.single as ({Employee employee, bool existing})).existing, isTrue);
      expect(svc.calls, hasLength(1));
    });

    testWidgets('a refusal from the server is shown in the form in plain words, and the dialog stays open', (t) async {
      final (:svc, :popped) = await openDialog(t, _FakeEmployees(refuse: true));
      await t.enterText(_k('assoc_name'), 'Someone');
      await t.enterText(_k('assoc_phone'), '9000000004');
      await t.tap(_k('assoc_save'));
      await t.pumpAndSettle();
      expect(_k('assoc_error'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      expect(popped, isEmpty);
      expect(svc.calls, hasLength(1));
      // fixing it and trying again works
      svc.refuse = false;
      await t.tap(_k('assoc_save'));
      await t.pumpAndSettle();
      expect(popped, hasLength(1));
    });

    testWidgets('Cancel closes without sending anything', (t) async {
      final (:svc, :popped) = await openDialog(t, _FakeEmployees());
      await t.enterText(_k('assoc_name'), 'Divya');
      await t.tap(_k('assoc_cancel'));
      await t.pumpAndSettle();
      expect(svc.calls, isEmpty);
      expect(popped.single, isNull);
    });

    test('the service posts to /employees/associates, leaving out an empty phone', () async {
      final seen = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'))..httpClientAdapter = _Capture(seen, status: 201, body: '{"employee":{"_id":"e9","name":"Divya","isAssociate":true,"type":"outsource"},"existing":false}');
      final r = await EmployeeService(dio).addAssociate(name: ' Divya ', phone: '  ', specialization: 'Hair');
      expect(seen.single.method, 'POST');
      expect(seen.single.path, '/employees/associates');
      expect(seen.single.data, {'name': 'Divya', 'specialization': 'Hair'});
      expect([r.employee.id, r.employee.isAssociate, r.existing], ['e9', true, false]);
    });
  });
}

class _FakeEmployees extends EmployeeService {
  _FakeEmployees({this.existing = false, this.refuse = false}) : super(Dio());
  final bool existing;
  bool refuse;
  final calls = <Map<String, String>>[];

  @override
  Future<({Employee employee, bool existing})> addAssociate({required String name, String phone = '', String specialization = ''}) async {
    calls.add({'name': name, 'phone': phone, 'spec': specialization});
    if (refuse) throw Exception('This number already belongs to Meera, who is on the team — pick them from the staff list instead.');
    return (employee: Employee.fromJson({'_id': 'e9', 'name': name, 'phone': phone, 'type': 'outsource', 'isAssociate': true, 'artistRole': 'assistant'}), existing: existing);
  }
}

class _Capture implements HttpClientAdapter {
  _Capture(this.seen, {this.status = 200, this.body = '{}'});
  final List<RequestOptions> seen;
  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString(body, status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}
