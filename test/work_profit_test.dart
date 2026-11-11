import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/work_profit_controller.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart'
    show FinanceQuery;
import 'package:nizan_crm/features/accounts/data/work_profit.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/work_profit_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/work_profit_card.dart';
import 'package:nizan_crm/features/accounts/services/work_profit_service.dart';

// WORK PROFIT: what each work earned and what it cost (Accounts). The server does the sums; these
// check the app reads them faithfully, asks for the right period / filter / page, and shows every
// number, flag and caveat plainly.

// ── fixtures ──

Map<String, dynamic> _work(
  String id, {
  String customer = 'Beena',
  String number = '',
  double gross = 0,
  double discount = 0,
  double taxable = 0,
  double gst = 0,
  double artist = 0,
  double fleet = 0,
  double freelance = 0,
  double pending = 0,
  double fleetShared = 0,
  Map<String, double> artistCats = const {},
  Map<String, double> fleetCats = const {},
  List<String> flags = const [],
  double? margin,
  double? profit,
  List<String> artists = const ['Anu'],
  String service = 'Bridal makeup',
  String place = 'Calicut',
  String start = '2026-10-05T04:30:00.000Z',
  double received = 0,
}) {
  final costs = artist + fleet + freelance;
  return {
    'bookingId': id,
    'bookingNumber': number.isEmpty ? 'BK-$id' : number,
    'customerName': customer,
    'service': service,
    'status': 'confirmed',
    'serviceStart': start,
    'place': place,
    'artists': artists,
    'revenue': {
      'gross': gross,
      'discount': discount,
      'net': gross - discount,
      'taxable': taxable,
      'gst': gst,
      'received': received,
      'outstanding': (gross - discount - received).clamp(0, double.infinity),
    },
    'costs': {
      'artist': {'total': artist, 'pending': pending, 'byCategory': artistCats},
      'fleet': {
        'total': fleet,
        'pending': 0,
        'shared': fleetShared,
        'byCategory': fleetCats,
      },
      'freelance': {
        'total': freelance,
        'pending': 0,
        'byCategory': freelance > 0
            ? {'payout': freelance}
            : <String, double>{},
      },
      'total': costs,
      'pending': pending,
    },
    'profit': profit ?? taxable - costs,
    'marginPct': margin,
    'flags': flags,
  };
}

/// A loss, a thin one, a good one, and one with no costs recorded.
List<Map<String, dynamic>> _works() => [
  _work(
    '1',
    customer: 'Loss Lena',
    gross: 2100,
    taxable: 2000,
    gst: 100,
    artist: 1500,
    fleet: 800,
    pending: 100,
    margin: -15,
    flags: ['loss', 'pending_costs'],
  ),
  _work(
    '2',
    customer: 'Thin Thara',
    gross: 10500,
    discount: 500,
    taxable: 9523.81,
    gst: 476.19,
    artist: 8000,
    freelance: 0,
    margin: 16,
    flags: ['thin'],
  ),
  _work(
    '3',
    customer: 'Good Gita',
    gross: 21000,
    taxable: 20000,
    gst: 1000,
    artist: 1500,
    fleet: 500,
    margin: 90,
    artists: ['Anu', 'Fathima'],
  ),
  _work(
    '4',
    customer: 'Quiet Qasim',
    gross: 5250,
    taxable: 5000,
    gst: 250,
    margin: 100,
    flags: ['no_costs'],
  ),
];

Map<String, dynamic> _totals({
  double unArtist = 350,
  double unFleet = 659.99,
}) => {
  'revenue': {
    'net': 38850,
    'taxable': 36523.81,
    'gst': 1826.19,
    'received': 12000,
  },
  'costs': {
    'artist': 11000,
    'fleet': 1300,
    'freelance': 0,
    'total': 12300,
    'pending': 100,
  },
  'profit': 24223.81,
  'marginPct': 66.3,
  'unallocated': {
    'artist': unArtist,
    'fleet': unFleet,
    'total': unArtist + unFleet,
  },
  'profitAfterUnallocated': 24223.81 - unArtist - unFleet,
  'count': {'works': 4, 'loss': 1, 'thin': 1, 'noCosts': 1, 'pendingCosts': 1},
};

Map<String, dynamic> _pageJson({
  List<Map<String, dynamic>>? items,
  int page = 1,
  int totalPages = 1,
  int? totalItems,
  Map<String, dynamic>? totals,
  bool gstOn = true,
}) {
  final list = items ?? _works();
  return {
    'from': '2026-10-01',
    'to': '2026-10-31',
    'totals': totals ?? _totals(),
    'unallocated': const {},
    'gst': {'enabled': gstOn, 'rate': gstOn ? 5 : 0, 'inclusive': true},
    'thinMarginPct': 20,
    'items': list,
    'page': page,
    'limit': 20,
    'totalItems': totalItems ?? list.length,
    'totalPages': totalPages,
    'truncated': false,
  };
}

WorkProfit _one(Map<String, dynamic> j) => WorkProfit.fromJson(j);

// ── a stand-in for the server ──

class _Fake extends WorkProfitService {
  _Fake() : super(Dio());

  final queries = <WorkProfitQuery>[];
  final exports = <WorkProfitQuery>[];
  Object? failPage;
  Object? failExport;
  int pages = 1;
  List<Map<String, dynamic>> data = _works();
  Completer<void>? hold;

  @override
  Future<WorkProfitPage> getPage(WorkProfitQuery q) async {
    queries.add(q);
    if (hold != null) await hold!.future;
    if (failPage != null) throw failPage!;
    var rows = data;
    if (q.flag.isNotEmpty) {
      rows = [
        for (final w in rows)
          if ((w['flags'] as List).contains(q.flag)) w,
      ];
    }
    final s = q.search.trim().toLowerCase();
    if (s.isNotEmpty) {
      rows = [
        for (final w in rows)
          if ('${w['customerName']} ${w['bookingNumber']}'
              .toLowerCase()
              .contains(s))
            w,
      ];
    }
    final filtered = q.flag.isNotEmpty || s.isNotEmpty;
    return WorkProfitPage.fromJson(
      _pageJson(
        items: rows,
        page: q.page,
        totalPages: filtered ? 1 : pages,
        totalItems: filtered ? rows.length : rows.length * pages,
      ),
    );
  }

  @override
  Future<WorkProfitPage> export(WorkProfitQuery q) async {
    exports.add(q);
    if (failExport != null) throw failExport!;
    return WorkProfitPage.fromJson(_pageJson(items: data));
  }
}

class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  final Object body;
  final int status;
  _Capture(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void _size(WidgetTester t, {double w = 1400, double h = 4200}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// A server failure with a raw HTML body: the kind of thing that must never reach the screen as it is.
AppException _serverError(String action) {
  final ro = RequestOptions(path: '/work-profit');
  return AppException(
    DioException(
      requestOptions: ro,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: ro,
        statusCode: 500,
        data: '<html>boom-secret</html>',
      ),
    ),
    action: action,
  );
}

(String, String) get _thisMonth =>
    FinanceQuery.monthBounds(FinancePeriodBar.thisMonth());

void main() {
  // ───────────── the request ─────────────
  group('the request', () {
    test('equal queries are the same request', () {
      const a = WorkProfitQuery(from: '2026-10-01', to: '2026-10-31');
      const b = WorkProfitQuery(from: '2026-10-01', to: '2026-10-31');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(flag: 'loss'), isNot(a));
      expect(a.copyWith(page: 2), isNot(a));
      expect(a.copyWith(sort: 'profit_asc'), isNot(a));
    });

    test('changing a filter goes back to page 1; paging does not', () {
      const q = WorkProfitQuery(from: 'a', to: 'b', page: 3, flag: 'loss');
      expect(q.refiltered(search: 'x').page, 1);
      expect(q.refiltered(flag: 'thin').page, 1);
      expect(q.refiltered(sort: 'profit_asc').page, 1);
      expect(q.copyWith(page: 4).page, 4);
      expect(q.copyWith(page: 4).flag, 'loss');
    });

    test('a flag can be cleared, and left alone', () {
      const q = WorkProfitQuery(from: 'a', to: 'b', flag: 'loss');
      expect(q.refiltered(flag: '').flag, '');
      expect(q.refiltered(search: 'x').flag, 'loss');
    });

    test('params: only what is set; search trimmed; export has no paging', () {
      const q = WorkProfitQuery(from: '2026-10-01', to: '2026-10-31');
      expect(q.toParams(), {
        'from': '2026-10-01',
        'to': '2026-10-31',
        'sort': 'date_desc',
        'page': 1,
        'limit': 20,
      });
      final full = q.copyWith(search: '  beena ', flag: 'loss', page: 2);
      expect(full.toParams()['search'], 'beena');
      expect(full.toParams()['flag'], 'loss');
      expect(full.toParams()['page'], 2);
      final ex = full.toParams(export: true);
      expect(ex['export'], '1');
      expect(ex.containsKey('page'), isFalse);
      expect(ex.containsKey('limit'), isFalse);
      expect(ex['flag'], 'loss');
    });
  });

  // ───────────── the answer ─────────────
  group('the answer', () {
    test('a page reads every figure', () {
      final p = WorkProfitPage.fromJson(
        _pageJson(totalPages: 3, totalItems: 41),
      );
      expect(p.items.length, 4);
      expect((p.page, p.totalPages, p.totalItems), (1, 3, 41));
      expect(p.gstOn, isTrue);
      expect(p.gstRate, 5);
      expect(p.thinMarginPct, 20);
      final t = p.totals;
      expect(
        (t.works, t.loss, t.thin, t.noCosts, t.pendingCount),
        (4, 1, 1, 1, 1),
      );
      expect(t.taxable, 36523.81);
      expect(t.costs, 12300);
      expect(t.pendingCosts, 100);
      expect(t.profit, 24223.81);
      expect(t.marginPct, 66.3);
      expect((t.unallocatedArtist, t.unallocatedFleet), (350, 659.99));
      expect(t.unallocated, 1009.99);
      expect(t.profitAfterUnallocated, closeTo(23213.82, 0.001));
    });

    test('one work reads its revenue, costs, flags and artists', () {
      final w = _one(
        _work(
          '9',
          gross: 10500,
          discount: 500,
          taxable: 9523.81,
          gst: 476.19,
          artist: 300,
          fleet: 460.01,
          freelance: 2000,
          fleetShared: 360,
          artistCats: {'food': 300},
          fleetCats: {'fuel': 460.01},
          pending: 100,
          margin: 71,
          flags: ['pending_costs'],
          artists: ['Anu', 'Fathima'],
          received: 4000,
        ),
      );
      expect(w.bookingNumber, 'BK-9');
      expect(w.artists, ['Anu', 'Fathima']);
      expect(w.serviceStart, isNotNull);
      expect(
        (w.revenue.gross, w.revenue.discount, w.revenue.net),
        (10500, 500, 10000),
      );
      expect((w.revenue.taxable, w.revenue.gst), (9523.81, 476.19));
      expect((w.revenue.received, w.revenue.outstanding), (4000, 6000));
      expect(w.costs.artist.byCategory, {'food': 300});
      expect(w.costs.fleet.shared, 360);
      expect(w.costs.freelance.total, 2000);
      expect(w.costs.pending, 100);
      expect(w.hasPending, isTrue);
      expect((w.isLoss, w.isThin, w.noCosts), (false, false, false));
      expect(w.marginPct, 71);
    });

    test('flags read as flags; no margin stays null', () {
      final loss = _one(_work('1', flags: ['loss']));
      expect(loss.isLoss, isTrue);
      expect(loss.marginPct, isNull);
      expect(_one(_work('2', flags: ['thin'])).isThin, isTrue);
      expect(_one(_work('3', flags: ['no_costs'])).noCosts, isTrue);
    });

    test('GST off (or a 0% rate) is not GST on', () {
      expect(WorkProfitPage.fromJson(_pageJson(gstOn: false)).gstOn, isFalse);
      final j = _pageJson()
        ..['gst'] = {'enabled': true, 'rate': 0, 'inclusive': true};
      expect(WorkProfitPage.fromJson(j).gstOn, isFalse);
    });

    test('a thin answer never throws, and the threshold falls back to 20%', () {
      final p = WorkProfitPage.fromJson({});
      expect(p.items, isEmpty);
      expect((p.page, p.totalPages), (1, 1));
      expect(p.thinMarginPct, 20);
      expect(p.totals.works, 0);
      final w = WorkProfit.fromJson({
        'bookingId': 'x',
        'costs': {'artist': null},
      });
      expect(w.costs.artist.total, 0);
      expect(w.revenue.taxable, 0);
      expect(w.serviceStart, isNull);
    });
  });

  // ───────────── the service ─────────────
  group('service', () {
    WorkProfitService svc(_Capture c) =>
        WorkProfitService(Dio()..httpClientAdapter = c);
    const q = WorkProfitQuery(
      from: '2026-10-01',
      to: '2026-10-31',
      flag: 'loss',
    );

    test('a page: GET /work-profit with the query', () async {
      final cap = _Capture(_pageJson());
      final p = await svc(cap).getPage(q);
      expect((cap.last!.method, cap.last!.path), ('GET', '/work-profit'));
      expect(cap.last!.queryParameters['from'], '2026-10-01');
      expect(cap.last!.queryParameters['flag'], 'loss');
      expect(cap.last!.queryParameters['page'], 1);
      expect(cap.last!.queryParameters.containsKey('export'), isFalse);
      expect(p.items.length, 4);
    });

    test('an export asks for everything: export=1, no paging', () async {
      final cap = _Capture(_pageJson());
      await svc(cap).export(q);
      expect(cap.last!.queryParameters['export'], '1');
      expect(cap.last!.queryParameters.containsKey('page'), isFalse);
      expect(cap.last!.queryParameters['flag'], 'loss');
    });

    test('a refusal is a friendly AppException', () async {
      final cap = _Capture({'message': 'Not authorized'}, status: 403);
      await expectLater(svc(cap).getPage(q), throwsA(isA<AppException>()));
      await expectLater(svc(cap).export(q), throwsA(isA<AppException>()));
    });
  });

  // ───────────── one work's card ─────────────
  group('the card', () {
    Widget host(WorkProfit w, {double width = 420}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: WorkProfitCard(work: w),
            ),
          ),
        ),
      ),
    );

    final good = _one(
      _work(
        '9',
        customer: 'Good Gita',
        gross: 10500,
        discount: 500,
        taxable: 9523.81,
        gst: 476.19,
        artist: 300,
        fleet: 460.01,
        freelance: 2000,
        fleetShared: 360,
        pending: 100,
        artistCats: {'food': 200, 'travel': 100},
        fleetCats: {'fuel': 400.01, 'toll': 60},
        margin: 71,
        flags: ['pending_costs'],
        received: 4000,
      ),
    );

    testWidgets(
      'it shows who, when, the profit, the margin, and where the money went',
      (t) async {
        _size(t);
        await t.pumpWidget(host(good));
        expect(find.textContaining('Good Gita'), findsOneWidget);
        expect(find.textContaining('BK-9'), findsOneWidget);
        expect(find.textContaining('Bridal makeup'), findsOneWidget);
        expect(find.textContaining('Anu'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('marginChip_9')),
            matching: find.text('71%'),
          ),
          findsOneWidget,
        );
        expect(
          t.widget<Text>(find.byKey(const Key('profitValue_9'))).data,
          '₹6,763.80',
        );
        expect(
          t.widget<Text>(find.byKey(const Key('revenue_9'))).data,
          '₹9,523.81',
        );
        expect(t.widget<Text>(find.byKey(const Key('artist_9'))).data, '−₹300');
        expect(
          t.widget<Text>(find.byKey(const Key('fleet_9'))).data,
          '−₹460.01',
        );
        expect(
          t.widget<Text>(find.byKey(const Key('freelance_9'))).data,
          '−₹2,000',
        );
        expect(
          t.widget<Text>(find.byKey(const Key('costs_9'))).data,
          '₹2,760.01',
        );
        expect(find.byKey(const Key('splitBar_9')), findsOneWidget);
        expect(
          find.text('Booked ₹10,500  ·  discount ₹500  ·  GST ₹476.19'),
          findsOneWidget,
        );
      },
    );

    testWidgets('costs that are not verified yet are called out, in rupees', (
      t,
    ) async {
      _size(t);
      await t.pumpWidget(host(good));
      expect(find.byKey(const Key('flag_pending_costs_9')), findsOneWidget);
      expect(find.text('₹100 of the costs not verified yet'), findsOneWidget);
    });

    testWidgets('a loss says so, in red, with the minus sign', (t) async {
      _size(t);
      final w = _one(
        _work(
          '1',
          gross: 2100,
          taxable: 2000,
          gst: 100,
          artist: 1500,
          fleet: 800,
          margin: -15,
          flags: ['loss'],
        ),
      );
      await t.pumpWidget(host(w));
      expect(find.text('Loss — it cost more than it earned'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('profitValue_1'))).data,
        '-₹300',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('marginChip_1')),
          matching: find.text('-15%'),
        ),
        findsOneWidget,
      );
      final lossColor = t
          .widget<Text>(find.byKey(const Key('profitValue_1')))
          .style!
          .color;
      final healthy = _one(
        _work('2', gross: 21000, taxable: 20000, artist: 2000, margin: 90),
      );
      await t.pumpWidget(host(healthy));
      expect(
        t.widget<Text>(find.byKey(const Key('profitValue_2'))).style!.color,
        isNot(lossColor),
      );
    });

    testWidgets('a thin margin names the threshold', (t) async {
      _size(t);
      final w = _one(
        _work('2', taxable: 10000, artist: 8400, margin: 16, flags: ['thin']),
      );
      await t.pumpWidget(host(w));
      expect(find.text('Thin margin — under 20%'), findsOneWidget);
    });

    testWidgets('no costs recorded warns that the profit may be overstated', (
      t,
    ) async {
      _size(t);
      final w = _one(
        _work('4', taxable: 5000, margin: 100, flags: ['no_costs']),
      );
      await t.pumpWidget(host(w));
      expect(
        find.text('No costs recorded — profit may be overstated'),
        findsOneWidget,
      );
      expect(
        t.widget<Text>(find.byKey(const Key('profitValue_4'))).data,
        '₹5,000',
      );
    });

    testWidgets('a healthy work has no flag chips at all', (t) async {
      _size(t);
      await t.pumpWidget(
        host(_one(_work('3', taxable: 20000, artist: 2000, margin: 90))),
      );
      expect(find.byKey(const Key('flag_loss_3')), findsNothing);
      expect(find.byKey(const Key('flag_thin_3')), findsNothing);
      expect(find.byKey(const Key('flag_no_costs_3')), findsNothing);
      expect(find.byKey(const Key('flag_pending_costs_3')), findsNothing);
    });

    testWidgets('a work that earned nothing shows "—", not a percentage', (
      t,
    ) async {
      _size(t);
      await t.pumpWidget(
        host(_one(_work('5', artist: 300, profit: -300, flags: ['loss']))),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('marginChip_5')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no booked / discount / GST line when there is none', (
      t,
    ) async {
      _size(t);
      await t.pumpWidget(host(_one(_work('6', taxable: 1000, margin: 100))));
      expect(find.textContaining('Booked'), findsNothing);
    });

    testWidgets('Details opens the breakdown and closes it again', (t) async {
      _size(t);
      await t.pumpWidget(host(good));
      expect(find.byKey(const Key('profitDetailsBody_9')), findsNothing);
      await t.tap(find.byKey(const Key('profitDetails_9')));
      await t.pump();
      expect(find.byKey(const Key('profitDetailsBody_9')), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('Toll'), findsOneWidget);
      expect(find.text('Payout'), findsOneWidget);
      expect(find.text('₹100 not verified yet'), findsOneWidget);
      expect(
        find.text(
          "₹360 is a share of a whole-day cost, split equally over the driver's works that day",
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Customer pays ₹10,000 · received ₹4,000 · outstanding ₹6,000',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Salaries, rent and other overheads are not included.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('profitDetails_9')));
      await t.pump();
      expect(find.byKey(const Key('profitDetailsBody_9')), findsNothing);
    });

    testWidgets('fits a narrow phone with long names', (t) async {
      _size(t, w: 320, h: 1600);
      final w = _one(
        _work(
          '7',
          customer: 'A very very long customer name that goes on and on',
          taxable: 9523.81,
          gst: 476.19,
          gross: 10500,
          discount: 500,
          artist: 8000,
          pending: 8000,
          margin: 16,
          flags: ['thin', 'pending_costs'],
          artists: ['Anu Kurian', 'Fathima Beevi', 'Sreelakshmi Menon'],
        ),
      );
      await t.pumpWidget(host(w, width: 288));
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('profitDetails_7')));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('the formats', () {
    test(
      'rupees: whole numbers plain, paise only when there are some, Indian grouping',
      () {
        expect(profitRupees(0), '₹0');
        expect(profitRupees(1234567), '₹12,34,567');
        expect(profitRupees(1234.5), '₹1,234.50');
        expect(profitRupees(-300), '-₹300');
      },
    );

    test('margins: whole numbers plain, one decimal otherwise, — for none', () {
      expect(marginText(71), '71%');
      expect(marginText(85.9), '85.9%');
      expect(marginText(-20), '-20%');
      expect(marginText(null), '—');
    });

    test(
      'an export row lines up with its headers and spells out the flags',
      () {
        final w = _one(
          _work(
            '1',
            customer: 'Beena',
            gross: 10500,
            discount: 500,
            taxable: 9523.81,
            gst: 476.19,
            artist: 300,
            fleet: 460.01,
            freelance: 2000,
            pending: 100,
            margin: 71,
            flags: ['pending_costs', 'no_costs'],
          ),
        );
        final row = workProfitExportRow(w);
        expect(row.length, kWorkProfitExportHeaders.length);
        expect(row[1], 'BK-1');
        expect(row[2], 'Beena');
        expect(row[4], '9523.81');
        expect(row[5], '476.19');
        expect(row[6], '300');
        expect(row[7], '460.01');
        expect(row[8], '2000');
        expect(row[9], '2760.01');
        expect(row[10], '100');
        expect(row[11], '6763.80');
        expect(row[12], '71');
        expect(row.last, 'Costs not verified; No costs recorded');
        expect(workProfitExportRow(_one(_work('2', flags: [])))[12], '');
      },
    );
  });

  // ───────────── the screen ─────────────
  group('the screen', () {
    late _Fake fake;
    setUp(() => fake = _Fake());

    Widget app() => ProviderScope(
      overrides: [workProfitServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: WorkProfitScreen()),
      ),
    );

    Future<void> open(
      WidgetTester t, {
      double w = 1400,
      double h = 4200,
    }) async {
      _size(t, w: w, h: h);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
    }

    testWidgets('it asks for this month, newest first, and lists the works', (
      t,
    ) async {
      await open(t);
      final (from, to) = _thisMonth;
      expect(fake.queries.first.from, from);
      expect(fake.queries.first.to, to);
      expect(fake.queries.first.sort, 'date_desc');
      expect(fake.queries.first.page, 1);
      expect(find.byKey(const Key('workProfitTitle')), findsOneWidget);
      for (final id in ['1', '2', '3', '4']) {
        expect(find.byKey(Key('workProfitCard_$id')), findsOneWidget);
      }
    });

    testWidgets(
      'the summary: revenue without GST, costs (and what is unverified), profit, counts',
      (t) async {
        await open(t);
        expect(find.text('₹36,523.81'), findsOneWidget);
        expect(find.text('Costs · ₹100 not verified'), findsOneWidget);
        expect(find.text('₹12,300'), findsOneWidget);
        expect(find.text('Profit · 66.3%'), findsOneWidget);
        expect(find.text('₹24,223.81'), findsOneWidget);
        expect(find.text('Works · 1 loss · 1 thin'), findsOneWidget);
        expect(find.text('4'), findsWidgets);
      },
    );

    testWidgets('it says what profit leaves out and how revenue is measured', (
      t,
    ) async {
      await open(t);
      final note = t.widget<Text>(find.byKey(const Key('profitNote'))).data!;
      expect(note, contains('without the 5% GST'));
      expect(note, contains('Salaries and overheads are not included'));
    });

    testWidgets('with GST off the note does not mention GST', (t) async {
      _size(t);
      final f = fake;
      await t.pumpWidget(
        ProviderScope(
          overrides: [workProfitServiceProvider.overrideWithValue(_GstOff(f))],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: WorkProfitScreen()),
          ),
        ),
      );
      await t.pumpAndSettle();
      final note = t.widget<Text>(find.byKey(const Key('profitNote'))).data!;
      expect(note, isNot(contains('GST')));
      expect(find.text('Revenue'), findsOneWidget);
    });

    testWidgets('there is no "All time" — a period is at most a year', (
      t,
    ) async {
      await open(t);
      expect(find.byKey(const Key('periodAll')), findsNothing);
      expect(find.byKey(const Key('periodPrev')), findsOneWidget);
    });

    testWidgets(
      'the costs that sit on no work are shown beside the total, and the profit after them',
      (t) async {
        await open(t);
        expect(find.byKey(const Key('unallocatedNote')), findsOneWidget);
        expect(
          find.textContaining(
            '₹1,009.99 was spent in this period but is not on any of these works',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'artists ₹350 · fleet ₹659.99',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            "After it, the period's profit is ₹23,213.82.",
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('no such note when nothing is spent outside the works', (
      t,
    ) async {
      _size(t);
      fake.data = _works();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            workProfitServiceProvider.overrideWithValue(_NoLoose(fake)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: WorkProfitScreen()),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('unallocatedNote')), findsNothing);
    });

    testWidgets('the flag chips carry the counts; All starts selected', (
      t,
    ) async {
      await open(t);
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Loss (1)'), findsOneWidget);
      expect(find.text('Thin margin (1)'), findsOneWidget);
      expect(find.text('Costs not verified (1)'), findsOneWidget);
      expect(find.text('No costs yet (1)'), findsOneWidget);
      expect(
        t.widget<ChoiceChip>(find.byKey(const Key('flagChip_all'))).selected,
        isTrue,
      );
    });

    testWidgets(
      'Loss narrows to the loss-making works; All brings everything back',
      (t) async {
        await open(t);
        await t.tap(find.byKey(const Key('flagChip_loss')));
        await t.pumpAndSettle();
        expect(fake.queries.last.flag, 'loss');
        expect(find.byKey(const Key('workProfitCard_1')), findsOneWidget);
        expect(find.byKey(const Key('workProfitCard_3')), findsNothing);
        expect(
          t.widget<ChoiceChip>(find.byKey(const Key('flagChip_loss'))).selected,
          isTrue,
        );
        await t.tap(find.byKey(const Key('flagChip_all')));
        await t.pumpAndSettle();
        expect(fake.queries.last.flag, '');
        expect(find.byKey(const Key('workProfitCard_3')), findsOneWidget);
      },
    );

    testWidgets('the other chips ask for their own flag', (t) async {
      await open(t);
      for (final (key, flag) in [
        ('flagChip_thin', 'thin'),
        ('flagChip_pending_costs', 'pending_costs'),
        ('flagChip_no_costs', 'no_costs'),
      ]) {
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(fake.queries.last.flag, flag, reason: key);
      }
    });

    testWidgets(
      'searching waits for a pause, then asks once; the note about loose costs steps aside',
      (t) async {
        await open(t);
        final before = fake.queries.length;
        await t.enterText(find.byKey(const Key('searchField')), 'gi');
        await t.pump(const Duration(milliseconds: 100));
        await t.enterText(find.byKey(const Key('searchField')), 'gita');
        await t.pump(const Duration(milliseconds: 200));
        expect(fake.queries.length, before, reason: 'still typing');
        await t.pump(const Duration(milliseconds: 300));
        await t.pumpAndSettle();
        expect(fake.queries.length, before + 1);
        expect(fake.queries.last.search, 'gita');
        expect(find.byKey(const Key('workProfitCard_3')), findsOneWidget);
        expect(find.byKey(const Key('workProfitCard_1')), findsNothing);
        expect(
          find.byKey(const Key('unallocatedNote')),
          findsNothing,
          reason: 'it is about the whole period, not a search',
        );
      },
    );

    testWidgets('nothing matches: a plain message, not a blank page', (
      t,
    ) async {
      await open(t);
      await t.enterText(find.byKey(const Key('searchField')), 'zzzz');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('profitEmpty')), findsOneWidget);
      expect(find.text('No works match these filters'), findsOneWidget);
    });

    testWidgets('clearing the search brings everything back', (t) async {
      await open(t);
      await t.enterText(find.byKey(const Key('searchField')), 'zzzz');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.close));
      await t.pumpAndSettle();
      expect(fake.queries.last.search, '');
      expect(find.byKey(const Key('workProfitCard_1')), findsOneWidget);
    });

    testWidgets('an empty period says so', (t) async {
      fake.data = [];
      await open(t);
      expect(find.text('No works in this period'), findsOneWidget);
    });

    testWidgets(
      'sorting: the menu offers the orders and asks for the chosen one',
      (t) async {
        await open(t);
        await t.tap(find.byKey(const Key('sortMenu')));
        await t.pumpAndSettle();
        for (final label in [
          'Newest first',
          'Oldest first',
          'Lowest profit first',
          'Highest profit first',
          'Lowest margin first',
          'Highest margin first',
        ]) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        await t.tap(find.text('Lowest profit first').last);
        await t.pumpAndSettle();
        expect(fake.queries.last.sort, 'profit_asc');
        expect(
          find.text('Lowest profit first'),
          findsOneWidget,
          reason: 'the button names the order in use',
        );
      },
    );

    testWidgets(
      'paging: Next asks for page 2; a new filter goes back to page 1',
      (t) async {
        fake.pages = 2;
        await open(t);
        expect(find.text('Page 1 of 2'), findsOneWidget);
        await t.ensureVisible(find.text('Next'));
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
        expect(fake.queries.last.page, 2);
        await t.tap(find.byKey(const Key('flagChip_loss')));
        await t.pumpAndSettle();
        expect(fake.queries.last.page, 1);
        expect(fake.queries.last.flag, 'loss');
      },
    );

    testWidgets('sorting or searching from page 2 goes back to page 1', (
      t,
    ) async {
      fake.pages = 2;
      await open(t);
      await t.ensureVisible(find.text('Next'));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(fake.queries.last.page, 2);
      await t.tap(find.byKey(const Key('sortMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Highest margin first').last);
      await t.pumpAndSettle();
      expect(fake.queries.last.sort, 'margin_desc');
      expect(fake.queries.last.page, 1);
      await t.ensureVisible(find.text('Next'));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(fake.queries.last.page, 2);
      await t.enterText(find.byKey(const Key('searchField')), 'gita');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(fake.queries.last.search, 'gita');
      expect(fake.queries.last.page, 1);
      expect(
        fake.queries.last.sort,
        'margin_desc',
        reason: 'the sort order is kept',
      );
    });

    testWidgets('the previous month asks for that month', (t) async {
      await open(t);
      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      final now = FinancePeriodBar.thisMonth();
      final (from, to) = FinanceQuery.monthBounds(
        DateTime(now.year, now.month - 1),
      );
      expect((fake.queries.last.from, fake.queries.last.to), (from, to));
      expect(
        find.text(
          DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1)),
        ),
        findsWidgets,
      );
    });

    testWidgets(
      'a custom range asks for exactly those days, and the export is named after them',
      (t) async {
        await open(t, w: 900, h: 900);
        await t.tap(find.byKey(const Key('periodRange')));
        await t.pumpAndSettle();
        final grid = find.byType(DateRangePickerDialog);
        expect(grid, findsOneWidget);
        await t.tap(find.descendant(of: grid, matching: find.text('1')).first);
        await t.pump();
        await t.tap(find.descendant(of: grid, matching: find.text('2')).first);
        await t.pump();
        await t.tap(find.text('Save'));
        await t.pumpAndSettle();
        final now = FinancePeriodBar.thisMonth();
        final ym = DateFormat('yyyy-MM').format(now);
        expect(fake.queries.last.from, '$ym-01');
        expect(fake.queries.last.to, '$ym-02');
        expect(fake.queries.last.page, 1);
        await t.tap(find.byKey(const Key('exportButton')));
        await t.pumpAndSettle();
        expect(fake.exports.single.from, '$ym-01');
        expect(fake.exports.single.to, '$ym-02');
        expect(
          find.text('Export Work Profit $ym-01 to $ym-02'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'moving to another month keeps the filter and goes back to page 1',
      (t) async {
        fake.pages = 2;
        await open(t);
        await t.tap(find.byKey(const Key('flagChip_thin')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('periodPrev')));
        await t.pumpAndSettle();
        expect(fake.queries.last.flag, 'thin');
        expect(fake.queries.last.page, 1);
      },
    );

    testWidgets('refresh fetches again', (t) async {
      await open(t);
      final before = fake.queries.length;
      await t.tap(find.byIcon(Icons.refresh_rounded));
      await t.pumpAndSettle();
      expect(fake.queries.length, greaterThan(before));
    });

    testWidgets('while the next page loads, the last one stays on screen', (
      t,
    ) async {
      await open(t);
      fake.hold = Completer<void>();
      await t.tap(find.byKey(const Key('flagChip_loss')));
      await t.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const Key('workProfitCard_3')),
        findsOneWidget,
        reason: 'no blank flash',
      );
      fake.hold!.complete();
      await t.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a work opens its details from the list', (t) async {
      await open(t);
      await t.ensureVisible(find.byKey(const Key('profitDetails_3')));
      await t.tap(find.byKey(const Key('profitDetails_3')));
      await t.pump();
      expect(find.byKey(const Key('profitDetailsBody_3')), findsOneWidget);
    });

    // ── errors ──
    testWidgets(
      'the first load failing shows a plain error with a retry, never the raw exception',
      (t) async {
        fake.failPage = _serverError('load the work profit');
        await open(t);
        expect(find.text('Try again'), findsOneWidget);
        expect(
          find.text(
            'The server ran into a problem. Please try again in a moment.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('boom-secret'), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);
        fake.failPage = null;
        await t.tap(find.text('Try again'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('workProfitCard_1')), findsOneWidget);
      },
    );

    testWidgets(
      'a later load failing keeps the works on screen and says what happened',
      (t) async {
        await open(t);
        fake.failPage = _serverError('load the work profit');
        await t.tap(find.byKey(const Key('periodPrev')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('workProfitCard_1')),
          findsOneWidget,
          reason: 'the last good page stays',
        );
        expect(find.text('Try again'), findsWidgets);
        expect(find.textContaining('boom-secret'), findsNothing);
        expect(find.textContaining('DioException'), findsNothing);
      },
    );

    // ── export ──
    testWidgets(
      'Export asks for everything that matches the filters and offers the file',
      (t) async {
        await open(t);
        await t.tap(find.byKey(const Key('flagChip_loss')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('exportButton')));
        await t.pumpAndSettle();
        expect(fake.exports.length, 1);
        expect(fake.exports.single.flag, 'loss');
        expect(fake.exports.single.from, _thisMonth.$1);
        expect(
          find.text(
            'Export Work Profit ${DateFormat('MMMM yyyy').format(FinancePeriodBar.thisMonth())}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'exporting nothing says so instead of opening an empty dialog',
      (t) async {
        fake.data = [];
        await open(t);
        await t.tap(find.byKey(const Key('exportButton')));
        await t.pumpAndSettle();
        expect(
          find.text('Nothing to export for these filters.'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'an export failing shows a friendly message and leaves the button usable',
      (t) async {
        await open(t);
        fake.failExport = _serverError('export the work profit');
        await t.tap(find.byKey(const Key('exportButton')));
        await t.pumpAndSettle();
        expect(find.textContaining('boom-secret'), findsNothing);
        expect(find.textContaining('DioException'), findsNothing);
        expect(
          find.text(
            'The server ran into a problem. Please try again in a moment.',
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          t.widget<IconButton>(find.byKey(const Key('exportButton'))).onPressed,
          isNotNull,
        );
      },
    );

    // ── phone ──
    testWidgets(
      'on a phone nothing overflows, filtering and details included',
      (t) async {
        await open(t, w: 390, h: 4000);
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('flagChip_loss')));
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('profitDetails_1')));
        await t.tap(find.byKey(const Key('profitDetails_1')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('workProfitCard_1')), findsOneWidget);
      },
    );
  });
}

// A server whose GST is off.
class _GstOff extends _Fake {
  final _Fake inner;
  _GstOff(this.inner);
  @override
  Future<WorkProfitPage> getPage(WorkProfitQuery q) async {
    final j = _pageJson(gstOn: false);
    return WorkProfitPage.fromJson(j);
  }
}

// A server with no loose costs.
class _NoLoose extends _Fake {
  final _Fake inner;
  _NoLoose(this.inner);
  @override
  Future<WorkProfitPage> getPage(WorkProfitQuery q) async {
    final j = _pageJson(totals: _totals(unArtist: 0, unFleet: 0));
    return WorkProfitPage.fromJson(j);
  }
}
