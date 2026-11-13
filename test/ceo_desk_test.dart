import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/ceo/data/ceo_inbox.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/presentation/screens/ceo_desk_screen.dart';
import 'package:nizan_crm/features/ceo/presentation/screens/decision_rules_screen.dart';
import 'package:nizan_crm/features/ceo/services/ceo_service.dart';
import 'package:nizan_crm/features/ceo/services/decision_service.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/screens/ceo_decisions_screen.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/presentation/common_widgets/main_layout.dart' show leadershipDestinations, leadershipTabIndex;
import 'package:nizan_crm/presentation/common_widgets/sidebar.dart';

// The leaders' Decisions screen (Waiting / Decided / Log), the Decision rules screen, the manual log's safeties, and how the data
// reads from the server.

Map<String, dynamic> _req(String id, {String kind = 'spend_expense', String title = 'Studio ring lights', num? amount = 80000, String status = 'pending', Map<String, dynamic>? decision}) => {
      'id': id,
      'kind': kind,
      'status': status,
      'open': status == 'pending' || status == 'deferred',
      'title': title,
      'subtitle': 'Lights & Co',
      'department': 'Sales',
      'amount': amount,
      'requestedBy': {'id': 'u1', 'name': 'Saleem', 'role': 'sales'},
      'checkedBy': {'id': 'u2', 'name': 'Dev', 'role': 'accounts', 'label': 'Accounts'},
      'checkNote': 'Bills match',
      'waitingDays': 2,
      'decision': decision,
      'summary': [],
      'attachments': [],
      'canDecide': status == 'pending' || status == 'deferred',
    };

Map<String, dynamic> _decided(String id, String status, String title, String who, String role, String note) => _req(id, title: title, status: status, decision: {
      'by': {'id': 'x', 'name': who, 'role': role},
      'at': '2026-11-10T09:00:00.000Z',
      'note': note,
    });

class _FakeDecisions extends DecisionService {
  _FakeDecisions({List<Map<String, dynamic>>? waiting, List<Map<String, dynamic>>? decided, DecisionPolicy? policy})
      : waiting = waiting ?? [_req('r1'), _req('r2', kind: 'hiring_plan', title: 'Senior Stylist × 3', amount: null), _req('r3', kind: 'project_budget', title: 'Budget for Expo', amount: 350000)],
        decided = decided ?? [_decided('d1', 'approved', 'New van', 'Anita', 'ceo', 'Go'), _decided('d2', 'rejected', 'Gold chairs', 'Dev', 'executive_director', 'Too dear')],
        current = policy ?? const DecisionPolicy(canEdit: true),
        super(Dio());

  final List<Map<String, dynamic>> waiting;
  final List<Map<String, dynamic>> decided;
  DecisionPolicy current;
  final queues = <DecisionFilter>[];
  ({double? expense, double? payout, double? budget, bool hiring})? saved;
  DecisionConflict? refuseSave;

  @override
  Future<DecisionRequest> one(String id) async => DecisionRequest.fromJson({...waiting.firstWhere((r) => r['id'] == id, orElse: () => _req(id)), 'history': []});

  @override
  Future<DecisionQueue> queue(DecisionFilter f, {String? cursor}) async {
    queues.add(f);
    final source = f.decided ? decided : waiting;
    final items = source.where((r) => (f.kind == null || r['kind'] == f.kind!.wire) && (f.status == null || r['status'] == f.status!.name)).toList();
    final byKind = <String, int>{};
    for (final r in waiting) {
      byKind[r['kind'] as String] = (byKind[r['kind']] ?? 0) + 1;
    }
    return DecisionQueue.fromJson({
      'items': items,
      'counts': {'open': waiting.length, 'pending': waiting.length, 'deferred': 0, 'byKind': byKind, 'oldestDays': 2},
    });
  }

  @override
  Future<DecisionPolicy> policy() async => current;

  @override
  Future<DecisionPolicy> savePolicy({double? expense, double? payout, double? projectBudget, required bool hiring}) async {
    if (refuseSave != null) throw refuseSave!;
    saved = (expense: expense, payout: payout, budget: projectBudget, hiring: hiring);
    current = DecisionPolicy(expense: expense, payout: payout, projectBudget: projectBudget, hiringPlansNeedLeadership: hiring, on: expense != null || payout != null || projectBudget != null || hiring, summary: 'department expenses above ₹50,000', canEdit: true, updatedByName: 'Admin');
    return current;
  }
}

class _FakeMonthEnd extends MonthEndService {
  _FakeMonthEnd() : super(Dio());
  final saves = <({String status, String? note})>[];
  final removed = <String>[];

  @override
  Future<CeoDecision> saveDecision(CeoDecision d, {String? note}) async {
    saves.add((status: d.status, note: note));
    return d;
  }

  @override
  Future<void> deleteDecision(String id) async => removed.add(id);
}

Finder _k(String key) => find.byKey(Key(key));

Future<void> _pump(WidgetTester tester, Widget screen, {_FakeDecisions? fake, _FakeMonthEnd? monthEnd, Access? access, Size size = const Size(1000, 1200), List<CeoDecision>? log}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _FakeDecisions();
  final overrides = <Override>[
    decisionServiceProvider.overrideWithValue(f),
    ceoInboxProvider.overrideWith((ref) async => CeoInbox.fromJson({'items': [], 'needsYou': f.waiting.length, 'withTeam': 0, 'oldestTeamDays': 0})),
    monthEndServiceProvider.overrideWithValue(monthEnd ?? _FakeMonthEnd()),
    openDecisionsProvider.overrideWith((ref) async => log ?? [const CeoDecision(id: 'l1', month: 11, year: 2026, title: 'Buy a second van', amount: 800000, owner: 'Anita')]),
    if (access != null) effectiveAccessProvider.overrideWithValue(access),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: screen))));
  await tester.pumpAndSettle();
}

const _ceoAccess = Access(AppRole.ceo, {}, roleKey: 'ceo');
const _adminAccess = Access(AppRole.admin, {}, roleKey: 'admin');
const _accountsAccess = Access(AppRole.accounts, {}, roleKey: 'accounts');

void main() {
  phoneBar();
  group('how the server\'s decisions read', () {
    test('a request: its kind, the team\'s check, the deferral, and what a leader may do', () {
      final r = DecisionRequest.fromJson(_req('a', kind: 'project_budget', title: 'Budget'));
      expect(r.kind, DecisionKind.projectBudget);
      expect(r.kind.label, 'Project budget');
      expect(r.checkedLine, 'Verified by Accounts (Dev)');
      expect(r.isOpen, isTrue);
      expect(r.canDecide, isTrue);
      expect(r.requestedBy!.name, 'Saleem');
    });

    test('a proposal that nobody checked says nothing about it; an unknown kind or status does not crash', () {
      final j = _req('a', kind: 'project_proposal')..remove('checkedBy');
      final r = DecisionRequest.fromJson(j);
      expect(r.checkedBy, isNull);
      expect(r.checkedLine, '');
      expect(DecisionRequest.fromJson({'id': 'x', 'kind': 'brand_new', 'status': 'odd', 'title': 'T'}).status, DecisionStatus.pending);
    });

    test('a settled request cannot be decided on, whatever canDecide says', () {
      final r = DecisionRequest.fromJson({..._decided('d', 'approved', 'T', 'Anita', 'ceo', 'ok'), 'canDecide': true});
      expect(r.isOpen, isFalse);
      expect(r.canDecide, isFalse);
      expect(r.decision!.by.nameWithTitle, 'Anita (CEO)');
      expect(r.decision!.note, 'ok');
    });

    test('a deferral to a future date is "now deferred"; once the date has passed it is back', () {
      final later = DecisionRequest.fromJson({..._req('a', status: 'deferred'), 'deferredUntil': DateTime.now().add(const Duration(days: 2)).toIso8601String()});
      final past = DecisionRequest.fromJson({..._req('a', status: 'deferred'), 'deferredUntil': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()});
      expect(later.isDeferredNow, isTrue);
      expect(past.isDeferredNow, isFalse);
    });

    test('a refusal that explains itself is a DecisionConflict; a server error is not', () {
      DioException e(int status, Object data) => DioException(requestOptions: RequestOptions(path: '/x'), response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data));
      final c = conflictFrom(e(409, {'code': 'ALREADY_DECIDED', 'message': 'Already approved by Dev', 'decision': {'by': {'name': 'Dev', 'role': 'executive_director'}, 'note': 'ok'}}))!;
      expect(c.isSettled, isTrue);
      expect(c.message, 'Already approved by Dev');
      expect(c.decision!.by.title, 'Executive Director');
      expect(conflictFrom(e(400, {'code': 'NOTE_REQUIRED', 'message': 'Say why it is rejected.'}))!.isSettled, isFalse);
      expect(conflictFrom(e(500, {'message': 'boom'})), isNull);
      expect(conflictFrom(e(500, {'code': 'SOMETHING', 'message': 'boom'})), isNull, reason: 'only a 409 / 400 is the server explaining itself');
      expect(conflictFrom(e(403, {'code': 'LEADERSHIP_ONLY', 'message': 'no'})), isNull);
      expect(conflictFrom(e(409, {'message': 'no code'})), isNull);
    });

    test('the rules: limits, the switch, and whether anyone could decide', () {
      final p = DecisionPolicy.fromJson({'spendLimits': {'expense': 50000, 'payout': null, 'projectBudget': 100000}, 'hiringPlansNeedLeadership': true, 'on': true, 'summary': 'x', 'canEdit': true, 'hasLeadership': false});
      expect(p.expense, 50000);
      expect(p.payout, isNull);
      expect(p.hiringPlansNeedLeadership, isTrue);
      expect(p.hasLeadership, isFalse);
      expect(DecisionPolicy.fromJson(const {}).on, isFalse);
    });

    test('the inbox carries the desk: counts, the first few, the last decided, the manual log', () {
      final i = CeoInbox.fromJson({
        'items': [],
        'needsYou': 2,
        'withTeam': 0,
        'oldestTeamDays': 0,
        'decisions': {'open': 2, 'pending': 1, 'deferred': 1, 'byKind': {'spend_expense': 2}, 'oldestDays': 4, 'preview': [_req('a')]},
        'recent': [_decided('d', 'approved', 'T', 'Anita', 'ceo', '')],
        'log': {'open': 3},
      });
      expect(i.desk.pending, 1);
      expect(i.desk.deferred, 1);
      expect(i.desk.byKind['spend_expense'], 2);
      expect(i.preview.single.id, 'a');
      expect(i.recent.single.decision!.by.name, 'Anita');
      expect(i.logOpen, 3);
      // an older server sends none of it
      final old = CeoInbox.fromJson({'items': [], 'needsYou': 0, 'withTeam': 0, 'oldestTeamDays': 0});
      expect(old.preview, isEmpty);
      expect(old.desk.open, 0);
      expect(old.logOpen, 0);
    });
  });

  group('the Decisions screen', () {
    testWidgets('Waiting: a card for each, the count on the tab, and a filter for each kind there is', (tester) async {
      await _pump(tester, const CeoDeskScreen());
      expect(_k('ceo_decision_r1'), findsOneWidget);
      expect(find.text('Senior Stylist × 3'), findsOneWidget);
      expect(find.text('Budget for Expo'), findsOneWidget);
      expect(find.descendant(of: _k('ceo_tab_waiting_count'), matching: find.text('3')), findsOneWidget);
      expect(_k('ceo_kind_spend_expense'), findsOneWidget);
      expect(_k('ceo_kind_hiring_plan'), findsOneWidget);
      expect(_k('ceo_kind_spend_payout'), findsNothing, reason: 'none of those are waiting');
    });

    testWidgets('filtering by kind shows only that kind; All brings them back', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, const CeoDeskScreen(), fake: fake);
      await tester.tap(_k('ceo_kind_hiring_plan'));
      await tester.pumpAndSettle();
      expect(find.text('Senior Stylist × 3'), findsOneWidget);
      expect(find.text('Studio ring lights'), findsNothing);
      await tester.tap(_k('ceo_kind_all'));
      await tester.pumpAndSettle();
      expect(find.text('Studio ring lights'), findsOneWidget);
    });

    testWidgets('nothing waiting: says so', (tester) async {
      await _pump(tester, const CeoDeskScreen(), fake: _FakeDecisions(waiting: []));
      expect(_k('ceo_desk_empty'), findsOneWidget);
    });

    testWidgets('Decided: who decided, when and why — either leader — and an outcome filter', (tester) async {
      await _pump(tester, const CeoDeskScreen());
      await tester.tap(_k('ceo_tab_decided'));
      await tester.pumpAndSettle();
      expect(find.text('New van'), findsOneWidget);
      expect(_text(tester, _k('ceo_outcome_line_d1')).contains('Anita (CEO)'), isTrue);
      expect(_text(tester, _k('ceo_outcome_line_d1')).contains('“Go”'), isTrue);
      expect(_text(tester, _k('ceo_outcome_line_d2')).contains('Dev (Executive Director)'), isTrue);
      expect(_k('ceo_approve_d1'), findsNothing, reason: 'a decided card has no buttons');
      await tester.tap(_k('ceo_decided_rejected'));
      await tester.pumpAndSettle();
      expect(find.text('New van'), findsNothing);
      expect(find.text('Gold chairs'), findsOneWidget);
    });

    testWidgets('the Log tab is the manual log, and it opens from a link (?tab=log)', (tester) async {
      await _pump(tester, deskFromUri(Uri.parse('/ceo/decisions?tab=log')));
      expect(find.text('Buy a second van'), findsOneWidget);
    });

    testWidgets('a notification\'s link opens that decision at once', (tester) async {
      await _pump(tester, deskFromUri(Uri.parse('/ceo/decisions?focus=r1')));
      expect(_k('ceo_detail_title'), findsOneWidget);
    });

    testWidgets('a phone (360) fits; a laptop shows two cards side by side', (tester) async {
      await _pump(tester, const CeoDeskScreen(), size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      await _pump(tester, const CeoDeskScreen(), size: const Size(1280, 800));
      expect(tester.takeException(), isNull);
      final a = tester.getTopLeft(_k('ceo_decision_r1'));
      final b = tester.getTopLeft(_k('ceo_decision_r2'));
      expect(b.dx, greaterThan(a.dx + 300));
    });
  });

  group('the manual decisions log', () {
    testWidgets('a status changes only through the menu, with a confirmation and an optional note — never by a stray tap', (tester) async {
      final me = _FakeMonthEnd();
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true), monthEnd: me);
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      expect(me.saves, isEmpty, reason: 'tapping the chip does not change anything by itself');
      await tester.tap(find.text('Mark approved'));
      await tester.pumpAndSettle();
      expect(me.saves, isEmpty, reason: 'asks first');
      await tester.enterText(_k('decision_status_note'), 'Agreed in the meeting');
      await tester.tap(_k('decision_status_confirm'));
      await tester.pumpAndSettle();
      expect(me.saves.single.status, 'approved');
      expect(me.saves.single.note, 'Agreed in the meeting');
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      final me = _FakeMonthEnd();
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true), monthEnd: me);
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark rejected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(me.saves, isEmpty);
    });

    testWidgets('there is no delete icon on a card: removing is in the menu and asks first', (tester) async {
      final me = _FakeMonthEnd();
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true), monthEnd: me);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      await tester.tap(_k('decision_more_l1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from the log'));
      await tester.pumpAndSettle();
      expect(me.removed, isEmpty, reason: 'asks first');
      await tester.tap(_k('decision_remove_confirm'));
      await tester.pumpAndSettle();
      expect(me.removed, ['l1']);
    });

    testWidgets('the add button says what it does', (tester) async {
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true));
      expect(find.text('Add to log'), findsOneWidget);
    });

    testWidgets('someone who may not settle an entry (Accounts) cannot open the status menu', (tester) async {
      final me = _FakeMonthEnd();
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true, canSettle: false), monthEnd: me);
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      expect(find.text('Mark approved'), findsNothing);
    });

    testWidgets('who settled an entry, when and why is shown on it', (tester) async {
      final settled = CeoDecision(id: 'l2', month: 11, year: 2026, title: 'Hire a trainer', status: 'approved', decidedByName: 'Anita', decisionNote: 'Yes', decidedAt: DateTime(2026, 11, 10));
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true), log: [settled]);
      expect(_text(tester, _k('decision_settled_l2')), 'Approved by Anita · 10 Nov: “Yes”');
    });

    testWidgets('an entry nobody has settled shows no such line', (tester) async {
      await _pump(tester, const CeoDecisionsScreen(initialOpenOnly: true));
      expect(_k('decision_settled_l1'), findsNothing);
    });
  });

  group('Decision rules', () {
    testWidgets('nothing is set: says "nothing is escalated", with empty (off) boxes and the switch off', (tester) async {
      await _pump(tester, const DecisionRulesScreen(), access: _adminAccess);
      expect(find.text('Currently: nothing is escalated.'), findsOneWidget);
      expect(tester.widget<TextField>(_k('rules_expense')).controller!.text, '');
      expect(tester.widget<SwitchListTile>(_k('rules_hiring')).value, isFalse);
      expect(tester.widget<FilledButton>(_k('rules_save')).onPressed, isNull, reason: 'nothing to save yet');
    });

    testWidgets('entering amounts and saving sends them (commas and ₹ are fine); a blank box is off', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, const DecisionRulesScreen(), fake: fake, access: _adminAccess);
      await tester.enterText(_k('rules_expense'), '₹50,000');
      await tester.enterText(_k('rules_budget'), '100000');
      await tester.tap(_k('rules_hiring'));
      await tester.pump();
      await tester.tap(_k('rules_save'));
      await tester.pumpAndSettle();
      expect(fake.saved!.expense, 50000);
      expect(fake.saved!.payout, isNull);
      expect(fake.saved!.budget, 100000);
      expect(fake.saved!.hiring, isTrue);
      expect(find.textContaining('Currently: department expenses above'), findsOneWidget);
    });

    testWidgets('something that is not a number is refused on the spot, nothing is sent', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, const DecisionRulesScreen(), fake: fake, access: _adminAccess);
      await tester.enterText(_k('rules_payout'), 'lots');
      await tester.pump();
      await tester.tap(_k('rules_save'));
      await tester.pumpAndSettle();
      expect(fake.saved, isNull);
      expect(_k('rules_error'), findsOneWidget);
    });

    testWidgets('no CEO / Executive Director login yet: the server\'s refusal is shown, and the screen says so up front', (tester) async {
      final fake = _FakeDecisions(policy: const DecisionPolicy(canEdit: true, hasLeadership: false))
        ..refuseSave = const DecisionConflict(code: 'NO_LEADERSHIP_ACCOUNT', message: 'There is no CEO or Executive Director login yet.');
      await _pump(tester, const DecisionRulesScreen(), fake: fake, access: _adminAccess);
      expect(_k('rules_no_leader'), findsOneWidget);
      await tester.enterText(_k('rules_expense'), '1000');
      await tester.pump();
      await tester.tap(_k('rules_save'));
      await tester.pumpAndSettle();
      expect(find.text('There is no CEO or Executive Director login yet.'), findsWidgets);
    });

    testWidgets('someone who cannot change them (Accounts) can read them, not edit', (tester) async {
      await _pump(tester, const DecisionRulesScreen(), fake: _FakeDecisions(policy: const DecisionPolicy(canEdit: false, expense: 50000, on: true, summary: 'department expenses above ₹50,000')), access: _accountsAccess);
      expect(_k('rules_read_only'), findsOneWidget);
      expect(_k('rules_save'), findsNothing);
      expect(tester.widget<TextField>(_k('rules_expense')).enabled, isFalse);
      expect(find.textContaining('department expenses above ₹50,000'), findsOneWidget);
    });

    testWidgets('a leader can edit them too', (tester) async {
      await _pump(tester, const DecisionRulesScreen(), access: _ceoAccess);
      expect(tester.widget<TextField>(_k('rules_expense')).enabled, isTrue);
    });
  });

  group('the sidebar', () {
    Future<void> pumpSidebar(WidgetTester tester, {int waiting = 0}) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Row(children: [
              SizedBox(
                width: 250,
                child: Sidebar(
                  fleetExpanded: false, fleetUserCollapsed: false, onFleetExpandToggle: (_) {},
                  accountsExpanded: false, accountsUserCollapsed: false, onAccountsExpandToggle: (_) {},
                  operationsExpanded: false, operationsUserCollapsed: false, onOperationsExpandToggle: (_) {},
                  administrativeExpanded: false, administrativeUserCollapsed: false, onAdministrativeExpandToggle: (_) {},
                  inventoryExpanded: false, inventoryUserCollapsed: false, onInventoryExpandToggle: (_) {},
                  salesExpanded: false, salesUserCollapsed: false, onSalesExpandToggle: (_) {},
                  hrExpanded: false, hrUserCollapsed: false, onHrExpandToggle: (_) {},
                  financeExpanded: false, financeUserCollapsed: false, onFinanceExpandToggle: (_) {},
                  itExpanded: false, itUserCollapsed: false, onItExpandToggle: (_) {},
                  stylistExpanded: false, stylistUserCollapsed: false, onStylistExpandToggle: (_) {},
                  marketingExpanded: false, marketingUserCollapsed: false, onMarketingExpandToggle: (_) {},
                  contentExpanded: false, contentUserCollapsed: false, onContentExpandToggle: (_) {},
                ),
              ),
            ]),
          ),
        ),
        GoRoute(path: '/ceo/rules', builder: (context, state) => const Scaffold(body: Text('RULES PAGE'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'Dev', email: 'd@x', role: 'executive_director', permissions: const ['ceo', 'planning'])),
          ceoInboxProvider.overrideWith((ref) async => CeoInbox.fromJson({'items': [], 'needsYou': waiting, 'withTeam': 0, 'oldestTeamDays': 0})),
        ],
        child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the Executive Director\'s menu: Home, Decisions, Decision rules — no help desk or backup', (tester) async {
      await pumpSidebar(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Decisions'), findsOneWidget);
      expect(find.text('Decision rules'), findsOneWidget);
      expect(find.text('Support'), findsNothing);
      expect(find.text('Backup'), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('the number waiting is on Decisions', (tester) async {
      await pumpSidebar(tester, waiting: 4);
      expect(find.descendant(of: _k('sidebar_decisions_badge'), matching: find.text('4')), findsOneWidget);
    });

    testWidgets('nothing waiting: no badge', (tester) async {
      await pumpSidebar(tester);
      expect(_k('sidebar_decisions_badge'), findsNothing);
    });

    testWidgets('Decision rules opens the rules page', (tester) async {
      await pumpSidebar(tester);
      await tester.tap(find.text('Decision rules'));
      await tester.pumpAndSettle();
      expect(find.text('RULES PAGE'), findsOneWidget);
    });
  });
}

String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

// ── the phone's bottom bar ───────────────────────────────────────────────────

void phoneBar() {
  group('the leaders\' phone bottom bar', () {
    test('Home, Decisions and Money each own their screens; every other screen is under More — nothing falls through to Home', () {
      expect(leadershipTabIndex('/ceo'), 0);
      expect(leadershipTabIndex('/ceo/decisions'), 1);
      expect(leadershipTabIndex('/ceo/rules'), 1);
      expect(leadershipTabIndex('/accounts/dashboard'), 2);
      expect(leadershipTabIndex('/accounts/work-profit'), 2);
      expect(leadershipTabIndex('/company-finance/month-end'), 2);
      for (final p in ['/projects', '/monthly-objectives', '/reports', '/hr/analytics', '/marketing/insights', '/notifications', '/profile', '/', '/reviews']) {
        expect(leadershipTabIndex(p), 3, reason: p);
      }
    });

    testWidgets('four tabs; the number waiting is a badge on Decisions, and none means no badge', (tester) async {
      Future<void> pump(int waiting) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(bottomNavigationBar: NavigationBar(selectedIndex: 0, destinations: leadershipDestinations(waiting))),
        ));
      }

      await pump(5);
      for (final label in ['Home', 'Decisions', 'Money', 'More']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.widget<Badge>(_k('ceo_nav_badge')).isLabelVisible, isTrue);
      expect(find.descendant(of: _k('ceo_nav_badge'), matching: find.text('5')), findsOneWidget);
      await pump(0);
      expect(tester.widget<Badge>(_k('ceo_nav_badge')).isLabelVisible, isFalse);
    });
  });
}
